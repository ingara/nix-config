#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "prompt-toolkit>=3.0",
#   "questionary>=2.1.1",
#   "rich>=15.0.0",
# ]
# ///

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import questionary
from prompt_toolkit.key_binding import KeyBindings, merge_key_bindings
from prompt_toolkit.keys import Keys
from prompt_toolkit.output.defaults import create_output
from rich import box
from rich.console import Console
from rich.status import Status
from rich.table import Table
from rich.text import Text


CONSOLE = Console(stderr=True)


@dataclass
class HerdrSignal:
    status: str
    detail: str
    live_paths: list[str] = field(default_factory=list)


@dataclass
class Guard:
    name: str
    passed: bool
    detail: str


@dataclass
class Checkout:
    path: str
    root: str
    repository: str
    name: str
    classification: str
    tier: int | None = None
    branch: str | None = None
    default_branch: str | None = None
    merge_target: str | None = None
    upstream: str | None = None
    clean: bool | None = None
    merged: bool | None = None
    unmerged_commits: int | None = None
    unpushed_commits: int | None = None
    dirty_line_count: int = 0
    dirty_paths: list[str] = field(default_factory=list)
    last_activity: str | None = None
    age_hours: float | None = None
    main_repository: str | None = None
    eligible: bool = False
    guards: list[Guard] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


@dataclass
class Counts:
    discovered: int = 0
    live: int = 0
    tier1: int = 0
    tier1_eligible: int = 0
    tier2: int = 0
    tier3: int = 0
    unclassifiable: int = 0


@dataclass
class SweepReport:
    generated_at: str
    roots: list[str]
    min_age_hours: float
    herdr: HerdrSignal
    counts: Counts
    checkouts: list[Checkout]


def die(message: str, code: int = 1) -> None:
    print(f"worktree-sweep: {message}", file=sys.stderr)
    raise SystemExit(code)


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )


def git(path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return run(["git", "-C", str(path), *args])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Report and interactively remove orphan Git worktrees.",
        epilog=(
            "Removal follows git semantics: gitignored files inside an "
            "otherwise clean checkout are deleted with it."
        ),
    )
    parser.add_argument(
        "--root",
        action="append",
        type=Path,
        help="worktree root containing <repository>/<checkout> directories",
    )
    parser.add_argument(
        "--min-age-hours",
        type=float,
        default=48.0,
        help="minimum idle age required for removal (default: 48)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="write the complete classification as JSON to stdout",
    )
    parser.add_argument(
        "--report-only",
        action="store_true",
        help="show the report without opening the interactive picker",
    )
    parser.add_argument(
        "--all",
        dest="show_all",
        action="store_true",
        help="include live herdr workspaces as disabled picker rows",
    )
    args = parser.parse_args()
    if args.min_age_hours < 0:
        parser.error("--min-age-hours must be non-negative")
    return args


def resolve_roots(arguments: list[Path] | None) -> list[Path]:
    roots = arguments or [Path("~/.herdr/worktrees").expanduser()]
    resolved: list[Path] = []
    seen: set[Path] = set()
    for root in roots:
        candidate = root.expanduser().resolve()
        if not candidate.is_dir():
            die(f"worktree root does not exist or is not a directory: {candidate}", 2)
        if candidate not in seen:
            resolved.append(candidate)
            seen.add(candidate)
    return resolved


def load_herdr_signal() -> HerdrSignal:
    binary = shutil.which("herdr")
    if binary is None:
        return HerdrSignal(
            status="unavailable",
            detail="herdr is not on PATH; liveness filtering was skipped",
        )

    result = run([binary, "workspace", "list"])
    if result.returncode != 0:
        detail = result.stderr.strip() or f"exit status {result.returncode}"
        return HerdrSignal(
            status="failed",
            detail=f"herdr workspace list failed ({detail}); liveness filtering was skipped",
        )

    try:
        payload: Any = json.loads(result.stdout)
        workspaces = payload["result"]["workspaces"]
        if not isinstance(workspaces, list):
            raise TypeError("workspaces is not a list")
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        return HerdrSignal(
            status="failed",
            detail=f"herdr returned unexpected JSON ({error}); liveness filtering was skipped",
        )

    # Tolerate individual malformed entries: one bad workspace must not
    # discard the liveness protection of every other live checkout.
    paths: set[str] = set()
    malformed = 0
    for workspace in workspaces:
        try:
            raw = Path(workspace["worktree"]["checkout_path"]).expanduser()
        except (KeyError, TypeError):
            malformed += 1
            continue
        if not raw.is_absolute():
            malformed += 1
            continue
        paths.add(str(raw.resolve()))
    detail = f"{len(paths)} live workspace checkout(s) reported"
    if malformed:
        detail += f"; {malformed} malformed entr{'y' if malformed == 1 else 'ies'} ignored"

    return HerdrSignal(
        status="available",
        detail=detail,
        live_paths=sorted(paths),
    )


def discover_directories(roots: list[Path]) -> list[tuple[Path, Path, str, str]]:
    directories: list[tuple[Path, Path, str, str]] = []
    seen: set[Path] = set()
    for root in roots:
        try:
            repositories = sorted(root.iterdir(), key=lambda path: path.name)
        except OSError as error:
            die(f"cannot read worktree root {root}: {error}", 2)
        for repository in repositories:
            if not repository.is_dir():
                continue
            try:
                children = sorted(repository.iterdir(), key=lambda path: path.name)
            except OSError:
                continue
            for checkout in children:
                if not checkout.is_dir():
                    continue
                resolved = checkout.resolve()
                if resolved in seen:
                    continue
                seen.add(resolved)
                directories.append((root, resolved, repository.name, checkout.name))
    return directories


def format_timestamp(timestamp: float) -> str:
    return datetime.fromtimestamp(timestamp).astimezone().isoformat(timespec="seconds")


def get_last_activity(path: Path) -> tuple[float | None, str | None]:
    timestamps: list[float] = []
    try:
        for entry in path.iterdir():
            try:
                timestamps.append(entry.stat().st_mtime)
            except OSError:
                continue
    except OSError as error:
        return None, f"could not inspect top-level mtimes: {error}"

    commit = git(path, "show", "-s", "--format=%ct", "HEAD")
    if commit.returncode == 0:
        try:
            timestamps.append(float(commit.stdout.strip()))
        except ValueError:
            return None, "git returned an invalid HEAD commit timestamp"
    elif not timestamps:
        return None, commit.stderr.strip() or "could not determine last activity"

    if not timestamps:
        return None, "checkout has no top-level entries or HEAD commit timestamp"
    return max(timestamps), None


def resolve_merge_target(path: Path) -> tuple[str | None, str | None, str | None]:
    symbolic = git(path, "symbolic-ref", "refs/remotes/origin/HEAD")
    target = "origin/main"
    default_branch = "main"
    if symbolic.returncode == 0:
        reference = symbolic.stdout.strip()
        prefix = "refs/remotes/"
        if reference.startswith(prefix):
            target = reference.removeprefix(prefix)
            default_branch = target.removeprefix("origin/")

    verify = git(path, "rev-parse", "--verify", "--quiet", f"{target}^{{commit}}")
    if verify.returncode != 0:
        return None, None, "no resolvable origin default branch"
    return target, default_branch, None


def current_branch(path: Path) -> str | None:
    result = git(path, "symbolic-ref", "--quiet", "--short", "HEAD")
    return result.stdout.strip() if result.returncode == 0 else None


def count_revisions(path: Path, revision_range: str) -> tuple[int | None, str | None]:
    result = git(path, "rev-list", "--count", revision_range)
    if result.returncode != 0:
        return None, result.stderr.strip() or f"could not count {revision_range}"
    try:
        return int(result.stdout.strip()), None
    except ValueError:
        return None, f"git returned an invalid count for {revision_range}"


def resolve_upstream(path: Path) -> str | None:
    result = git(
        path,
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
    )
    return result.stdout.strip() if result.returncode == 0 else None


def resolve_main_repository(path: Path) -> tuple[Path | None, str | None]:
    result = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if result.returncode != 0:
        return None, result.stderr.strip() or "could not resolve the common Git directory"
    common_directory = Path(result.stdout.strip()).resolve()
    if common_directory.name != ".git" or not common_directory.is_dir():
        return None, f"unsupported common Git directory: {common_directory}"
    main_repository = common_directory.parent
    if not main_repository.is_dir():
        return None, f"main repository is unavailable: {main_repository}"
    if main_repository == path.resolve():
        return None, "primary working tree, not a linked worktree"
    return main_repository, None


def lsof_guard(path: Path) -> Guard:
    binary = shutil.which("lsof")
    if binary is None:
        return Guard("lsof", False, "lsof is unavailable")

    result = run([binary, "+D", str(path)])
    if result.returncode == 1 and not result.stdout.strip() and not result.stderr.strip():
        return Guard("lsof", True, "no open handles found")
    if result.returncode == 0 and result.stdout.strip():
        return Guard("lsof", False, "open handles or working directories found")
    detail = result.stderr.strip() or f"unexpected exit status {result.returncode}"
    return Guard("lsof", False, f"lsof could not verify the checkout ({detail})")


def apply_removal_guards(
    checkout: Checkout,
    path: Path,
    min_age_hours: float,
) -> None:
    age_passed = (
        checkout.age_hours is not None and checkout.age_hours >= min_age_hours
    )
    age_detail = (
        f"idle for {checkout.age_hours:.2f}h; minimum is {min_age_hours:g}h"
        if checkout.age_hours is not None
        else "last activity could not be determined"
    )
    checkout.guards = [
        Guard("age", age_passed, age_detail),
        lsof_guard(path),
        Guard(
            "main_repository",
            checkout.main_repository is not None,
            (
                f"resolved to {checkout.main_repository}"
                if checkout.main_repository
                else "main repository could not be resolved"
            ),
        ),
    ]
    checkout.eligible = all(guard.passed for guard in checkout.guards)


def dirty_paths(porcelain_lines: list[str]) -> list[str]:
    paths: list[str] = []
    for line in porcelain_lines[:5]:
        paths.append(line[3:] if len(line) > 3 else line)
    return paths


def classify_checkout(
    root: Path,
    path: Path,
    repository: str,
    name: str,
    live_paths: set[str],
    min_age_hours: float,
) -> Checkout:
    base = Checkout(
        path=str(path),
        root=str(root),
        repository=repository,
        name=name,
        classification="unclassifiable",
    )

    if str(path) in live_paths:
        base.classification = "live"
        return base
    if not (path / ".git").exists():
        base.errors.append("directory is not a Git worktree")
        return base

    status = git(path, "status", "--porcelain")
    if status.returncode != 0:
        base.errors.append(status.stderr.strip() or "git status failed")
        return base

    lines = status.stdout.splitlines()
    base.clean = not lines
    base.branch = current_branch(path)
    base.merge_target, base.default_branch, target_error = resolve_merge_target(path)
    if target_error:
        base.errors.append(target_error)

    activity, activity_error = get_last_activity(path)
    if activity is not None:
        base.last_activity = format_timestamp(activity)
        base.age_hours = round(max(0.0, (time.time() - activity) / 3600), 2)
    if activity_error:
        base.errors.append(activity_error)

    main_repository, main_error = resolve_main_repository(path)
    if main_repository:
        base.main_repository = str(main_repository)
    if main_error:
        base.errors.append(main_error)

    if not base.clean:
        base.classification = "tier3"
        base.tier = 3
        base.dirty_line_count = len(lines)
        base.dirty_paths = dirty_paths(lines)
        return base

    base.upstream = resolve_upstream(path)
    if base.merge_target:
        merged = git(path, "merge-base", "--is-ancestor", "HEAD", base.merge_target)
        if merged.returncode in (0, 1):
            base.merged = merged.returncode == 0
        else:
            base.errors.append(
                merged.stderr.strip() or "could not compare HEAD to the merge target"
            )
        base.unmerged_commits, count_error = count_revisions(
            path, f"{base.merge_target}..HEAD"
        )
        if count_error:
            base.errors.append(count_error)

    if base.upstream:
        base.unpushed_commits, count_error = count_revisions(
            path, f"{base.upstream}..HEAD"
        )
        if count_error:
            base.errors.append(count_error)

    if base.merge_target and base.merged is True:
        base.classification = "tier1"
        base.tier = 1
        apply_removal_guards(base, path, min_age_hours)
        return base

    base.classification = "tier2"
    base.tier = 2
    apply_removal_guards(base, path, min_age_hours)
    if base.branch is None:
        # No branch means the worktree HEAD is the only ref to unmerged
        # commits; removal would make them unreachable.
        base.guards.append(
            Guard("branch", False, "detached HEAD; commits would become unreachable")
        )
        base.eligible = False
    return base


def scan_checkouts(
    roots: list[Path],
    min_age_hours: float,
    status: Status | None = None,
) -> tuple[HerdrSignal, list[Checkout]]:
    if status:
        status.update("Reading herdr workspace state...")
    herdr = load_herdr_signal()
    live_paths = set(herdr.live_paths)
    if status:
        status.update("Discovering worktree checkouts...")
    directories = discover_directories(roots)
    checkouts: list[Checkout] = []
    for index, (root, path, repository, name) in enumerate(directories, start=1):
        if status:
            status.update(
                f"Scanning {repository}/{name} ({index}/{len(directories)})..."
            )
        checkouts.append(
            classify_checkout(
                root,
                path,
                repository,
                name,
                live_paths,
                min_age_hours,
            )
        )
    return herdr, checkouts


def build_report(roots: list[Path], min_age_hours: float) -> SweepReport:
    if sys.stderr.isatty():
        with CONSOLE.status("Discovering worktree checkouts...") as status:
            herdr, checkouts = scan_checkouts(roots, min_age_hours, status)
    else:
        herdr, checkouts = scan_checkouts(roots, min_age_hours)

    counts = Counts(discovered=len(checkouts))
    for checkout in checkouts:
        if checkout.classification == "live":
            counts.live += 1
        elif checkout.classification == "tier1":
            counts.tier1 += 1
            counts.tier1_eligible += int(checkout.eligible)
        elif checkout.classification == "tier2":
            counts.tier2 += 1
        elif checkout.classification == "tier3":
            counts.tier3 += 1
        else:
            counts.unclassifiable += 1

    return SweepReport(
        generated_at=datetime.now().astimezone().isoformat(timespec="seconds"),
        roots=[str(root) for root in roots],
        min_age_hours=min_age_hours,
        herdr=herdr,
        counts=counts,
        checkouts=checkouts,
    )


def plural(count: int, noun: str) -> str:
    return f"{count} {noun}" + ("" if count == 1 else "s")


def pending_summary(checkout: Checkout) -> str:
    parts: list[str] = []
    if checkout.unmerged_commits is not None:
        parts.append(plural(checkout.unmerged_commits, "unmerged commit"))
    if checkout.upstream is None:
        parts.append("no upstream")
    elif checkout.unpushed_commits is not None:
        parts.append(plural(checkout.unpushed_commits, "unpushed commit"))
    if checkout.merge_target is None:
        parts.append("no origin default branch")
    return ", ".join(parts) or "merge state unavailable"


def checkout_summary(checkout: Checkout) -> str:
    if checkout.classification in ("tier1", "tier2"):
        failures = [
            f"{guard.name}: {guard.detail}"
            for guard in checkout.guards
            if not guard.passed
        ]
        summary = (
            f"merged into {checkout.merge_target}"
            if checkout.classification == "tier1"
            else pending_summary(checkout)
        )
        return (
            f"{summary}; eligible"
            if not failures
            else f"{summary}; blocked: {'; '.join(failures)}"
        )
    if checkout.classification == "tier3":
        paths = ", ".join(checkout.dirty_paths) or "paths unavailable"
        return f"{plural(checkout.dirty_line_count, 'changed path')}: {paths}"
    if checkout.classification == "live":
        return "open herdr workspace"
    return "; ".join(checkout.errors) or "classification failed"


def print_group(
    title: str,
    checkouts: list[Checkout],
    style: str,
) -> None:
    if not checkouts:
        return

    table = Table(
        title=f"{title} ({len(checkouts)})",
        title_style=f"bold {style}",
        box=box.SIMPLE,
        header_style="bold",
        padding=(0, 1),
    )
    table.add_column("Checkout", style=style, max_width=24)
    table.add_column("Details", overflow="fold")
    for checkout in checkouts:
        details = Text()
        details.append(
            f"{checkout.branch or 'detached HEAD'} | "
            f"idle since {checkout.last_activity or 'unknown'}\n"
        )
        details.append(f"{checkout_summary(checkout)}\n")
        details.append(checkout.path, style="dim")
        table.add_row(
            checkout.name,
            details,
        )
    CONSOLE.print(table)


def print_human(report: SweepReport) -> None:
    counts = report.counts
    eligible_tier2 = sum(
        checkout.eligible
        for checkout in report.checkouts
        if checkout.classification == "tier2"
    )
    blocked = counts.tier1 + counts.tier2 - counts.tier1_eligible - eligible_tier2
    header = Text("worktree-sweep", style="bold")
    header.append(
        f"  {counts.discovered} found | {counts.tier1_eligible} reclaimable | "
        f"{eligible_tier2} pending | {blocked} blocked | {counts.tier3} dirty | "
        f"{counts.live} live/excluded | herdr {report.herdr.status}"
    )
    CONSOLE.print(header)
    herdr_style = "green" if report.herdr.status == "available" else "yellow"
    CONSOLE.print(
        Text("Herdr liveness: ", style="bold"),
        Text(report.herdr.detail, style=herdr_style),
    )

    print_group(
        "Tier 1 - reclaimable",
        [item for item in report.checkouts if item.classification == "tier1"],
        "green",
    )
    print_group(
        "Tier 2 - pending work",
        [item for item in report.checkouts if item.classification == "tier2"],
        "yellow",
    )
    print_group(
        "Tier 3 - dirty",
        [item for item in report.checkouts if item.classification == "tier3"],
        "red",
    )
    print_group(
        "Unclassifiable",
        [item for item in report.checkouts if item.classification == "unclassifiable"],
        "magenta",
    )


def ask_checkbox(message: str, choices: list[Any]) -> list[Any] | None:
    question = questionary.checkbox(
        message,
        choices=choices,
        output=create_output(stdout=sys.stderr),
        instruction="(space to select, enter to confirm, esc to cancel)",
    )

    def cancel(event: Any) -> None:
        event.app.exit(result=None, style="class:aborting")

    question.application.key_bindings.add(Keys.Escape)(cancel)
    try:
        answer = question.unsafe_ask()
    except (EOFError, KeyboardInterrupt):
        return None
    return answer


def ask_confirm(message: str) -> bool:
    question = questionary.confirm(
        message,
        default=False,
        output=create_output(stdout=sys.stderr),
    )

    def cancel(event: Any) -> None:
        event.app.exit(result=False, style="class:aborting")

    cancel_bindings = KeyBindings()
    cancel_bindings.add(Keys.Escape, eager=True)(cancel)
    question.application.key_bindings = merge_key_bindings(
        [cancel_bindings, question.application.key_bindings]
    )
    try:
        return bool(question.unsafe_ask())
    except (EOFError, KeyboardInterrupt):
        return False


def truncate(value: str, width: int) -> str:
    if len(value) <= width:
        return value
    if width <= 3:
        return value[:width]
    return f"{value[: width - 3]}..."


def idle_since(checkout: Checkout) -> str:
    if checkout.last_activity is None:
        return "unknown"
    try:
        return datetime.fromisoformat(checkout.last_activity).strftime("%m-%d")
    except ValueError:
        return truncate(checkout.last_activity, 5)


def picker_state(checkout: Checkout) -> str:
    if checkout.classification == "tier1":
        return "merged"
    if checkout.classification == "tier2":
        unmerged = (
            f"{checkout.unmerged_commits}u"
            if checkout.unmerged_commits is not None
            else "?u"
        )
        unpushed = (
            "no-up"
            if checkout.upstream is None
            else (
                f"{checkout.unpushed_commits}p"
                if checkout.unpushed_commits is not None
                else "?p"
            )
        )
        return f"pending {unmerged}/{unpushed}"
    if checkout.classification == "tier3":
        paths = ", ".join(checkout.dirty_paths) or "paths unavailable"
        return f"dirty {paths}"
    if checkout.classification == "live":
        return "open herdr workspace"
    return f"error: {checkout.errors[0] if checkout.errors else 'classification failed'}"


def picker_label(checkout: Checkout, reason: str | None) -> str:
    terminal_width = CONSOLE.size.width
    reason_width = len(reason) + 3 if reason else 0
    width = max(24, terminal_width - reason_width - 10)
    idle = f"since {idle_since(checkout)}"
    available = max(12, width - len(idle) - 9)
    name_width = min(20, max(6, available // 3))
    branch_width = min(20, max(6, available // 3))
    state_width = max(6, available - name_width - branch_width)
    label = (
        f"{truncate(checkout.name, name_width)} | "
        f"{truncate(checkout.branch or 'detached', branch_width)} | "
        f"{truncate(picker_state(checkout), state_width)} | {idle}"
    )
    return truncate(label, width)


def failed_guard_reason(checkout: Checkout) -> str:
    failed = [guard.name for guard in checkout.guards if not guard.passed]
    return f"blocked by {', '.join(failed) or 'removal guards'}"


def disabled_reason(checkout: Checkout) -> str | None:
    if checkout.classification in ("tier1", "tier2"):
        return None if checkout.eligible else failed_guard_reason(checkout)
    if checkout.classification == "tier3":
        return "git refuses dirty removal"
    if checkout.classification == "live":
        return "open herdr workspace"
    return "classification error"


def picker_groups(
    report: SweepReport,
    show_all: bool,
) -> list[tuple[str, list[Checkout]]]:
    groups = [
        (
            "Reclaimable",
            [
                checkout
                for checkout in report.checkouts
                if checkout.classification == "tier1"
            ],
        ),
        (
            "Pending work (branch survives removal)",
            [
                checkout
                for checkout in report.checkouts
                if checkout.classification == "tier2"
            ],
        ),
        (
            "Dirty",
            [
                checkout
                for checkout in report.checkouts
                if checkout.classification == "tier3"
            ],
        ),
        (
            "Unclassifiable",
            [
                checkout
                for checkout in report.checkouts
                if checkout.classification == "unclassifiable"
            ],
        ),
    ]
    if show_all:
        groups.append(
            (
                "Live",
                [
                    checkout
                    for checkout in report.checkouts
                    if checkout.classification == "live"
                ],
            )
        )
    return [(title, checkouts) for title, checkouts in groups if checkouts]


def picker_choices(report: SweepReport, show_all: bool) -> list[Any]:
    choices: list[Any] = []
    for title, checkouts in picker_groups(report, show_all):
        choices.append(questionary.Separator(f"-- {title} --"))
        for checkout in checkouts:
            reason = disabled_reason(checkout)
            choices.append(
                questionary.Choice(
                    title=picker_label(checkout, reason),
                    value=checkout.path,
                    disabled=reason,
                )
            )
    return choices


def print_picker_header(report: SweepReport, show_all: bool) -> None:
    eligible_tier2 = sum(
        checkout.eligible
        for checkout in report.checkouts
        if checkout.classification == "tier2"
    )
    blocked = (
        report.counts.tier1
        + report.counts.tier2
        - report.counts.tier1_eligible
        - eligible_tier2
    )
    live_state = "shown" if show_all else "excluded"
    long_header = (
        "worktree-sweep  "
        f"{report.counts.tier1_eligible} reclaimable | "
        f"{eligible_tier2} pending | {blocked} blocked | "
        f"{report.counts.tier3} dirty | "
        f"{report.counts.unclassifiable} errors | "
        f"{report.counts.live} live {live_state} | "
        f"herdr {report.herdr.status}"
    )
    compact_header = (
        "worktree-sweep  "
        f"R:{report.counts.tier1_eligible} P:{eligible_tier2} B:{blocked} "
        f"D:{report.counts.tier3} E:{report.counts.unclassifiable} | "
        f"live {live_state}:{report.counts.live} | herdr {report.herdr.status}"
    )
    width = CONSOLE.size.width
    header = long_header if len(long_header) <= width else compact_header
    CONSOLE.print(
        Text(truncate(header, width), style="bold", no_wrap=True, overflow="crop")
    )


def print_disabled_inventory(report: SweepReport, show_all: bool) -> None:
    groups = picker_groups(report, show_all)
    if not groups:
        CONSOLE.print("No orphaned checkouts found.")
        return

    for title, checkouts in groups:
        CONSOLE.print(Text(title, style="bold"))
        for checkout in checkouts:
            reason = disabled_reason(checkout)
            CONSOLE.print(
                Text(
                    f"  - {picker_label(checkout, reason)} ({reason})",
                    no_wrap=True,
                    overflow="crop",
                )
            )


def confirm_pending_removals(checkouts: list[Checkout]) -> bool:
    CONSOLE.print(Text("Pending work selected:", style="bold yellow"))
    for checkout in checkouts:
        CONSOLE.print(
            f"  {checkout.name} | {checkout.branch or 'detached'} | "
            f"{pending_summary(checkout)}"
        )
    CONSOLE.print(
        "These checkouts will be removed; these branches and their commits "
        "remain in the repository."
    )
    return ask_confirm("Remove the selected pending-work checkouts?")


def print_outcome(label: str, detail: str, style: str) -> None:
    message = Text(f"{label}: ", style=f"bold {style}")
    message.append(detail)
    CONSOLE.print(message)


def refresh_candidate(checkout: Checkout, min_age_hours: float) -> Checkout | None:
    herdr = load_herdr_signal()
    # A herdr query that failed outright may be hiding live workspaces;
    # refuse to revalidate rather than proceed blind.
    if herdr.status == "failed":
        return None
    return classify_checkout(
        Path(checkout.root),
        Path(checkout.path),
        checkout.repository,
        checkout.name,
        set(herdr.live_paths),
        min_age_hours,
    )


def clean_interactively(report: SweepReport, show_all: bool) -> bool:
    failed = False
    print_picker_header(report, show_all)
    if report.herdr.status == "failed":
        # herdr exists but could not report live workspaces: liveness
        # filtering is blind, so offer no removals this run.
        print_outcome(
            "Removals disabled",
            f"{report.herdr.detail} — cannot tell live checkouts from orphans",
            "yellow",
        )
        print_disabled_inventory(report, show_all)
        return True
    candidates = [
        checkout
        for checkout in report.checkouts
        if checkout.classification in ("tier1", "tier2") and checkout.eligible
    ]
    if not candidates:
        print_disabled_inventory(report, show_all)
        return True

    selected = ask_checkbox(
        "Select worktrees to remove",
        picker_choices(report, show_all),
    )
    if not selected:
        return True

    candidates_by_path = {checkout.path: checkout for checkout in candidates}
    selected_candidates = [
        candidates_by_path[path] for path in selected if path in candidates_by_path
    ]
    pending = [
        checkout for checkout in selected_candidates if checkout.classification == "tier2"
    ]
    if pending and not confirm_pending_removals(pending):
        selected_candidates = [
            checkout
            for checkout in selected_candidates
            if checkout.classification != "tier2"
        ]

    removed_branches: list[tuple[Path, str, str]] = []
    for checkout in selected_candidates:
        current = refresh_candidate(checkout, report.min_age_hours)
        if current is None:
            print_outcome(
                "Skipped",
                f"{checkout.path}: herdr state could not be re-verified",
                "yellow",
            )
            failed = True
            continue
        if current.tier != checkout.tier or not current.eligible:
            print_outcome(
                "Skipped",
                f"{checkout.path} is no longer an eligible tier-{checkout.tier} "
                f"checkout ({checkout_summary(current)})",
                "yellow",
            )
            failed = True
            continue

        assert current.main_repository is not None
        result = git(
            Path(current.main_repository),
            "worktree",
            "remove",
            current.path,
        )
        if result.returncode != 0:
            detail = result.stderr.strip() or f"exit status {result.returncode}"
            print_outcome(
                "Git refused removal",
                f"{current.path}: {detail}",
                "red",
            )
            failed = True
            continue

        print_outcome("Removed", current.path, "green")
        if current.tier == 1 and current.merged is True and current.branch:
            removed_branches.append(
                (Path(current.main_repository), current.branch, current.name)
            )

    if removed_branches:
        selected_branches = ask_checkbox(
            "Select fully merged local branches to delete",
            [
                questionary.Choice(
                    title=f"{branch} | removed checkout {name}",
                    value=index,
                )
                for index, (_, branch, name) in enumerate(removed_branches)
            ],
        )
        for index in selected_branches or []:
            main_repository, branch, _ = removed_branches[index]
            branch_result = git(
                main_repository,
                "branch",
                "-d",
                branch,
            )
            if branch_result.returncode != 0:
                detail = (
                    branch_result.stderr.strip()
                    or f"exit status {branch_result.returncode}"
                )
                print_outcome(
                    "Git refused branch deletion",
                    f"{branch}: {detail}",
                    "red",
                )
                failed = True
            else:
                print_outcome("Deleted branch", branch, "green")
    return not failed


def main() -> int:
    args = parse_args()
    if shutil.which("git") is None:
        die("git is required but was not found on PATH", 2)

    roots = resolve_roots(args.root)
    report = build_report(roots, args.min_age_hours)
    if args.json:
        print(json.dumps(asdict(report), indent=2, sort_keys=True))
    elif args.report_only or not (sys.stdin.isatty() and sys.stderr.isatty()):
        print_human(report)

    interactive = (
        not args.json
        and not args.report_only
        and sys.stdin.isatty()
        and sys.stderr.isatty()
    )
    if interactive and not clean_interactively(report, args.show_all):
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        raise SystemExit(1) from None

"""Offline tests for herdr-agent-summary.py.

Usage: python3 herdr-agent-summary-test.py MODULE FIXTURES [unittest args]

The process under test runs against a fake Herdr, a fake model and an injected
clock. Model calls, the Herdr client, the hooks and one end-to-end run use
real child processes with stand-ins for `claude` and `herdr`.
"""

from __future__ import annotations

import dataclasses
import fcntl
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest

MODULE_PATH = ""
FIXTURES = ""
M = None  # the module under test, loaded in __main__

PREFIX = "\u200b  "
CLAUDE_SESSION = {"agent": "claude", "kind": "id", "source": "herdr:claude", "value": "c0ffee-1"}


def load_module():
    spec = importlib.util.spec_from_file_location("herdr_agent_summary", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def fixture(name: str) -> str:
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as handle:
        return handle.read()


def user(text):
    return {"type": "user", "message": {"role": "user", "content": text}}


def reply(text):
    return {
        "type": "assistant",
        "message": {"role": "assistant", "content": [{"type": "text", "text": text}]},
    }


def tool(name, arguments):
    return {
        "type": "assistant",
        "message": {
            "role": "assistant",
            "content": [{"type": "tool_use", "name": name, "input": arguments}],
        },
    }


def fresh(text):
    return {"agent_summary": PREFIX + text, "agent_summary_stale": None}


def stale(text):
    return {"agent_summary": None, "agent_summary_stale": PREFIX + "◌ " + text}


def report_tokens(report):
    tokens = {name: None for name in report["clear"]}
    if report["token"] is not None:
        tokens[report["token"][0]] = report["token"][1]
    return tokens


def wait_until(predicate, what, deadline=30.0):
    """Waits for an outcome of a real child process, not for a duration."""
    end = time.monotonic() + deadline
    while not predicate():
        if time.monotonic() > end:
            raise AssertionError(f"timed out waiting for {what}")
        time.sleep(0.02)


def ps(pid: int, fields: str) -> str | None:
    """`ps -o FIELDS -p PID` output, or None when no ps is reachable (the
    Darwin build environment may not have one on PATH)."""
    command = shutil.which("ps") or ("/bin/ps" if os.path.exists("/bin/ps") else None)
    if command is None:
        return None
    try:
        return subprocess.run(
            [command, "-o", fields, "-p", str(pid)], capture_output=True, text=True, check=False
        ).stdout.strip()
    except OSError:
        return None


def process_state(pid: int) -> str | None:
    """The pid's state letter ("Z" for a zombie), None once it is gone, or "?"
    when it exists but its state cannot be read."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return None
    except PermissionError:
        pass
    try:
        with open(f"/proc/{pid}/stat") as handle:
            return handle.read().rsplit(")", 1)[1].split()[0]
    except FileNotFoundError:
        if os.path.isdir("/proc"):
            return None
    except OSError:
        return "?"
    # No /proc, as on macOS, where kill(pid, 0) also succeeds for a zombie.
    state = ps(pid, "stat=")
    if state is None:
        return "?"
    return state[:1] or None


def alive(pid: int) -> bool:
    return process_state(pid) not in (None, "Z")


def describe(pid: int) -> str:
    try:
        with open(f"/proc/{pid}/stat") as handle:
            return handle.read().strip()
    except OSError:
        pass
    shown = ps(pid, "stat=,ppid=,pgid=,command=")
    return "no ps available" if shown is None else (shown or "no such process")


def command_of(pid: int) -> str:
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as handle:
            return handle.read().decode(errors="replace")
    except FileNotFoundError:
        if os.path.isdir("/proc"):
            return ""
    except OSError:
        return ""
    return ps(pid, "command=") or ""


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def monotonic(self):
        return self.now

    def wall(self):
        return 1_800_000_000.0 + self.now


class FakeHerdr:
    def __init__(self):
        self.agents = {}
        self.reports = []
        self.down = False
        self.reports_fail = False
        self.refused = set()
        self.agent_down_once = False

    def put(self, pane, agent, name, status, session, tokens=None):
        self.agents[pane] = {
            "pane_id": pane,
            "agent": agent,
            "name": name,
            "agent_status": status,
            "agent_session": session,
            "tokens": dict(tokens or {}),
        }

    def snapshot(self):
        return None if self.down else json.loads(json.dumps(list(self.agents.values())))

    def agent(self, pane):
        if self.agent_down_once:
            self.agent_down_once = False
            return None
        if self.down or pane not in self.agents:
            return None
        return json.loads(json.dumps(self.agents[pane]))

    def report(self, pane, label, seq, token, clear):
        self.reports.append(
            {"pane": pane, "agent": label, "seq": seq, "token": token, "clear": tuple(clear)}
        )
        if self.reports_fail or pane in self.refused:
            return False
        if pane in self.agents:
            tokens = self.agents[pane]["tokens"]
            for name in clear:
                tokens.pop(name, None)
            if token is not None:
                tokens[token[0]] = token[1]
        return True


class FakeCall:
    def __init__(self, model, prompt):
        self.prompt = prompt
        self.result = model.reply
        self.released = not model.hold
        self.cancelled = False
        # Whether nothing of the call is left running once it is ended.
        self.gone = True

    def release(self, result=None):
        if result is not None:
            self.result = result
        self.released = True

    def end(self, wait):
        if not self.released:
            self.cancelled = True
        return self.gone

    def poll(self, now):
        return (True, self.result) if self.released else (False, None)


class FakeModel:
    def __init__(self):
        self.reply = "Fixing the login test"
        self.hold = False
        self.calls = []

    def start(self, prompt, now):
        call = FakeCall(self, prompt)
        self.calls.append(call)
        return call


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="agent-summary-test-")
        self.claude_config = os.path.join(self.tmp, "claude-config")
        self.omp_sessions = os.path.join(self.tmp, "omp", "sessions")
        for path in (
            os.path.join(self.claude_config, "projects", "-repo"),
            os.path.join(self.omp_sessions, "-repo"),
            os.path.join(self.tmp, "elsewhere"),
        ):
            os.makedirs(path)
        self.socket = os.path.join(self.tmp, "sock")
        open(self.socket, "w").close()
        self.cfg = M.Config(
            worker_prefixes=("worker-",),
            interval=180,
            model="haiku",
            timeout=60,
            max_concurrent=2,
            claude_bin=os.path.join(self.tmp, "claude"),
            claude_config_dir=self.claude_config,
            omp_sessions_dir=self.omp_sessions,
            state_dir=os.path.join(self.tmp, "state"),
            socket_path=self.socket,
            herdr_bin=os.path.join(self.tmp, "herdr"),
        )
        os.makedirs(self.cfg.state_dir)
        self.paths = M.Paths.of(self.cfg)
        self.paths.prepare()
        self.clock = FakeClock()
        self.herdr = FakeHerdr()
        self.model = FakeModel()
        self.logs = []
        self.daemon = self.make_daemon()
        self.transcript = self.claude_transcript("c0ffee-1")
        self.held_fds = []

    def tearDown(self):
        for fd in self.held_fds:
            os.close(fd)
        shutil.rmtree(self.tmp)

    def make_daemon(self, cfg=None, herdr=None):
        cfg = cfg or self.cfg
        paths = M.Paths.of(cfg)
        paths.prepare()
        return M.Daemon(
            cfg,
            paths,
            herdr or self.herdr,
            self.model,
            M.Slots(paths.slot_dir, cfg.max_concurrent),
            self.clock,
            self.logs.append,
            "build-a",
        )

    def claude_transcript(self, session):
        return os.path.join(self.claude_config, "projects", "-repo", f"{session}.jsonl")

    def append(self, *entries, path=None):
        with open(path or self.transcript, "a", encoding="utf-8") as handle:
            for entry in entries:
                handle.write((entry if isinstance(entry, str) else json.dumps(entry)) + "\n")

    def lead(self, status, session=CLAUDE_SESSION, name="", tokens=None):
        self.herdr.put("lead", "claude", name, status, session, tokens)

    def step(self, seconds=0.0):
        self.clock.now += seconds
        self.daemon.step(self.clock.now)

    def settle(self):
        for _ in range(20):
            self.step()
            due = [r.due for r in self.daemon.records.values() if r.due is not None]
            if not self.daemon.jobs and not any(d <= self.clock.now for d in due):
                return
        raise AssertionError("the process did not settle")

    def event(self, pane="lead", build="build-a"):
        self.daemon.handle({"kind": "event", "pane": pane, "build": build})
        self.settle()

    def shown(self, pane="lead"):
        tokens = self.herdr.agents[pane]["tokens"]
        return {name: tokens.get(name) for name in ("agent_summary", "agent_summary_stale")}

    def state(self, pane="lead"):
        with open(os.path.join(self.paths.pane_dir, f"{pane}.json")) as handle:
            return json.load(handle)

    def hold(self, path):
        fd = os.open(path, os.O_WRONLY | os.O_CREAT, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        self.held_fds.append(fd)
        return fd

    def release(self, fd):
        self.held_fds.remove(fd)
        os.close(fd)

    def summarised(self, text):
        """A lead with a stored turn-end summary."""
        self.model.reply = text
        self.lead("idle")
        if not os.path.exists(self.transcript):
            self.append(user("Add retry to the login client"))
        self.settle()
        self.assertEqual(self.shown(), fresh(text))

    def request_clear(self):
        open(self.paths.clear_request, "w").close()
        self.daemon.handle({"kind": "clear", "build": "build-a"})
        self.step()

    def log_count(self, text):
        return sum(text in line for line in self.logs)


# --- Transcript digests and text ----------------------------------------------

CLAUDE_LINES = [
    '{"type":"user","message":{"role":"user","content":"Add retry to the login client"}}',
    '{"type":"ai-title","aiTitle":"Login retry work"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I will look at the client."},{"type":"tool_use","name":"Read","input":{"file_path":"src/old.ts"}}]}}',
    '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"IGNORE ME"}]}}',
    '{"type":"user","isMeta":true,"message":{"role":"user","content":"meta caveat"}}',
    '{"type":"user","message":{"role":"user","content":"<task-notification>done</task-notification>"}}',
    '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Also cover\\tthe\\nlogout path"}]}}',
    '{"type":"assistant","isSidechain":true,"message":{"role":"assistant","content":[{"type":"text","text":"subagent text"}]}}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"npm test","description":"Run the unit tests"}},{"type":"tool_use","name":"Edit","input":{"file_path":"src/logout.ts","old_string":"x"}}]}}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Tests \\u001b[31mfail\\u001b[0m on logout."}]}}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"te',
]


def omp_lines():
    lines = [
        '{"type":"title","v":1,"title":"OMP refactor","pad":"   "}',
        '{"type":"session","version":3,"cwd":"/repo"}',
    ]
    lines += [
        '{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"filler %d"}]}}'
        % i
        for i in range(1, 41)
    ]
    lines += [
        '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"Split the parser module"}]}}',
        '{"type":"message","message":{"role":"developer","content":[{"type":"text","text":"Continue."}]}}',
        '{"type":"message","message":{"role":"assistant","content":[{"type":"thinking"},{"type":"toolCall","name":"bash","arguments":{"i":"Running the parser tests","command":"cargo test"}},{"type":"toolCall","name":"read","arguments":{"path":"src/parser.rs"}}]}}',
        '{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"ok"}]}}',
        '{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Parser split into lexer and grammar."}]}}',
    ]
    return lines


class DigestTests(Base):
    def test_claude_digest(self):
        self.append(*CLAUDE_LINES)
        self.assertEqual(
            M.digest("claude", self.transcript, self.cfg.tail_bytes),
            {
                "title": "Login retry work",
                "prompts": ["Add retry to the login client", "Also cover the logout path"],
                "replies": ["I will look at the client.", "Tests fail on logout."],
                "tools": ["Bash: Run the unit tests", "Edit: src/logout.ts"],
                "key": "Alsocoverthelogoutpath",
            },
        )

    def test_last_prompt_stands_in_past_the_window(self):
        path = os.path.join(self.tmp, "long.jsonl")
        self.append(user("Port the CLI to Rust"), path=path)
        self.append(*[tool("Edit", {"file_path": f"src/{i}.rs"}) for i in range(1, 31)], path=path)
        self.append(
            {"type": "last-prompt", "lastPrompt": "Port the CLI to Rust", "sessionId": "s"},
            path=path,
        )
        found = M.digest("claude", path, 1500)
        self.assertEqual(found["prompts"], ["Port the CLI to Rust"])
        self.assertEqual(found["key"], "PorttheCLItoRust")
        self.assertEqual(len(found["tools"]), 8)

    def test_last_prompt_fallback_is_bounded(self):
        self.append(tool("Edit", {"file_path": "a"}))
        self.append({"type": "last-prompt", "lastPrompt": "x" * 70000})
        found = M.digest("claude", self.transcript, self.cfg.tail_bytes)
        self.assertEqual(found["prompts"], ["x" * 600])

    def test_small_window_keeps_the_omp_title(self):
        path = os.path.join(self.omp_sessions, "-repo", "2026_omp.jsonl")
        self.append(*omp_lines(), path=path)
        self.assertEqual(
            M.digest("omp", path, 700),
            {
                "title": "OMP refactor",
                "prompts": ["Split the parser module"],
                "replies": ["Parser split into lexer and grammar."],
                "tools": ["bash: Running the parser tests", "read: src/parser.rs"],
                "key": "Splittheparsermodule",
            },
        )

    def test_lone_surrogate_lines_are_skipped(self):
        self.append(
            '{"type":"user","message":{"content":"Kept \\ud83d\\ude00 pair"}}',
            '{"type":"user","message":{"content":"Cut \\ud83d"}}',
        )
        self.assertEqual(
            M.digest("claude", self.transcript, self.cfg.tail_bytes)["prompts"],
            ["Kept \U0001f600 pair"],
        )
        self.assertIsNone(M.parse_model_reply('{"is_error": false, "result": "x \\udc00"}'))

    def test_squash_removes_format_and_control_characters(self):
        self.assertEqual(
            M.squash("\x1b[1mA\x1b[0m\tb\u200bc\u00add\u0085e f\ufeff "), "A b c d e f"
        )

    def test_excerpt_takes_the_first_set_field(self):
        self.assertEqual(M.excerpt({"description": "", "command": "make"}), "")
        self.assertEqual(M.excerpt({"description": None, "command": "make"}), "make")
        self.assertEqual(M.excerpt({"other": 1}), '{"other":1}')
        self.assertEqual(M.excerpt(None), "null")
        self.assertEqual(len(M.excerpt("x" * 200)), 80)

    def test_render_digest(self):
        self.assertEqual(
            M.render_digest(
                {"title": "", "prompts": ["Do it"], "replies": [], "tools": ["Bash: make"]}, "idle"
            ),
            "Agent state: idle\nRecent user requests, oldest first:\n- Do it\n"
            "Tool calls since the latest request, oldest first:\n- Bash: make",
        )

    def test_sanitise(self):
        cases = [
            ('\n  **Summary:** "Reviewing `auth` module."\nSecond line', "Reviewing auth module"),
            ("\x1b[1mRunning\x1b[0m\ttests\u200b now", "Running tests now"),
            ("x" * 100, "x" * 59 + "…"),
            ("\u201cDrafting release notes\u201d", "Drafting release notes"),
            ("Fixing agent_summary tokens", "Fixing agent_summary tokens"),
            ("Status: done。", "done"),
            ("> - # Waiting for review...", "Waiting for review"),
        ]
        for raw, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(M.sanitise(raw), expected)

    def test_cksum_matches_coreutils(self):
        # `printf '%s\n' PATH | cksum` with coreutils 9.
        self.assertEqual(M.cksum(b"/run/user/1000/herdr/herdr.sock\n"), 608377971)
        self.assertEqual(M.cksum(b"/tmp/herdr-test/sock-b\n"), 1856806374)
        self.assertEqual(M.cksum(b""), 4294967295)


class FixtureTests(Base):
    def test_snapshot_fixture(self):
        agents = M.parse_snapshot(fixture("herdr-snapshot.json"))
        panes = [M.pane_facts(agent, ("worker-",)) for agent in agents]
        self.assertEqual([p.agent for p in panes], ["omp", "claude", "claude"])
        self.assertEqual([p.eligible for p in panes], [True, True, False])
        self.assertEqual([p.status for p in panes], ["done", "working", "working"])
        self.assertEqual(panes[0].kind, "path")
        self.assertEqual(panes[1].identity, "claude:id:00000000-0000-4000-8000-000000000000")
        self.assertTrue(M.has_summary(panes[1].tokens))
        self.assertEqual(panes[1].tokens["agent_summary_stale"], PREFIX + "◌ Example summary")

    def test_agent_get_fixtures(self):
        agent = M.parse_agent(fixture("herdr-agent-get.json"))
        self.assertEqual(agent["pane_id"], "w81:p3")
        self.assertFalse(M.pane_facts(agent, ("worker-",)).eligible)
        self.assertTrue(M.pane_facts(agent, ()).eligible)
        self.assertIsNone(M.parse_agent(""))
        self.assertIsNone(M.parse_agent(fixture("herdr-agent-get-missing.stderr")))

    def test_model_reply_fixtures(self):
        self.assertEqual(
            M.parse_model_reply(fixture("claude-reply.json")), "Fixing logout path retry and tests"
        )
        self.assertIsNone(M.parse_model_reply(fixture("claude-error.json")))
        self.assertIsNone(M.parse_model_reply("Invalid API key\n"))


# --- The per-server process ----------------------------------------------------


class EligibilityTests(Base):
    def test_ineligible_panes_are_never_summarised(self):
        outside = os.path.join(self.tmp, "elsewhere", "x.jsonl")
        self.append("{}", path=outside)
        self.append(user("Add retry"))
        self.herdr.put(
            "worker", "claude", "worker-impl", "idle", CLAUDE_SESSION, {"agent_summary": "old"}
        )
        self.herdr.put(
            "codex", "codex", "lead-codex", "idle", {"agent": "codex", "kind": "id", "value": "abc"}
        )
        self.herdr.put(
            "outside",
            "omp",
            "lead-outside",
            "idle",
            {"agent": "omp", "kind": "path", "value": outside},
        )
        control = {"agent": "claude", "kind": "id", "value": "c0ffee-1\nworker-x"}
        self.herdr.put("control", "claude", "lead-control", "idle", control)
        self.settle()
        for pane in ("worker", "codex", "outside", "control"):
            self.event(pane)
        self.assertEqual(self.model.calls, [])
        self.assertEqual(len(self.herdr.reports), 1)
        report = self.herdr.reports[0]
        self.assertEqual(report["pane"], "worker")
        self.assertEqual(
            report_tokens(report), {"agent_summary": None, "agent_summary_stale": None}
        )

    def test_control_characters_in_a_session_make_it_ineligible(self):
        path = os.path.join(self.omp_sessions, "-repo", "a\u200bb.jsonl")
        self.append(user("hidden"), path=path)
        data = {
            "pane_id": "p",
            "agent": "omp",
            "agent_session": {"agent": "omp", "kind": "path", "value": path},
        }
        self.assertFalse(M.pane_facts(data, ()).eligible)
        self.assertIsNotNone(M.resolve_transcript(self.cfg, M.pane_facts(data, ())))

    def test_transcript_confinement(self):
        link_target = os.path.join(self.tmp, "elsewhere", "secret.jsonl")
        self.append(user("secret"), path=link_target)
        os.symlink(link_target, os.path.join(self.omp_sessions, "-repo", "link.jsonl"))
        pane = M.pane_facts(
            {
                "pane_id": "p",
                "agent": "omp",
                "agent_status": "idle",
                "agent_session": {
                    "agent": "omp",
                    "kind": "path",
                    "value": os.path.join(self.omp_sessions, "-repo", "link.jsonl"),
                },
            },
            (),
        )
        self.assertIsNone(M.resolve_transcript(self.cfg, pane))
        bad = M.pane_facts(
            {
                "pane_id": "p",
                "agent": "claude",
                "agent_session": {"agent": "claude", "kind": "id", "value": "../x"},
            },
            (),
        )
        self.assertIsNone(M.resolve_transcript(self.cfg, bad))


class TurnEndTests(Base):
    def test_turn_end_summary(self):
        self.append(*CLAUDE_LINES)
        self.lead("idle")
        self.settle()
        self.assertEqual(len(self.model.calls), 1)
        prompt = self.model.calls[0].prompt
        self.assertIn("Agent state: idle", prompt)
        self.assertIn("- Edit: src/logout.ts", prompt)
        report = self.herdr.reports[-1]
        self.assertEqual((report["pane"], report["agent"]), ("lead", "claude"))
        self.assertEqual(report_tokens(report), fresh("Fixing the login test"))
        self.assertEqual(self.state()["identity"], "claude:id:c0ffee-1")

    def test_unchanged_transcript_needs_no_model_call(self):
        self.summarised("Fixing the login test")
        self.event()
        self.assertEqual(len(self.model.calls), 1)
        self.assertEqual(self.shown(), fresh("Fixing the login test"))

    def test_repeated_turn_ends_share_one_call(self):
        self.summarised("Fixing the login test")
        self.model.hold = True
        self.append(user("queued"))
        for _ in range(2):
            self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-a"})
            self.step()
        self.daemon.handle({"kind": "startup"})
        self.step()
        self.assertEqual(len(self.model.calls), 2)
        self.model.calls[-1].release()
        self.settle()
        self.assertEqual(len(self.model.calls), 2)

    def test_reply_is_sanitised(self):
        self.summarised("Fixing the login test")
        self.append(reply("more"))
        self.model.reply = '\n  **Summary:** "Reviewing `auth` module."\nSecond line'
        self.event()
        self.assertEqual(self.shown(), fresh("Reviewing auth module"))

    def test_failures_keep_the_previous_line_stale(self):
        self.summarised("Fixing agent_summary tokens")
        for result in (None, ""):
            self.append(user("next"))
            self.model.reply = result
            self.event()
            self.assertEqual(self.shown(), stale("Fixing agent_summary tokens"))
        self.assertEqual(self.log_count("summary failed for lead"), 2)
        self.assertTrue(self.state()["failed"])

    def test_no_free_slot_fails_after_the_wait(self):
        self.summarised("Old lead task")
        self.append(user("next"))
        slots = [self.hold(os.path.join(self.paths.slot_dir, f"slot.{i}")) for i in range(2)]
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-a"})
        self.step()
        self.assertEqual(len(self.model.calls), 1)
        self.assertIn("lead", self.daemon.jobs)
        self.step(self.cfg.timeout * 2)
        self.assertEqual(len(self.model.calls), 1)
        self.assertEqual(self.shown(), stale("Old lead task"))
        self.assertEqual(self.log_count("summary failed for lead"), 1)
        for fd in slots:
            self.release(fd)

    def test_empty_digest_needs_no_model_call(self):
        self.append({"type": "session"})
        self.lead("idle")
        self.settle()
        self.assertEqual(self.model.calls, [])


class LoopTests(Base):
    def test_working_event_marks_stale_until_the_loop_replaces_it(self):
        self.summarised("Fixing agent_summary tokens")
        self.herdr.reports.clear()
        self.lead("working", tokens=self.herdr.agents["lead"]["tokens"])
        self.append(user("Work on logout"))
        self.model.reply = "Working on logout"
        self.event()
        self.assertEqual(report_tokens(self.herdr.reports[0]), stale("Fixing agent_summary tokens"))
        self.assertEqual(len(self.model.calls), 1)
        self.step(self.cfg.settle)
        self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertEqual(self.shown(), fresh("Working on logout"))

    def test_mid_turn_refresh_only_after_growth(self):
        self.lead("working")
        self.append(user("Work on logout"))
        self.model.reply = "Working on logout"
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.assertEqual(len(self.model.calls), 1)
        for _ in range(3):
            self.step(self.cfg.interval)
            self.settle()
        self.assertEqual(len(self.model.calls), 1)
        self.assertEqual(self.shown(), fresh("Working on logout"))
        self.append(tool("Bash", {"command": "make"}))
        self.step(self.cfg.interval / 2)
        self.settle()
        self.assertEqual(len(self.model.calls), 1)
        self.step(self.cfg.interval / 2)
        self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertIn("Agent state: working", self.model.calls[-1].prompt)
        self.assertIn("- Bash: make", self.model.calls[-1].prompt)

    def test_request_change_refreshes_at_the_next_pass(self):
        self.lead("working")
        self.append(user("Work on logout"))
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.append(user("Now add metrics"))
        self.step(self.cfg.interval)
        self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertIn("- Now add metrics", self.model.calls[-1].prompt)

    def test_leaving_working_ends_the_loop_with_a_turn_end_summary(self):
        self.lead("working")
        self.append(user("Work on logout"))
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.lead("done", tokens=self.herdr.agents["lead"]["tokens"])
        self.append(reply("Finished."))
        self.model.reply = "Finished logout retry"
        self.event()
        self.assertEqual(len(self.model.calls), 2)
        self.assertIn("Agent state: done", self.model.calls[-1].prompt)
        self.assertEqual(self.shown(), fresh("Finished logout retry"))
        self.assertEqual(self.daemon.records["lead"].mode, "final")
        self.step(self.cfg.interval * 3)
        self.settle()
        self.assertEqual(len(self.model.calls), 2)

    def test_status_change_seen_by_reconcile_alone(self):
        self.lead("working")
        self.append(user("Work on logout"))
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.lead("idle", tokens=self.herdr.agents["lead"]["tokens"])
        self.step(self.cfg.reconcile_every)
        self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertIn("Agent state: idle", self.model.calls[-1].prompt)

    def test_reconcile_recovers_a_turn_missed_between_snapshots(self):
        self.summarised("Old task finished")
        self.append(user("New task"), reply("Done with it."))
        self.model.reply = "New task finished"
        for _ in range(2):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertEqual(self.state()["key"], "Newtask")
        self.assertEqual(self.shown(), fresh("New task finished"))

    def test_reconcile_picks_up_a_transcript_that_appears_later(self):
        self.lead("idle")
        self.settle()
        self.assertEqual(self.model.calls, [])
        self.append(user("Add retry"))
        self.step(self.cfg.reconcile_every)
        self.settle()
        self.assertEqual(len(self.model.calls), 1)
        self.assertEqual(self.shown(), fresh("Fixing the login test"))

    def test_a_new_turn_during_an_idle_call_is_summarised(self):
        self.summarised("Old completed task")
        self.append(user("Intermediate task"))
        self.model.hold = True
        self.step(self.cfg.reconcile_every)
        held = self.model.calls[-1]
        self.append(user("Latest task"), reply("Latest done."))
        self.model.hold = False
        self.model.reply = "Latest task finished"
        held.release("Intermediate task finished")
        for _ in range(3):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(len(self.model.calls), 3)
        self.assertEqual(self.state()["key"], "Latesttask")
        self.assertEqual(self.shown(), fresh("Latest task finished"))

    def test_growth_during_an_idle_call_is_summarised(self):
        self.model.hold = True
        self.model.reply = "Before checks"
        self.lead("idle")
        self.append(user("Add retry"))
        self.step()
        held = self.model.calls[-1]
        self.append(tool("Bash", {"command": "make check"}))
        self.model.hold = False
        self.model.reply = "Running checks"
        held.release()
        for _ in range(3):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertIn("- Bash: make check", self.model.calls[-1].prompt)
        self.assertEqual(self.state()["size"], os.path.getsize(self.transcript))
        self.assertEqual(self.shown(), fresh("Running checks"))

    def test_an_unverifiable_result_is_retried(self):
        self.summarised("Old task finished")
        self.append(user("New task"))
        self.model.reply = "New task finished"
        self.model.hold = True
        self.step(self.cfg.reconcile_every)
        self.herdr.agent_down_once = True
        self.model.hold = False
        self.model.calls[-1].release()
        self.step()
        self.assertEqual(self.shown(), stale("Old task finished"))
        self.step(self.cfg.reconcile_every)
        self.settle()
        self.assertEqual(self.shown(), fresh("New task finished"))

    def test_reconcile_ignores_session_metadata_writes(self):
        self.summarised("Old task finished")
        for mode in ("default", "plan", "default"):
            self.append({"type": "permission-mode", "permissionMode": mode})
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(len(self.model.calls), 1)
        self.assertEqual(self.shown(), fresh("Old task finished"))

    def test_reconcile_does_not_retry_a_failure_without_growth(self):
        self.summarised("Old task finished")
        self.append(user("New task"))
        self.model.reply = None
        for _ in range(6):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(len(self.model.calls), 2)
        self.assertEqual(self.shown(), stale("Old task finished"))

    def test_change_between_stopped_states_seen_by_reconcile(self):
        self.summarised("Waiting for approval")
        self.lead("blocked", tokens=self.herdr.agents["lead"]["tokens"])
        self.event()
        self.append(reply("Approved and done."))
        self.lead("idle", tokens=self.herdr.agents["lead"]["tokens"])
        self.model.reply = "Finished the retry"
        self.step(self.cfg.reconcile_every)
        self.settle()
        self.assertEqual(self.shown(), fresh("Finished the retry"))

    def test_working_seen_by_reconcile_marks_the_line_stale(self):
        self.summarised("Fixing the login test")
        self.append(user("Next request"))
        self.lead("working", tokens=self.herdr.agents["lead"]["tokens"])
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), stale("Fixing the login test"))

    def test_working_event_wakes_a_long_interval(self):
        self.daemon = self.make_daemon(dataclasses.replace(self.cfg, interval=3600))
        self.lead("working")
        self.append(user("Work on logout"))
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.lead("blocked", tokens=self.herdr.agents["lead"]["tokens"])
        self.event()
        self.append(user("Now add metrics"))
        self.lead("working", tokens=self.herdr.agents["lead"]["tokens"])
        self.model.reply = "Adding metrics"
        self.event()
        self.step(self.cfg.settle)
        self.settle()
        self.assertIn("- Now add metrics", self.model.calls[-1].prompt)
        self.assertEqual(self.shown(), fresh("Adding metrics"))

    def test_loop_outlives_a_missing_transcript_and_ends_with_its_pane(self):
        session = {"agent": "claude", "kind": "id", "value": "fresh-2"}
        self.herdr.put("fresh", "claude", "", "working", session)
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.assertEqual(self.model.calls, [])
        self.append(user("Start fresh"), path=self.claude_transcript("fresh-2"))
        self.step(self.cfg.interval)
        self.settle()
        self.assertEqual(len(self.model.calls), 1)
        del self.herdr.agents["fresh"]
        self.step(self.cfg.reconcile_every)
        self.assertNotIn("fresh", self.daemon.records)
        self.step(self.cfg.interval)
        self.settle()
        self.assertEqual(len(self.model.calls), 1)


class RaceTests(Base):
    """A pane that changes while its summary is running."""

    def start_held(self):
        self.model.hold = True
        self.model.reply = "Old lead task"
        self.lead("idle")
        self.append(user("Review old lead task"))
        self.settle_until_call()
        self.model.hold = False
        return self.model.calls[-1]

    def settle_until_call(self):
        calls = len(self.model.calls)
        for _ in range(5):
            self.step()
            if len(self.model.calls) > calls:
                return
        raise AssertionError("no model call started")

    def no_old_line(self):
        for report in self.herdr.reports:
            self.assertNotEqual(
                report_tokens(report).get("agent_summary"), PREFIX + "Old lead task"
            )

    def test_request_change_drops_the_result(self):
        call = self.start_held()
        self.append(user("Review the new task"))
        self.herdr.reports.clear()
        call.release()
        self.settle()
        self.no_old_line()
        self.assertEqual(self.log_count("discarded an obsolete summary for lead"), 1)
        self.assertFalse(os.path.exists(os.path.join(self.paths.pane_dir, "lead.json")))

    def test_another_session_takes_the_pane(self):
        self.append(user("Other session work"), path=self.claude_transcript("other-9"))
        call = self.start_held()
        self.lead(
            "idle",
            session={"agent": "claude", "kind": "id", "value": "other-9"},
            tokens={"agent_summary": "previous"},
        )
        self.herdr.reports.clear()
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-a"})
        self.assertEqual(
            report_tokens(self.herdr.reports[0]),
            {"agent_summary": None, "agent_summary_stale": None},
        )
        self.model.reply = "New session work"
        call.release()
        self.settle()
        self.no_old_line()
        self.assertEqual(self.shown(), fresh("New session work"))
        self.assertEqual(self.state()["identity"], "claude:id:other-9")

    def test_worker_takes_the_pane(self):
        call = self.start_held()
        self.lead(
            "idle",
            session={"agent": "claude", "kind": "id", "value": "other-9"},
            name="worker-replacement",
            tokens={"agent_summary": "previous"},
        )
        self.herdr.reports.clear()
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-a"})
        self.assertEqual(len(self.herdr.reports), 1)
        self.herdr.agents["lead"]["tokens"]["agent_summary"] = "late write"
        call.release()
        self.settle()
        self.assertEqual(len(self.herdr.reports), 2)
        for report in self.herdr.reports:
            self.assertEqual(report["pane"], "lead")
            self.assertEqual(
                report_tokens(report), {"agent_summary": None, "agent_summary_stale": None}
            )
        self.assertFalse(os.path.exists(os.path.join(self.paths.pane_dir, "lead.json")))


class FailedStateTests(Base):
    def test_failed_refresh_stays_stale_through_events_and_startup(self):
        self.summarised("Old lead task")
        self.append(reply("More work"))
        self.model.reply = None
        self.event()
        self.assertTrue(self.state()["failed"])
        slots = [self.hold(os.path.join(self.paths.slot_dir, f"slot.{i}")) for i in range(2)]
        failures = self.log_count("summary failed for lead")
        self.herdr.reports.clear()
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-a"})
        self.step()
        # Herdr dropped the tokens, as after a server restart.
        self.herdr.agents["lead"]["tokens"] = {}
        self.daemon.handle({"kind": "startup"})
        self.step()
        # The event's retry and the startup's queued pass both wait out the slots.
        self.step(self.cfg.timeout * 2)
        self.step(self.cfg.timeout * 2)
        self.settle()
        self.assertEqual(self.log_count("summary failed for lead"), failures + 2)
        lead_reports = [r for r in self.herdr.reports if r["pane"] == "lead"]
        self.assertGreaterEqual(len(lead_reports), 1)
        for report in lead_reports:
            self.assertEqual(report_tokens(report), stale("Old lead task"))
        for fd in slots:
            self.release(fd)
        self.append(user("Now add metrics"))
        self.model.reply = "Adding metrics"
        self.event()
        self.assertEqual(self.shown(), fresh("Adding metrics"))
        self.assertFalse(self.state()["failed"])


class StartupTests(Base):
    def omp_pane(self):
        path = os.path.join(self.omp_sessions, "-repo", "2026_omp.jsonl")
        self.append(*omp_lines(), path=path)
        self.herdr.put("omp", "omp", "", "idle", {"agent": "omp", "kind": "path", "value": path})

    def test_startup_restores_without_a_model_call(self):
        self.summarised("Adding metrics")
        self.append("{}", path=os.path.join(self.paths.pane_dir, "gone.json"))
        self.herdr.agents["lead"]["tokens"] = {}
        self.omp_pane()
        self.model.calls.clear()
        self.model.reply = "Splitting the parser"
        self.daemon = self.make_daemon()
        self.settle()
        self.assertFalse(os.path.exists(os.path.join(self.paths.pane_dir, "gone.json")))
        self.assertEqual(self.shown(), fresh("Adding metrics"))
        self.assertEqual(len(self.model.calls), 1)
        self.assertIn("Session title: OMP refactor", self.model.calls[0].prompt)
        self.assertEqual(self.shown("omp"), fresh("Splitting the parser"))
        self.assertTrue(os.path.exists(os.path.join(self.paths.pane_dir, "omp.json")))

    def test_lost_tokens_are_reported_again(self):
        self.summarised("Adding metrics")
        self.herdr.agents["lead"]["tokens"] = {}
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), fresh("Adding metrics"))
        self.assertEqual(len(self.model.calls), 1)

    def test_a_line_herdr_drops_is_reported_a_bounded_number_of_times(self):
        self.summarised("Adding metrics")
        # A snapshot confirms the line, which resets the delivery attempts.
        self.step(self.cfg.reconcile_every)
        reports = len(self.herdr.reports)
        # Herdr accepts the reports but does not apply them.
        self.herdr.report = lambda *args: self.herdr.reports.append(args) or True
        self.herdr.agents["lead"]["tokens"] = {}
        for _ in range(M.DELIVERY_ATTEMPTS + 5):
            self.step(self.cfg.reconcile_every)
        self.assertEqual(len(self.herdr.reports), reports + M.DELIVERY_ATTEMPTS)
        self.assertEqual(self.log_count("gave up updating the summary tokens of lead"), 1)
        self.assertEqual(len(self.model.calls), 1)

    def test_an_ineligible_line_is_cleared_a_bounded_number_of_times(self):
        tokens = {"agent_summary": "stuck"}
        self.herdr.put("worker", "claude", "worker-a", "idle", CLAUDE_SESSION, tokens)
        self.herdr.report = lambda *args: self.herdr.reports.append(args) or True
        for _ in range(M.DELIVERY_ATTEMPTS + 5):
            self.step(self.cfg.reconcile_every)
        self.assertEqual(len(self.herdr.reports), M.DELIVERY_ATTEMPTS)
        # An event still clears it.
        self.event("worker")
        self.assertEqual(len(self.herdr.reports), M.DELIVERY_ATTEMPTS + 1)

    def test_refused_event_deliveries_do_not_use_up_retries(self):
        self.summarised("Adding metrics")
        self.step(self.cfg.reconcile_every)
        self.herdr.agents["lead"]["tokens"] = {}
        self.herdr.reports_fail = True
        for _ in range(M.DELIVERY_ATTEMPTS):
            self.event()
        self.herdr.reports_fail = False
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), fresh("Adding metrics"))
        self.assertEqual(len(self.model.calls), 1)

    def test_startup_retries_a_line_given_up_on(self):
        self.summarised("Adding metrics")
        self.step(self.cfg.reconcile_every)
        report = self.herdr.report
        self.herdr.report = lambda *args: self.herdr.reports.append(args) or True
        self.herdr.agents["lead"]["tokens"] = {}
        for _ in range(M.DELIVERY_ATTEMPTS + 1):
            self.step(self.cfg.reconcile_every)
        self.herdr.report = report
        self.daemon.handle({"kind": "startup"})
        self.step()
        self.assertEqual(self.shown(), fresh("Adding metrics"))

    def test_a_refused_first_summary_is_delivered_later(self):
        self.herdr.reports_fail = True
        self.lead("idle")
        self.append(user("Add retry"))
        self.settle()
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.herdr.reports_fail = False
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), fresh("Fixing the login test"))
        self.assertEqual(len(self.model.calls), 1)

    def test_a_refused_heal_is_delivered_later(self):
        self.summarised("Adding metrics")
        self.herdr.agents["lead"]["tokens"] = {}
        self.herdr.reports_fail = True
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.herdr.reports_fail = False
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), fresh("Adding metrics"))
        self.assertEqual(len(self.model.calls), 1)

    def test_a_line_left_by_another_session_is_cleared(self):
        self.lead("idle", tokens={"agent_summary": "someone else"})
        self.settle()
        self.assertEqual(
            report_tokens(self.herdr.reports[0]),
            {"agent_summary": None, "agent_summary_stale": None},
        )

    def test_pruning(self):
        self.summarised("Adding metrics")
        for key in ("gone", "busy"):
            self.append("{}", path=os.path.join(self.paths.pane_dir, f"{key}.json"))
            self.append("{}", path=os.path.join(self.paths.pane_dir, f"{key}.json.12345"))
        for i in range(1, 301):
            self.append("{}", path=os.path.join(self.paths.pane_dir, f"closed-{i}.json"))
        self.append("{}", path=os.path.join(self.paths.pane_dir, "closed-7.json.999"))
        os.makedirs(self.paths.legacy_lock_dir)
        self.hold(os.path.join(self.paths.legacy_lock_dir, "busy.model"))
        # A pane missing from one routine snapshot keeps its summary.
        lead = self.herdr.agents.pop("lead")
        self.step(self.cfg.reconcile_every)
        self.assertEqual(len(os.listdir(self.paths.pane_dir)), 306)
        self.herdr.agents["lead"] = lead
        self.daemon.handle({"kind": "startup"})
        self.step()
        left = sorted(os.listdir(self.paths.pane_dir))
        self.assertEqual(left, ["busy.json", "busy.json.12345", "lead.json"])

    def test_state_is_private(self):
        self.summarised("Adding metrics")
        self.daemon.log = M.Log(self.paths.log_file, self.clock)
        self.daemon.log("entry")
        os.chmod(self.cfg.state_dir, 0o755)
        os.chmod(self.paths.pane_dir, 0o755)
        os.chmod(os.path.join(self.paths.pane_dir, "lead.json"), 0o644)
        os.chmod(self.paths.log_file, 0o644)
        M.secure_state(self.cfg.state_dir)
        for root, dirs, files in os.walk(self.cfg.state_dir):
            for name in dirs:
                self.assertEqual(stat.S_IMODE(os.stat(os.path.join(root, name)).st_mode), 0o700)
            for name in files:
                self.assertEqual(stat.S_IMODE(os.stat(os.path.join(root, name)).st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(os.stat(self.cfg.state_dir).st_mode), 0o700)

    def test_servers_keep_their_own_namespace(self):
        self.summarised("Adding metrics")
        self.omp_pane()
        self.step(self.cfg.reconcile_every)
        self.settle()
        other_socket = os.path.join(self.tmp, "sock-b")
        open(other_socket, "w").close()
        other = FakeHerdr()
        other.put("other", "codex", "", "idle", None)
        daemon_b = self.make_daemon(
            dataclasses.replace(self.cfg, socket_path=other_socket), herdr=other
        )
        daemon_b.step(self.clock.now)
        self.assertNotEqual(daemon_b.paths.server_dir, self.paths.server_dir)
        self.assertEqual(sorted(os.listdir(self.paths.pane_dir)), ["lead.json", "omp.json"])
        self.assertEqual(len(os.listdir(os.path.join(self.cfg.state_dir, "servers"))), 2)

    def test_clear(self):
        self.summarised("Adding metrics")
        self.herdr.put(
            "plain", "claude", "", "idle", {"agent": "claude", "kind": "id", "value": "none"}
        )
        self.step()
        self.herdr.reports.clear()
        self.request_clear()
        self.assertEqual(len(self.herdr.reports), 1)
        self.assertEqual(self.herdr.reports[0]["pane"], "lead")
        self.assertEqual(
            report_tokens(self.herdr.reports[0]),
            {"agent_summary": None, "agent_summary_stale": None},
        )
        self.assertEqual([n for n in os.listdir(self.paths.pane_dir) if n.endswith(".json")], [])
        self.step(self.cfg.reconcile_every)
        self.settle()
        self.assertEqual(len(self.herdr.reports), 1)
        # An event repopulates the line.
        self.event()
        self.assertEqual(self.shown(), fresh("Adding metrics"))

    def test_a_failed_clear_stays_pending(self):
        self.summarised("Should disappear")
        self.herdr.reports_fail = True
        self.request_clear()
        for _ in range(2):
            self.step(self.cfg.reconcile_every)
        self.assertEqual(len(self.paths.clear_claims()), 1)
        self.assertEqual(self.shown(), fresh("Should disappear"))
        self.assertGreaterEqual(self.log_count("Herdr refused the summary tokens of lead"), 1)
        self.herdr.reports_fail = False
        for _ in range(2):
            self.step(self.cfg.reconcile_every)
        self.assertEqual(self.paths.clear_claims(), [])
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.assertEqual(os.listdir(self.paths.pane_dir), [])

    def test_a_refused_clear_does_not_stall_other_panes(self):
        self.summarised("Lead summary")
        session = {"agent": "claude", "kind": "id", "value": "stuck-1"}
        self.herdr.put("stuck", "claude", "", "idle", session, {"agent_summary": "Stuck line"})
        self.herdr.refused.add("stuck")
        self.request_clear()
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.append(user("Next task"), reply("Done."))
        self.model.reply = "Next task finished"
        self.step(self.cfg.reconcile_every)
        self.settle()
        self.assertEqual(self.shown(), fresh("Next task finished"))
        self.assertEqual(len(self.paths.clear_claims()), 1)
        for _ in range(M.DELIVERY_ATTEMPTS):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(self.paths.clear_claims(), [])
        self.assertEqual(self.log_count("gave up updating the summary tokens of stuck"), 1)
        self.assertEqual(self.shown(), fresh("Next task finished"))

    def test_a_pending_clear_keeps_lines_made_after_it(self):
        self.summarised("Lead summary")
        session = {"agent": "claude", "kind": "id", "value": "stuck-1"}
        self.herdr.put("stuck", "claude", "", "idle", session, {"agent_summary": "Stuck line"})
        self.herdr.refused.add("stuck")
        self.request_clear()
        self.model.reply = "Post clear work"
        self.event()
        self.assertEqual(self.shown(), fresh("Post clear work"))
        self.herdr.refused.clear()
        for _ in range(2):
            self.step(self.cfg.reconcile_every)
        self.assertEqual(self.paths.clear_claims(), [])
        self.assertEqual(self.shown("stuck"), {"agent_summary": None, "agent_summary_stale": None})
        self.assertEqual(self.shown(), fresh("Post clear work"))
        self.assertTrue(os.path.exists(os.path.join(self.paths.pane_dir, "lead.json")))

    def test_a_clear_requested_during_a_clear_is_processed_afterwards(self):
        self.summarised("Before the first clear")
        report = self.herdr.report

        def requesting(pane, label, seq, token, clear):
            # The operator clears again while the first clear is reporting.
            if token is None and not self.paths.clear_claims()[1:]:
                M.hook("clear", None, self.paths, "build-a", start=lambda: None)
            return report(pane, label, seq, token, clear)

        self.herdr.report = requesting
        self.request_clear()
        self.herdr.report = report
        self.assertTrue(os.path.exists(self.paths.clear_request))
        self.model.reply = "Between the clears"
        self.event()
        self.assertEqual(self.shown(), fresh("Between the clears"))
        for _ in range(2):
            self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.assertFalse(os.path.exists(self.paths.clear_request))
        self.assertEqual(self.paths.clear_claims(), [])

    def test_a_refused_worker_clear_is_retried(self):
        self.summarised("Lead summary")
        self.herdr.reports_fail = True
        self.lead("idle", name="worker-1", tokens=self.herdr.agents["lead"]["tokens"])
        self.step(self.cfg.reconcile_every)
        self.herdr.reports_fail = False
        self.step(self.cfg.reconcile_every)
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})

    def test_clear_holds_for_a_working_pane(self):
        self.lead("working")
        self.append(user("Long build"))
        self.step()
        self.step(self.cfg.settle)
        self.settle()
        self.request_clear()
        for _ in range(4):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.assertEqual(len(self.model.calls), 1)

    def test_clear_abandons_a_running_call(self):
        self.model.hold = True
        self.lead("idle")
        self.append(user("Add retry"))
        self.step()
        self.request_clear()
        self.assertTrue(self.model.calls[0].cancelled)
        self.model.calls[0].release()
        self.settle()
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.assertEqual(os.listdir(self.paths.pane_dir), [])

    def test_clear_in_a_new_process_is_one_shot(self):
        self.summarised("Adding metrics")
        open(self.paths.clear_request, "w").close()
        self.daemon = self.make_daemon()
        for _ in range(3):
            self.step(self.cfg.reconcile_every)
            self.settle()
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.assertEqual(len(self.model.calls), 1)
        self.assertFalse(os.path.exists(self.paths.clear_request))


class LifecycleTests(Base):
    def test_a_hook_from_another_build_abandons_running_calls(self):
        stops = []
        self.daemon.on_stop = lambda: stops.append(len(self.daemon.jobs))
        self.model.hold = True
        self.lead("idle")
        self.append(user("Add retry"))
        self.step()
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-b"})
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-b"})
        # Calls end before the lock is handed over.
        self.assertEqual(stops, [0])
        self.assertTrue(self.model.calls[0].cancelled)
        self.assertTrue(self.daemon.finished)
        slots = M.Slots(self.paths.slot_dir, 2)
        held = [slots.acquire(), slots.acquire()]
        self.assertNotIn(None, held)
        for fd in held:
            slots.release(fd)

    def test_a_slot_is_kept_while_its_call_may_still_run(self):
        self.lead("idle")
        self.append(user("Add retry"))
        self.model.hold = True
        self.step()
        call = self.model.calls[0]
        call.gone = False
        call.release()
        self.step()
        self.assertIsNone(M.Slots(self.paths.slot_dir, 1).acquire())
        call.gone = True
        self.step()
        fd = M.Slots(self.paths.slot_dir, 1).acquire()
        self.assertIsNotNone(fd)
        os.close(fd)

    def test_a_retired_process_does_not_overwrite_its_successor(self):
        self.model.hold = True
        self.model.reply = "Old build result"
        self.lead("idle")
        self.append(user("Add retry"))
        self.step()
        old_call = self.model.calls[0]
        self.daemon.handle({"kind": "event", "pane": "lead", "build": "build-b"})
        self.append(tool("Bash", {"command": "make check"}))
        successor = self.make_daemon()
        successor.build = "build-b"
        self.model.hold = False
        self.model.reply = "New build result"
        successor.step(self.clock.now)
        successor.step(self.clock.now)
        self.assertEqual(self.shown(), fresh("New build result"))
        old_call.release()
        self.daemon.poll_jobs(self.clock.now)
        self.assertEqual(self.state()["summary"], "New build result")
        self.assertEqual(self.state()["size"], os.path.getsize(self.transcript))
        self.assertEqual(self.shown(), fresh("New build result"))

    def test_a_clear_request_outlives_a_build_change(self):
        self.summarised("Adding metrics")
        open(self.paths.clear_request, "w").close()
        self.daemon.handle({"kind": "clear", "build": "build-b"})
        self.assertTrue(self.daemon.finished)
        successor = self.make_daemon()
        successor.step(self.clock.now)
        self.assertEqual(self.shown(), {"agent_summary": None, "agent_summary_stale": None})
        self.assertFalse(os.path.exists(self.paths.clear_request))

    def test_a_model_call_that_cannot_start_releases_its_slot(self):
        self.summarised("Old lead task")

        def broken(prompt, now):
            raise UnicodeEncodeError("utf-8", "x", 0, 1, "surrogates not allowed")

        self.model.start = broken
        self.append(user("next"))
        self.event()
        self.assertEqual(self.shown(), stale("Old lead task"))
        slots = M.Slots(self.paths.slot_dir, 2)
        held = [slots.acquire(), slots.acquire()]
        self.assertNotIn(None, held)
        for fd in held:
            slots.release(fd)

    def test_a_failing_poll_ends_its_job(self):
        self.summarised("Old lead task")

        class Broken:
            def poll(self, now):
                raise PermissionError("killpg")

        self.model.start = lambda prompt, now: Broken()
        self.append(user("next"))
        self.event()
        self.assertEqual(self.daemon.jobs, {})
        self.assertEqual(self.shown(), stale("Old lead task"))

    def test_the_log_is_rotated_while_running(self):
        rotations = []
        self.daemon.rotate = lambda: rotations.append(1)
        self.step()
        self.step(self.cfg.reconcile_every)
        self.assertEqual(len(rotations), 2)

    def test_exits_when_the_socket_is_gone(self):
        self.step()
        os.unlink(self.socket)
        self.step(self.cfg.reconcile_every)
        self.assertTrue(self.daemon.finished)

    def test_exits_when_the_server_stops_answering(self):
        self.step()
        self.herdr.down = True
        for _ in range(5):
            self.step(self.cfg.reconcile_every)
        self.assertFalse(self.daemon.finished)
        for _ in range(2):
            self.step(self.cfg.reconcile_every)
        self.assertTrue(self.daemon.finished)

    def test_a_failing_pane_does_not_stop_the_others(self):
        path = os.path.join(self.omp_sessions, "-repo", "2026_omp.jsonl")
        self.append(*omp_lines(), path=path)
        self.herdr.put("omp", "omp", "", "idle", {"agent": "omp", "kind": "path", "value": path})
        self.lead("idle")
        self.append(user("Add retry"))
        original = M.digest

        def failing(agent, path, tail_bytes):
            if agent == "claude":
                raise RuntimeError("broken transcript")
            return original(agent, path, tail_bytes)

        M.digest = failing
        try:
            self.settle()
        finally:
            M.digest = original
        self.assertTrue(any("broken transcript" in line for line in self.logs))
        self.assertEqual(self.shown("omp"), fresh("Fixing the login test"))

    def test_panes_owned_by_a_legacy_loop_are_left_alone(self):
        os.makedirs(self.paths.legacy_lock_dir)
        held = self.hold(os.path.join(self.paths.legacy_lock_dir, "lead.loop"))
        self.lead("working", tokens={"agent_summary": PREFIX + "Old build line"})
        self.append(user("Work on logout"))
        self.step()
        self.event()
        self.step(self.cfg.interval)
        self.settle()
        self.assertEqual(self.herdr.reports, [])
        self.assertEqual(self.model.calls, [])
        self.release(held)
        self.step(self.cfg.reconcile_every)
        self.step(self.cfg.settle)
        self.settle()
        self.assertEqual(len(self.model.calls), 1)
        self.assertEqual(self.shown(), fresh("Fixing the login test"))


# --- Real child processes -------------------------------------------------------

FAKE_CLAUDE = """\
import json, os, sys, time
mode = open(os.environ["CLAUDE_MODE"]).read()
if mode == "noread":
    time.sleep(5)
    sys.exit(0)
if mode == "fork":
    # The leader exits at once; its descendant stays in the process group.
    if os.fork() == 0:
        with open(os.environ["DESCENDANT_PID"], "w") as handle:
            handle.write(str(os.getpid()))
        time.sleep(10)
        os._exit(0)
    while not os.path.exists(os.environ["DESCENDANT_PID"]):
        time.sleep(0.01)
    sys.exit(0)
entry = {
    "args": sys.argv[1:],
    "cwd": os.getcwd(),
    "input": sys.stdin.read(),
    "config": os.environ.get("CLAUDE_CONFIG_DIR", ""),
    "inherited": sorted(k for k in os.environ if k.startswith(("HERDR_", "CLAUDECODE", "CLAUDE_CODE_"))),
}
with open(os.environ["CLAUDE_LOG"], "a") as log:
    log.write(json.dumps(entry) + "\\n")
if mode == "fail":
    print("Invalid API key")
    sys.exit(1)
if mode == "error":
    print(open(os.environ["CLAUDE_ERROR"]).read())
    sys.exit(1)
if mode == "slow":
    time.sleep(300)
print(open(os.environ["CLAUDE_REPLY"]).read())
"""

FAKE_HERDR = """\
import glob, json, os, sys, time
if os.path.exists(os.environ.get("HANG_FILE", "/nonexistent")):
    time.sleep(300)
args = sys.argv[1:]
agents_dir = os.environ["AGENTS_DIR"]
if args[:2] == ["agent", "get"]:
    path = os.path.join(agents_dir, args[2] + ".json")
    if not os.path.exists(path):
        print('{"error":{"code":"agent_not_found"}}', file=sys.stderr)
        sys.exit(1)
    print(json.dumps({"id": "cli:agent:get", "result": {"type": "agent_info", "agent": json.load(open(path))}}))
elif args[:2] == ["api", "snapshot"]:
    agents = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(agents_dir, "*.json")))]
    print(json.dumps({"result": {"snapshot": {"agents": agents}}}))
elif args[:2] == ["pane", "report-metadata"]:
    with open(os.environ["REPORT_LOG"], "a") as log:
        log.write(json.dumps(args) + "\\n")
    if os.path.exists(os.environ.get("REPORT_FAIL", "/nonexistent")):
        sys.exit(1)
    path = os.path.join(agents_dir, args[2] + ".json")
    if os.path.exists(path):
        agent = json.load(open(path))
        for flag, value in zip(args, args[1:]):
            if flag == "--clear-token":
                agent["tokens"].pop(value, None)
            elif flag == "--token":
                name, _, text = value.partition("=")
                agent["tokens"][name] = text
        json.dump(agent, open(path, "w"))
else:
    sys.exit(2)
"""


class ProcessBase(Base):
    def setUp(self):
        super().setUp()
        self.claude_log = os.path.join(self.tmp, "claude-calls")
        self.claude_mode = os.path.join(self.tmp, "claude-mode")
        self.report_log = os.path.join(self.tmp, "reports")
        self.agents_dir = os.path.join(self.tmp, "agents")
        os.makedirs(self.agents_dir)
        self.write_script(self.cfg.claude_bin, FAKE_CLAUDE)
        self.write_script(self.cfg.herdr_bin, FAKE_HERDR)
        self.set_mode("reply")
        self.env = {
            "CLAUDE_MODE": self.claude_mode,
            "CLAUDE_LOG": self.claude_log,
            "CLAUDE_REPLY": os.path.join(FIXTURES, "claude-reply.json"),
            "CLAUDE_ERROR": os.path.join(FIXTURES, "claude-error.json"),
            "AGENTS_DIR": self.agents_dir,
            "REPORT_LOG": self.report_log,
            "HANG_FILE": os.path.join(self.tmp, "hang"),
            "REPORT_FAIL": os.path.join(self.tmp, "report-fail"),
            "DESCENDANT_PID": os.path.join(self.tmp, "descendant-pid"),
        }
        self.saved_env = dict(os.environ)
        os.environ.update(self.env)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.saved_env)
        super().tearDown()

    def write_script(self, path, body):
        with open(path, "w") as handle:
            handle.write(f"#!{sys.executable}\n{body}")
        os.chmod(path, 0o700)

    def set_mode(self, mode):
        with open(self.claude_mode, "w") as handle:
            handle.write(mode)

    def put_agent(self, pane, agent, name, status, session, tokens=None):
        with open(os.path.join(self.agents_dir, f"{pane}.json"), "w") as handle:
            json.dump(
                {
                    "pane_id": pane,
                    "agent": agent,
                    "name": name,
                    "agent_status": status,
                    "agent_session": session,
                    "tokens": tokens or {},
                },
                handle,
            )

    def claude_calls(self):
        try:
            with open(self.claude_log) as handle:
                return [json.loads(line) for line in handle]
        except FileNotFoundError:
            return []

    def run_call(self, prompt="Agent state: idle", advance=None):
        model = M.ClaudeModel(self.cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        call = model.start(prompt, 0.0)
        now = 0.0 if advance is None else advance
        result = [None]

        def done():
            finished, raw = call.poll(now)
            result[0] = raw
            return finished

        wait_until(done, "the model call")
        return result[0]


class ModelProcessTests(ProcessBase):
    def test_model_call_is_isolated(self):
        os.environ.update(
            {
                "HERDR_PANE_ID": "focused",
                "HERDR_ENV": "1",
                "CLAUDECODE": "1",
                "CLAUDE_CODE_ENTRYPOINT": "cli",
            }
        )
        self.assertEqual(
            self.run_call("Agent state: idle\n- Edit: x"), "Fixing logout path retry and tests"
        )
        (call,) = self.claude_calls()
        args = call["args"]
        for flag in ("-p", "--safe-mode", "--no-session-persistence", "--disable-slash-commands"):
            self.assertIn(flag, args)
        self.assertEqual(args[args.index("--tools") + 1], "")
        self.assertEqual(args[args.index("--model") + 1], "haiku")
        self.assertTrue(json.loads(args[args.index("--settings") + 1])["disableAllHooks"])
        self.assertEqual(args[args.index("--output-format") + 1], "json")
        self.assertEqual(args[args.index("--system-prompt") + 1], M.SYSTEM_PROMPT)
        self.assertEqual(call["cwd"], os.path.realpath(self.paths.claude_cwd))
        self.assertEqual(call["config"], self.claude_config)
        self.assertEqual(call["inherited"], [])
        self.assertEqual(call["input"], "Agent state: idle\n- Edit: x\n")

    def test_failures(self):
        for mode in ("fail", "error"):
            with self.subTest(mode=mode):
                self.set_mode(mode)
                self.assertIsNone(self.run_call())

    def test_hung_call_is_abandoned_at_the_timeout(self):
        self.set_mode("slow")
        model = M.ClaudeModel(self.cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        call = model.start("Agent state: idle", 0.0)
        self.assertEqual(call.poll(0.0), (False, None))
        wait_until(lambda: self.claude_calls(), "the model to start")
        self.assertEqual(call.poll(self.cfg.timeout), (False, None))
        wait_until(lambda: call.poll(self.cfg.timeout)[0], "the timed-out call to end", deadline=20)
        self.assertEqual(call.poll(self.cfg.timeout), (True, None))
        with open(self.paths.log_file) as handle:
            self.assertIn("model call timed out", handle.read())

    def test_input_beyond_a_pipe_buffer_does_not_block(self):
        self.set_mode("noread")
        model = M.ClaudeModel(self.cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        started = time.monotonic()
        call = model.start("x" * 200_000, 0.0)
        self.assertLess(time.monotonic() - started, 2.0)
        self.assertEqual(call.poll(self.cfg.timeout), (False, None))
        self.assertIsNotNone(call.term_at)
        wait_until(lambda: call.poll(self.cfg.timeout)[0], "the timed-out call to end")
        self.assertEqual(call.poll(self.cfg.timeout), (True, None))

    def test_cancel_ends_a_running_call(self):
        self.set_mode("slow")
        model = M.ClaudeModel(self.cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        call = model.start("Agent state: idle", 0.0)
        wait_until(lambda: self.claude_calls(), "the model to start")
        self.assertTrue(call.end(M.KILL_GRACE))
        self.assertIsNotNone(call.proc.returncode)
        self.assertEqual(call.poll(0.0), (True, None))

    def descendant(self):
        with open(self.env["DESCENDANT_PID"]) as handle:
            return int(handle.read())

    def assert_ended(self, pid):
        """A killed process may stay a zombie until its reaper, launchd on
        macOS, collects it; it must never be able to run again."""
        end = time.monotonic() + 10
        while process_state(pid) not in (None, "Z"):
            if time.monotonic() > end:
                self.fail(f"process {pid} still exists after the call ended: {describe(pid)}")
            time.sleep(0.02)

    def test_ending_a_call_reaches_descendants_of_an_exited_leader(self):
        self.set_mode("fork")
        model = M.ClaudeModel(self.cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        call = model.start("Agent state: idle", 0.0)
        wait_until(lambda: call.poll(0.0)[0], "the leader to exit")
        pid = self.descendant()
        self.assertTrue(alive(pid))
        self.assertTrue(call.end(M.KILL_GRACE))
        self.assert_ended(pid)

    def test_ending_a_call_with_an_unreaped_leader(self):
        self.set_mode("fork")
        model = M.ClaudeModel(self.cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        call = model.start("Agent state: idle", 0.0)
        wait_until(lambda: os.path.exists(self.env["DESCENDANT_PID"]), "the descendant")
        pid = self.descendant()
        # The leader has exited or is about to, and nothing has reaped it.
        self.assertIsNone(call.proc.returncode)
        self.assertTrue(call.end(M.KILL_GRACE))
        self.assert_ended(pid)

    def test_stop_reaches_descendants_of_an_exited_leader(self):
        self.set_mode("fork")
        log = M.Log(self.paths.log_file, self.clock)
        daemon = M.Daemon(
            self.cfg,
            self.paths,
            self.herdr,
            M.ClaudeModel(self.cfg, self.paths, log),
            M.Slots(self.paths.slot_dir, self.cfg.max_concurrent),
            self.clock,
            log,
            "build-a",
        )
        self.lead("idle")
        self.append(user("Add retry"))
        daemon.step(self.clock.now)
        (job,) = daemon.jobs.values()
        wait_until(lambda: job.call.proc.poll() is not None, "the leader to exit")
        pid = self.descendant()
        daemon.handle({"kind": "event", "pane": "lead", "build": "build-b"})
        self.assertTrue(daemon.finished)
        self.assert_ended(pid)
        slots = M.Slots(self.paths.slot_dir, 2)
        held = [slots.acquire(), slots.acquire()]
        self.assertNotIn(None, held)
        for fd in held:
            slots.release(fd)

    def test_missing_binary_fails_the_call(self):
        cfg = dataclasses.replace(self.cfg, claude_bin=os.path.join(self.tmp, "missing"))
        model = M.ClaudeModel(cfg, self.paths, M.Log(self.paths.log_file, self.clock))
        self.assertEqual(model.start("x", 0.0).poll(0.0), (True, None))


class HerdrCliTests(ProcessBase):
    def test_client(self):
        self.put_agent("lead", "claude", "", "idle", CLAUDE_SESSION)
        client = M.HerdrCli(self.cfg.herdr_bin, 10)
        self.assertEqual([a["pane_id"] for a in client.snapshot()], ["lead"])
        self.assertEqual(client.agent("lead")["agent_status"], "idle")
        self.assertIsNone(client.agent("missing"))
        client.report(
            "lead", "claude", 7, ("agent_summary", PREFIX + "Text"), ("agent_summary_stale",)
        )
        with open(self.report_log) as handle:
            self.assertEqual(
                json.loads(handle.read()),
                [
                    "pane",
                    "report-metadata",
                    "lead",
                    "--source",
                    "local.agent-summary",
                    "--agent",
                    "claude",
                    "--seq",
                    "7",
                    "--token",
                    "agent_summary=" + PREFIX + "Text",
                    "--clear-token",
                    "agent_summary_stale",
                ],
            )

    def test_report_failure_is_returned(self):
        self.put_agent("lead", "claude", "", "idle", CLAUDE_SESSION)
        client = M.HerdrCli(self.cfg.herdr_bin, 10)
        self.assertTrue(client.report("lead", "claude", 1, None, ("agent_summary",)))
        open(self.env["REPORT_FAIL"], "w").close()
        self.assertFalse(client.report("lead", "claude", 2, None, ("agent_summary",)))

    def test_unresponsive_server_is_bounded(self):
        open(self.env["HANG_FILE"], "w").close()
        client = M.HerdrCli(self.cfg.herdr_bin, 0.5)
        self.assertIsNone(client.snapshot())
        self.assertIsNone(client.agent("lead"))


class HookTests(Base):
    def setUp(self):
        super().setUp()
        self.starts = []

    def hook(self, kind="event", build="build-a"):
        M.hook(kind, "lead", self.paths, build, start=lambda: self.starts.append(1))

    def hold_process(self, build):
        self.hold(self.paths.lock)
        with open(self.paths.info, "w") as handle:
            json.dump({"pid": 1, "build": build}, handle)

    def test_starts_an_absent_process(self):
        self.hook()
        self.assertEqual(self.starts, [1])

    def test_messages_a_running_process(self):
        self.hold_process("build-a")
        inbox = M.Inbox(self.paths.inbox)
        self.hook()
        self.assertEqual(self.starts, [])
        self.assertEqual(inbox.read(), [{"kind": "event", "pane": "lead", "build": "build-a"}])

    def test_another_build_gets_a_successor(self):
        self.hold_process("build-old")
        inbox = M.Inbox(self.paths.inbox)
        self.hook()
        self.assertEqual(self.starts, [1])
        self.assertEqual(inbox.read()[0]["build"], "build-a")

    def test_clear_without_a_process_starts_one(self):
        self.hook("clear")
        self.assertEqual(self.starts, [1])
        self.assertTrue(os.path.exists(self.paths.clear_request))

    def test_clear_with_a_process_wakes_it(self):
        self.hold_process("build-a")
        inbox = M.Inbox(self.paths.inbox)
        self.hook("clear")
        self.assertEqual(self.starts, [])
        self.assertTrue(os.path.exists(self.paths.clear_request))
        self.assertEqual(inbox.read()[0]["kind"], "clear")


class AcquireTests(Base):
    def holder(self, build):
        fd = self.hold(self.paths.lock)
        with open(self.paths.info, "w") as handle:
            json.dump({"pid": 1, "build": build}, handle)
        return fd

    def test_free_lock(self):
        fd = M.acquire(self.paths, "build-a", wait=1, sleep=lambda s: None)
        self.assertIsNotNone(fd)
        os.close(fd)

    def test_same_build_already_running(self):
        self.holder("build-a")
        self.assertIsNone(M.acquire(self.paths, "build-a", wait=1, sleep=lambda s: None))

    def test_waits_for_another_build_to_exit(self):
        fd = self.holder("build-old")
        sleeps = []

        def sleep(seconds):
            sleeps.append(seconds)
            if seconds == 0.5 and fd in self.held_fds:
                self.release(fd)

        got = M.acquire(self.paths, "build-a", wait=5, sleep=sleep)
        self.assertIsNotNone(got)
        os.close(got)

    def test_one_successor_waits(self):
        self.holder("build-old")
        self.hold(self.paths.successor_lock)
        self.assertIsNone(M.acquire(self.paths, "build-a", wait=5, sleep=lambda s: None))

    def test_gives_up_when_the_old_process_stays(self):
        self.holder("build-old")
        self.assertIsNone(M.acquire(self.paths, "build-a", wait=2, sleep=lambda s: None))


class EndToEndTests(ProcessBase):
    """The hooks and the per-server process as Herdr runs them."""

    def setUp(self):
        super().setUp()
        self.pids = []
        config = {
            "worker_prefixes": ["worker-"],
            "interval": 30,
            "model": "haiku",
            "timeout": 10,
            "max_concurrent": 2,
            "claude_bin": self.cfg.claude_bin,
            "claude_config_dir": self.claude_config,
            "omp_sessions_dir": self.omp_sessions,
            "settle": 0,
            "reconcile_every": 0.2,
        }
        with open(MODULE_PATH, encoding="utf-8") as handle:
            source = handle.read()
        built = source.replace(
            'CONFIG_JSON = "@config@"', f"CONFIG_JSON = {json.dumps(json.dumps(config))}"
        )
        self.assertNotEqual(built, source)
        self.builds = []
        for name in ("build-a", "build-b"):
            path = os.path.join(self.tmp, name, "herdr-agent-summary")
            os.makedirs(os.path.dirname(path))
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(built)
            self.builds.append(path)
        self.env.update(
            {
                "HERDR_PLUGIN_STATE_DIR": self.cfg.state_dir,
                "HERDR_SOCKET_PATH": self.socket,
                "HERDR_BIN_PATH": self.cfg.herdr_bin,
                "PYTHONDONTWRITEBYTECODE": "1",
            }
        )

    def tearDown(self):
        # Without its socket the process stops and ends its model calls.
        if os.path.exists(self.socket):
            os.unlink(self.socket)
        end = time.monotonic() + 5
        while time.monotonic() < end and any(alive(pid) for pid in self.pids if pid):
            time.sleep(0.05)
        # Only processes this test started, identified by its temporary directory.
        for pid in self.pids:
            mine = self.tmp in command_of(pid)
            if mine and alive(pid):
                os.kill(pid, 9)
        super().tearDown()

    def hook(self, build, *args, event=None):
        env = dict(os.environ, **self.env)
        if event is not None:
            env["HERDR_PLUGIN_EVENT_JSON"] = json.dumps(event)
        # Herdr reads a hook's output to the end, so a process left holding
        # these pipes would keep the hook running.
        result = subprocess.run(
            [sys.executable, build, *args],
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def info(self):
        try:
            with open(self.paths.info) as handle:
                info = json.load(handle)
        except (OSError, ValueError):
            return {}
        if info.get("pid") not in self.pids:
            self.pids.append(info.get("pid"))
        return info

    def reports(self):
        try:
            with open(self.report_log) as handle:
                return [json.loads(line) for line in handle]
        except FileNotFoundError:
            return []

    def test_one_process_per_server_replaced_on_update(self):
        self.append(user("Add retry to the login client"))
        self.put_agent("lead", "claude", "", "idle", CLAUDE_SESSION)
        self.hook(self.builds[0], "--startup")
        line = "agent_summary=" + PREFIX + "Fixing logout path retry and tests"
        wait_until(lambda: any(line in r for r in self.reports()), "the first summary")
        first = self.info()
        self.assertEqual(first["build"], os.path.realpath(self.builds[0]))
        self.hook(self.builds[0], "--startup")
        self.hook(self.builds[0], "--event", event={"data": {"pane_id": "lead"}})
        self.assertEqual(self.info()["pid"], first["pid"])
        self.assertEqual(len(self.claude_calls()), 1)

        self.hook(self.builds[1], "--event", event={"data": {"pane_id": "lead"}})
        wait_until(
            lambda: self.info().get("build") == os.path.realpath(self.builds[1]), "the successor"
        )
        wait_until(lambda: not alive(first["pid"]), "the predecessor to exit")
        second = self.info()

        os.unlink(self.socket)
        wait_until(lambda: not alive(second["pid"]), "the process to exit with its server")
        with open(self.paths.log_file) as handle:
            log = handle.read()
        self.assertIn("a hook from another build arrived", log)
        self.assertIn("the Herdr server socket is gone", log)
        self.assertEqual(len(self.claude_calls()), 1)

    def test_clear_hook_returns_while_the_server_hangs(self):
        self.append(user("Add retry to the login client"))
        self.put_agent("lead", "claude", "", "idle", CLAUDE_SESSION)
        self.hook(self.builds[0], "--startup")
        line = "agent_summary=" + PREFIX + "Fixing logout path retry and tests"
        wait_until(lambda: any(line in r for r in self.reports()), "the first summary")
        pid = self.info()["pid"]
        os.unlink(self.socket)
        wait_until(lambda: not alive(pid), "the process to exit with its server")
        open(self.socket, "w").close()
        self.put_agent("lead", "claude", "", "idle", CLAUDE_SESSION, {"agent_summary": "x"})
        open(self.env["HANG_FILE"], "w").close()
        started = time.monotonic()
        self.hook(self.builds[0], "--clear")
        # Well inside the 10 s Herdr call timeout.
        self.assertLess(time.monotonic() - started, 5.0)
        os.unlink(self.env["HANG_FILE"])
        # The claim is consumed once Herdr shows the line gone.
        wait_until(
            lambda: not os.path.exists(self.paths.clear_request) and not self.paths.clear_claims(),
            "the clear",
            deadline=60,
        )
        self.assertEqual(os.listdir(self.paths.pane_dir), [])
        self.assertIn("--clear-token", self.reports()[-1])
        self.assertNotIn("--token", self.reports()[-1])
        # One-shot: nothing repopulates the line without an event.
        time.sleep(1)
        self.assertEqual(os.listdir(self.paths.pane_dir), [])
        self.assertEqual(len(self.claude_calls()), 1)
        self.info()
        os.unlink(self.socket)
        wait_until(lambda: all(not alive(p) for p in self.pids if p), "the process to exit")


if __name__ == "__main__":
    MODULE_PATH, FIXTURES = (os.path.abspath(path) for path in sys.argv[1:3])
    M = load_module()
    unittest.main(argv=[sys.argv[0], *sys.argv[3:]], verbosity=2)

# gh-dash — declarative GitHub dashboard (gh extension).
#
# The HM module owns the binary and auto-registers it in
# `programs.gh.extensions`, so `gh dash` works without a manual
# `gh extension install`. This file is the *global* config layer and stays
# generic (@me sections, layout, theme): gh-dash merges a `.gh-dash.yml`
# found at a repo's root on top of it (sections replace wholesale,
# keybindings union by key), which is where repo-specific sections and
# custom commands live.
#
# Theme: no Stylix target exists for gh-dash, so this bridges the base16
# palette manually (same pattern as nvim-theme.nix / sketchybar.nix).
# gh-dash falls back per-color when one is unset, but the full documented
# set is pinned here so no surface mixes palette and terminal-ANSI defaults.
{ config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;
in
{
  programs.gh-dash = {
    enable = true;
    settings = {
      prSections = [
        {
          title = "My Pull Requests";
          filters = "is:open author:@me";
        }
        {
          title = "Needs My Review";
          filters = "is:open review-requested:@me";
        }
        {
          title = "Involved";
          filters = "is:open involves:@me -author:@me";
        }
      ];
      issuesSections = [
        {
          title = "My Issues";
          filters = "is:open author:@me";
        }
        {
          title = "Assigned";
          filters = "is:open assignee:@me";
        }
        {
          title = "Involved";
          filters = "is:open involves:@me -author:@me";
        }
      ];
      repo = {
        branchesRefetchIntervalSeconds = 30;
        prsRefetchIntervalSeconds = 60;
      };
      defaults = {
        preview = {
          open = true;
          width = 50;
        };
        prsLimit = 20;
        prApproveComment = "LGTM";
        issuesLimit = 20;
        view = "prs";
        layout = {
          prs = {
            updatedAt.width = 5;
            createdAt.width = 5;
            repo.width = 20;
            author.width = 15;
            authorIcon.hidden = false;
            assignees = {
              width = 20;
              hidden = true;
            };
            base = {
              width = 15;
              hidden = true;
            };
            lines.width = 15;
          };
          issues = {
            updatedAt.width = 5;
            createdAt.width = 5;
            repo.width = 15;
            creator.width = 10;
            creatorIcon.hidden = false;
            assignees = {
              width = 20;
              hidden = true;
            };
          };
        };
        refetchIntervalMinutes = 30;
      };
      theme = {
        ui = {
          sectionsShowCount = true;
          table = {
            showSeparator = true;
            compact = false;
          };
        };
        # Semantic base16 mapping; brightness relationships mirror gh-dash's
        # own defaults (secondary text brighter than faint, borders dim).
        colors = {
          text = {
            primary = c.base05;
            secondary = c.base04;
            inverted = c.base00;
            faint = c.base03;
            warning = c.base0A;
            success = c.base0B;
            error = c.base08;
            # Upstream default keys actor to secondary; keep that relationship.
            actor = c.base04;
          };
          background.selected = c.base02;
          border = {
            primary = c.base03;
            secondary = c.base04;
            faint = c.base01;
          };
        };
      };
      pager.diff = "";
      confirmQuit = false;
      showAuthorIcons = true;
      smartFilteringAtLaunch = true;
    };
  };
}

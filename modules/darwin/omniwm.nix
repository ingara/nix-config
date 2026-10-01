# OmniWM v0.7.4 (settings schema 4). The Homebrew cask owns the app;
# Home Manager owns only its complete, store-backed settings.toml.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myOptions.windowManager;
  routingArrangements = cfg.omniwm.routing.arrangements;
  colors = config.lib.stylix.colors;
  channel = name: component: lib.toInt colors."${name}-rgb-${component}" / 255.0;
  color = name: alpha: {
    red = channel name "r";
    green = channel name "g";
    blue = channel name "b";
    inherit alpha;
  };

  # One entry per assignable action in v0.7.4's ActionCatalog. The
  # consumeOrExpelWindow{Left,Right} automation actions are unassignable.
  # The separate consume/expel actions are assignable but left to skhd:
  # binding both layers would handle Option+,/. twice.
  numbered =
    prefix: from: to:
    map (n: "${prefix}.${toString n}") (lib.range from to);
  requiredActions =
    lib.concatMap (prefix: numbered prefix 1 10) [
      "toggleScratchpad"
      "assignFocusedWindowToScratchpad"
    ]
    ++ lib.concatMap (prefix: numbered prefix 0 8) [
      "switchWorkspace"
      "moveToWorkspace"
      "moveColumnToWorkspace"
      "focusColumn"
    ]
    ++ lib.concatMap (prefix: numbered prefix 1 9) [
      "switchWorkspaceSlot"
      "moveToWorkspaceSlot"
      "focusWindowInColumn"
      "moveColumnToIndex"
    ]
    ++ [
      "workspaceBackAndForth"
      "switchWorkspace.next"
      "switchWorkspace.previous"
      "focus.left"
      "focus.down"
      "focus.up"
      "focus.right"
      "focusPrevious"
      "focusDownOrLeft"
      "focusUpOrRight"
      "focusWindowTop"
      "focusWindowBottom"
      "focusWindowDownOrTop"
      "focusWindowUpOrBottom"
      "focusWindowOrWorkspaceDown"
      "focusWindowOrWorkspaceUp"
      "centerColumn"
      "centerVisibleColumns"
      "moveWindowToWorkspaceUp"
      "moveWindowToWorkspaceDown"
      "moveColumnToWorkspaceUp"
      "moveColumnToWorkspaceDown"
      "move.left"
      "move.down"
      "move.up"
      "move.right"
      "moveWindowDown"
      "moveWindowUp"
      "moveWindowDownOrToWorkspaceDown"
      "moveWindowUpOrToWorkspaceUp"
      "consumeWindowIntoColumn"
      "expelWindowFromColumn"
      "focusMonitorNext"
      "focusMonitorPrevious"
      "focusMonitorLast"
      "moveWorkspaceToMonitor.left"
      "moveWorkspaceToMonitor.right"
      "moveWorkspaceToMonitor.up"
      "moveWorkspaceToMonitor.down"
      "moveWindowToMonitor.left"
      "moveWindowToMonitor.right"
      "moveWindowToMonitor.up"
      "moveWindowToMonitor.down"
      "toggleFullscreen"
      "toggleNativeFullscreen"
      "moveColumn.left"
      "moveColumn.right"
      "moveColumn.up"
      "moveColumn.down"
      "moveColumnToFirst"
      "moveColumnToLast"
      "toggleColumnTabbed"
      "focusColumnFirst"
      "focusColumnLast"
      "cycleSizeForward"
      "cycleSizeBackward"
      "cycleWindowPrimarySpanForward"
      "cycleWindowPrimarySpanBackward"
      "cycleWindowSecondarySpanForward"
      "cycleWindowSecondarySpanBackward"
      "toggleContainerFullPrimarySpan"
      "expandContainerToAvailablePrimarySpan"
      "resetWindowSecondarySpan"
      "setContainerPrimarySpan.decrease10Percent"
      "setContainerPrimarySpan.increase10Percent"
      "setWindowPrimarySpan.decrease10Percent"
      "setWindowPrimarySpan.increase10Percent"
      "setWindowSecondarySpan.decrease10Percent"
      "setWindowSecondarySpan.increase10Percent"
      "balanceSizes"
      "moveToRoot"
      "toggleSplit"
      "swapSplit"
      "resizeGrow.horizontal"
      "resizeGrow.vertical"
      "resizeShrink.horizontal"
      "resizeShrink.vertical"
      "resizeFocusedWindow.grow"
      "resizeFocusedWindow.shrink"
      "preselect.left"
      "preselect.right"
      "preselect.up"
      "preselect.down"
      "preselectClear"
      "openCommandPalette"
      "raiseAllFloatingWindows"
      "rescueOffscreenWindows"
      "toggleFocusedWindowFloating"
      "closeFocusedWindow"
      "openMenuAnywhere"
      "setWindowMark"
      "removeWindowMark"
      "toggleWorkspaceBarVisibility"
      "toggleHiddenBarPanel"
      "toggleQuakeTerminal"
      "toggleWorkspaceLayout"
      "toggleOverview"
      "toggleSystemStats"
    ];

  bindings = {
    "switchWorkspace.next" = "Control+Option+J";
    "switchWorkspace.previous" = "Control+Option+K";
    moveWindowToWorkspaceDown = "Control+Option+Shift+J";
    moveWindowToWorkspaceUp = "Control+Option+Shift+K";
    "focus.left" = "Option+H";
    "focus.down" = "Option+J";
    "focus.up" = "Option+K";
    "focus.right" = "Option+L";
    focusPrevious = "Option+X";
    focusColumnFirst = "Option+U";
    focusColumnLast = "Option+O";
    focusMonitorNext = "Option+M";
    focusMonitorPrevious = "Option+N";
    "move.left" = "Option+Shift+H";
    "move.down" = "Option+Shift+J";
    "move.up" = "Option+Shift+K";
    "move.right" = "Option+Shift+L";
    moveColumnToFirst = "Option+Shift+U";
    moveColumnToLast = "Option+Shift+O";
    "setContainerPrimarySpan.decrease10Percent" = "Option+Minus";
    "setContainerPrimarySpan.increase10Percent" = "Option+Equal";
    "setWindowSecondarySpan.decrease10Percent" = "Option+Shift+Minus";
    "setWindowSecondarySpan.increase10Percent" = "Option+Shift+Equal";
    centerColumn = "Option+C";
    toggleColumnTabbed = "Option+T";
    toggleContainerFullPrimarySpan = "Option+W";
    balanceSizes = "Option+Shift+B";
    toggleFullscreen = "Option+Shift+F";
    toggleFocusedWindowFloating = "Option+G";
    toggleOverview = "Option+Tab";
  };
  workspaceBindings = lib.listToAttrs (
    lib.concatMap (n: [
      {
        name = "switchWorkspace.${toString (n - 1)}";
        value = "Option+${toString n}";
      }
      {
        name = "moveToWorkspace.${toString (n - 1)}";
        value = "Option+Shift+${toString n}";
      }
    ]) (lib.range 1 (builtins.length workspaceIDs))
  );
  allBindings = bindings // workspaceBindings;

  workspaceIDs = [
    "AD36F001-C57E-41A5-AC1D-DF5249D007F0"
    "454CECD4-5E9D-4ED1-95D7-979D48817F5F"
    "BEB842B5-E894-4791-9FD1-397C3CDD3538"
    "248AA883-2261-4D45-943C-79C0E46A232B"
    "8B8C45D6-CE9E-41D9-BD50-BE4989D5E3DE"
  ];

  settings = {
    schemaVersion = 4;
    general = {
      hotkeysEnabled = true;
      systemHyperTrigger = "None";
      hyperKeyModifiers = "Control+Option+Shift+Command";
      defaultLayoutType = "niri";
      preventSleepEnabled = false;
      updateChecksEnabled = false; # Updates come from the pinned Homebrew cask.
      ipcEnabled = true;
      animationsEnabled = true;
    };
    focus = {
      followsMouse = false;
      raiseOnMouseFocus = false;
      lockModifier = "off";
      moveMouseToFocusedWindow = false;
      followsWindowToMonitor = false;
      crossesMonitorAtEdge = false;
      moveCrossesMonitorAtEdge = false;
    };
    mouseWarp = {
      margin = 1;
      enabled = true;
      constrainToArrangement = false;
    };
    routing = {
      mode = if routingArrangements == [ ] then "macOS" else "custom";
      arrangements = routingArrangements;
    };
    gaps = {
      size = 6.0;
      fullscreenUsesOuterGaps = false;
      outer = {
        left = 6.0;
        right = 6.0;
        top = 6.0;
        bottom = 6.0;
      };
    };
    niri = {
      visibleContainerCount = 2;
      infiniteLoop = false;
      centerFocusedColumn = "never";
      alwaysCenterSingleColumn = false;
      singleWindowFit = "fill";
      containerPrimarySpanPresets = [
        0.25
        0.33
        0.5
        0.66
        0.75
      ];
      defaultContainerPrimarySpan = 0.5;
      resizeStepPercent = 5;
      edgeGaps = true;
    };
    dwindle = {
      smartSplit = false;
      defaultSplitRatio = 1.0;
      splitWidthMultiplier = 1.0;
      singleWindowFit = "fill";
      useGlobalGaps = true;
      moveToRootStable = true;
    };
    borders = {
      enabled = true;
      width = 3.0;
      color = color "base0D" 1.0;
    };
    overview = {
      enabled = true;
      zoom = 1.0;
      backdrop = color "base00" 1.0;
      windowBorders = {
        normal = color "base03" 0.5;
        hovered = color "base0D" 1.0;
        selected = color "base0B" 1.0;
      };
    };
    workspaceBar = {
      enabled = true;
      showLabels = true;
      showFloatingWindows = false;
      windowLevel = "popup";
      position = "belowMenuBar";
      notchMode = "off";
      notchActiveZoneWidth = 180.0;
      systemStatsButton = false;
      deduplicateAppIcons = false;
      hideEmptyWorkspaces = false;
      excludedBundleIDs = [ ];
      iconOverrides = { };
      reserveLayoutSpace = true;
      revealModifier = "off";
      revealHoldMilliseconds = 200.0;
      hideInNativeFullscreen = false;
      height = 24.0;
      backgroundOpacity = 0.1;
      xOffset = 0.0;
      yOffset = 0.0;
    };
    gestures = {
      scrollEnabled = true;
      scrollSensitivity = 5.0;
      scrollModifierKey = "optionShift";
      mouseMoveModifierKey = "option";
      mouseResizeModifierKey = "option";
      fingerCount = 3;
      invertDirection = true;
      trackpadScrollStyle = "snap";
      workspaceSwipeEnabled = false;
      workspaceSwipeFingerCount = 3;
      workspaceSwipeAxis = "vertical";
    };
    statusBar = {
      showWorkspaceName = false;
      showAppNames = false;
      useWorkspaceId = false;
    };
    hiddenBar = {
      enabled = false;
      hiddenBundleIDs = [ ];
      rehideIntervalSeconds = 5.0;
    };
    clipboard = {
      historyEnabled = false;
      maxItems = 200;
      maxItemBytes = 8388608;
      maxTotalBytes = 67108864;
      ignoredTypes = [ ];
    };
    quakeTerminal = {
      enabled = false;
      position = "center";
      widthPercent = 50.0;
      heightPercent = 50.0;
      animationDuration = 0.2;
      autoHide = false;
      backgroundEffect = "standardBlur";
    };
    scratchpads.labels = { };
    appearance.mode = "dark";
    hotkeys = map (id: {
      inherit id;
      binding = allBindings.${id} or "Unassigned";
    }) requiredActions;
    workspaces = lib.imap0 (i: id: {
      inherit id;
      name = toString (i + 1);
      layoutType = "niri";
      monitorAssignment.type = if i == 3 || i == 4 then "secondary" else "main";
    }) workspaceIDs;
    # Preserve the v0.7.4 built-in minimum-size rules when replacing the GUI file.
    appRules = [
      {
        id = "6A31F08A-4051-4354-B439-42F4C71894A3";
        bundleId = "com.openai.codex";
        minWidth = 800.0;
        minHeight = 600.0;
      }
      {
        id = "4BA546DA-2875-4BEF-B13F-1539E833B1A0";
        bundleId = "com.eltima.cmd1.pro.mas";
        minWidth = 950.0;
        minHeight = 550.0;
      }
      {
        id = "486CEFA6-69AA-4A3C-AF27-BCD38F4F138B";
        bundleId = "com.google.Chrome";
        minWidth = 500.0;
        minHeight = 375.0;
      }
      {
        id = "979F05F4-FFA2-4EDD-B23F-08A9944C759F";
        bundleId = "dev.zed.Zed";
        minWidth = 360.0;
        minHeight = 240.0;
      }
      {
        id = "81426D13-C1A5-475E-AFBC-00BBA05042D0";
        bundleId = "com.apple.Safari";
        minWidth = 574.0;
        minHeight = 220.0;
      }
      {
        id = "1CF39647-F30D-4E76-9686-79B551F1B094";
        bundleId = "app.zen-browser.zen";
        minWidth = 500.0;
        minHeight = 495.0;
      }
      {
        id = "005C00D3-F665-47F8-BDAE-D80790E9E46B";
        bundleId = "org.mozilla.firefox";
        minWidth = 500.0;
        minHeight = 120.0;
      }
      {
        id = "C21156B1-0224-4998-97E3-8F4FA65B9F3B";
        bundleId = "company.thebrowser.dia";
        minWidth = 500.0;
        minHeight = 420.0;
      }
      {
        id = "2DE9390B-0DB4-4D0C-9ABA-06F76F1D4EA9";
        bundleId = "com.spotify.client";
        minWidth = 800.0;
        minHeight = 600.0;
      }
      {
        id = "AF752D95-8497-4844-BE20-4C93E73BAEF2";
        bundleId = "com.hnc.Discord";
        minWidth = 800.0;
        minHeight = 500.0;
      }
      {
        id = "7876C9EF-437E-4D4F-9C27-B1B02F4AABCE";
        bundleId = "com.mitchellh.ghostty";
        minWidth = 90.0;
        minHeight = 48.0;
      }
      {
        id = "8ECAB78B-BCDD-4245-BC25-1609A49B1C86";
        bundleId = "com.microsoft.Outlook";
        minWidth = 930.0;
        minHeight = 650.0;
      }
      {
        id = "552FB77D-BF0E-4737-90A6-B5BC6986C579";
        bundleId = "com.apple.MobileSMS";
        minWidth = 660.0;
        minHeight = 320.0;
      }
    ];
    monitorBarOverrides = [ ];
    monitorOrientationOverrides = [ ];
    monitorNiriOverrides = [ ];
    monitorDwindleOverrides = [ ];
    monitorGapOverrides = [ ];
  };
in
{
  assertions = lib.optionals (lib.elem "omniwm" cfg.enabled) [
    {
      assertion = builtins.length (lib.unique requiredActions) == builtins.length requiredActions;
      message = "OmniWM schema 4 hotkey action IDs must appear exactly once";
    }
    {
      assertion = lib.all (id: lib.elem id requiredActions) (lib.attrNames allBindings);
      message = "OmniWM bound action is absent from the schema 4 required action list";
    }
  ];
  xdg.configFile."omniwm/settings.toml" = lib.mkIf (lib.elem "omniwm" cfg.enabled) {
    source = (pkgs.formats.toml { }).generate "omniwm-settings.toml" settings;
  };
}

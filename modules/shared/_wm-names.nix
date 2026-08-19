# The selectable WMs, partitioned by class — single source for the
# windowManager enum (options.nix) and the Linux-host validity assertion
# (home/default.nix), so adding a WM stays one edit. Plain data, not a module
# (underscore prefix, same convention as roles/_lib.nix).
{
  darwin = [
    "yabai"
    "aerospace"
    "omniwm"
    "paneru"
    "nehir"
  ];
  linux = [
    "hyprland"
    "niri"
  ];
}

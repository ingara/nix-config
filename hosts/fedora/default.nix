{
  config,
  pkgs,
  lib,
  catppuccin,
  nix-flatpak,
  plasma-manager,
  userConfig,
  claude-code-nix,
  ...
}:

let
  user = userConfig.username;
  catppuccin-kde-macchiato = pkgs.catppuccin-kde.override {
    flavour = [ "macchiato" ];
    accents = [ "mauve" ];
    winDecStyles = [ "modern" ];
  };
in
{
  imports = [
    catppuccin.homeModules.catppuccin
    nix-flatpak.homeManagerModules.nix-flatpak
    plasma-manager.homeModules.plasma-manager
    (import ../../modules/shared/dotfiles.nix {
      configPath = "${config.home.homeDirectory}/nix-config";
      wmBackend = "none";
    })
  ];

  catppuccin = {
    flavor = "macchiato";
    enable = true;
    starship.enable = true;
    tmux.enable = true;
    fzf.enable = true;
    delta.enable = true;
    bat.enable = true;
    fish.enable = true;
    kvantum.enable = true;
    cursors.enable = true;
  };

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    packages = pkgs.callPackage ./packages.nix { } ++ [
      claude-code-nix.packages.x86_64-linux.default
      # plasma-manager scripts call `qdbus` but Fedora Plasma 6 ships `qdbus-qt6`
      (pkgs.writeShellScriptBin "qdbus" ''exec /usr/bin/qdbus-qt6 "$@"'')
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
    };

    sessionPath = [
      "$HOME/go/bin"
    ];

    stateVersion = "24.11";
  };

  programs = {
    plasma = {
      enable = true;
      workspace = {
        colorScheme = "CatppuccinMacchiatoMauve";
        cursor = {
          theme = "catppuccin-macchiato-mauve-cursors";
          size = 28;
        };
        iconTheme = "Papirus-Dark";
        theme = "breeze-dark";
        windowDecorations = {
          library = "org.kde.kwin.aurorae";
          theme = "__aurorae__svg__CatppuccinMacchiato-Modern";
        };
      };

      # Active/inactive window title bar colors (Catppuccin Macchiato)
      configFile.kdeglobals.WM = {
        activeBackground = "198,160,246"; # mauve
        activeForeground = "202,211,245"; # text
        inactiveBackground = "36,39,58"; # mantle
        inactiveForeground = "110,115,141"; # overlay0
      };

      input.keyboard.layouts = [
        { layout = "norwerty"; }
      ];

      panels = [
        # ── Top bar (macOS-style menu bar) ──
        {
          location = "top";
          height = 28;
          alignment = "center";
          lengthMode = "fill";
          floating = false;
          screen = "all";
          widgets = [
            { appMenu.compactView = true; }

            {
              applicationTitleBar = {
                layout = {
                  elements = [ "windowTitle" ];
                  horizontalAlignment = "left";
                  showDisabledElements = "deactivated";
                  verticalAlignment = "center";
                };
                windowTitle = {
                  source = "appName";
                  hideEmptyTitle = true;
                  font = {
                    bold = false;
                    fit = "fixedSize";
                    size = 12;
                  };
                  margins = {
                    left = 10;
                    right = 5;
                    top = 0;
                    bottom = 0;
                  };
                };
                behavior.activeTaskSource = "activeTask";
                overrideForMaximized.enable = false;
              };
            }

            { panelSpacer.expanding = true; }

            {
              pager.general = {
                displayedText = "desktopNumber";
                showWindowOutlines = true;
                navigationWrapsAround = true;
              };
            }

            {
              systemTray.items = {
                shown = [
                  "org.kde.plasma.battery"
                  "org.kde.plasma.bluetooth"
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.volume"
                ];
              };
            }

            {
              digitalClock = {
                time.format = "24h";
                time.showSeconds = "never";
                date.enable = true;
                date.format = "shortDate";
                date.position = "besideTime";
                calendar.firstDayOfWeek = "monday";
              };
            }
          ];
        }

        # ── Bottom dock (macOS-style floating dock) ──
        {
          location = "bottom";
          height = 56;
          alignment = "center";
          lengthMode = "fit";
          floating = true;
          hiding = "dodgewindows";
          opacity = "translucent";
          screen = "all";
          widgets = [
            {
              iconTasks = {
                launchers = [
                  "applications:app.zen_browser.zen.desktop"
                  "applications:steam.desktop"
                  "applications:com.slack.Slack.desktop"
                  "applications:com.discordapp.Discord.desktop"
                  "applications:com.mitchellh.ghostty.desktop"
                ];
                appearance.indicateAudioStreams = true;
                behavior = {
                  grouping.method = "byProgramName";
                  sortingMethod = "manually";
                  minimizeActiveTaskOnClick = true;
                  middleClickAction = "newInstance";
                  showTasks.onlyInCurrentScreen = true;
                };
              };
            }
          ];
        }
      ];
    };
  }
  // import ../../modules/shared/home-manager.nix {
    inherit
      config
      pkgs
      lib
      userConfig
      ;
    sshSignProgram = "/opt/1Password/op-ssh-sign";
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };

  # Aurorae theme needs to be in ~/.local/share for KDE to find it on Fedora
  xdg.dataFile."aurorae/themes/CatppuccinMacchiato-Modern".source =
    "${catppuccin-kde-macchiato}/share/aurorae/themes/CatppuccinMacchiato-Modern";

  services.flatpak.enable = true;
  services.flatpak.packages = [
    "io.github.zen_browser.zen"
    "com.discordapp.Discord"
    "com.slack.Slack"
    "com.visualstudio.code"
  ];

  # Norwerty keyboard layout (US QWERTY with Norwegian characters)
  # https://tobiasvl.github.io/norwerty/
  xdg.configFile."xkb/symbols/norwerty".text = ''
    // Norwerty by Tobias V. Langhoff
    // Based on Swerty by Johan E. Gustafsson
    default partial alphanumeric_keys
    xkb_symbols "basic" {

        name[Group1]="Norwegian (Norwerty)";

        key <TLDE>  { [     grave,	asciitilde, section, onehalf ]	};
        key <AE01>	{ [         1,     exclam   	     	     ]  };
        key <AE02>	{ [         2,         at,  quotedbl 	     ]	};
        key <AE03>	{ [         3, numbersign,  sterling 	     ]	};
        key <AE04>	{ [         4,     dollar,  currency 	     ]	};
        key <AE05>	{ [         5,    percent,  EuroSign 	     ]	};
        key <AE06>	{ [         6, asciicircum, dead_circumflex  ]	};
        key <AE07>	{ [         7,  ampersand,  braceleft        ]	};
        key <AE08>	{ [         8,   asterisk,  bracketleft	     ]	};
        key <AE09>	{ [         9,  parenleft,  bracketright     ]	};
        key <AE10>	{ [         0, parenright,  braceright 	     ]	};
        key <AE11>	{ [     minus, underscore,  dead_diaeresis,  dead_circumflex ]  };
        key <AE12>	{ [     equal,       plus,  dead_tilde 	     ]	};

        key <AD01>	{ [         q,          Q   		     ] 	};
        key <AD02>	{ [         w,          W 		     ]	};
        key <AD03>	{ [         e,          E,  EuroSign  	     ]	};
        key <AD04>	{ [         r,          R   		     ]	};
        key <AD05>	{ [         t,          T 		     ]	};
        key <AD06>	{ [         y,          Y 		     ]	};
        key <AD07>	{ [         u,          U 		     ]	};
        key <AD08>	{ [         i,          I 		     ]	};
        key <AD09>	{ [         o,          O,  braceleft	     ]	};
        key <AD10>	{ [         p,          P,  braceright 	     ]	};
        key <AD11>	{ [	    aring,  Aring,  bracketleft,  braceleft ]  };
        key <AD12>	{ [dead_acute, dead_grave,  bracketright,  braceright ]  };
        key <AC01>	{ [         a,          A   		     ]	};
        key <AC02>	{ [         s,          S 		     ]	};
        key <AC03>	{ [         d,          D 		     ]	};
        key <AC04>	{ [         f,          F 		     ]	};
        key <AC05>	{ [         g,          G 		     ]	};
        key <AC06>	{ [         h,          H 		     ]	};
        key <AC07>	{ [         j,          J 		     ]	};
        key <AC08>	{ [         k,          K 		     ]	};
        key <AC09>	{ [         l,          L 		     ]	};
        key <AC10>	{ [    oslash,   Ooblique,     semicolon,  colon ]  };
        key <AC11>	{ [        ae,         AE,    apostrophe,  quotedbl ]  };

        key <BKSL>	{ [ backslash,        bar		     ]	};
        key <AB01>	{ [         z,          Z 		     ]	};
        key <AB02>	{ [         x,          X 		     ]	};
        key <AB03>	{ [         c,          C 		     ]	};
        key <AB04>	{ [         v,          V 		     ]	};
        key <AB05>	{ [         b,          B 		     ] 	};
        key <AB06>	{ [         n,          N 		     ]	};
        key <AB07>	{ [         m,          M,  mu		     ]	};
        key <AB08>	{ [     comma,       less  		     ]	};
        key <AB09>	{ [    period,    greater,  colon	     ]	};
        key <AB10>	{ [     slash,   question 		     ] 	};

        include "level3(ralt_switch)"
    };
  '';

  xdg.configFile."xkb/rules/evdev.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE xkbConfigRegistry SYSTEM "xkb.dtd">
    <xkbConfigRegistry version="1.1">
      <layoutList>
        <layout>
          <configItem>
            <name>norwerty</name>
            <shortDescription>no</shortDescription>
            <description>Norwegian (Norwerty)</description>
            <languageList>
              <iso639Id>nor</iso639Id>
            </languageList>
          </configItem>
        </layout>
      </layoutList>
    </xkbConfigRegistry>
  '';

}

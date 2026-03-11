{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.zed;
  userSettingsFile = pkgs.writeText "zed-user-settings.json" (builtins.toJSON cfg.settings);
  gitRoot = config.git.root;
  stateFile = "${config.env.DEVENV_STATE}/zed-settings.json";

  taskType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      label = lib.mkOption {
        type = lib.types.str;
        description = "Display name for the task.";
      };
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to execute.";
      };
      args = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Command arguments.";
      };
      env = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Environment variable overrides.";
      };
      cwd = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Working directory (defaults to project root).";
      };
      use_new_terminal = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to create a new terminal tab.";
      };
      allow_concurrent_runs = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to allow multiple instances.";
      };
      reveal = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "always"
            "no_focus"
            "never"
          ]
        );
        default = null;
        description = "Terminal pane visibility: always, no_focus, or never.";
      };
      hide = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "never"
            "always"
            "on_success"
          ]
        );
        default = null;
        description = "Post-execution terminal behavior: never, always, or on_success.";
      };
      shell = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything));
        default = null;
        description = ''
          Shell configuration. Either "system", { program = "sh"; },
          or { with_arguments = { program = "/bin/bash"; args = [ "--login" ]; }; }.
        '';
      };
      show_summary = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to display the task summary.";
      };
      show_command = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to display the command line.";
      };
      tags = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Runnable indicator tags.";
      };
      reevaluate_context = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to re-evaluate variables on rerun.";
      };
    };
  };

  serializeTask = task: lib.filterAttrs (_: v: v != null) task;
in
{
  options.zed = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "Zed editor project configuration";

        nixd = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Configure nixd LSP via `devenv lsp`. Sets the binary to `devenv lsp` (which passes --config to nixd) and generates settings for workspace/configuration.";
              };
            };
          };
          default = { };
          description = "nixd LSP configuration.";
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Settings for .zed/settings.json. When nixd is enabled, these are merged with nixd config and binary settings.";
        };

        tasks = lib.mkOption {
          type = lib.types.listOf taskType;
          default = [ ];
          description = "Task definitions for .zed/tasks.json. Each entry is a Zed task object.";
        };

        extraFiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Additional JSON files to create in .zed/. Keys are filenames, values are serialized to JSON.";
          example = lib.literalExpression ''
            {
              "i18n.json" = {
                localePaths = [ "packages/common-lang/src/sv" ];
                sourceLocale = "sv";
              };
            }
          '';
        };
      };
    };
    default = { };
    description = "Zed editor project configuration. Manages .zed/settings.json, tasks, and nixd LSP integration.";
  };

  config = lib.mkIf cfg.enable {
    files = lib.mkMerge [
      (lib.mkIf (cfg.tasks != [ ]) {
        ".zed/tasks.json".json = map serializeTask cfg.tasks;
      })
      (lib.mkIf (!cfg.nixd.enable && cfg.settings != { }) {
        ".zed/settings.json".json = cfg.settings;
      })
      (lib.mapAttrs' (name: value: lib.nameValuePair ".zed/${name}" { json = value; }) cfg.extraFiles)
    ];

    tasks = lib.mkIf cfg.nixd.enable {
      "devenv:zed-settings" = {
        exec = ''
          mkdir -p ${gitRoot}/.zed
          nixd_config=$(devenv lsp --print-config 2>/dev/null)
          ${lib.getExe pkgs.jq} -s '
            .[1] * {
              lsp: {
                nixd: {
                  binary: { path: "devenv", arguments: ["lsp"] },
                  settings: .[0].nixd
                }
              }
            }
          ' <(echo "$nixd_config") ${userSettingsFile} > ${stateFile}
          ln -sf ${stateFile} ${gitRoot}/.zed/settings.json
        '';
        after = [ "devenv:files" ];
        before = [ "devenv:enterShell" ];
      };
    };
  };
}

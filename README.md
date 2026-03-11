# devenv-modules

Reusable [devenv](https://devenv.sh) modules.

## Modules

### zed

Zed editor project configuration — generates `.zed/settings.json`, `.zed/tasks.json`, and arbitrary extra files.

Features:
- **nixd auto-configuration** — merges `devenv lsp --print-config` into settings (opt-in via `zed.nixd.enable`)
- **Typed tasks** — freeform submodule with documented fields for all Zed task properties
- **Extra files** — write any JSON file into `.zed/`

## Usage

Add the input to your `devenv.yaml`:

```yaml
inputs:
  devenv-modules:
    url: github:sebb3/devenv-modules
```

Import and configure in your `devenv.nix`:

```nix
{ inputs, ... }:
{
  imports = [ inputs.devenv-modules.devenvModules.zed ];

  zed = {
    enable = true;
    # nixd.enable = true;  # default, auto-configures nixd LSP

    settings = {
      language_servers = [ "biome" "tsgo" "nixd" "!..." ];
    };

    tasks = [
      {
        label = "build";
        command = "make";
        reveal = "never";
      }
    ];

    extraFiles."i18n.json" = {
      localePaths = [ "src/locales/en" ];
      sourceLocale = "en";
    };
  };
}
```

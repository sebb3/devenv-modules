{
  description = "Reusable devenv modules";

  outputs = _: {
    devenvModules = {
      zed = ./modules/zed.nix;
    };
  };
}

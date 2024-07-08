{ config, lib, pkgs, ...}:
{

  packages.default = pkgs.symlinkJoin {
    name = "my-neovim-config";
    path = [ "./" ];
  };

}

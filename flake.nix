{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let
    pkgs = nixpkgs;
  in
  {

    nixosModules.peter-nvim = import ./default.nix;
    packages.default = pkgs.symlinkJoin {
      name = "my-neovim-config";
      paths = [ "./" ];
    };
  };
}

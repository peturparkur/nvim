return {
  lsp = {
    ['nil_ls'] = {
      alias = 'nil',
    },
    nixd = {
      settings = {
        nixd = {
          nixpkgs = {
            expr = 'import <nixpkgs> { }',
          },
          formatting = {
            command = { 'nixfmt' },
          },
          options = {
            nixos = {
              expr = '(builtins.getFlake "/home/peter/nodes/nixos-minipc").nixosConfigurations.peter-laptop.options',
            },
            home_manager = {
              expr = '(builtins.getFlake "/home/peter/nodes/nixos-minipc").nixosConfigurations.peter@peter-laptop.options',
            },
          },
        },
      },
    },
  },
}

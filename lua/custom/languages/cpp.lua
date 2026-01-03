-- local codelldb = require "mason-nvim-dap.mappings.adapters.codelldb"
return {
  lsp = {
    clangd = {},
  },
  dap = { codelldb = {} },
  format = { ['clang-format'] = {} },
}

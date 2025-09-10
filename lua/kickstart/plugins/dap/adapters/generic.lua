return function(name, options, adapter)
  local dap = require 'dap'

  if options == nil then
    options = {}
  end

  if adapter == nil then
    adapter = {}
  end

  -- we override the default configurations with our options
  options = vim.tbl_deep_extend('force', require('mason-nvim-dap.mappings.configurations')[name], options)

  dap.configurations.python = options
  dap.adapters.python = function(callback, config)
    adapter = vim.tbl_deep_extend('force', require('mason-nvim-dap.mappings.adapters')[name], adapter)
    callback(adapter)
  end
end

-- @name
return function(name)
  local dap = require 'dap'

  dap.adapters.python = function(callback, config)
    callback(require('mason-nvim-dap.mappings.adapters')[name])
  end
  dap.configurations.python = require('mason-nvim-dap.mappings.configurations')[name]
end

local M = {}

-- any cases where name of package is different from the binary name
local name_to_bin = {
  -- ['csharp-language-server'] = 'csharp-ls',
  -- ['python-lsp-server'] = 'pylsp',
  -- ['docker-compose-language-service'] = 'docker-compose-langserver',
}

-- We guarantee 'ensure_installed' package is installed locally
-- If enforce_local is false then we install it via mason-registry
-- By default we install LSPs via mason
M.install = function(ensure_installed, enforce_local)
  -- ensure installed is expected of the form <lspname>: {cmd: "", settings: {...}}

  -- Allow for passing in a single string
  if type(ensure_installed) == 'string' then
    ensure_installed = { ensure_installed }
  end

  if enforce_local == nil then
    enforce_local = false
  end

  -- Function to check if the executable exists in the PATH
  local function executable_exists(name)
    if name_to_bin[name] then
      return vim.fn.executable(name_to_bin[name]) == 1
    end
    return vim.fn.executable(name) == 1
  end

  local registry = require 'mason-registry'
  registry.refresh(function()
    for pkg_name, config in pairs(ensure_installed) do
      local key = pkg_name
      -- most of the times the binary of the nvim_lsp config is independent of the name of the config
      -- key represents the name of the binary/cli command that we check for in the PATH
      if config['alias'] then
        key = config['alias']
      end
      if (not executable_exists(key)) and not enforce_local then
        -- sometimes the LSP has a different name in Mason and nvim_ls config
        -- we use config[mason] to set the pkg Mason should look for in these cases
        if config['mason'] then
          pkg_name = config['mason']
        end
        local pkg = registry.get_package(pkg_name)
        if not pkg:is_installed() then
          pkg:install()
        end
      end
    end
  end)
end

return M

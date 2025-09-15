--- Lazily map files

--- languages -> {lsp, dap, format, lint} -> pkg -> config

--- @type table<string, table<string, table<string, table>>>
local M = {}

local META = {}
function META.__index(table, key)
  local ok, adapter = pcall(require, 'custom.languages.' .. key)
  if not ok then
    return nil
  end
  table[key] = adapter
  return adapter
end

setmetatable(M, META)

return M

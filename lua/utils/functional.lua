M = {}

---comment
---@generic K, V, L, T
---@param tbl table<K, V>
---@param func fun(key: K, value: V): (L, T) Function
---@return table<L, T>
M.tbl_keyvalue_map = function(func, tbl)
  local result = {}
  for key, value in pairs(tbl) do
    local k, v = func(key, value)
    result[k] = v
  end
  return result
end

---comment
---@generic K, V, L, T
---@param tbl table<K, V>
---@param func fun(idx: integer, key: K, value: V): (L, T) Function
---@return table<L, T>
M.tbl_index_keyvalue_map = function(func, tbl)
  local result = {}
  local i = 1
  for key, value in pairs(tbl) do
    local k, v = func(i, key, value)
    result[k] = v
    i = i + 1
  end
  return result
end

---@generic K, V
---@param tbl table<K, V>
---@return integer
M.len = function(tbl)
  local i = 0
  for _, _ in pairs(tbl) do
    i = i + 1
  end
  return i
end

---comment
---@generic K, V
---@param tbl table<integer, table<K, V>>
---@return table<K, V>
M.extract = function(tbl)
  local result = {}
  for _, data in ipairs(tbl) do
    for k, v in pairs(data) do
      result[k] = v
    end
  end
  return result
end

return M

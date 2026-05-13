local constants = require("vypras1.constants")

local M = {}

local cached_items
local cached_lookup

function M.items()
  if cached_items then return cached_items end

  local items = {}
  for _, group in ipairs(constants.item_groups) do
    for _, color in ipairs(constants.colors) do
      items[#items + 1] = string.format(group.pattern, color)
    end
  end

  cached_items = items
  return items
end

function M.item_lookup()
  if cached_lookup then return cached_lookup end
  local lookup = {}
  for _, item in ipairs(M.items()) do
    lookup[item] = true
  end
  cached_lookup = lookup
  return lookup
end

function M.pair_key(pair)
  return tostring(pair[1]) .. "|" .. tostring(pair[2])
end

function M.valid_item(item)
  return M.item_lookup()[item] == true
end

function M.valid_pair(pair)
  return type(pair) == "table" and M.valid_item(pair[1]) and M.valid_item(pair[2])
end

function M.all_pair_count()
  local count = #M.items()
  return count * count
end

function M.random_pair(rng)
  local items = M.items()
  local rand = rng or math.random
  return {
    items[rand(1, #items)],
    items[rand(1, #items)],
  }
end

function M.random_unused(used_lookup, rng, max_attempts)
  used_lookup = used_lookup or {}
  max_attempts = max_attempts or 20000

  for _ = 1, max_attempts do
    local pair = M.random_pair(rng)
    if not used_lookup[M.pair_key(pair)] then
      return pair
    end
  end

  return nil, "no free frequency pair found after " .. tostring(max_attempts) .. " attempts"
end

function M.build_used_lookup(allocations)
  local used = {}
  for _, allocation in pairs(allocations or {}) do
    if allocation.active and allocation.pair then
      used[M.pair_key(allocation.pair)] = true
    end
  end
  return used
end

return M

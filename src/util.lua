-------------------------------
-- Various utility functions --
-------------------------------

-- splits a string on a separator, and returns all the parts.  If the number
-- of splits reaches `limit`, no more splits are performed and the resulting
-- string is appended as a single unit.  If such an early return occurs,
-- `true` is returned as the second return value.
local function split(str, sep, limit)
  assert((not limit) or (limit >= 1), "invalid limit specified")

  local res   = {}
  local idx   = 1
  local last  = 1

  -- cache lengths
  local str_l, sep_l = #str, #sep

  while idx <= str_l do
    local part = str:sub(idx, idx + sep_l - 1)

    if part == sep then
      table.insert(res, str:sub(last, idx - 1))
      idx  = idx + sep_l
      last = idx

      if #res == limit then
        table.insert(res, str:sub(idx))
        return res, true
      end

    else
      idx = idx + 1
    end
  end

  table.insert(res, str:sub(last))
  return res
end

-- trims leading and trailing whitespace
local function trim(str)
  return str:gsub("^%s+", "")
            :gsub("%s+$", "")
end

local function slice(tbl, start, last)
  start = start or 1
  last  = last  or #tbl

  local res = {}
  for i=start,last do
    table.insert(res, tbl[i])
  end

  return res
end

---- Exposed stuff --------------------------------------------------
return { split = split
       , trim  = trim
       , slice = slice
       }

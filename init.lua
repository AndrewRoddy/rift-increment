-- rift-increment: `<C-a>` and `<C-x>` like Vim. They add 1 to, or take 1
-- from, the number under the cursor, or the next number on the line if the
-- cursor isn't on one.
--
-- A `-` right before a number counts as its sign. Hex (`0x1f`) and binary
-- (`0b101`) work too, and keep their width and the case of their letters.
-- Leading zeros keep a number's width, so 007 becomes 008. Afterwards the
-- cursor sits on the number's last character.
--
-- rift doesn't pass counts to plugins, so `5<C-a>` only adds 1. Use
-- `:Increment 5` or `:Decrement 5` instead.
local M = {}

-- rift.replace_lines also eats the newline after the range, and it takes
-- two undos. So put that newline back, and in Normal mode do the edit
-- inside a quick trip to Insert mode so a single `u` undoes it.
local function set_lines(s, e, lines)
  local out = { table.unpack(lines) }
  if #out > 0 and e < rift.get_line_count() then out[#out + 1] = "" end
  local wrap = rift.get_mode() == "normal"
  if wrap then rift.exec_action("mode:insert") end
  rift.replace_lines(s, e, out)
  if wrap then rift.exec_action("mode:normal") end
end

-- rift's columns count characters, but Lua strings are bytes. These convert
-- a column to a (1-based) byte index and back.
local function char_to_byte(s, col) return utf8.offset(s, col + 1) or (#s + 1) end
local function byte_to_char(s, b) return (utf8.len(s:sub(1, b - 1)) or (b - 1)) end

-- Maps go through `:lua` because that's when rift updates the cursor that
-- plugins see. Mapping `editor:run:Increment` directly would see the cursor
-- from before the last motion.
local function map(mode, keys, name)
  rift.map(mode, keys, string.format("editor:run:lua _rift_commands[%q].fn({})", name))
end

-- Every number on the line, in order, as { s, e, kind }. `s` and `e` are
-- byte positions, and `s` includes any sign or 0x / 0b.
local function numbers(line)
  local found, i = {}, 1
  while i <= #line do
    local s, e = line:find("0[xX]%x+", i)
    local kind = "hex"
    local bs, be = line:find("0[bB][01]+", i)
    local ds, de = line:find("%d+", i)
    if not ds then break end
    -- `0x1f` is one hex number, not a 0 followed by something else.
    if s == ds then
      kind = "hex"
    elseif bs == ds then
      s, e, kind = bs, be, "bin"
    else
      s, e, kind = ds, de, "dec"
      if s > 1 and line:sub(s - 1, s - 1) == "-" then s = s - 1 end
    end
    found[#found + 1] = { s = s, e = e, kind = kind }
    i = e + 1
  end
  return found
end

local function format_number(text, kind, delta)
  if kind == "hex" then
    local prefix, digits = text:sub(1, 2), text:sub(3)
    -- Like Vim, hex never goes negative: 0x0 minus 1 wraps around to
    -- 0xffffffffffffffff. Lua's %x already prints negatives that way.
    local n = math.tointeger(tonumber(digits, 16)) + delta
    local fmt = digits:match("%u") and "%0" .. #digits .. "X" or "%0" .. #digits .. "x"
    return prefix .. string.format(fmt, n)
  elseif kind == "bin" then
    local prefix, digits = text:sub(1, 2), text:sub(3)
    local n = tonumber(digits, 2) + delta
    if n < 0 then n = 0 end
    local bits = {}
    repeat
      table.insert(bits, 1, tostring(n & 1))
      n = n >> 1
    until n == 0
    local out = table.concat(bits)
    if #out < #digits then out = string.rep("0", #digits - #out) .. out end
    return prefix .. out
  else
    local neg = text:sub(1, 1) == "-"
    local digits = neg and text:sub(2) or text
    local n = tonumber(digits) * (neg and -1 or 1) + delta
    local out = tostring(math.abs(n))
    -- Pad back out to the old width if it had leading zeros.
    if digits:match("^0%d") and #out < #digits then
      out = string.rep("0", #digits - #out) .. out
    end
    return (n < 0 and "-" or "") .. out
  end
end

function M.add(delta)
  if rift.buf_kind() ~= "file" then return end
  local row, col = rift.get_cursor()
  local line = rift.get_lines(row, row)[1] or ""
  local cur = char_to_byte(line, col)
  for _, num in ipairs(numbers(line)) do
    if num.e >= cur then
      local text = line:sub(num.s, num.e)
      local new = format_number(text, num.kind, delta)
      local new_line = line:sub(1, num.s - 1) .. new .. line:sub(num.e + 1)
      set_lines(row, row, { new_line })
      rift.set_cursor(row, byte_to_char(new_line, num.s + #new - 1))
      return
    end
  end
end

local defaults = {
  increment = "<C-a>", -- false to disable
  decrement = "<C-x>", -- false to disable
}

function M.setup(opts)
  opts = opts or {}
  local inc = opts.increment
  if inc == nil then inc = defaults.increment end
  local dec = opts.decrement
  if dec == nil then dec = defaults.decrement end

  rift.register_command("Increment", function(args)
    M.add(tonumber(args[1]) or 1)
  end, "Add N (default 1) to the number at or after the cursor")
  rift.register_command("Decrement", function(args)
    M.add(-(tonumber(args[1]) or 1))
  end, "Subtract N (default 1) from the number at or after the cursor")
  if inc then map("n", inc, "Increment") end
  if dec then map("n", dec, "Decrement") end
end

return M

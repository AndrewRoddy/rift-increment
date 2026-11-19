# rift-increment

Vim's `<C-a>` / `<C-x>` for rift: add 1 to, or subtract 1 from, the number
under the cursor, or the first number after it on the line.

| Key | Does |
|---|---|
| `<C-a>` | Increment |
| `<C-x>` | Decrement |

- Decimal numbers take a `-` right before them as their sign (`-1` → `0`).
- `0x1f` (hex) and `0b101` (binary) are recognised. Their width and the case
  of hex letters are kept.
- Leading zeros keep a decimal number's width (`007` → `008`).
- The cursor ends on the number's last character, and `u` undoes it in one step.

rift doesn't pass counts to plugins, so `5<C-a>` adds 1. Use `:Increment 5`
or `:Decrement 5` instead.

## Options

```lua
{ "AndrewRoddy/rift-increment", opts = {
  increment = "<C-a>",  -- false to disable
  decrement = "<C-x>",  -- false to disable
} },
```

## Install

rift-increment installs through riftpm. Install riftpm first from
[Monster0506/riftpm](https://github.com/Monster0506/riftpm) (see its README),
then add rift-increment to your `plugins.lua` spec:

```lua
{ "AndrewRoddy/rift-increment" },
```

Run `:PluginSync` to clone it.

Tested with rift 0.7.7.

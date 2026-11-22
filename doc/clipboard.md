# Clipboard copying over SSH and sharing in nested Neovim

`init.lua` enables `unnamedplus` and calls `require('custom.clipboard').setup()`
early, before plugins load. Normal desktop sessions retain their existing
clipboard provider.

## Which editor is doing the yank?

These are different arrangements:

```text
local terminal → SSH → Neovim → ToggleTerm → CLI application (e.g. Pi)
```

Selecting terminal-buffer text with Neovim's Visual mode and pressing `y` uses
that same Neovim's clipboard provider. There is no second editor to connect to.
If no native provider is available, this configuration uses OSC 52 writes to
copy the text through SSH to the local terminal's clipboard. The terminal must
support and permit OSC 52 clipboard writes.

To copy Pi's displayed response, leave terminal-input mode with `<C-\><C-n>`
(or the configured `<Esc><Esc>`), select the text with `v` or `V`, and press `y`.
Then paste into a local application using its normal paste shortcut.

```text
SSH → outer Neovim → ToggleTerm → Pi → inner Neovim (external editor)
```

Pi's external editor is another process with independent registers. ToggleTerm
sets `$NVIM` to the outer editor's local RPC socket; Pi and its editor inherit
it. Without a native clipboard provider, the inner editor uses that socket to
share the outer editor's unnamed register.

## Automatic selection

1. Respect an explicitly configured `vim.g.clipboard` provider.
2. If neither `$NVIM` nor an SSH session (`$SSH_CONNECTION` or `$SSH_TTY`) is
   present, leave clipboard handling unchanged.
3. Prefer Neovim's detected non-OSC-52 provider: macOS, Wayland, X11, Windows,
   tmux, or another supported clipboard tool. This also applies over SSH.
4. If `$NVIM` is present, connect to the parent and use the register bridge.
   OSC 52 is not considered a native provider here: Neovim's built-in terminal
   permits clipboard writes from applications but does not support OSC 52 reads.
5. Otherwise, in an SSH session, install OSC 52 copying with a local paste cache.

Detection follows Neovim's normal environment/tool checks. It cannot guarantee
that an advertised display or clipboard service is healthy. A stale `$NVIM`
socket produces a warning and leaves clipboard configuration unchanged.

## SSH copying and paste limitations

OSC 52 sends escape sequences to the local terminal; it does not need a remote
X11/Wayland clipboard service or SSH clipboard forwarding. A terminal or
multiplexer may block these sequences or impose size limits. Native clipboard
detection still takes precedence, so a detected tmux provider requires working
tmux clipboard integration.

The SSH fallback **never reads the local desktop clipboard**. Neovim's `p`
pastes the most recent text copied in that editor, with separate caches for
`+` and `*`. To insert something copied in a local application, use the local
terminal's paste shortcut instead. This avoids clipboard-read permission
prompts and OSC 52 read timeouts.

This config handles Neovim yanks of terminal-buffer text, not Pi's own copy
commands or input-widget clipboard shortcuts. No inner editor is required.

## Using the nested-editor bridge

- Yank in the outer editor, then press `p` in the inner editor.
- Yank in the inner editor, then press `p` in the outer editor.
- Both inner `+` and `*` map to the parent's **unnamed register**, not separate
  desktop selections. Named registers remain local to each editor.
- Characterwise, linewise and blockwise text retain their paste semantics;
  block width is inferred from the text, as with Neovim's clipboard protocol.
- Reads always fetch current parent contents. Writes update the parent's
  unnamed register and, if it has a provider, its `+` clipboard too. This
  includes the SSH OSC 52 copier. No desktop clipboard read is needed.

The bridge is only for editor-to-editor sharing. If the parent exits,
clipboard operations report an error instead of silently returning empty data.
Communication uses synchronous local RPC and requires the parent to respond.
No network listener or SSH forwarding is added. The inherited socket grants
normal Neovim RPC access, not a clipboard-only security boundary.

## Overrides

Change the call in `init.lua` to one of:

```lua
require('custom.clipboard').setup { mode = 'auto' }   -- Default
require('custom.clipboard').setup { mode = 'off' }    -- Disable bridge and SSH fallback
require('custom.clipboard').setup { mode = 'parent' } -- Prefer parent over native detection when nested
```

An explicitly configured `vim.g.clipboard` always wins, even in `parent` mode.
Configure it before this setup call; unset it if you want automatic selection.
See also `:help clipboard-osc52` and `:help terminal-osc52`.

## Diagnostics and tests

In either editor:

```vim
:echo $NVIM
:echo provider#clipboard#Executable()
```

An active bridge reports `Parent Neovim registers`. An outer SSH editor using
the fallback reports `OSC 52 copy (local paste cache)`. The outer editor need
not have a clipboard provider for editor-to-editor register sharing to work,
but copying to the local desktop requires a working clipboard transport.

Run the isolated integration tests from the repository root on Linux:

```sh
nvim --headless -u NONE -i NONE -l tests/clipboard.lua
```

The tests start disposable Neovim processes and use temporary sockets, fake
clipboard tools, and intercepted OSC 52 writes; they do not read or overwrite
your real desktop clipboard. They check terminal-buffer yanks without an inner
editor, emitted OSC 52 sequences, cached paste, and nested register sharing.

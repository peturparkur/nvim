# Clipboard sharing in nested Neovim

`init.lua` enables `unnamedplus` and calls `require('custom.clipboard').setup()`
early, before plugins load. Normal desktop sessions retain their existing
clipboard provider.

## Which editor is doing the yank?

These are different arrangements:

```text
SSH → Neovim → ToggleTerm → CLI application
```

Selecting terminal-buffer text with Neovim's Visual mode and pressing `y` uses
that same Neovim's registers. There is no second editor to connect to.

```text
SSH → outer Neovim → ToggleTerm → Pi → inner Neovim (external editor)
```

Pi's external editor is another process with independent registers. ToggleTerm
sets `$NVIM` to the outer editor's local RPC socket; Pi and its editor inherit
it. Without a native clipboard provider, the inner editor uses that socket to
share the outer editor's unnamed register.

## Automatic selection

1. Respect an explicitly configured `vim.g.clipboard` provider.
2. If `$NVIM` is absent, leave standalone clipboard handling unchanged.
3. Prefer Neovim's detected non-OSC-52 provider: macOS, Wayland, X11, Windows,
   tmux, or another supported clipboard tool. This preserves nested-editor
   behavior on a desktop laptop and does not depend on whether SSH is in use.
4. Otherwise, connect to the parent and use the register bridge. OSC 52 is not
   considered a native provider here: Neovim's built-in terminal permits
   clipboard writes from applications but does not support OSC 52 reads.

Detection follows Neovim's normal environment/tool checks. It cannot guarantee
that an advertised display or clipboard service is healthy. A stale `$NVIM`
socket produces a warning and leaves clipboard configuration unchanged.

## Using the bridge

- Yank in the outer editor, then press `p` in the inner editor.
- Yank in the inner editor, then press `p` in the outer editor.
- Both inner `+` and `*` map to the parent's **unnamed register**, not separate
  desktop selections. Named registers remain local to each editor.
- Characterwise, linewise and blockwise text retain their paste semantics;
  block width is inferred from the text, as with Neovim's clipboard protocol.
- Reads always fetch current parent contents. Writes update the parent's
  unnamed register and, if it has a provider, its `+` clipboard too. No desktop
  clipboard read is needed.

The bridge is only for editor-to-editor sharing. It does not add clipboard
support to Pi's own input widget or other CLI applications. If the parent exits,
clipboard operations report an error instead of silently returning empty data.
Communication uses synchronous local RPC and requires the parent to respond.
No network listener or SSH forwarding is added. The inherited socket grants
normal Neovim RPC access, not a clipboard-only security boundary.

## Overrides

Change the call in `init.lua` to one of:

```lua
require('custom.clipboard').setup { mode = 'auto' }   -- Default
require('custom.clipboard').setup { mode = 'off' }    -- Never install the bridge
require('custom.clipboard').setup { mode = 'parent' } -- Prefer parent over native detection
```

An explicitly configured `vim.g.clipboard` always wins, even in `parent` mode.
Configure it before this setup call; unset it if you want automatic selection.

## Standalone SSH and the home desktop clipboard

```text
home terminal → SSH → standalone Neovim
```

There is no parent Neovim in this arrangement, so the bridge does nothing.
Copying from the remote editor to the home desktop requires a separate
clipboard transport, commonly OSC 52. This feature does not enable that
transport or change standalone SSH behavior.

OSC 52 writes plus the home terminal's paste shortcut can work over SSH.
Reading with `p` through an OSC 52 provider depends on the terminal's clipboard
read permissions and does not work through an enclosing Neovim terminal.
See `:help clipboard-osc52` and `:help terminal-osc52`.

## Diagnostics and tests

In either editor:

```vim
:echo $NVIM
:echo provider#clipboard#Executable()
```

An active bridge reports `Parent Neovim registers`. The outer editor need not
have a system clipboard provider for register sharing to work.

Run the isolated integration tests from the repository root on Linux:

```sh
nvim --headless -u NONE -i NONE -l tests/clipboard.lua
```

The tests start disposable Neovim processes and use temporary sockets and fake
clipboard tools; they do not read or overwrite your real desktop clipboard.

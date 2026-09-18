# Minarch Neovim configuration

Minarch maintains the complete editor configuration in `config/nvim/`. It uses
LazyVim and lazy.nvim, with a local Seafoam colorscheme whose palette follows
OXWM defaults. The plugin specifications, keybindings, and `lazy-lock.json` are
part of this repository. Changes to the editor should be reviewed and tested
here; there is no separate configuration repository to sync from.

## Dependencies

`install/packages` includes the system-level editor dependencies. The config
has no enabled LazyVim extras; its only plugin overrides are Seafoam and the
Snacks project search directory. Dependencies come from the locked LazyVim
defaults:

| Packages | Purpose |
| --- | --- |
| `neovim`, `git` | Editor, lazy.nvim bootstrap, plugin downloads and Git features |
| `ripgrep`, `fd`, `lazygit` | Snacks search/file pickers, grug-far search, todo-comments, Git UI |
| `tree-sitter-cli`, `gcc`, `curl`, `tar` | Generate, compile, and download Treesitter parsers |
| `curl`, `unzip`, `tar`, `gzip` | Mason tool downloads and archive extraction |
| Mason-managed `stylua`, `shfmt`, `lua-language-server` | Default Lua/shell formatters and Lua LSP; installed by Mason, not the OS manifest |
| `xclip` | X11 system clipboard integration |

The [locked Treesitter requirements](https://github.com/nvim-treesitter/nvim-treesitter/blob/5cb0114e6242625db56dd6440e945ed1ece10bc7/README.md#requirements)
specify Neovim >= 0.12 and tree-sitter CLI >= 0.26.1. Use current Arch packages
meeting those versions to reproduce the lockfile. LazyVim itself accepts older
Neovim but selects a different Treesitter revision there.
See also [locked LazyVim defaults](https://github.com/LazyVim/LazyVim/tree/999700997f72227187d49d8b92667183dc7fc809/lua/lazyvim/plugins)
and [Mason requirements](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/README.md#requirements).

A Nerd Font and a true-color terminal are useful for the UI/icons; Minarch
supplies patched st and JetBrains Mono Nerd Font. Node, Python, Rust, and
additional language servers are not required by the enabled config. Plugin
downloads, Mason tools, and parser installation need network access on first
use. The lazy.nvim update checker remains enabled.

## Validation

Installer checks cover seeding, preservation, backup replacement, dangling
symlinks, and XDG paths containing spaces. On Neovim 0.12.5, isolated fresh
bootstrap passed with the tree-sitter CLI available; startup also passed after
restoring and verifying every plugin revision against `lazy-lock.json`. An
intentionally injected Lua error correctly failed the headless smoke test. No
live user configuration was modified by these checks.

## Seafoam palette

The palette in `colors/seafoam.lua` follows [OXWM's default config](https://github.com/tonybanters/oxwm/blob/fc4ada9ac4ee8e34ace203290a2b14d10e4671cc/templates/config.lua):
background `#1a1b26`, foreground `#bbbbbb`, cyan `#0db9d7`, blue `#6dade3`,
light blue `#7aa2f7`, purple `#ad8ee6`, green `#9ece6a`, red `#f7768e`,
and lavender `#a9b1d6`. Supporting dim surfaces, selection, comment gray, and
yellow extend the window manager's UI palette for editor highlights. The
Seafoam name and highlight mappings remain intact. This is a static palette,
with no runtime dependency on OXWM or its repository.

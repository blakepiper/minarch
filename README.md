# Minarch

Minarch's canonical Neovim configuration is the complete Blarchy
configuration in [`config/nvim/`](config/nvim). Its LazyVim/lazy.nvim architecture,
plugin overrides and lockfile are preserved. The existing Seafoam highlight
mappings now use oxwm’s default navy/gray palette and colorful accents. See
[upstream provenance and dependency notes](docs/neovim-upstream.md).

Run `./install.sh` as your regular user on Arch Linux to install the editor
packages with `sudo pacman` and seed `~/.config/nvim/` (or `$XDG_CONFIG_HOME/nvim`).
Use `./install.sh --config-only` to seed configuration without installing packages.
This repository currently contains the editor portion of Minarch.

Existing configuration, including symlinks, is preserved by default. To replace
it explicitly, use `./install.sh --replace-config`; the installer first copies
the new configuration into staging, then moves the original to a unique
`nvim.backup.XXXXXXXX/nvim` beneath the config directory. The printed backup path
can be moved back after moving the replacement aside. Plugin data is retained.

Open `nvim` to let the upstream bootstrap install plugins and tools. Ordinary
upstream update behavior remains enabled and can change the installed lockfile.
To reproduce the imported plugin revisions after bootstrap or updates, close
Neovim, copy `config/nvim/lazy-lock.json` from this repository back into your
installed Neovim config directory, then run `nvim --headless '+Lazy! restore' '+qa!'`.

Run `scripts/smoke-test.sh` to verify installed configuration files, or
`scripts/smoke-test.sh --headless` to also check actual Neovim startup. The latter
may download plugins/tools on a fresh installation and fails on configuration
errors, missing Neovim, or a 180-second timeout. It checks startup, not every
interactive feature or completion of all background tool downloads.
Install the package manifest before the first startup: without `tree-sitter`
available, upstream can race two Mason installation requests for that tool.

Run `tests/install.sh` to verify config seeding, preservation, and backup behavior
in temporary directories without changing your own configuration.

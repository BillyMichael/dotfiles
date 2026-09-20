# dotfiles

Managed with [chezmoi](https://chezmoi.io). Source lives in `~/.local/share/chezmoi`.

## Fresh Mac
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply BillyMichael
brew bundle --global
```
The zshrc guards every optional tool, so the first shell works before `brew bundle` has run.
On a machine where Ghostty or 1Password were installed by hand, adopt them: `brew install --cask --adopt ghostty 1password`.

## Day to day
| Task | Command |
|---|---|
| Edit a tracked file | `chezmoi edit ~/.zshrc` then `chezmoi apply` |
| Pull in a change you made directly in `~` | `chezmoi re-add` |
| See what would change | `chezmoi diff` |
| Add a new file | `chezmoi add ~/.config/foo` |
| Commit | `chezmoi cd` then normal git |

## What's where
- `dot_zshrc` — plain zsh, no framework. Starship prompt, fzf, zoxide, three Homebrew plugins.
- `dot_config/starship.toml` — prompt. Kubernetes context/namespace shown always.
- `dot_config/ghostty/config` — terminal font, theme (follows macOS appearance), splits.
- `dot_Brewfile` — everything Homebrew, for `brew bundle --global`.
- `dot_config/zsh/functions/opsecrets.zsh` — loads 1Password items tagged `terminal` into env.

## Not tracked, on purpose
`~/.config/zsh/local.zsh` holds secrets and machine/client-specific exports. It is sourced last by `.zshrc` and listed in `.chezmoiignore`.
`~/.cache/zsh/` holds the 1Password export cache (mode 600, refreshed at most every 12h, single-flight with a lock, 10-minute back-off after a failed attempt).

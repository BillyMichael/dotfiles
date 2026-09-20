# dotfiles

Managed with [chezmoi](https://chezmoi.io). Source lives in `~/.local/share/chezmoi`.

## Fresh Mac
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply <git-remote-of-this-repo>
brew bundle --global
```

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

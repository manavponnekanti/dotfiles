# Dotfiles

## Setup

### 1. Install Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. Install Brew packages

```sh
brew bundle --file=~/dotfiles/Brewfile
```

### 3. Stow dotfiles

From the dotfiles directory:

```sh
cd ~/dotfiles
stow zsh git hammerspoon keyboard
```

### 4. Load keyboard remapping

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.KeyRemapping.plist
```

You may need to add `hidutil` to your input monitoring permissions. It's in /usr/bin, hidden folder.

### 5. Install Hammerspoon ReloadConfiguration spoon

```sh
mkdir -p ~/.hammerspoon/Spoons
curl -fsSL "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ReloadConfiguration.spoon.zip" -o /tmp/ReloadConfiguration.spoon.zip
unzip -qo /tmp/ReloadConfiguration.spoon.zip -d ~/.hammerspoon/Spoons
rm /tmp/ReloadConfiguration.spoon.zip
```

## Maintenance

### Updating Brew packages

```sh
brew update && brew upgrade
```

### Adding a new Brew package

Install it, then update the Brewfile:

```sh
brew install <package>
brew bundle dump --file=~/dotfiles/Brewfile --force
```

### Adding a new dotfile package

1. Create a directory in `~/dotfiles` mirroring the home directory structure. For example, to manage `~/.config/foo/config.toml`:

   ```
   mkdir -p ~/dotfiles/foo/.config/foo
   mv ~/.config/foo/config.toml ~/dotfiles/foo/.config/foo/config.toml
   ```

2. Stow it:

   ```sh
   cd ~/dotfiles
   stow foo
   ```

3. Add the new package name to the `stow` command in the Setup section above.

### Editing stowed dotfiles

Edit the files directly in `~/dotfiles/` (e.g. `~/dotfiles/zsh/.zshrc`). Since stow creates symlinks, changes take effect immediately — no re-stow needed.

### Removing a stow package

```sh
cd ~/dotfiles
stow -D <package>
```

This removes the symlinks from your home directory without deleting the source files.

### Syncing changes

```sh
cd ~/dotfiles
git add -A && git commit -m "description of change"
git push
```

On another machine, pull and re-stow:

```sh
cd ~/dotfiles
git pull
stow zsh git hammerspoon keyboard
```

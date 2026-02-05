# Karabiner Elements Configuration

Keyboard customisation for macOS using [Karabiner Elements](https://karabiner-elements.pqrs.org/).

## Current Rules

### Complex Modifications

| Rule | Description |
|------|-------------|
| Caps Lock → Escape | Only active in Ghostty terminal |
| Caps Lock → Escape | Only active in Rider IDE |
| Caps Lock → Escape | Only active in WebStorm IDE |
| Caps Lock → Escape | Only active in GoLand IDE |
| Right Option → Control | Only active in Ghostty and JetBrains IDEs |

### Apple Keyboard Specific (USB)

For the built-in/external Apple keyboard (vendor: 1452, product: 592):

| From | To | Purpose |
|------|-----|---------|
| Grave/Tilde (`) | Non-US Backslash | UK layout fix |
| Non-US Backslash | Grave/Tilde (`) | UK layout fix |
| Keypad Enter | Return | Consistency |

## Installation

The config is symlinked from dotfiles:

```bash
mkdir -p ~/.config/karabiner
ln -sf ~/dotfiles/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
```

## Editing

You can edit the configuration either:
- Directly in `karabiner.json`
- Via Karabiner Elements preferences (changes sync to dotfiles automatically)

## Requirements

```bash
brew install --cask karabiner-elements
```

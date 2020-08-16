# Pubspec Assist for Neovim
Easily add dependencies to your Dart / Flutter project without leaving Neovim

## Installation
### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'f-person/pubspec-assist-nvim'
```

## Usage
#### Add dependency
```vim
:PubspecAssistAddDependency provider
```

#### Add dev dependency
```vim
:PubspecAssistAddDevDependency build runner
```

## Demo
![demo](assets/demo.gif?raw=true)

## Plans
Currently the plugin will pick the first search result, selection will be added soon.

Inspired by [Pubspec Assist](https://github.com/jeroen-meijer/pubspec-assist) [VS Code extension](https://marketplace.visualstudio.com/items?itemName=jeroen-meijer.pubspec-assist)

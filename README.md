# not-html.nvim

A Neovim plugin that lets you edit HTML files using a concise, readable syntax called `not_html`. When you open an `.html` file, it is automatically decompiled into `not_html` syntax. When you save, it is transparently compiled back to HTML. The underlying `.html` file is never changed to a different format -- `not_html` is purely a visual editing layer.

## What it looks like

HTML on disk:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>My Page</title>
    <link rel="stylesheet" href="styles.css"/>
  </head>
  <body>
    <!-- Site heading -->
    <h1>Welcome!</h1>
    <p>Hello <strong>World</strong></p>
  </body>
</html>
```

What you see and edit in Neovim:

```
~!doctype(html)
~html(lang: en) {
  ~head {
    ~meta(charset: utf-8)
    ~title { My Page }
    ~link(rel: stylesheet, href: styles.css)
  }
  ~body {
    ~! { Site heading }
    ~h1 { Welcome! }
    ~p {
      Hello
      ~strong { World }
    }
  }
}
```

## Features

- **Transparent roundtrip** -- open HTML, edit as `not_html`, save back to HTML. No data loss.
- **Preserves structure** -- DOCTYPE declarations, comments, blank lines, and line breaks all survive the roundtrip.
- **Syntax highlighting** -- elements, attributes, values, comments, and escapes are all highlighted.
- **Zero dependencies** -- pure Lua, no external tools or binaries required.
- **Toggle on/off** -- disable the plugin with `:NotHtmlToggle` to edit raw HTML when needed.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "tymnim/not-html.vim",
  config = function()
    require("not_html").setup()
  end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'tymnim/not-html.vim'
```

Then in your `init.lua`:

```lua
require("not_html").setup()
```

Or in your `init.vim`:

```vim
lua require("not_html").setup()
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "tymnim/not-html.vim",
  config = function()
    require("not_html").setup()
  end,
}
```

### Local development

Clone the repo and add it to your runtime path:

```lua
vim.opt.runtimepath:prepend("~/path/to/not-html.nvim")
require("not_html").setup()
```

## Setup

Call `setup()` to activate the plugin. It hooks into `BufReadCmd` and `BufWriteCmd` for `*.html` and `*.htm` files.

```lua
require("not_html").setup({
  enabled = true, -- set to false to start disabled
})
```

## Commands

| Command | Description |
|---|---|
| `:NotHtmlToggle` | Toggle the plugin on/off. When off, HTML files open and save as raw HTML. |
| `:NotHtmlCompile` | Convert the current buffer from `not_html` to HTML (in-place). |
| `:NotHtmlDecompile` | Convert the current buffer from HTML to `not_html` (in-place). |

## Syntax reference

### Elements

Every HTML element becomes `~tagname`. Attributes go in `()`, children go in `{}`.

```
~div                                    → <div></div>
~img(src: photo.jpg)                    → <img src="photo.jpg"/>
~p { Hello }                            → <p>Hello</p>
~a(href: /, class: nav-link) { Home }   → <a href="/" class="nav-link">Home</a>
```

### Attributes

Key-value pairs separated by `:`, multiple attributes separated by `,`. Values are unquoted and run until the next `,` or `)`.

```
~meta(charset: utf-8)
~div(class: container main, id: app)
```

Boolean attributes are bare names:

```
~script(defer, src: app.js)
~input(disabled)
```

### Comments

HTML comments use the `~!` tag:

```
~! { TODO\: fix this }                  → <!-- TODO: fix this -->
```

Multiline:

```
~! {
  First line
  Second line
}
```

### DOCTYPE

```
~!doctype(html)                         → <!DOCTYPE html>
```

### Escaping

Use `\` to escape breaking characters (`~ { } ( ) : ,`) in text or attribute values:

```
~div(style: height\: 100px)
~p { Price is \~5 }
```

## Running tests

```bash
nvim -l test/test_lua.lua
```

## Full specification

See [spec.md](spec.md) for the complete language specification, grammar, processing pipeline, and decompilation rules.

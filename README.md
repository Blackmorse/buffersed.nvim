# buffersed.nvim
<b>buffersed.nvim</b> is a small and simple plugin for searching and previewing replacements in a floating window (similar to `grep` and `sed`).

# Table of Contents

1. [Installation](#installation)
2. [BufferSearch](#buffersearch)
3. [BufferSed](#buffersed)
4. [Keymaps](#keymaps)
5. [Configuration](#configuration)

## Installation

To install buffersed.nvim, use a package manager such as <b>packer</b>:
```lua
use {
  "Blackmorse/buffersed.nvim", 
  requires = { { "Blackmorse/coNVIMient.nvim" } }
}
```

## BufferSearch

<b>BufferSearch</b> allows you to search and filter lines without a match, highlighting matched substrings.

## BufferSed
<b>BufferSed</b> displays a floating window showing the difference before and after a replacement, highlighting the difference. After hitting `<CR>`, the original buffer content will be replaced (with confirmation).


## Keymaps
Here some keymap available:

 - `Ctrl-p,Ctrl-n`: move up and down one line
 - `Ctrl-d,Ctl-u`: move up and down half of the screen
 - `<Esc><Esc>` or `Ctrl-C`: quit
 - `<CR>`: perform the replacement in the original buffer (with confirmation)
 - `<Tab>`: switch between <i>search</i> and <i>replace</i> prompts

## Configuration
Here is an example of all the configuration options:
```lua
require("buffersed").setup({
    width = 0.8, -- could be a float (relative to the window sized) or integer
    height = 0.5, -- the same
    custom_position_row = 3, -- floating window row position
    custom_position_col = 4, --floating window column position
    search_highlight = "guifg=#ff007c gui=bold ctermfg=198 cterm=bold ctermbg=darkblue",
    replace_highlight = "guifg=#ff007c gui=bold ctermfg=198 cterm=bold ctermbg=darkyellow"
})
```

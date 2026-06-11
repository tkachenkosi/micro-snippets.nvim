## SimpleSnippets.nvim
#### A minimal, educational snippet plugin for Neovim (0.12+).
SimpleSnippets is not a full-featured competitor to LuaSnip or UltiSnips.
It’s a tiny, hackable, and transparent implementation designed to help you understand how snippet engines work under the hood – and to be easily extended for your own needs.

### Features
- Expand snippets with a single keymap (default <C-j>).
- Triggers are read from the text before the cursor (any non‑space sequence).
- Snippet storage: simple text files – one per filetype.
- Clean syntax: each snippet starts with ---trigger followed by the snippet body.
- Multiline snippets are automatically indented to match the trigger’s leading whitespace (tabs/spaces preserved).
- Works with mixed indentation (tabs, spaces, or both).
- Smart caching: snippet files are parsed once and reloaded automatically when changed.
- Absolutely no external dependencies – pure Lua, runs on Neovim 0.12+.

### Why use this?
- Learn how snippet expansion, text parsing, and buffer manipulation work in Neovim.
- Customise every part of the plugin without fighting a complex API.
- Keep it simple – if you only need basic keyword expansion and don’t want a heavy snippet framework.

### Installation
With lazy.nvim:
```lua
{
    "yourusername/simple-snippets.nvim",
    config = function()
        require("simple-snippets").setup({
            snippets_dir = vim.fn.stdpath("config") .. "/snippets",
            keymap = "<C-j>",
            auto_reload = true,
            multiline_indent = true -- "prefix" or "none"
        })
    end,
}
```

### Snippet file format
Create a folder snippets in your Neovim config directory (e.g. ~/.config/nvim/snippets).
Each file must be named after a filetype: python.snippets, go.snippets, lua.snippets, etc.
Example go.snippets:
```bash
---ret
return fmt.Errorf("error: %w", err)

---if
if err != nil {
    slog.Error("error: %v", err)
}

---log
slog.Info("$1")
```
- ---trigger marks the beginning of a snippet.
- The following lines (until the next ---trigger or end of file) are the snippet body.
- Empty lines inside a snippet are preserved.
- Optional $1 placeholder will move the cursor after expansion (basic support).

### Usage
1. Type a trigger word (e.g., if) in a buffer whose filetype matches a *.snippets file.
2. Press <C-j> (or your configured key).
3. The trigger is replaced by the snippet body.
4. If the snippet contains $1, the cursor jumps to that position.

### How it works (in simple terms)
1. You press the keymap.
2. The plugin reads the text from the cursor backwards until a space or line start – that’s your trigger.
3. It looks up the current filetype and opens snippets/<filetype>.snippets.
4. It parses the file (using the ---trigger format) and caches the result.
5. If the trigger exists, it replaces the trigger text with the snippet body.
6. For multiline snippets, every line after the first gets the same leading whitespace as the original trigger line (configurable).

### Limitations (by design)
- No advanced placeholders (jump between $1, $2, $0 – only basic single placeholder).
- No nested or dynamic snippets.
- No visual‑selection wrapping.
- No Lua functions inside snippets.
These limitations keep the code small, educational, and easy to modify.

### License
MIT


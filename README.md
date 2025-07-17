# show-coverage.nvim

A Neovim plugin that displays code coverage information directly in the editor using signs and highlights.

## Features

- Display coverage information using configurable signs (✓ for covered, ✗ for uncovered)
- Support for multiple coverage file formats:
  - JSON coverage files
  - XML coverage files (Cobertura format)
  - LCOV format files (JavaScript/Jest)
  - Binary .coverage files (Python coverage package)
- Configurable highlight groups and colors
- Line highlighting with customizable styles
- Multi-line comment detection
- Auto-detection of coverage file format

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'show-coverage.nvim',
  config = function()
    require('show-coverage').setup()
  end
}
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'show-coverage.nvim'
```

## Usage

### Commands

- `:CoverageShow` - Display coverage signs for current buffer
- `:CoverageHide` - Remove coverage signs from current buffer
- `:CoverageToggle` - Toggle coverage display on/off

### Lua API

```lua
local coverage = require('show-coverage')

-- Setup with custom configuration
coverage.setup({
  coverage_file = "coverage",
  coverage_format = "auto"
})

-- Show coverage for current buffer
coverage.show()

-- Hide coverage for current buffer
coverage.hide()

-- Toggle coverage display
coverage.toggle()
```

## Configuration

Default configuration:

```lua
require('show-coverage').setup({
  -- Base name for coverage file (without extension)
  coverage_file = "coverage",

  -- Format: "auto", "json", "xml", "coverage"
  coverage_format = "auto",

  -- Sign characters
  signs = {
    covered = "✓",
    uncovered = "✗",
    partial = "◐",
  },

  -- Highlight group names
  highlight_groups = {
    covered = "CoverageCovered",
    uncovered = "CoverageUncovered",
    partial = "CoveragePartial",
  },

  -- Enable line highlighting
  highlight_lines = false,

  -- Line highlight group names
  line_highlight_groups = {
    covered = "CoverageLineCovered",
    uncovered = "CoverageLineUncovered",
    partial = "CoverageLinePartial",
  },

  -- Sign highlight styles
  sign_highlights = {
    covered = { fg = "#00ff00" },
    uncovered = { fg = "#ff0000" },
    partial = { fg = "#ffff00" },
  },

  -- Line highlight styles
  line_highlights = {
    covered = { undercurl = true, sp = "#c4dbb4" },
    uncovered = { undercurl = true, sp = "#d4b0b8" },
    partial = { undercurl = true, sp = "#d4b0b8" },
  },
})
```

### Custom Highlight Examples

```lua
-- Custom colors and styles
require('show-coverage').setup({
  sign_highlights = {
    covered = { fg = "#a6e3a1", bg = "#181825" },
    uncovered = { fg = "#f38ba8", bold = true },
  },
  line_highlights = {
    covered = { underline = true, sp = "#a6e3a1" },
    uncovered = { underdouble = true, sp = "#f38ba8" },
  }
})
```

## Coverage File Formats

### JSON Format

Expected structure:
```json
{
  "files": {
    "path/to/file.js": {
      "executed_lines": [1, 2, 5, 10, 15]
    }
  }
}
```

### XML Format (Cobertura)

Supports standard Cobertura XML format with `<class>` elements containing `<line>` elements.

### LCOV Format

Standard LCOV format used by JavaScript testing tools like Jest:
```
SF:src/file.js
DA:1,1
DA:2,0
DA:3,1
end_of_record
```

### Binary .coverage Format (Python)

Python's coverage package binary format. Requires the `coverage` tool to be installed:

```bash
pip install coverage
```

The plugin automatically converts binary `.coverage` files to JSON using:
```bash
coverage json -o temp.json --data-file .coverage
```

## Requirements

- Neovim 0.7+
- Coverage data file in supported format
- For binary .coverage files: Python `coverage` package (`pip install coverage`)

## License

MIT

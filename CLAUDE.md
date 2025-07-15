# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin called `show-coverage.nvim` that displays code coverage information directly in the editor using signs and highlights. The plugin reads coverage data from JSON files and visualizes it with configurable symbols and colors.

## Architecture

- **Main module**: `lua/show-coverage.lua` - Core Lua module containing all functionality
- **Plugin entry point**: `plugin/show-coverage.vim` - Vim script that creates user commands and prevents duplicate loading
- **Coverage data source**: Expects `coverage.json` file in the working directory (configurable via `coverage_file` option)

### Key Components

1. **Configuration system** (`config` table): Manages coverage file path, display signs, and highlight groups
2. **Coverage parsing** (`parse_coverage_json`): Reads and parses JSON coverage data
3. **File matching** (`get_file_coverage`): Matches current buffer to coverage data entries
4. **Sign application** (`apply_signs`): Uses Neovim's extmarks API to display coverage indicators
5. **Public API** (`M.setup`, `M.show`, `M.hide`, `M.toggle`): Main functions exposed to users

## User Commands

The plugin provides three commands via `plugin/show-coverage.vim`:
- `:CoverageShow` - Display coverage signs for current buffer
- `:CoverageHide` - Remove coverage signs from current buffer
- `:CoverageToggle` - Toggle coverage display on/off

## Development Notes

- Uses Neovim's modern `nvim_create_namespace` and `nvim_buf_set_extmark` APIs for sign management
- Coverage data format expects `files` object with `executed_lines` arrays per file
- File matching uses pattern matching to handle relative vs absolute paths
- No build tools, package managers, or test frameworks configured - this is a minimal plugin structure
- Plugin follows standard Neovim plugin conventions with lua/ and plugin/ directories

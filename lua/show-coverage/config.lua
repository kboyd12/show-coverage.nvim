local M = {}

local default_config = {
	coverage_file = "coverage",
	coverage_format = "auto", -- "auto", "json", "xml", "coverage"
	signs = {
		covered = "✓",
		uncovered = "✗",
		partial = "◐",
	},
	highlight_groups = {
		covered = "CoverageCovered",
		uncovered = "CoverageUncovered",
		partial = "CoveragePartial",
	},
	highlight_lines = false,
	line_highlight_groups = {
		covered = "CoverageLineCovered",
		uncovered = "CoverageLineUncovered",
		partial = "CoverageLinePartial",
	},
	sign_highlights = {
		covered = { fg = "#00ff00" },
		uncovered = { fg = "#ff0000" },
		partial = { fg = "#ffff00" },
	},
	line_highlights = {
		covered = { undercurl = true, sp = "#c4dbb4" },
		uncovered = { undercurl = true, sp = "#d4b0b8" },
		partial = { undercurl = true, sp = "#d4b0b8" },
	},
}

local config = vim.deepcopy(default_config)

function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)
	M.setup_highlights()
end

function M.get()
	return config
end

function M.setup_highlights()
	vim.api.nvim_set_hl(0, config.highlight_groups.covered, config.sign_highlights.covered)
	vim.api.nvim_set_hl(0, config.highlight_groups.uncovered, config.sign_highlights.uncovered)
	vim.api.nvim_set_hl(0, config.highlight_groups.partial, config.sign_highlights.partial)

	vim.api.nvim_set_hl(0, config.line_highlight_groups.covered, config.line_highlights.covered)
	vim.api.nvim_set_hl(0, config.line_highlight_groups.uncovered, config.line_highlights.uncovered)
	vim.api.nvim_set_hl(0, config.line_highlight_groups.partial, config.line_highlights.partial)
end

return M

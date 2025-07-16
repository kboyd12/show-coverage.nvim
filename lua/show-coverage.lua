local M = {}

local config_module = require("show-coverage.config")
local parsers = require("show-coverage.parsers")
local display = require("show-coverage.display")
local utils = require("show-coverage.utils")

local coverage_data = {}

function M.setup(opts)
	config_module.setup(opts)
end

function M.show()
	local config = config_module.get()
	coverage_data = parsers.parse_coverage_file(config)
	if not coverage_data then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.api.nvim_buf_get_name(bufnr)

	if filepath == "" then
		print("No file in current buffer")
		return
	end

	local file_coverage = utils.get_file_coverage(coverage_data, filepath)
	if not file_coverage then
		print("No coverage data for current file")
		return
	end

	display.apply_signs(bufnr, file_coverage, config, utils)
end

function M.hide()
	local bufnr = vim.api.nvim_get_current_buf()
	display.clear_signs(bufnr)
end

function M.toggle()
	local bufnr = vim.api.nvim_get_current_buf()

	if display.has_signs(bufnr) then
		M.hide()
	else
		M.show()
	end
end

return M

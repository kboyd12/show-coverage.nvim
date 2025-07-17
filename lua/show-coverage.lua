local M = {}

local config_module = require("show-coverage.config")
local parsers = require("show-coverage.parsers")
local display = require("show-coverage.display")
local utils = require("show-coverage.utils")

local coverage_data = {}
local auto_show_enabled = false

function M.setup(opts)
	config_module.setup(opts)

	if opts and opts.auto_show then
		M.enable_auto_show()
	end
end

function M.enable_auto_show()
	auto_show_enabled = true

	vim.api.nvim_create_augroup("ShowCoverage", { clear = true })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = "ShowCoverage",
		callback = function()
			if auto_show_enabled then
				M.show()
			end
		end,
	})
end

function M.disable_auto_show()
	auto_show_enabled = false
	vim.api.nvim_del_augroup_by_name("ShowCoverage")
end

function M.refresh()
	if auto_show_enabled or display.has_signs(vim.api.nvim_get_current_buf()) then
		M.show()
	end
end

function M.find_and_update()
	local config = config_module.get()
	local git_root = utils.find_git_root()

	if not git_root then
		print("Not in a git repository")
		return
	end

	local search_pattern = config.coverage_file .. "*"

	utils.find_coverage_async(git_root, function(coverage_path)
		if coverage_path then
			print("Found coverage file: " .. coverage_path)
			coverage_data = parsers.parse_coverage_file(config, coverage_path)
			if coverage_data then
				M.show()
			else
				print("Failed to parse coverage file")
			end
		else
			print("No coverage file found in git repository")
		end
	end, search_pattern)
end

function M.show()
	local config = config_module.get()

	parsers.parse_coverage_file(config, function(data)
		coverage_data = data
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
	end)
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

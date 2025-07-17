local M = {}

local config_module = require("show-coverage.config")
local parsers = require("show-coverage.parsers")
local display = require("show-coverage.display")
local utils = require("show-coverage.utils")

local coverage_data = {}
local auto_show_enabled = false
local file_watchers = {}

function M.setup(opts)
	config_module.setup(opts)

	-- Get the merged config after setup
	local config = config_module.get()

	if config.auto_show then
		M.enable_auto_show()
	end

	if config.watch_files then
		M.enable_file_watching()
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

function M.enable_file_watching()
	M.disable_file_watching() -- Clear any existing watchers

	utils.find_coverage_async(nil, function(coverage_path)
		if coverage_path then
			M.watch_coverage_file(coverage_path)
		end
	end, ".coverage")
end

function M.disable_file_watching()
	for _, watcher in pairs(file_watchers) do
		if watcher then
			watcher:stop()
		end
	end
	file_watchers = {}
end

function M.watch_coverage_file(filepath)
	if file_watchers[filepath] then
		file_watchers[filepath]:stop()
	end

	local watcher = vim.loop.new_fs_event()
	if not watcher then
		print("Failed to create file watcher")
		return
	end

	file_watchers[filepath] = watcher

	local function on_change(err, filename, events)
		if err then
			print("File watcher error:", err)
			-- Try to restart the watcher after an error
			vim.defer_fn(function()
				M.watch_coverage_file(filepath)
			end, 1000)
			return
		end

		if events.change or events.rename then
			print("Coverage file updated, refreshing...")
			-- Debounce rapid changes
			vim.defer_fn(function()
				M.show()
				-- Restart watcher after file changes (handles recreated files)
				vim.defer_fn(function()
					M.watch_coverage_file(filepath)
				end, 500)
			end, 100)
		end
	end

	-- Watch the directory instead of the file to handle recreated files
	local dir = vim.fn.fnamemodify(filepath, ":h")
	local filename = vim.fn.fnamemodify(filepath, ":t")

	watcher:start(dir, {}, function(err, changed_filename, events)
		if err then
			on_change(err, changed_filename, events)
			return
		end

		-- Only trigger if our specific file changed
		if changed_filename == filename then
			on_change(err, changed_filename, events)
		end
	end)

	print("Watching coverage directory for file:", filepath)
end

function M.refresh()
	if auto_show_enabled or display.has_signs(vim.api.nvim_get_current_buf()) then
		M.show()
	end
end

function M.find_and_update()
	local config = config_module.get()
	local git_root = utils.find_git_root()
	print(git_root)

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

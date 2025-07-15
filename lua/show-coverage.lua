local M = {}

local config = {
	coverage_file = "coverage",
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
}

local namespace_id = vim.api.nvim_create_namespace("show-coverage")
local coverage_data = {}

local function parse_coverage_json()
	local coverage_json = config.coverage_file .. ".json"
	local file = io.open(coverage_json, "r")
	if not file then
		print("Coverage file not found: " .. coverage_json)
		return nil
	end

	local content = file:read("*all")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		print("Failed to parse coverage JSON")
		return nil
	end

	return data
end

local function get_file_coverage(filepath)
	if not coverage_data.files then
		return nil
	end

	for file, data in pairs(coverage_data.files) do
		if file:match(filepath .. "$") or filepath:match(file .. "$") then
			return data
		end
	end
	return nil
end

local function apply_signs(bufnr, file_coverage)
	if not file_coverage or not file_coverage.executed_lines then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)

	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	for line_num = 1, total_lines do
		local is_covered = false
		for _, covered_line in ipairs(file_coverage.executed_lines) do
			if covered_line == line_num then
				is_covered = true
				break
			end
		end

		local sign = is_covered and config.signs.covered or config.signs.uncovered
		local hl_group = is_covered and config.highlight_groups.covered or config.highlight_groups.uncovered

		vim.api.nvim_buf_set_extmark(bufnr, namespace_id, line_num - 1, 0, {
			sign_text = sign,
			sign_hl_group = hl_group,
		})
	end
end

function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)

	-- Set up highlight groups
	vim.api.nvim_set_hl(0, "CoverageCovered", { fg = "#00ff00" })
	vim.api.nvim_set_hl(0, "CoverageUncovered", { fg = "#ff0000" })
	vim.api.nvim_set_hl(0, "CoveragePartial", { fg = "#ffff00" })
end

function M.show()
	coverage_data = parse_coverage_json()
	if not coverage_data then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.api.nvim_buf_get_name(bufnr)

	if filepath == "" then
		print("No file in current buffer")
		return
	end

	local file_coverage = get_file_coverage(filepath)
	if not file_coverage then
		print("No coverage data for current file")
		return
	end

	apply_signs(bufnr, file_coverage)
end

function M.hide()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
end

function M.toggle()
	local bufnr = vim.api.nvim_get_current_buf()
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace_id, 0, -1, {})

	if #marks > 0 then
		M.hide()
	else
		M.show()
	end
end

return M

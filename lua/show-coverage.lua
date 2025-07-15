local M = {}

local config = {
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
	highlight_lines = true,
	line_highlight_groups = {
		covered = "CoverageLineCovered",
		uncovered = "CoverageLineUncovered",
		partial = "CoverageLinePartial",
	},
}

local namespace_id = vim.api.nvim_create_namespace("show-coverage")
local coverage_data = {}

--- Parse XML coverage file (Cobertura format)
--- @param filepath string Path to XML file
--- @return table|nil coverage_data The parsed coverage data or nil if failed
local function parse_coverage_xml(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	local coverage_data = { files = {} }

	-- Parse Cobertura XML format
	-- Look for class elements with filename attributes and their content
	for filename, class_content in content:gmatch('<class[^>]+filename="([^"]+)"[^>]*>(.-)</class>') do
		local file_data = { executed_lines = {} }

		-- Extract line numbers from line elements within this class with hits > 0
		-- Pattern: <line number="X" hits="Y"/>
		for line_num, hits in class_content:gmatch('<line[^>]+number="(%d+)"[^>]+hits="(%d+)"') do
			if tonumber(hits) > 0 then
				table.insert(file_data.executed_lines, tonumber(line_num))
			end
		end

		coverage_data.files[filename] = file_data
	end

	return coverage_data
end

--- Parse binary .coverage file using external tool
--- @param filepath string Path to .coverage file
--- @return table|nil coverage_data The parsed coverage data or nil if failed
local function parse_coverage_binary(filepath)
	-- This would require an external tool like dotnet-coverage or similar
	-- For now, return nil as this needs external dependencies
	print("Binary .coverage parsing not yet implemented - requires external tool")
	return nil
end

--- Parse coverage data from JSON file
--- @return table|nil coverage_data The parsed coverage data or nil if file not found or invalid
local function parse_coverage_json(filepath)
	local file = io.open(filepath, "r")
	if not file then
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

--- Auto-detect and parse coverage file
--- @return table|nil coverage_data The parsed coverage data or nil if file not found or invalid
local function parse_coverage_file()
	local base_name = config.coverage_file
	local format = config.coverage_format

	-- Try different file extensions based on format
	local file_candidates = {}

	if format == "auto" then
		table.insert(file_candidates, { base_name .. ".json", "json" })
		table.insert(file_candidates, { base_name .. ".xml", "xml" })
		table.insert(file_candidates, { "coverage.xml", "xml" })
		table.insert(file_candidates, { base_name .. ".coverage", "coverage" })
		table.insert(file_candidates, { base_name, "json" }) -- fallback
	elseif format == "json" then
		table.insert(file_candidates, { base_name .. ".json", "json" })
	elseif format == "xml" then
		table.insert(file_candidates, { base_name .. ".xml", "xml" })
		table.insert(file_candidates, { "coverage.xml", "xml" })
	elseif format == "coverage" then
		table.insert(file_candidates, { base_name .. ".coverage", "coverage" })
	end

	-- Try each candidate file
	for _, candidate in ipairs(file_candidates) do
		local filepath, file_format = candidate[1], candidate[2]
		local file = io.open(filepath, "r")
		if file then
			file:close()

			if file_format == "json" then
				local data = parse_coverage_json(filepath)
				if data then
					return data
				end
			elseif file_format == "xml" then
				local data = parse_coverage_xml(filepath)
				if data then
					return data
				end
			elseif file_format == "coverage" then
				local data = parse_coverage_binary(filepath)
				if data then
					return data
				end
			end
		end
	end

	print("Coverage file not found. Tried: " .. table.concat(
		vim.tbl_map(function(c)
			return c[1]
		end, file_candidates),
		", "
	))
	return nil
end

--- Get coverage data for a specific file path
--- @param filepath string The absolute file path to search for
--- @return table|nil file_coverage The coverage data for the file or nil if not found
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

--- Check if a line contains executable code (not comments or whitespace)
--- @param bufnr number The buffer number
--- @param line_num number The line number (1-indexed)
--- @return boolean is_executable True if line contains executable code
local function is_executable_line(bufnr, line_num)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
	if not line then
		return false
	end

	-- Remove leading/trailing whitespace
	line = line:match("^%s*(.-)%s*$")

	-- Empty lines
	if line == "" then
		return false
	end

	-- Comment patterns for common languages
	local comment_patterns = {
		"^//", -- C++, JS, Java, etc.
		"^#", -- Python, Shell, etc.
		"^%-%-", -- Lua
		"^%*", -- Multi-line C comments
		"^/%*", -- Start of C comment
		"^%*/", -- End of C comment
		'^"', -- Some languages use quotes for comments
	}

	for _, pattern in ipairs(comment_patterns) do
		if line:match(pattern) then
			return false
		end
	end

	return true
end

--- Apply coverage signs to a buffer using extmarks
--- @param bufnr number The buffer number to apply signs to
--- @param file_coverage table Coverage data for the file containing executed_lines array
local function apply_signs(bufnr, file_coverage)
	if not file_coverage or not file_coverage.executed_lines then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)

	-- Create a set of covered lines for faster lookup
	local covered_lines = {}
	for _, line_num in ipairs(file_coverage.executed_lines) do
		covered_lines[line_num] = true
	end

	-- Only show coverage for executable lines
	local total_lines = vim.api.nvim_buf_line_count(bufnr)
	for line_num = 1, total_lines do
		if is_executable_line(bufnr, line_num) then
			local is_covered = covered_lines[line_num] or false

			local sign = is_covered and config.signs.covered or config.signs.uncovered
			local hl_group = is_covered and config.highlight_groups.covered or config.highlight_groups.uncovered

			local extmark_opts = {
				sign_text = sign,
				sign_hl_group = hl_group,
			}

			-- Add line highlighting if enabled
			if config.highlight_lines then
				local line_hl_group = is_covered and config.line_highlight_groups.covered
					or config.line_highlight_groups.uncovered

				-- Get the line content to determine text span
				local line_content = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ""
				local text_start = line_content:find("%S") or 1 -- First non-whitespace character
				local text_end = #line_content:match(".*%S") or #line_content -- Last non-whitespace character

				-- Apply underline only to text portion
				if text_end >= text_start then
					extmark_opts.end_col = text_end
					extmark_opts.hl_group = line_hl_group
				end
			end

			vim.api.nvim_buf_set_extmark(bufnr, namespace_id, line_num - 1, 0, extmark_opts)
		end
	end
end

--- Setup the plugin with user configuration
--- @param opts table|nil Configuration options:
---   - coverage_file: string (default "coverage") - Base name for coverage file
---   - coverage_format: string (default "auto") - Format: "auto", "json", "xml", "coverage"
---   - signs: table - Override sign characters (covered, uncovered, partial)
---   - highlight_groups: table - Override highlight group names
---   - highlight_lines: boolean (default false) - Enable line background highlighting
---   - line_highlight_groups: table - Override line highlight group names
function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)

	-- Set up sign highlight groups
	vim.api.nvim_set_hl(0, "CoverageCovered", { fg = "#00ff00" })
	vim.api.nvim_set_hl(0, "CoverageUncovered", { fg = "#ff0000" })
	vim.api.nvim_set_hl(0, "CoveragePartial", { fg = "#ffff00" })

	-- Set up line highlight groups with underlines
	vim.api.nvim_set_hl(0, "CoverageLineCovered", { undercurl = true, sp = "#c4dbb4" })
	vim.api.nvim_set_hl(0, "CoverageLineUncovered", { undercurl = true, sp = "#d4b0b8" })
	vim.api.nvim_set_hl(0, "CoverageLinePartial", { undercurl = true, sp = "#d4b0b8" })
end

--- Display coverage signs for the current buffer
--- Reads coverage data and applies signs to lines based on execution status
function M.show()
	coverage_data = parse_coverage_file()
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

--- Hide all coverage signs from the current buffer
--- Clears all extmarks in the plugin's namespace
function M.hide()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
end

--- Toggle coverage signs display for the current buffer
--- Shows coverage if not currently displayed, hides if already shown
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

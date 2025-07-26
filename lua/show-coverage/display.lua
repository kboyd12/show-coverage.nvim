local M = {}

local namespace_id = vim.api.nvim_create_namespace("show-coverage")

function M.apply_signs(bufnr, file_coverage, config, utils)
	if not file_coverage then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)

	-- Create a set of missing (uncovered) lines
	local missing_lines = {}
	if file_coverage.missing_lines then
		for _, line_num in ipairs(file_coverage.missing_lines) do
			missing_lines[line_num] = true
		end
	end

	local executable_lines = M.mark_executable_lines(bufnr)
	local executable_set = {}
	for _, line_num in ipairs(executable_lines) do
		executable_set[line_num] = true
	end

	for _, line_num in ipairs(executable_lines) do
		-- Line is covered if it's NOT in the missing_lines set
		local is_covered = not missing_lines[line_num]

		local sign = is_covered and config.signs.covered or config.signs.uncovered
		local hl_group = is_covered and config.highlight_groups.covered or config.highlight_groups.uncovered

		local extmark_opts = {
			sign_text = sign,
			sign_hl_group = hl_group,
		}

		if config.highlight_lines then
			local line_hl_group = is_covered and config.line_highlight_groups.covered or config.line_highlight_groups.uncovered

			local line_content = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ""
			local text_start = line_content:find("%S") or 1
			local text_end = #line_content:match(".*%S") or #line_content

			if text_end >= text_start then
				extmark_opts.end_col = text_end
				extmark_opts.hl_group = line_hl_group
			end
		end

		vim.api.nvim_buf_set_extmark(bufnr, namespace_id, line_num - 1, 0, extmark_opts)
	end
end

function M.clear_signs(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
end

function M.has_signs(bufnr)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace_id, 0, -1, {})
	return #marks > 0
end

local function is_comment_line(line)
	-- Check if the line is a comment line
	if not line then
		return { false, false }
	end

	-- Python comment pattern: starts with #
	if line:match("^%s*#") then
		return { true, false }
	end

	-- Single line string (not multiline docstring)
	if line:match("^%s*[\"']+[^\"']+[\"']+%s*$") then
		return { true, false }
	end

	-- Check for docstring start/end (""" or ''')
	if line:match("^%s*[\"']+%s*$") then
		return { true, true }
	end

	return { false, false }
end

function M.mark_executable_lines(bufnr)
	local executable_lines = {}
	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	local multiline_comment = false
	local comment = false

	for line_num = 1, total_lines do
		local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]

		if multiline_comment then
			-- We're inside a multiline comment, check if this line ends it
			if line:match("^%s*[\"']+%s*$") then
				multiline_comment = false -- End of multiline comment
			end
			goto continue -- Skip this line as it's part of multiline comment
		end

		-- Skip empty lines (lines with only whitespace)
		if not line or line:match("^%s*$") then
			goto continue
		end

		local result = is_comment_line(line)
		comment, multiline_comment = result[1], result[2]

		if comment and not multiline_comment then
			goto continue -- Single line comment
		elseif comment and multiline_comment then
			goto continue -- Start of multiline comment (already handled above)
		end

		-- This is an executable line
		table.insert(executable_lines, line_num)

		::continue::
	end
	return executable_lines
end

return M

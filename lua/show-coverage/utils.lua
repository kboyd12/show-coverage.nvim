local M = {}

function M.get_file_coverage(coverage_data, filepath)
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

function M.is_executable_line(bufnr, line_num)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
	if not line then
		return false
	end

	line = line:match("^%s*(.-)%s*$")

	if line == "" then
		return false
	end

	local comment_patterns = {
		"^//",
		"^#",
		"^%-%-",
		"^%*",
		"^/%*",
		"^%*/",
		'^"',
	}

	for _, pattern in ipairs(comment_patterns) do
		if line:match(pattern) then
			return false
		end
	end

	return true
end

return M

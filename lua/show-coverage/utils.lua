local M = {}

function M.find_git_root()
	local handle = io.popen("git rev-parse --show-toplevel")
	if not handle then
		return nil
	end
	local path = handle:read("*a")
	handle:close()
	return path:gsub("\n", "")
end

function M.find_coverage_async(git_root, callback, coverage_file)
	git_root = git_root or M.find_git_root()
	vim.fn.jobstart({ "find", git_root, "-type", "f", "-name", coverage_file, "-print", "-quit" }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			-- data is a list of lines; first element is our path or empty
			local path = (data and data[1] ~= "" and data[1]) or nil
			callback(path)
		end,
		on_stderr = function(_, err)
			vim.notify("Error finding .coverage: " .. table.concat(err, "\n"), vim.log.levels.ERROR)
			callback(nil)
		end,
	})
end

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

local function is_in_multiline_comment(bufnr, line_num)
	local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

	local comment_patterns = {
		c = { start = "/%*", stop = "%*/" },
		cpp = { start = "/%*", stop = "%*/" },
		java = { start = "/%*", stop = "%*/" },
		javascript = { start = "/%*", stop = "%*/" },
		typescript = { start = "/%*", stop = "%*/" },
		css = { start = "/%*", stop = "%*/" },
		lua = { start = "%-%-@%[%[", stop = "%-%-@%]%]" },
		python = { start = '"""', stop = '"""' },
		html = { start = "<!%-%-", stop = "%-%->" },
		xml = { start = "<!%-%-", stop = "%-%->" },
	}

	local pattern = comment_patterns[filetype]
	if not pattern then
		return false
	end

	local in_comment = false

	for i = 1, line_num do
		local current_line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""

		local start_pos = current_line:find(pattern.start)
		local end_pos = current_line:find(pattern.stop)

		if start_pos and (not end_pos or start_pos < end_pos) then
			in_comment = true
		end

		if end_pos and in_comment then
			if i == line_num and end_pos < #current_line then
				return false
			end
			in_comment = false
		end

		if i == line_num then
			return in_comment
		end
	end

	return false
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

	if is_in_multiline_comment(bufnr, line_num) then
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

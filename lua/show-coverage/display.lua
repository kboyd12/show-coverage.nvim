local M = {}

local namespace_id = vim.api.nvim_create_namespace("show-coverage")

function M.apply_signs(bufnr, file_coverage, config, utils)
	if not file_coverage or not file_coverage.executed_lines then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)

	local covered_lines = {}
	for _, line_num in ipairs(file_coverage.executed_lines) do
		covered_lines[line_num] = true
	end

	local total_lines = vim.api.nvim_buf_line_count(bufnr)
	for line_num = 1, total_lines do
		if utils.is_executable_line(bufnr, line_num) then
			local is_covered = covered_lines[line_num] or false

			local sign = is_covered and config.signs.covered or config.signs.uncovered
			local hl_group = is_covered and config.highlight_groups.covered or config.highlight_groups.uncovered

			local extmark_opts = {
				sign_text = sign,
				sign_hl_group = hl_group,
			}

			if config.highlight_lines then
				local line_hl_group = is_covered and config.line_highlight_groups.covered
					or config.line_highlight_groups.uncovered

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
end

function M.clear_signs(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
end

function M.has_signs(bufnr)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace_id, 0, -1, {})
	return #marks > 0
end

return M

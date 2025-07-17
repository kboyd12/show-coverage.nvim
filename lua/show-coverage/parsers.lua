local M = {}

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

local function parse_coverage_binary(filepath)
	-- Check if coverage tool is available
	local check_handle = io.popen("which coverage 2>/dev/null")
	if not check_handle then
		print("Python coverage tool not found. Install with: pip install coverage")
		return nil
	end

	local coverage_path = check_handle:read("*line")
	check_handle:close()

	if not coverage_path or coverage_path == "" then
		print("Python coverage tool not found. Install with: pip install coverage")
		return nil
	end

	-- Use Python's coverage package to convert binary .coverage to JSON
	local temp_json = os.tmpname() .. ".json"

	-- Run coverage json command to convert binary to JSON
	local cmd = string.format("coverage json -o %s --data-file %s", temp_json, filepath)
	local handle = io.popen(cmd .. " 2>&1")

	if not handle then
		print("Failed to execute coverage command")
		return nil
	end

	local result = handle:read("*all")
	local exit_code = handle:close()

	if not exit_code then
		print("Coverage command failed: " .. result)
		-- Clean up temp file if it exists
		os.remove(temp_json)
		return nil
	end

	-- Parse the generated JSON file
	local coverage_data = parse_coverage_json(temp_json)

	-- Clean up temp file
	os.remove(temp_json)

	-- Convert Python coverage format to our format
	if coverage_data and coverage_data.files then
		local converted_data = { files = {} }

		for file_path, file_data in pairs(coverage_data.files) do
			converted_data.files[file_path] = { executed_lines = {} }

			-- Python coverage JSON has executed_lines as keys with values
			-- or summary.covered_lines array
			if file_data.executed_lines then
				for line_num, _ in pairs(file_data.executed_lines) do
					table.insert(converted_data.files[file_path].executed_lines, tonumber(line_num))
				end
			elseif file_data.summary and file_data.summary.covered_lines then
				converted_data.files[file_path].executed_lines = file_data.summary.covered_lines
			end
		end

		return converted_data
	end

	return coverage_data
end

function M.parse_coverage_file(config, callback)
	local utils = require("show-coverage.utils")

	if not callback then
		-- Sync mode: try .coverage first, then coverage.json
		local coverage_data = parse_coverage_binary(".coverage")
		if coverage_data then
			return coverage_data
		end
		return parse_coverage_json("coverage.json")
	end

	-- Async mode: find .coverage file in git tree
	local git_root = utils.find_git_root()
	if not git_root then
		print("Not in a git repository")
		callback(nil)
		return
	end

	utils.find_coverage_async(git_root, function(coverage_path)
		if coverage_path then
			print("Found .coverage file: " .. coverage_path)
			local data = parse_coverage_binary(coverage_path)
			callback(data)
		else
			print("No .coverage file found in git repository")
			callback(nil)
		end
	end, ".coverage")
end

return M

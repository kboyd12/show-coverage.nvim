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

local function parse_coverage_xml(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	local coverage_data = { files = {} }

	for filename, class_content in content:gmatch('<class[^>]+filename="([^"]+)"[^>]*>(.-)</class>') do
		local file_data = { executed_lines = {} }

		for line_num, hits in class_content:gmatch('<line[^>]+number="(%d+)"[^>]+hits="(%d+)"') do
			if tonumber(hits) > 0 then
				table.insert(file_data.executed_lines, tonumber(line_num))
			end
		end

		coverage_data.files[filename] = file_data
	end

	return coverage_data
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

	-- Use Python's coverage package to convert binary .coverage to XML
	local temp_xml = os.tmpname() .. ".xml"

	-- Run coverage xml command to convert binary to XML
	local cmd = string.format("coverage xml -o %s --data-file %s", temp_xml, filepath)
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
		os.remove(temp_xml)
		return nil
	end

	-- Parse the generated XML file using our existing XML parser
	local coverage_data = parse_coverage_xml(temp_xml)

	-- Clean up temp file
	os.remove(temp_xml)

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

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
	print("Binary .coverage parsing not yet implemented - requires external tool")
	return nil
end

function M.parse_coverage_file(config)
	local base_name = config.coverage_file
	local format = config.coverage_format

	local file_candidates = {}

	if format == "auto" then
		table.insert(file_candidates, { base_name .. ".json", "json" })
		table.insert(file_candidates, { base_name .. ".xml", "xml" })
		table.insert(file_candidates, { "coverage.xml", "xml" })
		table.insert(file_candidates, { base_name .. ".coverage", "coverage" })
		table.insert(file_candidates, { base_name, "json" })
	elseif format == "json" then
		table.insert(file_candidates, { base_name .. ".json", "json" })
	elseif format == "xml" then
		table.insert(file_candidates, { base_name .. ".xml", "xml" })
		table.insert(file_candidates, { "coverage.xml", "xml" })
	elseif format == "coverage" then
		table.insert(file_candidates, { base_name .. ".coverage", "coverage" })
	end

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

return M

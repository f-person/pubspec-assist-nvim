local json = require 'pubspec-assist-nvim.json'
local base_url = 'https://pub.dartlang.org/api'

local function split(str, sep)
    local fields = {}
    local pattern = string.format('([^%s]+)', sep)
    string.gsub(str, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end

-- returns output of a command
function os.capture(cmd)
    local handle = assert(io.popen(cmd, 'r'))
    local output = assert(handle:read('*a'))
    handle:close()

    output = string.gsub(
                 string.gsub(string.gsub(output, '^%s+', ''), '%s+$', ''),
                 '[\n\r]+', ' ')
    return output
end

-- returns a table with json
local function http_get(url)
    local response =
        os.capture('curl -sb -H "Accept: application/json" ' .. url)
    return json.decode(response)
end

-- returns a list of package names
local function search_package(query)
    local response = http_get(base_url .. '/search?q=' .. query)
    local package_names = {}
    for _, element in pairs(response.packages) do
        table.insert(package_names, element.package)
    end
    return package_names
end

-- returns a table with [name] and [latest_version]
local function get_package_info(name)
    local response = http_get(base_url .. '/packages/' .. name)
    return {name = response.name, latest_version = response.latest.version}
end

-- package: <table>{name: string, latest_version: string}
local function generate_dependency_string(package)
    return '  ' .. package.name .. ': ^' .. package.latest_version
end

-- dependecy_type is either 'dependencies' or 'dev_dependencies'
local function add_dependency(new_package, dependecy_type)
    local dependecy_type_query = dependecy_type .. ':'
    local dependecy_line_index = -1

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for index, line in pairs(lines) do
        if line:gsub('%s+', '') == dependecy_type_query then
            dependecy_line_index = index
        end
    end

    local existing_package_line_index = -1
    for index, line in pairs(lines) do
        if line:match(':') ~= nil then
            local potential_match = split(line, ':')[1]
            if potential_match:gsub('%s+', '') == new_package.name then
                existing_package_line_index = index
                break
            end
        end
    end

    if existing_package_line_index == -1 then
        local new_lines = {}
        local new_dependency_line_index

        if dependecy_line_index == -1 then
            new_dependency_line_index = -1 -- end of the file
            table.insert(new_lines, '')
            table.insert(new_lines, dependecy_type_query)
        else
            for i = dependecy_line_index + 1, #lines do
                if lines[i]:match('^  ') == nil and lines[i]:match('^#') == nil then
                    new_dependency_line_index = i - 1
                    break
                end
                if i == #lines then new_dependency_line_index = i end
            end
        end
        table.insert(new_lines, generate_dependency_string(new_package))

        vim.api.nvim_buf_set_lines(0, new_dependency_line_index,
                                   new_dependency_line_index, false, new_lines)
    else
        local new_lines = {generate_dependency_string(new_package)}
        vim.api.nvim_buf_set_lines(0, existing_package_line_index - 1,
                                   existing_package_line_index, false, new_lines)
    end
end

local function get_package_info_and_add_dependency(query, dependecy_type)
    if query:gsub('%s+', '') == '' then
        print('No package name specified')
        return
    end

    query = query:gsub(' ', '_')
    local packages = search_package(query)
    local package = get_package_info(packages[1])

    add_dependency(package, dependecy_type)
end

local function pubspec_add_dependency(query)
    get_package_info_and_add_dependency(query, 'dependencies')
end

local function pubspec_add_dev_dependency(query)
    get_package_info_and_add_dependency(query, 'dev_dependencies')
end

return {
    pubspec_add_dependency = pubspec_add_dependency,
    pubspec_add_dev_dependency = pubspec_add_dev_dependency
}

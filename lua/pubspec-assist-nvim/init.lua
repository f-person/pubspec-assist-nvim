local json = require 'pubspec-assist-nvim.json'

local base_url = 'https://pub.dartlang.org/api'
local win
local dependency_type

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

    if existing_package_line_index ~= -1 then
        local new_lines = {generate_dependency_string(new_package)}
        vim.api.nvim_buf_set_lines(0, existing_package_line_index - 1,
                                   existing_package_line_index, false, new_lines)
    else
        local new_lines = {}
        local new_dependency_line_index

        local dependency_string = generate_dependency_string(new_package)
        if dependecy_line_index == -1 then
            new_dependency_line_index = -1 -- end of the file
            table.insert(new_lines, '')
            table.insert(new_lines, dependecy_type_query)
            table.insert(new_lines, dependency_string)
        else
            table.insert(new_lines, dependency_string)
            for i = dependecy_line_index + 1, #lines do
                if lines[i] == '' or
                    (lines[i]:match('^  %S+') and dependency_string < lines[i]) then
                    new_dependency_line_index = i - 1
                    break
                elseif i == #lines then
                    new_dependency_line_index = i
                    break
                end
            end
        end

        vim.api.nvim_buf_set_lines(0, new_dependency_line_index,
                                   new_dependency_line_index, false, new_lines)
    end
end

local function set_mappings(buf)
    local mappings = {['<cr>'] = 'select_package()', q = 'close_window()'}

    for k, v in pairs(mappings) do
        local opts = {nowait = true, noremap = true, silent = true}
        local rhs = ':lua require"pubspec-assist-nvim".' .. v .. '<cr>'
        vim.api.nvim_buf_set_keymap(buf, 'n', k, rhs, opts)
    end
end

local function open_select_package_window(packages)
    local buf = vim.api.nvim_create_buf(false, true)

    local width = vim.api.nvim_get_option("columns")
    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = #packages,
        row = width,
        col = #packages
    }

    win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_win_set_option(win, 'cursorline', true)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, packages)
    set_mappings(buf)
end

local function close_window() vim.api.nvim_win_close(win, true) end

local function select_package()
    local package_name = vim.api.nvim_get_current_line()
    close_window()

    local package = get_package_info(package_name)
    add_dependency(package, dependency_type)
end

-- returns a package if it is the only package in [packages] that matches
-- the query, otherwise null
local function smart_select_package(packages, query)
    local match_index
    local matches = 0
    for index, package in ipairs(packages) do
        if package:match(query) then
            matches = matches + 1
            match_index = index
        end
    end

    if matches == 1 then
        return packages[match_index]
    else
        return nil
    end
end

local function get_package_info_and_add_dependency(query)
    if query:gsub('%s+', '') == '' then
        print('No package name specified')
        return
    end

    query = query:gsub(' ', '_')
    local packages = search_package(query)
    local package_name = smart_select_package(packages, query)
    if package_name == nil then
        open_select_package_window(packages)
    else
        local package = get_package_info(package_name)
        add_dependency(package, dependency_type)
    end
end

local function pubspec_add_dependency(query)
    dependency_type = 'dependencies'
    get_package_info_and_add_dependency(query)
end

local function pubspec_add_dev_dependency(query)
    dependency_type = 'dev_dependencies'
    get_package_info_and_add_dependency(query)
end

return {
    pubspec_add_dependency = pubspec_add_dependency,
    pubspec_add_dev_dependency = pubspec_add_dev_dependency,
    select_package = select_package,
    close_window = close_window
}

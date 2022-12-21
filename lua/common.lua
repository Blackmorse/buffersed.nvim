local api = vim.api

local configuration = {}

local function trim(s)
   return s:match "^%s*(.-)%s*$"
end

local function calculate_dimensions(custom_width, custom_height, custom_row, custom_col)
    local result = {}
    result.width = vim.api.nvim_get_option("columns")
    result.height = vim.api.nvim_get_option("lines")

    if custom_height and math.ceil(custom_height) == custom_height then
        result.content_height = math.min(custom_height, result.height - 10)
    elseif custom_height and math.ceil(custom_height) ~= custom_height then
        result.content_height = math.max(10, math.ceil(result.height * custom_height - 4))
    else
        result.content_height = math.max(10, math.ceil(result.height * 0.5 - 4))
    end

    if custom_width and math.ceil(custom_width) == custom_width then
        result.content_width = math.min(result.width - 5, custom_width)
    elseif custom_width and math.ceil(custom_width) ~= custom_width then
        result.content_width = math.max(20, math.ceil(result.width * custom_width))
    else
        result.content_width = math.max(20, math.ceil(result.width * 0.8))
    end

    result.content_row = custom_row or math.ceil((result.height  - result.content_height) / 2 - 1)
    result.content_col = custom_col or math.ceil((result.width - result.content_width) / 2)

    return result
end

local function set_config(config)
    config = config or {}
    local custom_width = config.width
    local custom_height = config.height
    local custom_row = config.custom_position_row
    local custom_col = config.custom_position_col

    configuration.dimensions = calculate_dimensions(custom_width, custom_height, custom_row, custom_col)

    configuration.dimensions.sed_buf_width = math.ceil(configuration.dimensions.content_width / 2)
end

local function create_sd_content_buffer(col, row, width, height, lines)
    local sd_content_buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(sd_content_buffer, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(sd_content_buffer, 'buftype', 'nowrite')

    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        zindex = 51
    }

    api.nvim_buf_set_lines(sd_content_buffer, 0, -1, false, lines)
    api.nvim_buf_set_option(sd_content_buffer, 'modifiable', false)
    local sd_content_window = api.nvim_open_win(sd_content_buffer, true, opts)
    api.nvim_win_set_option(sd_content_window, 'winhl', 'Normal:MyHighlight')
    api.nvim_win_set_option(sd_content_window, 'scrolloff', 999)
    api.nvim_win_set_option(sd_content_window, 'scrollbind', true)

    api.nvim_win_set_cursor(sd_content_window, {math.ceil(math.min(height / 2, #lines)), 0} )

    return sd_content_buffer, sd_content_window
end


local function create_typein_buffer(col, row, width)
    local typein_buffer = api.nvim_create_buf(false, true)

    local buf_opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = 1,
        row = row,
        col = col
    }

    api.nvim_buf_set_lines(typein_buffer, 0, -1, false, {''})
    local typein_window = api.nvim_open_win(typein_buffer, true, buf_opts)

    local window = vim.wo[typein_window]

    window.scrollbind = false
    window.wrap = false

    return typein_buffer, typein_window
end

local function start_insert()
    api.nvim_command('startinsert')
    local window = api.nvim_get_current_win()
    local pos = api.nvim_win_get_cursor(window)
    local row = pos[1]
    local col = pos[2]
    api.nvim_win_set_cursor(window, {row, col + 1})
end

local function scroll_down(content_window, content_buffer, lines)
    local namespace = require('highlights').line_namespace

    local coordinates = api.nvim_win_get_cursor(content_window)
    local row = coordinates[1]
    local col = coordinates[2]
    api.nvim_buf_clear_namespace(content_buffer, namespace, 0, -1)

    local all_lines = api.nvim_buf_get_lines(content_buffer, 0, -1, false)

    local new_line_position = math.min(math.max(1, row + lines), #all_lines)
    api.nvim_win_set_cursor(content_window, {new_line_position, 1})

    local current_line = all_lines[new_line_position]
    local length = string.len(current_line)

    api.nvim_buf_set_extmark(content_buffer, namespace, new_line_position - 1, 0, {end_row = new_line_position - 1,  end_col = length, hl_group = 'BuffersedLineHighlight'})
end

return {
    configuration = configuration,
    create_sd_content_buffer = create_sd_content_buffer,
    create_typein_buffer = create_typein_buffer,
    trim = trim,
    start_insert = start_insert,
    set_config = set_config,
    scroll_down = scroll_down
}

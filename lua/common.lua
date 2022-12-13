local api = vim.api

local function trim(s)
   return s:match "^%s*(.-)%s*$"
end

local function dimensions()
    local result = {}
    result.width = vim.api.nvim_get_option("columns")
    result.height = vim.api.nvim_get_option("lines")

    result.content_height = math.max(10, math.ceil(result.height * 0.5 - 4))
    result.content_width = math.max(20, math.ceil(result.width * 0.8))

    result.content_row = math.ceil((result.height  - result.content_height) / 2 - 1)
    result.content_col = math.ceil((result.width - result.content_width) / 2)

    return result
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

    api.nvim_win_set_cursor(sd_content_window, {math.ceil(height / 2), 0} )

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


return {
    dimensions = dimensions,
    create_sd_content_buffer = create_sd_content_buffer,
    create_typein_buffer = create_typein_buffer,
    trim = trim
}

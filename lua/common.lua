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

local function scroll(windows, lines, insert_mode)
    local content_window = windows[1]
    local content_buffer = api.nvim_win_get_buf(content_window)

    local current_row = api.nvim_win_get_cursor(content_window)[1]
    local lines_table = api.nvim_buf_get_lines(content_buffer, 0, -1, false)
    local scroll_opt = api.nvim_win_get_option(content_window, 'scroll')
    local max_lines_number = #lines_table

    local first_visible_line = api.nvim_exec('echo line("w0", ' .. content_window  .. ')', true)
    local last_visible_line = api.nvim_exec('echo line("w$", ' .. content_window .. ')', true)
    local row = current_row

    if current_row <= scroll_opt + 1 and lines < 0 then
        row = row
    elseif current_row > max_lines_number - scroll_opt and lines > 0 then
        row = row
    else
        row = current_row + lines
    end

    for _, window in ipairs(windows) do
        api.nvim_win_set_cursor(window, { math.max(math.min(row, max_lines_number - scroll_opt), 1 + scroll_opt), 0 })
    end

    if insert_mode then
        api.nvim_command('startinsert')
    end
end

local function set_scrolling_mappings(windows, typein_buffers, modes)
    local scroll_opt = api.nvim_win_get_option(windows[1], 'scroll')

    local windows_array = '{ ' .. table.concat(windows, ', ') .. ' }'
    for _, typein_buffer in ipairs(typein_buffers) do
        for _, mode in ipairs(modes) do
           local insert_mode = tostring(mode == 'i')

            api.nvim_buf_set_keymap(typein_buffer, mode, '<C-d>', '<Esc>:lua require("common").scroll(' .. windows_array .. ', ' .. scroll_opt .. ', ' .. insert_mode .. ')<CR>', {nowait = true, noremap = true, silent = true})
            api.nvim_buf_set_keymap(typein_buffer, mode, '<C-u>', '<Esc>:lua require("common").scroll(' .. windows_array .. ', ' .. '-' .. scroll_opt .. ', ' .. insert_mode .. ')<CR>', {nowait = true, noremap = true, silent = true})

            api.nvim_buf_set_keymap(typein_buffer, mode, '<C-e>', '<Esc>:lua require("common").scroll(' .. windows_array .. ', ' .. '1, ' .. insert_mode ..')<CR>', {nowait = true, noremap = true, silent = true})
            api.nvim_buf_set_keymap(typein_buffer, mode, '<C-y>', '<Esc>:lua require("common").scroll(' .. windows_array .. ', -1, ' .. insert_mode .. ')<CR>', {nowait = true, noremap = true, silent = true})
        end
    end
end

return {
    dimensions = dimensions,
    create_sd_content_buffer = create_sd_content_buffer,
    create_typein_buffer = create_typein_buffer,
    trim = trim,
    set_scrolling_mappings = set_scrolling_mappings,
    scroll = scroll
}

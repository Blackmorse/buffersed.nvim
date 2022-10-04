local b = vim.b
local api = vim.api
local content_buffer, content_window
local typein_buffer, typein_window
local border_buf, border_win


local function create_border_window()
    border_buf = api.nvim_create_buf(false, true)

    local border_buf_opts = {
        style = "minimal",
        relative = "editor",
        border = "shadow",
        width = 102,
        height = 25,
        row = 9,
        col = 14
    }
    local border_lines = { '╭' .. string.rep('─', 100) .. '╮' }
    local middle_line = '│' .. string.rep(' ', 100) .. '│'
    for i=1, 20 do
      table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '├' .. string.rep('─', 100) .. '┤')
    table.insert(border_lines, '│ > '..string.rep(' ', 97) .. '│')

    table.insert(border_lines, '╰' .. string.rep('─', 100) .. '╯')
    api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    border_win = api.nvim_open_win(border_buf, true, border_buf_opts)
    api.nvim_win_set_option(border_win, 'winhl', 'Normal:MyHighlight')
end

local function create_typein_window()
    typein_buffer = api.nvim_create_buf(false, true)

    local buf_opts = {
        style = "minimal",
        relative = "editor",
        width = 97,
        height = 1,
        row = 31,
        col = 18
    }

    api.nvim_buf_set_lines(typein_buffer, 0, -1, false, {''})
    typein_window = api.nvim_open_win(typein_buffer, true, buf_opts)

    local window = vim.wo[typein_window]
    local buffer = vim.bo[typein_buffer]

    window.scrollbind = false
    window.wrap = false
end

local function create_content_buffer()
    local user_buffer = api.nvim_get_current_buf()
    local lines = api.nvim_buf_get_lines(user_buffer, 0, -1, false)

    content_buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(content_buffer, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(content_buffer, 'buftype', 'nowrite')

    local opts = {
        style = "minimal",
        relative = "editor",
        width = 100,
        height = 20,
        row = 10,
        col = 15
    }

    api.nvim_buf_set_lines(content_buffer, 0, -1, false, lines)
    api.nvim_buf_set_option(content_buffer, 'modifiable', false)
    content_window = api.nvim_open_win(content_buffer, true, opts)
    api.nvim_win_set_option(content_window, 'winhl', 'Normal:MyHighlight')
end


local function open_float()
    create_content_buffer()
    create_border_window()
    create_typein_window()

    --api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)
    --api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)
end


local function close_float()
    api.nvim_win_close(typein_window, true)
    api.nvim_win_close(content_window, true)
    api.nvim_win_close(border_win, true)
end

local function set_mappings()
    api.nvim_buf_set_keymap(typein_buffer, 'n', 'q', ':lua require"buffersed".close_float()<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(typein_buffer, 'i', '<cr>', '<Esc>:lua require"buffersed".close_float()<cr>', { nowait = true, noremap = true, silent = true})
end

local function buffersed()
    open_float()
    set_mappings()
end


return {
    buffersed = buffersed,
    close_float = close_float
}

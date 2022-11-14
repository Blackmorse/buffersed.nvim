local b = vim.b
local api = vim.api
local border_buf, border_win
local s_content_buffer, s_content_window, d_content_buffer, d_content_window
local s_typein_buffer, s_typein_window, d_typein_buffer, d_typein_window

local dimensions = require('common').dimensions()

local function create_splitted_border_window()
    local border_buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(border_buffer, 'buftype', 'nowrite')

    local border_buf_opts = {
        style = "minimal",
        relative = "editor",
        border = "shadow",
        width = dimensions.content_width + 2,
        height = dimensions.content_height + 4,
        row = dimensions.content_row - 1,
        col = dimensions.content_col - 1,
        zindex = 50
    }
    local middle_index = math.ceil(dimensions.content_width / 2)

    local border_lines = { '╭' .. string.rep('─', middle_index) .. '┬' .. string.rep('─', dimensions.content_width - middle_index - 1) .. '╮' }
    local middle_line = '│' .. string.rep(' ', middle_index) .. '│' .. string.rep(' ', dimensions.content_width - middle_index - 1) .. '│'
    for i=1, dimensions.content_height do
      table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '├' .. string.rep('─', middle_index) .. '┼' .. string.rep('─', dimensions.content_width - middle_index - 1) .. '┤')
    table.insert(border_lines, '│ > '..string.rep(' ', middle_index - 3) .. '│ > ' .. string.rep(' ', dimensions.content_width - middle_index - 4) .. '│')

    table.insert(border_lines, '╰' .. string.rep('─', middle_index) .. '┴' .. string.rep('─', dimensions.content_width - middle_index - 1) .. '╯')
    api.nvim_buf_set_lines(border_buffer, 0, -1, false, border_lines)

    local border_window = api.nvim_open_win(border_buffer, true, border_buf_opts)
    api.nvim_win_set_option(border_window, 'winhl', 'Normal:MyHighlight')

    return border_buffer, border_window
end

local function set_mappings()
    api.nvim_buf_set_keymap(s_typein_buffer, 'i', '<Tab>', '<Esc>:lua vim.fn.win_gotoid(' .. d_typein_window ..')<cr>:startinsert<cr>', { nowait = true, noremap = true, silent = true})

    api.nvim_buf_set_keymap(s_typein_buffer, 'n', '<Tab>', '<Esc>:lua vim.fn.win_gotoid(' .. d_typein_window ..')<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(d_typein_buffer, 'i', '<Tab>', '<Esc>:lua vim.fn.win_gotoid(' .. s_typein_window ..')<cr>:startinsert<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(d_typein_buffer, 'n', '<Tab>', ':lua vim.fn.win_gotoid(' .. s_typein_window ..')<cr>', { nowait = true, noremap = true, silent = true})
end

local function buffersed()
    local middle_index = math.ceil(dimensions.content_width / 2)

    local user_buffer = api.nvim_get_current_buf()
    local original_content_buffer_lines = api.nvim_buf_get_lines(user_buffer, 0, -1, false)

    s_content_buffer, s_content_window = require('common').create_sd_content_buffer(dimensions.content_col, dimensions.content_row, middle_index, dimensions.content_height, original_content_buffer_lines)
    d_content_buffer, d_content_window = require('common').create_sd_content_buffer(dimensions.content_col + middle_index + 1, dimensions.content_row, dimensions.content_width - middle_index - 1, dimensions.content_height, original_content_buffer_lines)
    border_buf, border_win = create_splitted_border_window()

    s_typein_buffer, s_typein_window = require('common').create_typein_buffer(dimensions.content_col + 3, dimensions.content_row + dimensions.content_height + 1, middle_index - 3)
    d_typein_buffer, d_typein_window = require('common').create_typein_buffer(dimensions.content_col + 4 + middle_index, dimensions.content_row + dimensions.content_height + 1, dimensions.content_width - middle_index - 4)

    vim.fn.win_gotoid(s_typein_window)

    set_mappings()
end

return {
     buffersed = buffersed
}

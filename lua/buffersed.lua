local b = vim.b
local api = vim.api
local content_buffer, content_window
local typein_buffer, typein_window
local border_buf, border_win
local original_content_buffer_lines

local width = api.nvim_get_option("columns")
local height = api.nvim_get_option("lines")

local content_height = math.max(10, math.ceil(height * 0.5 - 4))
local content_width = math.max(20, math.ceil(width * 0.8))

local content_row = math.ceil((height  - content_height) / 2 - 1)
local content_col = math.ceil((width - content_width) / 2)

local function create_border_window()
    border_buf = api.nvim_create_buf(false, true)

    local border_buf_opts = {
        style = "minimal",
        relative = "editor",
        border = "shadow",
        width = content_width + 2,
        height = content_height + 4,
        row = content_row - 1,
        col = content_col - 1
    }
    local border_lines = { '╭' .. string.rep('─', content_width) .. '╮' }
    local middle_line = '│' .. string.rep(' ', content_width) .. '│'
    for i=1, content_height do
      table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '├' .. string.rep('─', content_width) .. '┤')
    table.insert(border_lines, '│ > '..string.rep(' ', content_width - 3) .. '│')

    table.insert(border_lines, '╰' .. string.rep('─', content_width) .. '╯')
    api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    border_win = api.nvim_open_win(border_buf, true, border_buf_opts)
    api.nvim_win_set_option(border_win, 'winhl', 'Normal:MyHighlight')
end

local function create_typein_window()
    typein_buffer = api.nvim_create_buf(false, true)

    local buf_opts = {
        style = "minimal",
        relative = "editor",
        width = content_width - 3,
        height = 1,
        row = content_row + content_height + 1,
        col = content_col + 3
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
    original_content_buffer_lines = api.nvim_buf_get_lines(user_buffer, 0, -1, false)

    content_buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(content_buffer, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(content_buffer, 'buftype', 'nowrite')

    local opts = {
        style = "minimal",
        relative = "editor",
        width = content_width,
        height = content_height,
        row = content_row,
        col = content_col
    }

    api.nvim_buf_set_lines(content_buffer, 0, -1, false, original_content_buffer_lines)
    api.nvim_buf_set_option(content_buffer, 'modifiable', false)
    content_window = api.nvim_open_win(content_buffer, true, opts)
    api.nvim_win_set_option(content_window, 'winhl', 'Normal:MyHighlight')
end

local function trim(s)
   return s:match "^%s*(.-)%s*$"
end

local function update_typein_buffer()
    local lines = api.nvim_buf_get_lines(typein_buffer, 0, 1, false)
    local grep_line = lines[1]

    local content_lines = original_content_buffer_lines
    local filtered_lines = {}
    local extmarks = {}
    local namespace = require('highlights').namespace_id

    local new_index = 1
    for index,str in ipairs(content_lines) do
        local start_index, end_index = string.find(str, grep_line)
        if start_index or trim(grep_line) == '' then
            if(trim(grep_line)) ~= '' then
                local coordinates = {}
                coordinates.line = new_index
                coordinates.start_col = start_index
                coordinates.end_col = end_index
                extmarks[new_index] = coordinates
            end

            filtered_lines[new_index] = str
            new_index = new_index + 1
        end
    end


    api.nvim_buf_set_option(content_buffer, 'modifiable', true)
    api.nvim_buf_set_lines(content_buffer, 0, -1, false, filtered_lines)
    api.nvim_buf_set_option(content_buffer, 'modifiable', false)
    for i, coordinates in pairs(extmarks) do
        api.nvim_buf_set_extmark(content_buffer, namespace, coordinates.line - 1, coordinates.start_col - 1, {end_row = coordinates.line - 1, end_col = coordinates.end_col, hl_group = 'BuffersedSearchHighlight'})
    end
end

local function open_float()
    create_content_buffer()

    create_border_window()
    create_typein_window()

    api.nvim_command('augroup TypinCommandHandler')
    api.nvim_command('autocmd!')
    api.nvim_command("autocmd TextChangedI <buffer=" .. typein_buffer .. "> lua require('buffersed').update_typein_buffer()")
    api.nvim_command("autocmd TextChanged <buffer=" .. typein_buffer .. "> lua require('buffersed').update_typein_buffer()")
    api.nvim_command('augroup end')

    api.nvim_command('startinsert')
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
    close_float = close_float,
    update_typein_buffer = update_typein_buffer
}

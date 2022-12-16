local b = vim.b
local api = vim.api
local content_buffer, content_window
local typein_buffer, typein_window
local border_buf, border_win
local original_content_buffer_lines

local trim = require('common').trim


local function create_border_window()
    local dimensions = require('common').configuration.dimensions
    border_buf = api.nvim_create_buf(false, true)

    local border_buf_opts = {
        style = "minimal",
        relative = "editor",
        border = "shadow",
        width = dimensions.content_width + 2,
        height = dimensions.content_height + 4,
        row = dimensions.content_row - 1,
        col = dimensions.content_col - 1
    }
    local border_lines = { '╭' .. string.rep('─', dimensions.content_width) .. '╮' }
    local middle_line = '│' .. string.rep(' ', dimensions.content_width) .. '│'
    for i=1, dimensions.content_height do
      table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '├' .. string.rep('─', dimensions.content_width) .. '┤')
    table.insert(border_lines, '│ > '..string.rep(' ', dimensions.content_width - 3) .. '│')

    table.insert(border_lines, '╰' .. string.rep('─', dimensions.content_width) .. '╯')
    api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

    border_win = api.nvim_open_win(border_buf, true, border_buf_opts)
    api.nvim_win_set_option(border_win, 'winhl', 'Normal:MyHighlight')
    api.nvim_win_set_option(border_win, 'scrollbind', false)
end

local function update_typein_buffer()
    local lines = api.nvim_buf_get_lines(typein_buffer, 0, 1, false)
    local grep_line = lines[1]

    local content_lines = original_content_buffer_lines
    local filtered_lines = {}
    local extmarks = {}
    local namespace = require('highlights').search_namespace

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


local function close_float()
    api.nvim_win_close(typein_window, true)
    api.nvim_win_close(content_window, true)
    api.nvim_win_close(border_win, true)
end

local function create_close_autogrp()
    local close_buf_group_id = api.nvim_create_augroup("BuffersearchCloseGroup", { clear = true })
    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = typein_buffer,
        group = close_buf_group_id,
        callback = close_float
    })

    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = content_buffer,
        group = close_buf_group_id,
        callback = close_float
    })
end

local function switch_to_window_with_tab(window, insert_mode)
    -- delete and re-create close autocommands to disable closing when pressing <Tab>
    api.nvim_del_augroup_by_name("BuffersearchCloseGroup")
    vim.fn.win_gotoid(window)
    create_close_autogrp()
    if insert_mode then
        api.nvim_command('startinsert')
    end
end

local function set_autocommands()
    local typein_group = api.nvim_create_augroup("TypinCommandHandler", {clear = true})
    api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
        buffer = typein_buffer,
        group = typein_group,
        callback = update_typein_buffer
    })

    api.nvim_create_autocmd({"InsertLeave"}, {
        buffer = typein_buffer,
        group = typein_group,
        callback = function() switch_to_window_with_tab(content_window, false) end
    })

    create_close_autogrp()

    api.nvim_command('startinsert')
end


local function set_mappings()
    local dimensions = require('common').configuration.dimensions
    api.nvim_buf_set_keymap(typein_buffer, 'i', '<cr>', '<Esc>:lua require"buffersearch".close_float()<cr>', { nowait = true, noremap = true, silent = true})

    api.nvim_buf_set_keymap(content_buffer, 'n', 'i', ':lua require("buffersearch").switch_to_window_with_tab(' .. typein_window .. ', true)<cr>', { nowait = true, noremap = true, silent = true})
end

local function buffsearch()
    local dimensions = require('common').configuration.dimensions
    local user_buffer = api.nvim_get_current_buf()
    original_content_buffer_lines = api.nvim_buf_get_lines(user_buffer, 0, -1, false)

    content_buffer, content_window = require('common').create_sd_content_buffer(dimensions.content_col, dimensions.content_row, dimensions.content_width, dimensions.content_height, original_content_buffer_lines)

    create_border_window()
    typein_buffer, typein_window = require('common').create_typein_buffer(dimensions.content_col + 3, dimensions.content_row + dimensions.content_height + 1, dimensions.content_width - 3)

    set_autocommands()
    set_mappings()
end


return {
    buffersearch = buffsearch,
    close_float = close_float,
    update_typein_buffer = update_typein_buffer,
    switch_to_window_with_tab = switch_to_window_with_tab
}

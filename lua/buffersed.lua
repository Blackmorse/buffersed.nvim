local b = vim.b
local api = vim.api
local border_buf, border_win
local s_content_buffer, s_content_window, d_content_buffer, d_content_window
local s_typein_buffer, s_typein_window, d_typein_buffer, d_typein_window

local  original_content_buffer_lines

local s_extmarks = {}
local d_extmarks = {}
local trim = require('common').trim
local set_scrolling_mappings = require('common').set_scrolling_mappings

local function create_splitted_border_window()
    local dimensions = require('common').configuration.dimensions

    local border_buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(border_buffer, 'buftype', 'nowrite')

    local border_buf_opts = {
        style = "minimal",
        relative = "editor",
        border = "shadow",
        width = dimensions.sed_buf_width * 2 + 3, -- 3 = borders total width
        height = dimensions.content_height + 4, -- 4 = for the bottom pane
        row = dimensions.content_row - 1,
        col = dimensions.content_col - 1,
        zindex = 50
    }

    local border_lines = { '╭' .. string.rep('─', dimensions.sed_buf_width) .. '┬' .. string.rep('─', dimensions.sed_buf_width) .. '╮' }
    local middle_line = '│' .. string.rep(' ', dimensions.sed_buf_width) .. '│' .. string.rep(' ', dimensions.sed_buf_width) .. '│'
    for i=1, dimensions.content_height do
      table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, '├' .. string.rep('─', dimensions.sed_buf_width) .. '┼' .. string.rep('─', dimensions.sed_buf_width) .. '┤')
    table.insert(border_lines, '│ > '..string.rep(' ', dimensions.sed_buf_width - 3) .. '│ > ' .. string.rep(' ', dimensions.sed_buf_width - 3) .. '│')

    table.insert(border_lines, '╰' .. string.rep('─', dimensions.sed_buf_width) .. '┴' .. string.rep('─', dimensions.sed_buf_width) .. '╯')
    api.nvim_buf_set_lines(border_buffer, 0, -1, false, border_lines)

    local border_window = api.nvim_open_win(border_buffer, true, border_buf_opts)
    api.nvim_win_set_option(border_window, 'winhl', 'Normal:MyHighlight')
    api.nvim_win_set_option(border_window, 'scrollbind', false)

    return border_buffer, border_window
end

local function close_windows()
    api.nvim_win_close(s_typein_window, true)
    api.nvim_win_close(d_typein_window, true)
    api.nvim_win_close(s_content_window, true)
    api.nvim_win_close(d_content_window, true)
    api.nvim_win_close(border_win, true)
end

local function create_close_autogrp()
    local close_buf_group_id = api.nvim_create_augroup("TypeinCloseGroup", {clear = true})
    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = s_typein_buffer,
        group = close_buf_group_id,
        callback = close_windows
    })

    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = d_typein_buffer,
        group = close_buf_group_id,
        callback = close_windows
    })

    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = s_content_buffer,
        group = close_buf_group_id,
        callback = close_windows
    })

    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = d_content_buffer,
        group = close_buf_group_id,
        callback = close_windows
    })
end

local function switch_to_window_with_tab(window, insert_mode)
    -- delete and re-create close autocommands to disable closing when pressing <Tab>
    api.nvim_del_augroup_by_name("TypeinCloseGroup")
    vim.fn.win_gotoid(window)
    create_close_autogrp()
    if insert_mode then
        api.nvim_command('startinsert')
    end
end

local function set_mappings()
    api.nvim_buf_set_keymap(s_typein_buffer, 'i', '<Tab>', '<Esc>:lua require("buffersed").switch_to_window_with_tab(' .. d_typein_window ..', true)<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(s_typein_buffer, 'n', '<Tab>', '<Esc>:lua require("buffersed").switch_to_window_with_tab(' .. d_typein_window ..', false)<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(d_typein_buffer, 'i', '<Tab>', '<Esc>:lua require("buffersed").switch_to_window_with_tab(' .. s_typein_window ..', true)<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(d_typein_buffer, 'n', '<Tab>', ':lua require("buffersed").switch_to_window_with_tab(' .. s_typein_window ..', false)<cr>', { nowait = true, noremap = true, silent = true})

    api.nvim_buf_set_keymap(s_content_buffer, 'n', 'i', ':lua require("buffersed").switch_to_window_with_tab(' .. s_typein_window .. ', true)<cr>:startinsert<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(d_content_buffer, 'n', 'i', ':lua require("buffersed").switch_to_window_with_tab(' .. d_typein_window .. ', true)<cr>:startinsert<cr>', { nowait = true, noremap = true, silent = true})

    api.nvim_buf_set_keymap(s_content_buffer, 'n', '<Tab>', ':lua require("buffersed").switch_to_window_with_tab(' .. d_content_window .. ', false)<cr>', { nowait = true, noremap = true, silent = true})
    api.nvim_buf_set_keymap(d_content_buffer, 'n', '<Tab>', ':lua require("buffersed").switch_to_window_with_tab(' .. s_content_window .. ', false)<cr>', { nowait = true, noremap = true, silent = true})
end

local function find_all_matching_indexes(s, f)
    local t = {}                   -- table to store the indices
    local i = 0
    while true do
      i = string.find(s, f, i+1, true)    -- find 'next' newline
      if i == nil then break end
      table.insert(t, i)
    end
    return t
end

local function clear_extmarks(extmarks, content_buffer, namespace)
    for i, ext_id in pairs(extmarks) do
        api.nvim_buf_del_extmark(content_buffer, namespace, ext_id)
    end
    return {}
end

local function update_s_buffer()
    local namespace = require('highlights').s_sed_namespace
    s_extmarks = clear_extmarks(s_extmarks, s_content_buffer, namespace)

    local grep_line = api.nvim_buf_get_lines(s_typein_buffer, 0, 1, false)[1]

    if string.len(trim(grep_line)) == 0 then
        return
    end

    local content_lines = original_content_buffer_lines

    for index,str in ipairs(content_lines) do
        local indexes = find_all_matching_indexes(str, grep_line)

        for i, start_index in ipairs(indexes) do
            local end_index = start_index + string.len(grep_line) - 1
            local extmark_id = api.nvim_buf_set_extmark(s_content_buffer, namespace, index - 1, start_index - 1, {end_row = index - 1, end_col = end_index, hl_group = 'BuffersedSedHighlightS'})
            table.insert(s_extmarks, extmark_id)
        end
    end
end


local function update_d_buffer()
    local namespace = require('highlights').s_sed_namespace

    local grep_line = api.nvim_buf_get_lines(s_typein_buffer, 0, 1, false)[1]
    local replace_line = api.nvim_buf_get_lines(d_typein_buffer, 0, 1, false)[1]

    local content_lines = original_content_buffer_lines
    d_extmarks = clear_extmarks(d_extmarks, d_content_buffer, namespace)

    if string.len(trim(grep_line)) == 0 then
        api.nvim_buf_set_option(d_content_buffer, 'modifiable', true)
        api.nvim_buf_set_lines(d_content_buffer, 0, -1, false, content_lines)
        api.nvim_buf_set_option(d_content_buffer, 'modifiable', false)
        return
    end

    local grep_line_len = string.len(grep_line)
    local replace_line_len = string.len(replace_line)

    local new_buffer_lines = {}
    local extmarks_coordinates = {}

    for index, str in ipairs(content_lines) do
        local indexes = find_all_matching_indexes(str, grep_line)
        local updated_indexes = {}
        local offset = 0
        for ind, val in ipairs(indexes) do
            table.insert(updated_indexes, val - offset)

            local coordinates = {}
            coordinates.line = index
            coordinates.start_col = val - offset
            coordinates.end_col = val - offset + replace_line_len
            table.insert(extmarks_coordinates, coordinates)
            offset = offset + grep_line_len - replace_line_len
        end

        local replaced_string = string.gsub(str, grep_line, replace_line)
        table.insert(new_buffer_lines, replaced_string)
    end

    api.nvim_buf_set_option(d_content_buffer, 'modifiable', true)
    api.nvim_buf_set_lines(d_content_buffer, 0, -1, false, new_buffer_lines)
    api.nvim_buf_set_option(d_content_buffer, 'modifiable', false)

    for i, coordinates in ipairs(extmarks_coordinates) do
        if coordinates.start_col ~= coordinates.end_col then
            local extmark = api.nvim_buf_set_extmark(d_content_buffer, namespace, coordinates.line - 1, coordinates.start_col - 1,
              {
                  end_row = coordinates.line - 1,
                  end_col = coordinates.end_col - 1,
                  hl_group = "BuffersedSedHighlightD"
              })
            table.insert(d_extmarks, extmark)
          end
    end
end



local function set_autocommands()
    local type_group_id = api.nvim_create_augroup("TypinCommandHandler", {clear = true})
    api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
        buffer = s_typein_buffer,
        group = type_group_id,
        callback = function () update_s_buffer(); update_d_buffer() end
    })

    api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
        buffer = d_typein_buffer,
        group = type_group_id,
        callback = function () update_s_buffer(); update_d_buffer() end
    })

    api.nvim_create_autocmd({"InsertLeave"}, {
        buffer = s_typein_buffer,
        group = type_group_id,
        callback = function() switch_to_window_with_tab(s_content_window, false) end
    })

    api.nvim_create_autocmd({"InsertLeave"}, {
        buffer = d_typein_buffer,
        group = type_group_id,
        callback = function() switch_to_window_with_tab(d_content_window, false) end
    })

    api.nvim_create_autocmd({"InsertEnter"}, {
        buffer = s_content_buffer,
        group = type_group_id,
        callback = function() switch_to_window_with_tab(s_typein_buffer, true) end
    })

    api.nvim_create_autocmd({"InsertEnter"}, {
        buffer = d_content_buffer,
        group = type_group_id,
        callback = function() switch_to_window_with_tab(d_typein_buffer, true) end
    })

    create_close_autogrp()
end

local function buffersed()
    local dimensions = require('common').configuration.dimensions
    local user_buffer = api.nvim_get_current_buf()
    original_content_buffer_lines = api.nvim_buf_get_lines(user_buffer, 0, -1, false)

    s_content_buffer, s_content_window = require('common').create_sd_content_buffer(dimensions.content_col, dimensions.content_row, dimensions.sed_buf_width, dimensions.content_height, original_content_buffer_lines)
    d_content_buffer, d_content_window = require('common').create_sd_content_buffer(dimensions.content_col + dimensions.sed_buf_width + 1, dimensions.content_row, dimensions.sed_buf_width, dimensions.content_height, original_content_buffer_lines)
    border_buf, border_win = create_splitted_border_window()

    s_typein_buffer, s_typein_window = require('common').create_typein_buffer(dimensions.content_col + 3, dimensions.content_row + dimensions.content_height + 1, dimensions.sed_buf_width - 3)
    d_typein_buffer, d_typein_window = require('common').create_typein_buffer(dimensions.content_col + 4 + dimensions.sed_buf_width, dimensions.content_row + dimensions.content_height + 1, dimensions.sed_buf_width - 3)

    vim.fn.win_gotoid(s_typein_window)
    api.nvim_command('startinsert')

    set_mappings()
    set_autocommands()

end

return {
     buffersed = buffersed,
     update_s_buffer = update_s_buffer,
     update_d_buffer = update_d_buffer,
     switch_to_window_with_tab = switch_to_window_with_tab,
     set_config = set_config
}

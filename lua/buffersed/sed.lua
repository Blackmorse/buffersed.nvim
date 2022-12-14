local b = vim.b
local api = vim.api
local convimient = require('convimient')

local border_buf, border_win
local s_content_buffer, s_content_window, d_content_buffer, d_content_window
local s_typein_buffer, s_typein_window, d_typein_buffer, d_typein_window

local shared = {}
local  original_content_buffer_lines

local s_extmarks = {}
local d_extmarks = {}
local trim = require('buffersed.common').trim
local set_scrolling_mappings = require('buffersed.common').set_scrolling_mappings

local function create_splitted_border_window()
    local dimensions = require('buffersed.common').configuration.dimensions

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
    api.nvim_del_augroup_by_name("TypeinCloseGroup")

    api.nvim_win_close(s_typein_window, true)
    api.nvim_win_close(d_typein_window, true)
    api.nvim_win_close(s_content_window, true)
    api.nvim_win_close(d_content_window, true)
    api.nvim_win_close(border_win, true)

    shared.user_buffer = nil
end

local function create_close_autogrp()
    local close_buf_group_id = api.nvim_create_augroup("TypeinCloseGroup", {clear = true})
    convimient.vim_create_autocmd({"BufLeave"}, { group = close_buf_group_id, callback = close_windows}, {s_typein_buffer, d_typein_buffer})
end

local function switch_to_window_with_tab(window)
    -- delete and re-create close autocommands to disable closing when pressing <Tab>
    api.nvim_del_augroup_by_name("TypeinCloseGroup")
    vim.fn.win_gotoid(window)
    create_close_autogrp()
end

local function confirmation()
    local typein_line = api.nvim_buf_get_lines(s_typein_buffer, 0, 1, false)[1]
    if typein_line == '' then
        close_windows()
        return
    end
    vim.ui.select({"Yes", "No"}, {
        prompt = "Are you sure you want to replace original buffer?"
    },
    function(choice, idx)
        if choice == "Yes" then
            local replaced_lines = api.nvim_buf_get_lines(d_content_buffer, 0, -1, false)
            api.nvim_buf_set_lines(shared.user_buffer, 0, -1, false, replaced_lines)
            local close_buf_group_id = api.nvim_create_augroup("TypeinCloseGroup", {clear = true})
            close_windows()
        end
    end)
end

local function navigate_content_mappings()
    local half_height = math.ceil(require('buffersed.common').configuration.dimensions.content_height / 2)
    local scroll_down = require('buffersed.common').scroll_down

    local opts = { nowait = true, noremap = true, silent = true }
    local buffers = { s_typein_buffer, d_typein_buffer }
    local scroll_func = function(lines)
        return function ()
            scroll_down(s_content_window, s_content_buffer, lines)
            scroll_down(d_content_window, d_content_buffer, lines)
        end
    end

    convimient.vim_keymap_set('i', '<C-n>', scroll_func(1), opts, buffers)
    convimient.vim_keymap_set('i', '<C-p>', scroll_func(-1), opts, buffers)
    convimient.vim_keymap_set('i', '<C-d>', scroll_func(half_height), opts, buffers)
    convimient.vim_keymap_set('i', '<C-u>', scroll_func(-half_height), opts, buffers)
end

local function set_mappings()
    convimient.vim_keymap_set({'i', 'n'}, '<CR>', confirmation, { nowait = true, noremap = true, silent = true }, {s_typein_buffer, d_typein_buffer})

    vim.keymap.set({ 'i', 'n' }, '<Tab>', function() switch_to_window_with_tab(d_typein_window) end, {buffer = s_typein_buffer, nowait = true, silent = true, noremap = true})
    vim.keymap.set({ 'i', 'n' }, '<Tab>', function() switch_to_window_with_tab(s_typein_window) end, {buffer = d_typein_buffer, nowait = true, silent = true, noremap = true})

    convimient.vim_keymap_set({'i', 'n'}, {'<esc><esc>', '<C-c>'}, close_windows, { nowait = true, noremap = true, silent = true}, {s_typein_buffer, d_typein_buffer})

    navigate_content_mappings()
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
    local namespace = require('buffersed.highlights').s_sed_namespace
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
    local namespace = require('buffersed.highlights').s_sed_namespace

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
    convimient.vim_create_autocmd({"TextChangedI", "TextChanged"}, {
        group = type_group_id,
        callback = function() update_s_buffer(); update_d_buffer() end
    }, {s_typein_buffer, d_typein_buffer})

    create_close_autogrp()
end

local function buffersed()
    local dimensions = require('buffersed.common').configuration.dimensions
    local maybe = require('buffersed.search').shared.user_buffer
    shared.user_buffer = maybe and maybe or api.nvim_get_current_buf()

    original_content_buffer_lines = api.nvim_buf_get_lines(shared.user_buffer, 0, -1, false)

    s_content_buffer, s_content_window = require('buffersed.common').create_sd_content_buffer(dimensions.content_col, dimensions.content_row, dimensions.sed_buf_width, dimensions.content_height, original_content_buffer_lines)
    d_content_buffer, d_content_window = require('buffersed.common').create_sd_content_buffer(dimensions.content_col + dimensions.sed_buf_width + 1, dimensions.content_row, dimensions.sed_buf_width, dimensions.content_height, original_content_buffer_lines)
    border_buf, border_win = create_splitted_border_window()

    s_typein_buffer, s_typein_window = require('buffersed.common').create_typein_buffer(dimensions.content_col + 3, dimensions.content_row + dimensions.content_height + 1, dimensions.sed_buf_width - 3)
    d_typein_buffer, d_typein_window = require('buffersed.common').create_typein_buffer(dimensions.content_col + 4 + dimensions.sed_buf_width, dimensions.content_row + dimensions.content_height + 1, dimensions.sed_buf_width - 3)

    vim.fn.win_gotoid(s_typein_window)
    require('buffersed.common').start_insert()

    set_mappings()
    set_autocommands()

    local scroll_down = require('buffersed.common').scroll_down
    vim.defer_fn(function()
        scroll_down(s_content_window, s_content_buffer, 0)
        scroll_down(d_content_window, d_content_buffer, 0)
    end, 100)
end

return {
     buffersed = buffersed,
     update_s_buffer = update_s_buffer,
     updatclose_buf_group_id = update_d_buffer,
     shared = shared
}

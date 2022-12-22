local b = vim.b
local api = vim.api
local content_buffer, content_window
local typein_buffer, typein_window
local border_buf, border_win
local original_content_buffer_lines

local shared = {}

local trim = require('buffersed.common').trim


local function create_border_window()
    local dimensions = require('buffersed.common').configuration.dimensions
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
    local namespace = require('buffersed.highlights').search_namespace

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
    api.nvim_del_augroup_by_name("BuffersearchCloseGroup")

    api.nvim_win_close(typein_window, true)
    api.nvim_win_close(content_window, true)
    api.nvim_win_close(border_win, true)

    shared.user_buffer = nil
end

local function create_close_autogrp()
    local close_buf_group_id = api.nvim_create_augroup("BuffersearchCloseGroup", { clear = true })
    api.nvim_create_autocmd({"BufLeave"}, {
        buffer = typein_buffer,
        group = close_buf_group_id,
        callback = close_float
    })
end

local function set_autocommands()
    local typein_group = api.nvim_create_augroup("TypinCommandHandler", {clear = true})
    api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
        buffer = typein_buffer,
        group = typein_group,
        callback = update_typein_buffer
    })

    create_close_autogrp()
end

local function navigate_content_mappings()
    local half_height = math.ceil(require('buffersed.common').configuration.dimensions.content_height / 2)
    local scroll_down = require('buffersed.common').scroll_down

    vim.keymap.set('i', '<C-n>', function() scroll_down(content_window, content_buffer, 1) end, { nowait = true, noremap = true, silent = true, buffer = typein_buffer})
    vim.keymap.set('i', '<C-p>', function() scroll_down(content_window, content_buffer, -1) end, { nowait = true, noremap = true, silent = true, buffer = typein_buffer})
    vim.keymap.set('i', '<C-d>', function() scroll_down(content_window, content_buffer, half_height) end, { nowait = true, noremap = true, silent = true, buffer = typein_buffer})
    vim.keymap.set('i', '<C-u>', function() scroll_down(content_window, content_buffer, -half_height) end, { nowait = true, noremap = true, silent = true, buffer = typein_buffer})
end

local function set_mappings()
    local dimensions = require('buffersed.common').configuration.dimensions
    vim.keymap.set('i', '<cr>', close_float, { buffer = typein_buffer, nowait = true, noremap = true, silent = true })
    -- Todo insert, normal mode.
    vim.keymap.set('i', '<esc><esc>', close_float, {buffer = typein_buffer, nowait = true, noremap = true, silent = true})
    vim.keymap.set('n', '<esc><esc>', close_float, {buffer = typein_buffer, nowait = true, noremap = true, silent = true})
    vim.keymap.set('i', '<C-c>', close_float, {buffer = typein_buffer, nowait = true, noremap = true, silent = true})

    navigate_content_mappings()
end

local function buffsearch()
    local dimensions = require('buffersed.common').configuration.dimensions

    local maybe = require('buffersed.sed').shared.user_buffer
    shared.user_buffer = maybe and maybe or api.nvim_get_current_buf()
    original_content_buffer_lines = api.nvim_buf_get_lines(shared.user_buffer, 0, -1, false)

    content_buffer, content_window = require('buffersed.common').create_sd_content_buffer(dimensions.content_col, dimensions.content_row, dimensions.content_width, dimensions.content_height, original_content_buffer_lines)

    create_border_window()
    typein_buffer, typein_window = require('buffersed.common').create_typein_buffer(dimensions.content_col + 3, dimensions.content_row + dimensions.content_height + 1, dimensions.content_width - 3)

    set_mappings()
    set_autocommands()

    local half_height = math.min(math.ceil(dimensions.content_height / 2), #original_content_buffer_lines)

    api.nvim_win_set_cursor(content_window, {half_height ,1})
    local namespace = require('buffersed.highlights').line_namespace

    vim.fn.win_gotoid(typein_window)
    require('buffersed.common').start_insert()

    local scroll_down = require('buffersed.common').scroll_down
    -- to make highlight happen
    vim.defer_fn(function() scroll_down(content_window, content_buffer, 0) end, 100)
end


return {
    buffersearch = buffsearch,
    close_float = close_float,
    update_typein_buffer = update_typein_buffer,
    shared = shared
}

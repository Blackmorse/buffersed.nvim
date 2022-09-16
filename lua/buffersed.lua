local api = vim.api
local buf, win

local function open_float()
    buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    local opts = {
        style = "minimal",
        relative = "editor",
        width = 100,
        height = 20,
        row = 10,
        col = 15
    }

    win = api.nvim_open_win(buf, true, opts)
end

function close_float()
    api.nvim_win_close(win, true)
end

function set_mappings()
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require"buffersed".close_float()<cr>', { nowait = true, noremap = true, silent = true})
end

function buffersed()
    open_float()
    set_mappings()
end

return {
    buffersed = buffersed,
    close_float = close_float
}

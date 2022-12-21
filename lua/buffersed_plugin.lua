local api = vim.api

local function setup(user_conf)
    require('common').set_config(user_conf)
    require('highlights').set_config(user_conf)

    require('highlights').init_highlights()
    require('highlights').run_autocommands()

    api.nvim_create_user_command(
        "BufferSearch",
        function(opts) require('buffersearch').buffersearch() end,
        {})

    api.nvim_create_user_command(
        "BufferSed",
        function(opts) require('buffersed').buffersed() end,
        {})
end
return {
    setup = setup
}

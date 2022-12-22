local api = vim.api

local function setup(user_conf)
    require('buffersed.common').set_config(user_conf)
    require('buffersed.highlights').set_config(user_conf)

    require('buffersed.highlights').init_highlights()
    require('buffersed.highlights').run_autocommands()

    api.nvim_create_user_command(
        "BufferSearch",
        function(opts) require('buffersed.search').buffersearch() end,
        {})

    api.nvim_create_user_command(
        "BufferSed",
        function(opts) require('buffersed.sed').buffersed() end,
        {})
end
return {
    setup = setup
}

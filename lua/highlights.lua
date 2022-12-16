local api = vim.api
local M = {}
local s_highlight, d_highlight

function M.set_config(user_conf)
    local conf = user_conf or {}
    s_highlight = conf.search_highlight or "guifg=#ff007c gui=bold ctermfg=198 cterm=bold ctermbg=darkgreen"
    d_highlight = conf.replace_highlight or "guifg=#1f007c gui=bold ctermfg=198 cterm=bold ctermbg=red"
end

function M.init_highlights()
    api.nvim_command('highlight default BuffersedSearchHighlight ' .. s_highlight)
    api.nvim_command('highlight default BuffersedSedHighlightS ' .. s_highlight)
    api.nvim_command('highlight default BuffersedSedHighlightD ' .. d_highlight)
    M.search_namespace = api.nvim_create_namespace('BuffersedSearchHighlightNamespace')
    M.s_sed_namespace = api.nvim_create_namespace('BuffersedSearchHighlightNamespace')
end

function M.run_autocommands()
    api.nvim_command('augroup BuffersedSearchHighlightGroup')
    api.nvim_command('autocmd!')
    api.nvim_command("autocmd ColorScheme * lua require'highlights'.init_highlights()")
    api.nvim_command('augroup end')
end

return M

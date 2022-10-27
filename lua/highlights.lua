local api = vim.api
local M = {}


function M.init_highlights()
    api.nvim_command('highlight default BuffersedSearchHighlight guifg=#ff007c gui=bold ctermfg=198 cterm=bold ctermbg=darkgreen')
    M.namespace_id = api.nvim_create_namespace('BuffersedSearchHighlightNamespace')
end

function M.run_autocommands()
    api.nvim_command('augroup BuffersedSearchHighlightGroup')
    api.nvim_command('autocmd!')
    api.nvim_command("autocmd ColorScheme * lua require'highlights'.init_highlights()")
    api.nvim_command('augroup end')
end

return M

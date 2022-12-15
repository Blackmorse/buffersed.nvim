"if exists('g:loaded_buffersed') | finish | endif 
"
"let s:save_cpo = &cpo " save user coptions
"set cpo&vim " reset them to defaults
"
"" command to run our plugin
"command! Buffsearch lua require'buffersearch'.buffersearch()
"command! Buffsed lua require'buffersed'.buffersed()
"
"let &cpo = s:save_cpo " and restore after
"unlet s:save_cpo
"
"let g:loaded_buffersed = 1
"
"lua require'highlights'.init_highlights()
"lua require'highlights'.run_autocommands()

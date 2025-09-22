" Configurações para arquivos .chat
setlocal foldmethod=expr
setlocal foldexpr=ChatFoldLevel(v:lnum)
setlocal foldtext=ChatFoldText()

" Configurações de quebra de linha e wrap
setlocal wrap
setlocal linebreak
setlocal nolist

" Mapeamentos locais
nnoremap <buffer> <silent> <CR> :call <SID>ToggleFold()<CR>

function! s:ToggleFold()
    if foldclosed('.') == -1
        foldclose
    else
        foldopen
    endif
endfunction

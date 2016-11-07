"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! deol#start(command) abort
  if exists('t:deol')
    execute 'buffer' t:deol.bufnr
    execute 'lcd' fnameescape(t:deol.cwd)
    startinsert
    return
  endif

  let t:deol = deol#_new()
  execute 'lcd' fnameescape(t:deol.cwd)
  execute 'terminal' a:command
endfunction

function! deol#_new() abort
  return {
        \ 'bufnr': bufnr('%'),
        \ 'cwd': input('Current directory: ', getcwd(), 'dir'),
        \ }
endfunction

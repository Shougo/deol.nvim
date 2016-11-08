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

  let cwd = input('Current directory: ', getcwd(), 'dir')
  if cwd == ''
    return
  endif

  let t:deol = deol#_new(cwd)
  execute 'lcd' fnameescape(t:deol.cwd)
  execute 'terminal' a:command
  setlocal bufhidden=hide
endfunction

function! deol#_new(cwd) abort
  return {
        \ 'bufnr': bufnr('%'),
        \ 'cwd': fnamemodify(a:cwd, ':p'),
        \ }
endfunction

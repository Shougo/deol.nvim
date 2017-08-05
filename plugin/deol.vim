"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

if !has('nvim') && !exists('*term_start')
  echomsg 'deol.nvim requires Neovim or terminal feature enabled Vim.'
  finish
endif

if exists('g:loaded_deol')
  finish
endif
let g:loaded_deol = 1

command! -nargs=* -range -complete=shellcmd
      \ Deol call deol#start({'command': <q-args>})
command! -nargs=1 -range -complete=dir
      \ DeolCd call deol#cd(<q-args>)
command! DeolEdit call deol#edit()

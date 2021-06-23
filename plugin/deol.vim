"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

if !has('nvim-0.3') && !has('patch-8.2.1978')
  echomsg 'deol.nvim requires Neovim 0.3+ or Vim 8.2.1978+.'
  finish
endif

if exists('g:loaded_deol')
  finish
endif
let g:loaded_deol = 1

command! -nargs=* -range -bar -complete=customlist,deol#_complete
      \ Deol call deol#start(<q-args>)
command! -nargs=1 -range -bar -complete=dir
      \ DeolCd call deol#cd(<q-args>)
command! -bar DeolEdit call deol#edit()

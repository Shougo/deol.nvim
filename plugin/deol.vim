if !has('nvim-0.8') && !has('patch-8.2.1978')
  echomsg 'deol.nvim requires Neovim 0.8+ or Vim 8.2.1978+.'
  finish
endif

if 'g:loaded_deol'->exists()
  finish
endif
let g:loaded_deol = 1

command! -nargs=* -range -bar -complete=custom,deol#_complete
      \ Deol call deol#start(<q-args>)
command! -nargs=1 -range -bar -complete=dir
      \ DeolCd call deol#cd(<q-args>)
command! -bar DeolEdit call deol#edit()

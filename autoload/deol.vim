let s:is_windows = has('win32') || has('win64')

let g:deol#_prev_deol = -1
let g:deol#enable_dir_changed = g:
      \ ->get('deol#enable_dir_changed', v:true)
let g:deol#prompt_pattern = g:
      \ ->get('deol#prompt_pattern', s:is_windows ? '\f\+>' : '')
let g:deol#shell_history_path = g:->get('deol#shell_history_path', '')
let g:deol#shell_history_max = g:->get('deol#shell_history_max', 500)
let g:deol#nvim_server = g:->get('deol#nvim_server', '')
let g:deol#floating_border = g:->get('deol#floating_border', 'none')

let s:default_term_options = #{
      \   curwin: v:true,
      \   exit_cb: { job, status -> execute('unlet! t:deol') },
      \ }
let g:deol#_term_options = s:default_term_options->extend(
      \ g:->get('deol#extra_options', {}))
let s:default_maps = #{
      \   bg: '<C-z>',
      \   edit: 'e',
      \   execute_line: '<CR>',
      \   next_prompt: '<C-n>',
      \   paste_prompt: '<C-y>',
      \   previous_prompt: '<C-p>',
      \   quit: 'q',
      \   start_append: 'a',
      \   start_append_last: 'A',
      \   start_insert: 'i',
      \   start_insert_first: 'I',
      \ }
let g:deol#_maps = s:default_maps->extend(g:->get('deol#custom_map', {}))

augroup deol
  autocmd!
augroup END

function! deol#start(cmdline) abort
  return deol#_start(s:parse_options(a:cmdline))
endfunction

function! deol#_start(options) abort
  let options = a:options->copy()

  if 't:deol'->exists() && t:deol.bufnr->bufexists()
    const ids = t:deol.bufnr->win_findbuf()
    if !(ids->empty()) && options.toggle
      call deol#quit()
    else
      call s:switch(options)
    endif

    return
  endif

  if options.cwd ==# ''
    let options.cwd = getcwd()
  endif

  const cwd = s:expand(options.cwd)
  if !(cwd->isdirectory())
    redraw
    const result = printf('[deol] %s is not directory.  Create?', cwd)
          \ ->confirm("&Yes\n&No\n&Cancel")
    if result != 1
      return
    endif

    call mkdir(cwd, 'p')
  endif

  call s:split(options)

  let t:deol = deol#_new(cwd, options)
  let t:deol.prev_bufnr = '%'->bufnr()
  call t:deol.init_deol_buffer()

  if has('nvim')
    call s:insert_mode(t:deol)
  else
    " In Vim8, must be insert mode to redraw
    startinsert
  endif

  if options.edit
    call deol#edit()
  endif
endfunction

function! s:switch(options) abort
  const options = a:options->copy()
  let deol = t:deol
  let deol.prev_bufnr = '%'->bufnr()

  const ids = deol.bufnr->win_findbuf()
  if ids->empty()
    call s:split(options)
    execute 'buffer' deol.bufnr
  else
    call win_gotoid(ids[0])
  endif

  let g:deol#_prev_deol = win_getid()

  if options.cwd !=# ''
    call deol.cd(options.cwd)
  else
    call s:cd(deol.cwd)
  endif

  if options.edit
    call deol#edit()
  else
    call s:insert_mode(deol)
  endif
endfunction

function! deol#new(options) abort
  let options = s:user_options()->extend(copy(a:options))
  if options->get('cwd', '') ==# ''
    let options.cwd = 'Current directory: '->input(getcwd(), 'dir')
  endif

  if options.cwd ==# ''
    return
  endif
  const cwd = s:expand(options.cwd)
  if !(cwd->isdirectory())
    redraw
    const result = printf('[deol] %s is not directory.  Create?', cwd)
          \ ->confirm("&Yes\n&No\n&Cancel")
    if result != 1
      return
    endif

    call mkdir(cwd, 'p')
  endif

  tabnew
  return deol#_start(options)
endfunction

function! deol#send(string) abort
  if !('t:deol'->exists())
    return ''
  endif

  call t:deol.jobsend(s:cleanup() .. a:string .. "\<CR>")
  return ''
endfunction

function! deol#cd(directory) abort
  if !('t:deol'->exists()) || t:deol.bufnr->bufwinnr() < 0
    return
  endif

  call t:deol.cd(a:directory)

  " Needs redraw for Vim8
  if !has('nvim')
    call s:term_redraw(t:deol.bufnr)
  endif
endfunction

function! deol#edit() abort
  if !('t:deol'->exists())
    Deol
  endif

  const ids = win_findbuf(t:deol.bufnr)
  if !(ids->empty()) && win_getid() != ids[0]
    call win_gotoid(ids[0])
    call cursor(line('$'), 0)
  endif

  call t:deol.switch_edit_buffer()

  call t:deol.init_edit_buffer()

  " Set the current command line
  const buflines = t:deol.bufnr->getbufline(1, '$')
        \ ->filter({ _, val -> val !=# '' })
  const pattern = '^\%(' .. g:deol#prompt_pattern .. '\m\)'
  if !(buflines->empty()) && buflines[-1] =~# pattern
    const cmdline = buflines[-1]->substitute(pattern, '', '')
    if '$'->getline() ==# ''
      call setline('$', cmdline)
    else
      call append('$', cmdline)
    endif
  endif

  call cursor('$'->line(), 0)
  startinsert!
endfunction

function! deol#kill_editor() abort
  bdelete
  call win_gotoid(g:deol#_prev_deol)
endfunction

function! deol#get_cmdline() abort
  if &l:filetype !=# 'deol'
    return '.'->getline()
  endif

  const pattern = '^\%(' .. g:deol#prompt_pattern .. '\m\)'
  return '.'->getline()->substitute(pattern, '', '')
endfunction

function! deol#_new(cwd, options) abort
  let deol = s:deol->copy()
  let deol.command = a:options.command
  let deol.edit_winid = -1
  let deol.edit_bufnr = -1
  let deol.edit_filetype = a:options.edit_filetype
  let deol.options = a:options
  call deol.cd(a:cwd)

  " Set $EDITOR.
  let editor_command = ''
  if 'g:guise_loaded'->exists()
    " Use guise instead
  elseif 'g:edita_loaded'->exists()
    " Use edita instead
    let editor_command = edita#EDITOR()
  "elseif v:progname ==# 'nvim' && g:deol#nvim_server !=# '' && has('nvim-0.7')
  "  " Use clientserver for neovim
  "  let editor_command =
  "        \ printf('%s --server %s --remote-tab-wait-silent',
  "        \   v:progpath, s:expand(g:deol#nvim_server))
  elseif v:progname ==# 'nvim' && 'nvr'->executable()
    " Use neovim-remote for neovim
    let editor_command = 'nvr --remote-tab-wait-silent'
  elseif v:progpath->executable() && has('clientserver')
    " Use clientserver for Vim8
    let editor_command =
          \ printf('%s %s --remote-tab-wait-silent',
          \   v:progpath,
          \   (v:servername ==# '' ? '' : ' --servername='.v:servername))
  elseif v:progpath->executable()
    let editor_command = v:progpath
  endif

  if editor_command !=# ''
    let $EDITOR = editor_command
    let $GIT_EDITOR = editor_command
  endif

  return deol
endfunction

function! deol#quit() abort
  if 't:deol'->exists()
    if t:deol.edit_bufnr->bufwinnr() > 0
      " Close edit buffer in the first
      execute t:deol.edit_bufnr->bufwinnr() 'wincmd w'
      close!
    endif

    let deolwin = t:deol.bufnr->bufwinnr()
    if deolwin < 0
      return
    endif

    execute deolwin 'wincmd w'
  endif

  if winnr('$') > 1
    close!
  else
    " Move to alternate buffer
    if 't:deol'->exists() && s:check_buffer(t:deol.prev_bufnr)
      execute 'buffer' t:deol.prev_bufnr
    elseif 't:deol'->exists() && s:check_buffer(bufnr('#'))
      buffer #
    else
      enew
    endif
  endif
endfunction

function! s:cd(directory) abort
  execute 'tchdir' fnameescape(a:directory)
endfunction

let s:deol = {}

function! s:deol.cd(directory) abort
  const directory = a:directory->fnamemodify(':p')
  if (self->has_key('cwd') && self.cwd ==# directory)
        \ || !(directory->isdirectory())
    return
  endif

  let self.cwd = directory
  call s:cd(self.cwd)

  const quote = s:is_windows ? '"' : "'"
  call self.jobsend(printf('%scd %s%s%s%s',
        \ s:cleanup(), quote, self.cwd, quote, "\<CR>"))
endfunction

function! s:deol.init_deol_buffer() abort
  if has('nvim')
    " Note: termopen() replaces current buffer
    enew
    call termopen(self.command)

    let self.jobid = b:terminal_job_id
    let self.pid = b:terminal_job_pid
  else
    let options = g:deol#_term_options->extend(
          \ b:->get('deol_extra_options', {}))
    call term_start(self.command, options)
    let self.pid = term_getjob('%'->bufnr())->job_info().process
  endif

  let self.bufnr = '%'->bufnr()
  let g:deol#_prev_deol = win_getid()

  nnoremap <buffer> <Plug>(deol_execute_line)
        \ <Cmd>call <SID>eval_deol(v:false)<CR>
  tnoremap <buffer> <Plug>(deol_execute_line)
        \ <Cmd>call <SID>eval_deol(v:true)<CR>
  nnoremap <buffer> <Plug>(deol_bg)
        \ <Cmd>call <SID>bg()<CR>
  nnoremap <buffer> <Plug>(deol_previous_prompt)
        \ <Cmd>call <SID>search_prompt('bWn')<CR>
  nnoremap <buffer> <Plug>(deol_next_prompt)
        \ <Cmd>call <SID>search_prompt('Wn')<CR>
  nnoremap <buffer> <Plug>(deol_paste_prompt)
        \ <Cmd>call <SID>paste_prompt()<CR>
  nnoremap <buffer> <Plug>(deol_edit)
        \ <Cmd>call deol#edit()<CR>
  nnoremap <buffer><expr> <Plug>(deol_start_insert)
        \ <SID>start_insert('i')
  nnoremap <buffer><expr> <Plug>(deol_start_insert_first)
        \ 'i' .. ("\<Left>"->repeat(, '.'->getline()->len()))
  nnoremap <buffer><expr> <Plug>(deol_start_append)
        \ <SID>start_insert('A')
  nnoremap <buffer><expr> <Plug>(deol_start_append_last)
        \ 'i' .. ("\<Right>"->repeat('.'->getline()->len()))
  nnoremap <buffer> <Plug>(deol_quit)
        \ <Cmd>call deol#quit()<CR>

  setlocal bufhidden=hide
  setlocal nolist
  setlocal nobuflisted
  setlocal nowrap
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal colorcolumn=
  setlocal nonumber
  setlocal norelativenumber
  if '+smoothscroll'->exists()
    " NOTE: If smoothscroll is set in neovim, freezed in terminal buffer.
    setlocal nosmoothscroll
  endif

  for [rhs, lhs] in g:deol#_maps->items()
    execute 'nmap <buffer> ' .. lhs .. ' <Plug>(deol_' .. rhs .. ')'
  endfor

  " set filetype twice to load after/ftplugin in Vim8
  setlocal filetype=deol
  setlocal filetype=deol

  if g:deol#enable_dir_changed
    if has('nvim')
      autocmd deol DirChanged <buffer> call deol#cd(v:event.cwd)
    else
      " Note: Use <afile> does not work...
      autocmd deol DirChanged <buffer> call deol#cd(getcwd())
    endif
  endif

  if '##TermClose'->exists()
    autocmd deol TermClose <buffer> unlet! t:deol
  endif
  autocmd deol InsertEnter <buffer> call s:set_prev_deol(t:deol)
endfunction

function! s:deol.switch_edit_buffer() abort
  if self.edit_bufnr->win_findbuf() == [self.edit_winid]
    call win_gotoid(self.edit_winid)
    return
  endif

  const cwd = getcwd()

  const edit_bufname = 'deol-edit@' .. t:deol.bufnr->bufname()
  if self.options.split ==# 'floating' && '*nvim_open_win'->exists()
    call nvim_open_win('%'->bufnr(), v:true, #{
          \   relative: 'editor',
          \   row: (self.options.winrow + winheight(0))->str2nr(),
          \   col: self.options.wincol->str2nr(),
          \   width: 0->winwidth(),
          \   height: 1,
          \   border: g:deol#floating_border,
          \ })
    execute edit_bufname->bufadd() 'buffer'
  else
    execute 'split' edit_bufname->fnameescape()
  endif

  if '$'->line() == 1
    call append(0, deol#_get_histories())
  endif

  call s:cd(cwd)

  let self.edit_winid = win_getid()
  let self.edit_bufnr = '%'->bufnr()
endfunction

function! s:deol.init_edit_buffer() abort
  setlocal bufhidden=hide
  setlocal buftype=nofile
  setlocal nolist
  setlocal nobuflisted
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal colorcolumn=
  setlocal nonumber
  setlocal norelativenumber
  setlocal noswapfile

  execute 'resize' self.options.edit_winheight

  " Set filetype
  const command = self.command[0]->fnamemodify(':t:r')
  let filetype = self.edit_filetype
  let default_filetype = #{
        \   ash: 'sh',
        \   bash: 'bash',
        \   fish: 'fish',
        \   ksh: 'sh',
        \   sh: 'sh',
        \   xonsh: 'python',
        \   zsh: 'zsh',
        \ }
  if filetype ==# '' && default_filetype->has_key(command)
    let filetype = default_filetype[command]
  endif

  let self.bufedit = '%'->bufnr()

  nnoremap <buffer> <Plug>(deol_execute_line)
        \ <Cmd>call <SID>eval_edit(v:false)<CR>
  inoremap <buffer> <Plug>(deol_execute_line)
        \ <Cmd>call <SID>eval_edit(v:true)<CR>
  nnoremap <buffer> <Plug>(deol_quit)
        \ <Cmd>call deol#quit()<CR>
  inoremap <buffer> <Plug>(deol_quit)
        \ <Cmd>call deol#quit()<CR>
  nnoremap <buffer> <Plug>(deol_backspace)
        \ <Cmd>call <SID>deol_backspace()<CR>
  inoremap <buffer> <Plug>(deol_backspace)
        \ <Cmd>call <SID>deol_backspace()<CR>
  nnoremap <buffer><expr> <Plug>(deol_ctrl_c)
        \ deol#send("\<C-c>")
  inoremap <buffer><expr> <Plug>(deol_ctrl_c)
        \ deol#send("\<C-c>") .. "\<ESC>a"
  inoremap <buffer><expr> <Plug>(deol_ctrl_d)
        \ deol#send("\<C-d>") .. "\<ESC>a"

  nmap <buffer> <CR>  <Plug>(deol_execute_line)
  nmap <buffer> <BS>  <Plug>(deol_backspace)
  nmap <buffer> <C-h> <Plug>(deol_backspace)
  nmap <buffer> q     <Plug>(deol_quit)
  nmap <buffer> <C-c> <Plug>(deol_ctrl_c)

  imap <buffer> <CR>  <Plug>(deol_execute_line)
  imap <buffer> <BS>  <Plug>(deol_backspace)
  imap <buffer> <C-h> <Plug>(deol_backspace)
  imap <buffer> <C-c> <Plug>(deol_ctrl_c)
  imap <buffer> <C-d> <Plug>(deol_ctrl_d)

  let &l:filetype = filetype

  if g:deol#enable_dir_changed
    if has('nvim')
      autocmd deol DirChanged <buffer> call deol#cd(v:event.cwd)
    else
      " Note: Use <afile> does not work...
      autocmd deol DirChanged <buffer> call deol#cd(getcwd())
    endif
  endif
endfunction

function! s:deol.jobsend(keys) abort
  if !(self->has_key('bufnr'))
    return
  endif

  if has('nvim')
    call chansend(self.jobid, a:keys)
  else
    call term_sendkeys(self.bufnr, a:keys)

    call s:term_redraw(self.bufnr)

    call term_wait(self.bufnr)
  endif

  " Set prev deol
  call s:set_prev_deol(self)
endfunction

function! s:set_prev_deol(deol) abort
  const ids = a:deol.bufnr->win_findbuf()
  if !(ids->empty())
    let g:deol#_prev_deol = ids[0]
  endif
endfunction

function! s:term_redraw(bufnr) abort
  if has('nvim')
    redraw
    return
  endif

  " Note: In Vim8, auto redraw does not work!

  const ids = a:bufnr->win_findbuf()
  if ids->empty()
    return
  endif

  const prev_mode = mode()
  const prev_winid = win_getid()
  call win_gotoid(ids[0])

  " Goto insert mode
  silent! execute 'normal!' s:start_insert('A')

  " Go back to normal mode
  silent! call s:stop_insert_term()

  call win_gotoid(prev_winid)
endfunction

function! s:start_insert_term() abort
  if has('nvim')
    startinsert
  else
    sleep 50m
    call feedkeys('i', 'n')
  endif
endfunction
function! s:stop_insert_term() abort
  if has('nvim')
    stopinsert
  else
    sleep 100m
    call feedkeys("\<C-\>\<C-n>", 'n')
  endif
endfunction

function! s:eval_edit(is_insert) abort
  if !('t:deol'->exists())
    return
  endif

  if s:eval_commands(deol#get_cmdline(), a:is_insert)
    call s:auto_cd(a:is_insert)
    return
  endif

  call s:auto_cd(a:is_insert)

  if a:is_insert
    call append('$'->line(), '')
    call cursor(['$'->line(), 0])
    call s:start_insert_term()
  endif
endfunction

function! s:eval_commands(cmdline, is_insert) abort
  let deol = t:deol

  const ex_command = a:cmdline->matchstr('^:\zs.*')
  if ex_command !=# ''
    " Execute as Ex command

    if &l:filetype ==# 'deol'
      call deol.jobsend(s:cleanup())
    endif

    execute ex_command
    if a:is_insert && s:is_deol_edit_buffer()
      call append('$'->line(), '')
      call cursor(['$'->line(), 0])
      call s:start_insert_term()
    endif
    return v:true
  endif

  const path = a:cmdline->matchstr('^vim\s\+\zs\%(\S\|\\\s\)\+')
  if path !=# ''
    " file edit by Vim

    if &l:filetype ==# 'deol'
      call deol.jobsend(s:cleanup())
    endif

    call deol#quit()
    execute 'edit' path->fnameescape()
    return v:true
  endif

  " If the current line is the last line, deol must send <CR> only
  const cmdline = (&l:filetype ==# 'deol'
        \ && ('.'->line() == '$'->line() || mode() ==# 't')) ?
        \ '' : s:cleanup() .. a:cmdline
  call deol.jobsend(cmdline .. "\<CR>")

  " Note: Needs wait to proceed messages
  sleep 100m
  call s:term_redraw(deol.bufnr)

  return v:false
endfunction

function! s:deol_backspace() abort
  if '.'->getline() ==# '' && t:deol.options.toggle
    stopinsert
    call deol#quit()
  elseif deol#get_input() ==# ''
  elseif mode() ==# 'n'
    normal! x
  elseif mode() ==# 'i'
    normal! x
    call cursor([0, '.'->col() + 1])
  endif
endfunction

function! s:eval_deol(is_insert) abort
  if g:deol#prompt_pattern ==# '' || !('t:deol'->exists())
    return
  endif

  if '.'->getline() =~# g:deol#prompt_pattern
    if s:eval_commands(deol#get_cmdline(), a:is_insert)
      return
    endif
  else
    call t:deol.jobsend("\<CR>")
  endif

  " NOTE: t:deol may be not found.
  if !('t:deol'->exists())
    return
  endif

  call s:auto_cd(a:is_insert)

  if a:is_insert
    call s:start_insert_term()
  else
    call s:insert_mode(t:deol)
  endif
endfunction

function! s:search_prompt(flag) abort
  if g:deol#prompt_pattern ==# ''
    return
  endif

  const col = '.'->col()
  call cursor(0, 1)
  const pattern = '^\%(' .. g:deol#prompt_pattern .. '\m\).\?'
  const pos = pattern->searchpos(a:flag)
  if pos[0] != 0
    call cursor(pos[0], pos[0]->getline()->matchend(pattern))
  else
    call cursor(0, col)
  endif
endfunction

function! s:paste_prompt() abort
  if g:deol#prompt_pattern ==# '' || !('t:deol'->exists())
    return
  endif

  call t:deol.jobsend(s:cleanup() .. deol#get_cmdline())
  call s:insert_mode(t:deol)
endfunction

function! s:bg() abort
  if !('t:deol'->exists())
    return
  endif

  const options = t:deol.options
  unlet t:deol
  call deol#_start(options)
endfunction

function! s:split(options) abort
  if a:options.split ==# ''
    return
  endif

  if a:options.split ==# 'floating' && '*nvim_open_win'->exists()
    call nvim_open_win(bufnr('%'), v:true, #{
          \   relative: 'editor',
          \   row: a:options.winrow->str2nr(),
          \   col: a:options.wincol->str2nr(),
          \   width: a:options.winwidth->str2nr(),
          \   height: a:options.winheight->str2nr(),
          \   border: g:deol#floating_border,
          \ })
  elseif a:options.split ==# 'vertical'
    vsplit
    execute 'vertical resize' a:options.winwidth->str2nr()
  elseif a:options.split ==# 'farleft'
    vsplit
    wincmd H
    execute 'vertical resize' a:options.winwidth->str2nr()
  elseif a:options.split ==# 'farright'
    vsplit
    wincmd L
    execute 'vertical resize' a:options.winwidth->str2nr()
  else
    split
    execute 'resize' a:options.winheight->str2nr()
  endif

  " Open dummy buffer
  enew
endfunction


function! s:insert_mode(deol) abort
  if a:deol.options.start_insert
    startinsert
  else
    call s:stop_insert_term()
  endif
endfunction

function! s:start_insert(mode) abort
  const prompt = deol#get_prompt()
  if prompt ==# ''
    return a:mode
  endif

  const cmdline_len = deol#get_cmdline()->len()
  return 'i' .. repeat("\<Right>", cmdline_len)
        \ .. repeat("\<Left>", cmdline_len - deol#get_input()->len()
        \ + (a:mode ==# 'i' ? 1 : 0))
endfunction

function! deol#get_prompt() abort
  if &filetype !=# 'deol'
    return ''
  endif

  const pattern = '^\%(' .. g:deol#prompt_pattern .. '\m\)'
  return s:get_text(mode())->matchstr(pattern)
endfunction

function! s:get_text(mode) abort
  return a:mode ==# 'c'
        \ ? getcmdline()
        \ : a:mode ==# 't' && !has('nvim')
        \ ? term_getline('', '.')
        \ : '.'->getline()
endfunction
function! deol#get_input() abort
  const mode = mode()
  const col = mode ==# 't' && !has('nvim') ?
        \ term_getcursor(bufnr('%'))[1] : col('.')
  const input = s:get_text(mode)->matchstr('^.*\%' .
        \ ((mode ==# 'i' || mode ==# 't') ? col : col + 1) .. 'c')
  return input[deol#get_prompt()->len():]
endfunction

function! s:user_options() abort
  return #{
        \   auto_cd: v:true,
        \   command: [],
        \   cwd: '',
        \   edit: v:false,
        \   edit_filetype: '',
        \   edit_winheight: 1,
        \   split: '',
        \   start_insert: v:true,
        \   toggle: v:false,
        \   wincol: &columns / 4,
        \   winheight: 15,
        \   winrow: &lines / 3,
        \   winwidth: 80,
        \ }
endfunction

function! s:parse_options(cmdline) abort
  let options = s:user_options()

  for arg in a:cmdline->split('\%(\\\@<!\s\)\+')
    let arg = arg->substitute('\\\( \)', '\1', 'g')
    let arg_key = arg->substitute('=\zs.*$', '', '')

    let name = arg_key->tr('-', '_')->substitute('=$', '', '')[1:]
    if name =~# '^no_'
      let name = name[3:]
      let value = 0
    else
      let value = (arg_key =~# '=$') ? arg[arg_key->len() :] : 1
    endif

    if s:user_options()->keys()->index(name) >= 0
      let options[name] = value
    else
      call add(options.command, arg)
    endif
  endfor

  if options.command->empty()
    let options.command = [&shell]
  endif

  return options
endfunction

function! deol#_get_histories() abort
  const history_path = s:expand(g:deol#shell_history_path)
  if !(history_path->filereadable())
    return []
  endif

  let histories = history_path->readfile()
  if g:deol#shell_history_max > 0 &&
      \ histories->len() > g:deol#shell_history_max
      let histories = histories[-g:deol#shell_history_max :]
  endif
  return map(histories,
        \ { _, val -> val->substitute(
        \  '^\%(\d\+/\)\+[:[:digit:]; ]\+\|^[:[:digit:]; ]\+', '', '')
        \ })
endfunction

function! deol#_complete(arglead, cmdline, cursorpos) abort
  let _ = []

  " Option names completion.
  const bool_options = s:user_options()->copy()
        \ ->filter({ _, val -> type(val) == v:t_bool })->keys()
  let _ += bool_options->copy()->map({ _, val -> '-' .. tr(val, '_', '-') })
  const string_options = s:user_options()->copy()
        \ ->filter({ _, val -> type(val) != v:t_bool })->keys()
  let _ += string_options->copy()
        \ ->map({ _, val -> '-' .. tr(val, '_', '-') .. '=' })

  " Add "-no-" option names completion.
  let _ += bool_options->copy()->map({ _, val -> '-no-' .. tr(val, '_', '-') })

  let _ += a:arglead->getcompletion('shellcmd')

  return _->filter({ key, val -> stridx(val, a:arglead) == 0 })->sort()->uniq()
endfunction

function! s:cleanup() abort
  return has('win32') ? '' : "\<C-u>"
endfunction

function! deol#abbrev(check, lhs, rhs) abort
  return '.'->getline() ==# a:check && v:char ==# ' ' ? a:rhs : a:lhs
endfunction

function! s:check_buffer(bufnr) abort
  return a:bufnr->buflisted()
        \ && a:bufnr !=# t:deol.edit_bufnr
        \ && a:bufnr !=# t:deol.bufnr
endfunction

function! s:is_deol_edit_buffer() abort
  return '%'->bufname() =~# '^deol-edit@'
endfunction

function! s:row() abort
  return (!has('nvim') && mode() ==# 't') ?
        \ term_getcursor('%'->bufnr())[0] : '.'->line()
endfunction

function! s:expand(path) abort
  return s:substitute_path_separator(
        \ (a:path =~# '^\~') ? a:path->fnamemodify(':p') :
        \ (a:path =~# '^\$') ? a:path->expand() :
        \ a:path)
endfunction
function! s:substitute_path_separator(path) abort
  return s:is_windows ? a:path->substitute('\\', '/', 'g') : a:path
endfunction

function! deol#_get(tabnr) abort
  const deol = a:tabnr->gettabvar('deol', v:null)
  if deol is v:null
    return deol
  endif

  return #{
        \   cwd: deol.cwd,
        \   options: deol.options,
        \ }
endfunction

function! s:auto_cd(is_insert) abort
  if !('t:deol'->exists()) || !t:deol.options.auto_cd
    return
  endif

  const cwd = printf('/proc/%d/cwd', t:deol.pid)
  if cwd->isdirectory()
    " Use directory tracking
    const directory = cwd->resolve()
  else
    const directory = s:expand(
          \ deol#get_cmdline()->matchstr('\W\%(cd\s\+\)\?\zs\%(\S\|\\\s\)\+'))
  endif

  if directory->isdirectory() && getcwd() !=# directory
    call s:cd(directory)

    let t:deol.cwd = directory

    " NOTE: Need to back normal mode to update the title string
    if has('nvim') && a:is_insert
      call feedkeys("\<C-\>\<C-n>i", 'n')
    endif
  endif
endfunction

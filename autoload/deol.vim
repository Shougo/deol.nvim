"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let s:is_windows = has('win32') || has('win64')
let s:default_password_pattern =
        \   '\%(Enter \|Repeat \|[Oo]ld \|[Nn]ew \|login ' .
        \   '\|Kerberos \|EncFS \|CVS \|UNIX \| SMB \|LDAP \|\[sudo] ' .
        \   '\|^\|\n\|''s \)\%([Pp]assword\|[Pp]assphrase\)\>'

let g:deol#_prev_deol = -1
let g:deol#enable_dir_changed = get(g:, 'deol#enable_dir_changed', 1)
let g:deol#prompt_pattern = get(g:, 'deol#prompt_pattern', '')
let g:deol#password_pattern = get(g:, 'deol#password_pattern',
      \ s:default_password_pattern)
let g:deol#shell_history_path = get(g:, 'deol#shell_history_path', '')
let g:deol#shell_history_max = get(g:, 'deol#shell_history_max', 500)

let s:default_term_options = {
      \ 'curwin': v:true,
      \ 'exit_cb': { job, status -> execute('unlet! t:deol') },
      \ }
let g:deol#_term_options = extend(s:default_term_options,
      \ get(g:, 'deol#extra_options', {}))
let s:default_maps = {
      \ 'bg': '<C-z>',
      \ 'edit': 'e',
      \ 'execute_line': '<CR>',
      \ 'next_prompt': '<C-n>',
      \ 'paste_prompt': '<C-y>',
      \ 'previous_prompt': '<C-p>',
      \ 'quit': 'q',
      \ 'start_append': 'a',
      \ 'start_append_last': 'A',
      \ 'start_insert': 'i',
      \ 'start_insert_first': 'I',
      \ }
let g:deol#_maps = extend(s:default_maps, get(g:, 'deol#custom_map', {}))

augroup deol
  autocmd!
augroup END

function! deol#start(cmdline) abort
  return deol#_start(s:parse_options(a:cmdline))
endfunction

function! deol#_start(options) abort
  let options = copy(a:options)

  if exists('t:deol') && bufexists(t:deol.bufnr)
    let ids = win_findbuf(t:deol.bufnr)
    if !empty(ids) && options.toggle
      call deol#quit()
    else
      call s:switch(options)
    endif

    return
  endif

  if options.cwd ==# ''
    let options.cwd = getcwd()
  endif

  let cwd = s:expand(options.cwd)
  if !isdirectory(cwd)
    redraw
    let result = confirm(printf('[deol] %s is not directory.  Create?', cwd),
          \ "&Yes\n&No\n&Cancel")
    if result != 1
      return
    endif

    call mkdir(cwd, 'p')
  endif

  call s:split(options)

  let t:deol = deol#_new(cwd, options)
  let t:deol.prev_bufnr = bufnr('%')
  call t:deol.init_deol_buffer()

  if !has('nvim')
    " Vim8 takes initialization...
    sleep 150m
  endif
  call s:insert_mode(t:deol)

  if options.edit
    call deol#edit()
  endif
endfunction

function! s:switch(options) abort
  let options = copy(a:options)
  let deol = t:deol
  let deol.prev_bufnr = bufnr('%')

  let ids = win_findbuf(deol.bufnr)
  if empty(ids)
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
  let options = extend(s:user_options(), copy(a:options))
  if get(options, 'cwd', '') ==# ''
    let options.cwd = input('Current directory: ', getcwd(), 'dir')
  endif

  if options.cwd ==# ''
    return
  endif
  let cwd = s:expand(options.cwd)
  if !isdirectory(cwd)
    redraw
    let result = confirm(printf('[deol] %s is not directory.  Create?', cwd),
          \ "&Yes\n&No\n&Cancel")
    if result != 1
      return
    endif

    call mkdir(cwd, 'p')
  endif

  tabnew
  return deol#_start(options)
endfunction

function! deol#send(string) abort
  if !exists('t:deol')
    return ''
  endif

  call t:deol.jobsend(s:cleanup() . a:string . "\<CR>")
  return ''
endfunction

function! deol#cd(directory) abort
  if !exists('t:deol') || bufwinnr(t:deol.bufnr) < 0
    return
  endif

  call t:deol.cd(a:directory)

  " Needs redraw for Vim8
  if !has('nvim')
    call s:term_redraw(t:deol.bufnr)
  endif
endfunction

function! deol#edit() abort
  if !exists('t:deol')
    Deol
  endif

  let ids = win_findbuf(t:deol.bufnr)
  if !empty(ids) && win_getid() != ids[0]
    call win_gotoid(ids[0])
    call cursor(line('$'), 0)
  endif

  call t:deol.switch_edit_buffer()

  call t:deol.init_edit_buffer()

  " Set the current command line
  let buflines = filter(getbufline(t:deol.bufnr, 1, '$'),
        \ { _, val -> val !=# '' })
  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  if !empty(buflines) && buflines[-1] =~# pattern
    let cmdline = substitute(buflines[-1], pattern, '', '')
    if getline('$') ==# ''
      call setline('$', cmdline)
    else
      call append('$', cmdline)
    endif
  endif

  call cursor(line('$'), 0)
  startinsert!
endfunction

function! deol#kill_editor() abort
  bdelete
  call win_gotoid(g:deol#_prev_deol)
endfunction

function! deol#get_cmdline() abort
  if &l:filetype !=# 'deol'
    return getline('.')
  endif

  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  return substitute(getline('.'), pattern, '', '')
endfunction

function! deol#_new(cwd, options) abort
  let deol = copy(s:deol)
  let deol.command = a:options.command
  let deol.edit_winid = -1
  let deol.edit_bufnr = -1
  let deol.edit_filetype = a:options.edit_filetype
  let deol.options = a:options
  call deol.cd(a:cwd)

  " Set $EDITOR.
  let editor_command = ''
  if exists('g:edita_loaded')
    " Use edita instead
    let editor_command = edita#EDITOR()
  elseif v:progname ==# 'nvim' && executable('nvr')
    " Use neovim-remote for neovim
    let editor_command = 'nvr --remote-tab-wait-silent'
  elseif executable(v:progpath) && has('clientserver')
    " Use clientserver for Vim8
    let editor_command =
          \ printf('%s %s --remote-tab-wait-silent',
          \   v:progpath,
          \   (v:servername ==# '' ? '' : ' --servername='.v:servername))
  elseif executable(v:progpath)
    let editor_command = v:progpath
  endif

  if editor_command !=# ''
    let $EDITOR = editor_command
    let $GIT_EDITOR = editor_command
  endif

  return deol
endfunction

function! deol#quit() abort
  if exists('t:deol')
    if bufwinnr(t:deol.edit_bufnr) > 0
      " Close edit buffer in the first
      execute bufwinnr(t:deol.edit_bufnr) 'wincmd w'
      close!
    endif

    let deolwin = bufwinnr(t:deol.bufnr)
    if deolwin < 0
      return
    endif

    execute deolwin 'wincmd w'
  endif

  if winnr('$') == 1
    " Move to alternate buffer
    if exists('t:deol') && s:check_buffer(t:deol.prev_bufnr)
      execute 'buffer' t:deol.prev_bufnr
    elseif exists('t:deol') && s:check_buffer(bufnr('#'))
      buffer #
    else
      enew
    endif
  else
    close!
  endif
endfunction

function! s:cd(directory) abort
  execute (exists(':tchdir') ? 'tchdir' : 'lcd') fnameescape(a:directory)
endfunction

let s:deol = {}

function! s:deol.cd(directory) abort
  let directory = fnamemodify(a:directory, ':p')
  if (has_key(self, 'cwd') && self.cwd ==# directory)
        \ || !isdirectory(directory)
    return
  endif

  let self.cwd = directory
  call s:cd(self.cwd)
  call self.jobsend(s:cleanup() . 'cd ' . fnameescape(self.cwd) . "\<CR>")
endfunction

function! s:deol.init_deol_buffer() abort
  if has('nvim')
    execute 'terminal' self.command
    let self.jobid = b:terminal_job_id
    let self.pid = b:terminal_job_pid
  else
    call term_start(self.command, extend(g:deol#_term_options,
          \ get(b:, 'deol_extra_options', {})))
    let self.pid = job_info(term_getjob(bufnr('%'))).process
  endif

  let self.bufnr = bufnr('%')
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
        \ 'i' . repeat("\<Left>", len(getline('.')))
  nnoremap <buffer><expr> <Plug>(deol_start_append)
        \ <SID>start_insert('A')
  nnoremap <buffer><expr> <Plug>(deol_start_append_last)
        \ 'i' . repeat("\<Right>", len(getline('.')))
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

  for [rhs, lhs] in items(g:deol#_maps)
    execute 'nmap <buffer> ' . lhs . ' <Plug>(deol_' . rhs . ')'
  endfor

  " set filetype twice to load after/ftplugin in Vim8
  setlocal filetype=deol
  setlocal filetype=deol

  if exists('##DirChanged') && self.options.dir_changed
    if has('nvim')
      autocmd deol DirChanged <buffer>
            \ call deol#cd(v:event.cwd)
    else
      " Note: Use <afile> does not work...
      autocmd deol DirChanged <buffer>
            \ call deol#cd(getcwd())
    endif
  endif

  if exists('##TermClose')
    autocmd deol TermClose <buffer> unlet! t:deol
  endif
  autocmd deol InsertEnter <buffer> call <SID>set_prev_deol(t:deol)
endfunction

function! s:deol.switch_edit_buffer() abort
  if win_findbuf(self.edit_bufnr) == [self.edit_winid]
    call win_gotoid(self.edit_winid)
    return
  endif

  let cwd = getcwd()

  let edit_bufname = 'deol-edit@' . bufname(t:deol.bufnr)
  if self.options.split ==# 'floating' && exists('*nvim_open_win')
    call nvim_open_win(bufnr('%'), v:true, {
          \ 'relative': 'editor',
          \ 'row': str2nr(self.options.winrow + winheight(0)),
          \ 'col': str2nr(self.options.wincol),
          \ 'width': winwidth(0),
          \ 'height': 1,
          \ })
    if exists('*bufadd')
      let bufnr = bufadd(edit_bufname)
      execute bufnr 'buffer'
    else
      execute 'edit' fnameescape(edit_bufname)
    endif
  else
    execute 'split' fnameescape(edit_bufname)
  endif

  if line('$') == 1
    call append(0, deol#_get_histories())
  endif

  call s:cd(cwd)

  let self.edit_winid = win_getid()
  let self.edit_bufnr = bufnr('%')
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
  let command = fnamemodify(self.command, ':t:r')
  let filetype = self.edit_filetype
  let default_filetype = {
        \ 'ash': 'sh',
        \ 'bash': 'bash',
        \ 'fish': 'fish',
        \ 'ksh': 'sh',
        \ 'sh': 'sh',
        \ 'xonsh': 'python',
        \ 'zsh': 'zsh',
        \ }
  if filetype ==# '' && has_key(default_filetype, command)
    let filetype = default_filetype[command]
  endif

  let self.bufedit = bufnr('%')

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
        \ deol#send("\<C-c>") . "\<ESC>a"
  inoremap <buffer><expr> <Plug>(deol_ctrl_d)
        \ deol#send("\<C-d>") . "\<ESC>a"

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

  if exists('##DirChanged') && g:deol#enable_dir_changed
    if has('nvim')
      autocmd deol DirChanged <buffer>
            \ call deol#cd(v:event.cwd)
    else
      " Note: Use <afile> does not work...
      autocmd deol DirChanged <buffer>
            \ call deol#cd(getcwd())
    endif
  endif
endfunction

function! s:deol.jobsend(keys) abort
  if !has_key(self, 'bufnr')
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
  let ids = win_findbuf(a:deol.bufnr)
  if !empty(ids)
    let g:deol#_prev_deol = ids[0]
  endif
endfunction

function! s:term_redraw(bufnr) abort
  if has('nvim')
    redraw
    return
  endif

  " Note: In Vim8, auto redraw does not work!

  let ids = win_findbuf(a:bufnr)
  if empty(ids)
    return
  endif

  let prev_mode = mode()
  let prev_winid = win_getid()
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
  if !exists('t:deol')
    return
  endif

  if s:eval_commands(deol#get_cmdline(), a:is_insert)
    return
  endif

  if a:is_insert
    call append(line('$'), '')
    call cursor([line('$'), 0])
    call s:start_insert_term()
  endif
endfunction

function! s:eval_commands(cmdline, is_insert) abort
  let deol = t:deol

  let ex_command = matchstr(a:cmdline, '^:\zs.*')
  if ex_command !=# ''
    " Execute as Ex command

    if &l:filetype ==# 'deol'
      call deol.jobsend(s:cleanup())
    endif

    execute ex_command
    if a:is_insert && s:is_deol_edit_buffer()
      call append(line('$'), '')
      call cursor([line('$'), 0])
      call s:start_insert_term()
    endif
    return v:true
  endif

  let path = matchstr(a:cmdline, '^vim\s\+\zs\%(\S\|\\\s\)\+')
  if path !=# ''
    " file edit by Vim

    if &l:filetype ==# 'deol'
      call deol.jobsend(s:cleanup())
    endif

    call deol#quit()
    execute 'edit' fnameescape(path)
    return v:true
  endif

  " If the current line is the last line, deol must send <CR> only
  let cmdline = (&l:filetype ==# 'deol' &&
        \ (line('.') == line('$') || mode() ==# 't')) ?
        \ '' : s:cleanup() . a:cmdline
  call deol.jobsend(cmdline . "\<CR>")

  " Note: Needs wait to proceed messages
  sleep 100m
  call s:term_redraw(deol.bufnr)

  " Password check
  call s:check_password()

  if deol.options.auto_cd
    let cwd = printf('/proc/%d/cwd', deol.pid)
    if isdirectory(cwd)
      " Use directory tracking
      let directory = resolve(cwd)
    else
      let directory = s:expand(matchstr(
            \ a:cmdline, '^\%(cd\s\+\)\?\zs\%(\S\|\\\s\)\+'))
    endif

    if isdirectory(directory) && getcwd() !=# directory
      noautocmd call s:cd(directory)
    endif
  endif

  return v:false
endfunction

function! s:check_password() abort
  if !exists('t:deol')
    return
  endif

  while 1
    " Get the last non empty line
    let lines = filter(getbufline(t:deol.bufnr, 1, '$'),
          \ { _, val -> val !=# '' })
    if empty(lines) || lines[-1] !~? g:deol#password_pattern
      break
    endif

    " Password input.
    set imsearch=0
    " Note: call inputsave() to clear input queue.
    call inputsave()
    redraw | echo ''
    let secret = inputsecret('Input Secret : ')
    redraw | echo ''
    if secret ==# ''
      break
    endif

    call t:deol.jobsend(secret . "\<CR>")

    " Note: Needs wait to proceed messages
    sleep 3000m

    call s:term_redraw(t:deol.bufnr)
  endwhile
endfunction

function! s:deol_backspace() abort
  if getline('.') ==# '' && t:deol.options.toggle
    stopinsert
    call deol#quit()
  elseif s:get_input() ==# ''
  elseif mode() ==# 'n'
    normal! x
  elseif mode() ==# 'i'
    normal! x
    call cursor([0, col('.') + 1])
  endif
endfunction

function! s:eval_deol(is_insert) abort
  if g:deol#prompt_pattern ==# '' || !exists('t:deol')
    return
  endif

  if getline('.') =~# g:deol#prompt_pattern
    if s:eval_commands(deol#get_cmdline(), a:is_insert)
      return
    endif
  else
    call t:deol.jobsend("\<CR>")
  endif

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

  let col = col('.')
  call cursor(0, 1)
  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\).\?'
  let pos = searchpos(pattern, a:flag)
  if pos[0] != 0
    call cursor(pos[0], matchend(getline(pos[0]), pattern))
  else
    call cursor(0, col)
  endif
endfunction

function! s:paste_prompt() abort
  if g:deol#prompt_pattern ==# '' || !exists('t:deol')
    return
  endif

  let cmdline = deol#get_cmdline()
  call t:deol.jobsend(s:cleanup() . cmdline)
  call s:insert_mode(t:deol)
endfunction

function! s:bg() abort
  if !exists('t:deol')
    return
  endif

  let options = t:deol.options
  unlet t:deol
  call deol#_start(options)
endfunction

function! s:split(options) abort
  if a:options.split ==# ''
    return
  endif

  if a:options.split ==# 'floating' && exists('*nvim_open_win')
    call nvim_open_win(bufnr('%'), v:true, {
          \ 'relative': 'editor',
          \ 'row': str2nr(a:options.winrow),
          \ 'col': str2nr(a:options.wincol),
          \ 'width': str2nr(a:options.winwidth),
          \ 'height': str2nr(a:options.winheight),
          \ })
  elseif a:options.split ==# 'vertical'
    vsplit
    execute 'vertical resize' str2nr(a:options.winwidth)
  elseif a:options.split ==# 'farleft'
    vsplit
    wincmd H
    execute 'vertical resize' str2nr(a:options.winwidth)
  elseif a:options.split ==# 'farright'
    vsplit
    wincmd L
    execute 'vertical resize' str2nr(a:options.winwidth)
  else
    split
    execute 'resize' str2nr(a:options.winheight)
  endif
endfunction


function! s:insert_mode(deol) abort
  if a:deol.options.start_insert
    startinsert
  else
    call s:stop_insert_term()
  endif
endfunction

function! s:start_insert(mode) abort
  let prompt = s:get_prompt()
  if prompt ==# ''
    return a:mode
  endif

  return 'i' . repeat("\<Right>", len(deol#get_cmdline()))
        \ . repeat("\<Left>", len(deol#get_cmdline()) - len(s:get_input())
        \ + (a:mode ==# 'i' ? 1 : 0))
endfunction

function! s:get_prompt() abort
  if &filetype !=# 'deol'
    return ''
  endif

  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  return matchstr(getline('.'), pattern)
endfunction

function! s:get_input() abort
  let input = matchstr(getline('.'), '^.*\%' .
        \ (mode() ==# 'i' ? col('.') : col('.') + 1) . 'c')
  return input[len(s:get_prompt()):]
endfunction

function! s:user_options() abort
  return {
        \ 'auto_cd': v:true,
        \ 'command': &shell,
        \ 'cwd': '',
        \ 'dir_changed': v:true,
        \ 'edit': v:false,
        \ 'edit_filetype': '',
        \ 'edit_winheight': 1,
        \ 'split': '',
        \ 'start_insert': v:true,
        \ 'toggle': v:false,
        \ 'wincol': &columns / 4,
        \ 'winheight': 15,
        \ 'winrow': &lines / 3,
        \ 'winwidth': 80,
        \ }
endfunction

function! s:parse_options(cmdline) abort
  let options = s:user_options()

  for arg in split(a:cmdline, '\%(\\\@<!\s\)\+')
    let arg = substitute(arg, '\\\( \)', '\1', 'g')
    let arg_key = substitute(arg, '=\zs.*$', '', '')

    let name = substitute(tr(arg_key, '-', '_'), '=$', '', '')[1:]
    if name =~# '^no_'
      let name = name[3:]
      let value = 0
    else
      let value = (arg_key =~# '=$') ? arg[len(arg_key) :] : 1
    endif

    if index(keys(s:user_options()), name) >= 0
      let options[name] = value
    else
      let options['command'] = arg
    endif
  endfor

  return options
endfunction

function! deol#_get_histories() abort
  let history_path = s:expand(g:deol#shell_history_path)
  if !filereadable(history_path)
    return []
  endif

  let histories = readfile(history_path)
  if g:deol#shell_history_max > 0 &&
      \ len(histories) > g:deol#shell_history_max
      let histories = histories[-g:deol#shell_history_max :]
  endif
  return map(histories,
        \ { _, val -> substitute(
        \  val, '^\%(\d\+/\)\+[:[:digit:]; ]\+\|^[:[:digit:]; ]\+', '', '')
        \ })
endfunction

function! deol#_complete(arglead, cmdline, cursorpos) abort
  let _ = []

  " Option names completion.
  let bool_options = keys(filter(copy(s:user_options()),
        \ { _, val -> type(val) == v:t_bool }))
  let _ += map(copy(bool_options), { _, val -> '-' . tr(val, '_', '-') })
  let string_options = keys(filter(copy(s:user_options()),
        \ { _, val -> type(val) != v:t_bool }))
  let _ += map(copy(string_options),
        \ { _, val -> '-' . tr(val, '_', '-') . '=' })

  " Add "-no-" option names completion.
  let _ += map(copy(bool_options), { _, val -> '-no-' . tr(val, '_', '-') })

  if exists('*getcompletion')
    let _ += getcompletion(a:arglead, 'shellcmd')
  endif

  return uniq(sort(filter(_, { key, val -> stridx(val, a:arglead) == 0 })))
endfunction

function! s:cleanup() abort
  return has('win32') ? '' : "\<C-u>"
endfunction

function! deol#abbrev(check, lhs, rhs) abort
  return getline('.') ==# a:check && v:char ==# ' ' ? a:rhs : a:lhs
endfunction

function! s:check_buffer(bufnr) abort
  return buflisted(a:bufnr)
        \ && a:bufnr !=# t:deol.edit_bufnr
        \ && a:bufnr !=# t:deol.bufnr
endfunction

function! s:is_deol_edit_buffer() abort
  return bufname('%') =~# '^deol-edit@'
endfunction

function! s:expand(path) abort
  return s:substitute_path_separator(
        \ (a:path =~# '^\~') ? fnamemodify(a:path, ':p') :
        \ (a:path =~# '^\$') ? expand(a:path) :
        \ a:path)
endfunction
function! s:substitute_path_separator(path) abort
  return s:is_windows ? substitute(a:path, '\\', '/', 'g') : a:path
endfunction

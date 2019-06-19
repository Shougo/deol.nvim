"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let g:deol#_prev_deol = -1
let g:deol#enable_dir_changed = get(g:, 'deol#enable_dir_changed', 1)
let g:deol#prompt_pattern = get(g:, 'deol#prompt_pattern', '')
let g:deol#shell_history_path = get(g:, 'deol#shell_history_path', '')
let g:deol#shell_history_max = get(g:, 'deol#shell_history_max', 500)

augroup deol
  autocmd!
augroup END

function! deol#start(cmdline) abort
  return deol#_start(s:parse_options(a:cmdline))
endfunction

function! deol#_start(options) abort
  let options = copy(a:options)

  if exists('t:deol') && bufexists(t:deol.bufnr)
    call s:switch(options)
    return
  endif

  if options.cwd == ''
    let options.cwd = getcwd()
  endif

  let cwd = expand(options.cwd)
  if !isdirectory(cwd)
    echomsg '[deol] ' . cwd . ' is not directory'
    return
  endif

  call s:split(options)

  let t:deol = deol#_new(cwd, options)
  call t:deol.init_deol_buffer()

  call s:insert_mode(t:deol)

  if options.edit
    call deol#edit()
  endif
endfunction

function! s:switch(options) abort
  let options = copy(a:options)
  let deol = t:deol

  let id = win_findbuf(deol.bufnr)
  if empty(id)
    call s:split(options)
    execute 'buffer' deol.bufnr
  else
    call win_gotoid(id[0])
  endif

  let g:deol#_prev_deol = win_getid()

  if options.cwd != ''
    call deol.cd(options.cwd)
  else
    call s:cd(deol.cwd)
  endif

  call s:insert_mode(deol)

  if options.edit
    call deol#edit()
  endif
endfunction

function! deol#new(options) abort
  let options = extend(s:user_options(), copy(a:options))
  if get(options, 'cwd', '') == ''
    let options.cwd = input('Current directory: ', getcwd(), 'dir')
  endif

  if options.cwd == ''
    return
  endif

  tabnew
  return deol#_start(options)
endfunction

function! deol#send(string) abort
  if !exists('t:deol')
    return
  endif

  call t:deol.jobsend("\<C-u>" . a:string . "\<CR>")
endfunction

function! deol#cd(directory) abort
  if exists('t:deol') && bufwinnr(t:deol.bufnr) > 0
    call t:deol.cd(a:directory)
  endif
endfunction

function! deol#edit() abort
  if !exists('t:deol')
    Deol
  endif

  let id = win_findbuf(t:deol.bufnr)
  if !empty(id) && win_getid() != id[0]
    call win_gotoid(id[0])
    call cursor(line('$'), 0)
  endif

  call t:deol.switch_edit_buffer()

  call t:deol.init_edit_buffer()

  " Set the current command line
  let buflines = filter(getbufline(t:deol.bufnr, 1, '$'), "v:val != ''")
  if !empty(buflines)
    let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
    let cmdline = substitute(buflines[-1], pattern, '', '')
    if getline('$') == ''
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
  if executable('nvr')
    let editor_command = 'nvr --remote-tab-wait-silent'
  elseif executable('gvim')
    let editor_command =
          \ printf('gvim %s --remote-tab-wait-silent',
          \   (v:servername == '' ? '' : ' --servername='.v:servername))
  endif
  if editor_command != ''
    let $EDITOR = editor_command
    let $GIT_EDITOR = editor_command
  endif

  return deol
endfunction

function! s:cd(directory) abort
  execute (exists(':tchdir') ? 'tchdir' : 'lcd') fnameescape(a:directory)
endfunction

let s:deol = {}

function! s:deol.cd(directory) abort
  let directory = fnamemodify(a:directory, ':p')
  if has_key(self, 'cwd') && self.cwd ==# directory
    return
  endif

  let self.cwd = directory
  call s:cd(self.cwd)
  call self.jobsend("\<C-u>cd " . fnameescape(self.cwd) . "\<CR>")
endfunction

function! s:deol.init_deol_buffer() abort
  if has('nvim')
    execute 'terminal' self.command
    let self.jobid = b:terminal_job_id
  else
    call term_start(self.command, {'curwin': v:true})
  endif

  let self.bufnr = bufnr('%')
  let g:deol#_prev_deol = win_getid()

  nnoremap <buffer><silent> <Plug>(deol_execute_line)
        \ :<C-u>call <SID>execute_line()<CR>
  nnoremap <buffer><silent> <Plug>(deol_bg)
        \ :<C-u>call <SID>bg()<CR>
  nnoremap <buffer><silent> <Plug>(deol_previous_prompt)
        \ :<C-u>call <SID>search_prompt('bWn')<CR>
  nnoremap <buffer><silent> <Plug>(deol_next_prompt)
        \ :<C-u>call <SID>search_prompt('Wn')<CR>
  nnoremap <buffer><silent> <Plug>(deol_paste_prompt)
        \ :<C-u>call <SID>paste_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(deol_edit)
        \ :<C-u>call deol#edit()<CR>
  nnoremap <buffer><expr> <Plug>(deol_start_insert)
        \ <SID>start_insert('i')
  nnoremap <buffer><expr> <Plug>(deol_start_insert_first)
        \ 'i' . repeat("\<Left>", len(getline('.')))
  nnoremap <buffer><expr> <Plug>(deol_start_append)
        \ <SID>start_insert('A')
  nnoremap <buffer><expr> <Plug>(deol_start_append_last)
        \ 'i' . repeat("\<Right>", len(getline('.')))
  nnoremap <buffer><expr><silent> <Plug>(deol_quit)
        \ winnr('$') == 1 ? ":\<C-u>buffer #\<CR>" : ":\<C-u>close!\<CR>"

  nmap <buffer> e     <Plug>(deol_edit)
  nmap <buffer> i     <Plug>(deol_start_insert)
  nmap <buffer> I     <Plug>(deol_start_insert_first)
  nmap <buffer> a     <Plug>(deol_start_append)
  nmap <buffer> A     <Plug>(deol_start_append_last)
  nmap <buffer> <CR>  <Plug>(deol_execute_line)
  nmap <buffer> <C-p> <Plug>(deol_previous_prompt)
  nmap <buffer> <C-n> <Plug>(deol_next_prompt)
  nmap <buffer> <C-y> <Plug>(deol_paste_prompt)
  nmap <buffer> <C-z> <Plug>(deol_bg)
  nmap <buffer> q     <Plug>(deol_quit)

  setlocal bufhidden=hide
  setlocal nolist
  setlocal nowrap
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal colorcolumn=
  setlocal nonumber
  setlocal norelativenumber

  setlocal filetype=deol

  if exists('##DirChanged') && g:deol#enable_dir_changed
    if has('nvim')
      autocmd deol DirChanged <buffer>
            \ call deol#cd(v:event.cwd)
    else
      autocmd deol DirChanged <buffer>
            \ call deol#cd(fnamemodify(expand('<afile>'), ':p'))
    endif
  endif
endfunction

function! s:deol.switch_edit_buffer() abort
  if win_findbuf(self.edit_bufnr) == [self.edit_winid]
    call win_gotoid(self.edit_winid)
    return
  endif

  if self.options.split == 'floating' && exists('*nvim_open_win')
    call nvim_open_win(bufnr('%'), v:true, {
          \ 'relative': 'editor',
          \ 'row': str2nr(self.options.winrow + winheight(0)),
          \ 'col': str2nr(self.options.wincol),
          \ 'width': winwidth(0),
          \ 'height': 1,
          \ })
    edit deol-edit
  else
    split deol-edit
  endif

  if line('$') == 1
    call append(0, s:get_histories())
  endif

  let self.edit_winid = win_getid()
  let self.edit_bufnr = bufnr('%')
endfunction

function! s:deol.init_edit_buffer() abort
  setlocal hidden
  setlocal bufhidden=hide
  setlocal buftype=nofile
  setlocal nolist
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal colorcolumn=
  setlocal nonumber
  setlocal norelativenumber

  resize 1

  " Set filetype
  let command = fnamemodify(self.command, ':t:r')
  let filetype = self.edit_filetype
  let default_filetype = {
        \ 'ash': 'sh',
        \ 'bash': 'zsh',
        \ 'fish': 'fish',
        \ 'ksh': 'sh',
        \ 'sh': 'sh',
        \ 'zsh': 'zsh',
        \ 'xonsh': 'python',
        \ }
  if filetype ==# '' && has_key(default_filetype, command)
    let filetype = default_filetype[command]
  endif

  let self.bufedit = bufnr('%')

  nnoremap <buffer><silent> <Plug>(deol_execute_line)
        \ :<C-u>call <SID>send_editor()<CR>
  inoremap <buffer><silent> <Plug>(deol_execute_line)
        \ <ESC>:call <SID>send_editor()<CR>o
  nnoremap <buffer><expr><silent> <Plug>(deol_quit)
        \ winnr('$') == 1 ? ":\<C-u>buffer #\<CR>" : ":\<C-u>close!\<CR>"

  nmap <buffer> <CR> <Plug>(deol_execute_line)
  nmap <buffer> q    <Plug>(deol_quit)
  imap <buffer> <CR> <Plug>(deol_execute_line)

  let &l:filetype = filetype
endfunction

function! s:deol.jobsend(keys) abort
  if !has_key(self, 'bufnr')
    return
  endif

  if has('nvim')
    call jobsend(self.jobid, a:keys)
  else
    call term_sendkeys(self.bufnr, a:keys)
  endif
endfunction

function! s:send_editor() abort
  if !exists('t:deol')
    return
  endif

  call t:deol.jobsend("\<C-u>" . getline('.') . "\<CR>")
endfunction

function! s:execute_line() abort
  if g:deol#prompt_pattern == '' || !exists('t:deol')
    return
  endif

  let cmdline = deol#get_cmdline()
  call t:deol.jobsend(cmdline . "\<CR>")
  call s:insert_mode(t:deol)
endfunction

function! s:search_prompt(flag) abort
  if g:deol#prompt_pattern == ''
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
  if g:deol#prompt_pattern == '' || !exists('t:deol')
    return
  endif

  let cmdline = deol#get_cmdline()
  call t:deol.jobsend("\<C-u>" . cmdline)
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

  if a:options.split == 'floating' && exists('*nvim_open_win')
    call nvim_open_win(bufnr('%'), v:true, {
          \ 'relative': 'editor',
          \ 'row': str2nr(a:options.winrow),
          \ 'col': str2nr(a:options.wincol),
          \ 'width': str2nr(a:options.winwidth),
          \ 'height': str2nr(a:options.winheight),
          \ })
  elseif a:options.split == 'vertical'
    vsplit
  else
    split
  endif
endfunction


function! s:insert_mode(deol) abort
  if a:deol.options.start_insert
    startinsert
  endif
endfunction

function! s:start_insert(mode) abort
  let prompt = s:get_prompt()
  if prompt == ''
    return a:mode
  endif

  return 'i' . repeat("\<Right>", len(deol#get_cmdline()))
        \ . repeat("\<Left>", len(deol#get_cmdline()) - len(s:get_input())
        \ + (a:mode ==# 'i' ? 1 : 0))
endfunction

function! s:get_prompt() abort
  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  return matchstr(getline('.'), pattern)
endfunction

function! s:get_input() abort
  let input = matchstr(getline('.'), '^.*\%' . (col('.') + 1) . 'c')
  return input[len(s:get_prompt()):]
endfunction

function! s:user_options() abort
  return {
        \ 'command': &shell,
        \ 'edit': v:false,
        \ 'edit_filetype': '',
        \ 'cwd': '',
        \ 'split': '',
        \ 'start_insert': v:true,
        \ 'wincol': &columns / 4,
        \ 'winheight': 30,
        \ 'winrow': &lines / 3,
        \ 'winwidth': 90,
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

function! s:get_histories() abort
  let history_path = expand(g:deol#shell_history_path)
  if !filereadable(history_path)
    return []
  endif

  return map(readfile(history_path)[-g:deol#shell_history_max :],
        \ 'substitute(v:val, "^\\%(\\d\\+/\\)\\+[:[:digit:]; ]\\+\\|' .
        \ '^[:[:digit:]; ]\\+", "", "g")')
endfunction

function! deol#_complete(arglead, cmdline, cursorpos) abort
  let _ = []

  " Option names completion.
  let bool_options = keys(filter(copy(s:user_options()),
        \ 'type(v:val) == type(v:true) || type(v:val) == type(v:false)'))
  let _ += map(copy(bool_options), "'-' . tr(v:val, '_', '-')")
  let string_options = keys(filter(copy(s:user_options()),
        \ 'type(v:val) != type(v:true) && type(v:val) != type(v:false)'))
  let _ += map(copy(string_options), "'-' . tr(v:val, '_', '-') . '='")

  " Add "-no-" option names completion.
  let _ += map(copy(bool_options), "'-no-' . tr(v:val, '_', '-')")

  if exists('*getcompletion')
    let _ += getcompletion(a:arglead, 'shellcmd')
  endif

  return uniq(sort(filter(_, 'stridx(v:val, a:arglead) == 0')))
endfunction

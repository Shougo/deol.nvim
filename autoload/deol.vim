"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let g:deol#_prev_deol = -1
let g:deol#prompt_pattern = get(g:, 'deol#prompt_pattern', '')
let g:deol#enable_dir_changed = get(g:, 'deol#enable_dir_changed', 1)

augroup deol
  autocmd!
augroup END

if exists('##DirChanged') && g:deol#enable_dir_changed
  autocmd deol DirChanged * call deol#cd(v:event.cwd)
endif

function! deol#start(options) abort
  if exists('t:deol') && bufexists(t:deol.bufnr)
    let deol = t:deol
    let id = win_findbuf(deol.bufnr)
    if empty(id)
      execute 'buffer' deol.bufnr
    else
      call win_gotoid(id[0])
    endif
    if has_key(a:options, 'cwd')
      call deol.cd(a:options.cwd)
    else
      call s:cd(deol.cwd)
    endif
    let g:deol#_prev_deol = win_getid()
    startinsert
    return
  endif

  let options = copy(a:options)
  if get(options, 'command', '') == ''
    let options.command = &shell
  endif
  if get(options, 'cwd', '') == ''
    let options.cwd = input('Current directory: ', getcwd(), 'dir')
  endif

  let cwd = expand(options.cwd)
  if !isdirectory(cwd)
    echomsg '[deol] ' . cwd . ' is not directory'
    return
  endif

  let t:deol = deol#_new(cwd, options.command)
  call t:deol.init_deol_buffer()
endfunction

function! deol#new(options) abort
  let options = copy(a:options)
  if get(options, 'cwd', '') == ''
    let options.cwd = input('Current directory: ', getcwd(), 'dir')
  endif

  if options.cwd == ''
    return
  endif

  tabnew
  return deol#start(options)
endfunction

function! deol#send(string) abort
  if !exists('t:deol')
    return
  endif

  call t:deol.jobsend("\<C-u>" . a:string . "\<CR>")
endfunction

function! deol#cd(directory) abort
  if exists('t:deol')
    call t:deol.cd(a:directory)
  endif
endfunction

function! deol#edit() abort
  if !exists('t:deol')
    Deol
  endif

  if win_findbuf(t:deol.edit_bufnr) == [t:deol.edit_winid]
    call win_gotoid(t:deol.edit_winid)
  else
    split deol-edit
    if !has_key(t:deol, 'bufedit')
      call t:deol.init_edit_buffer()
    endif
    let t:deol.edit_winid = win_getid()
    let t:deol.edit_bufnr = bufnr('%')
  endif

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

function! deol#_new(cwd, command) abort
  let deol = copy(s:deol)
  let deol.command = a:command
  let deol.edit_winid = -1
  let deol.edit_bufnr = -1
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
    call term_start(self.command)
  endif
  setlocal bufhidden=hide
  setlocal filetype=deol
  let self.bufnr = bufnr('%')
  let g:deol#_prev_deol = win_getid()

  nnoremap <buffer><silent> <Plug>(deol_execute_line)
        \ :<C-u>call <SID>execute_line()<CR>
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

  nmap <buffer> e     <Plug>(deol_edit)
  nmap <buffer> i     <Plug>(deol_start_insert)
  nmap <buffer> I     <Plug>(deol_start_insert_first)
  nmap <buffer> a     <Plug>(deol_start_append)
  nmap <buffer> A     <Plug>(deol_start_append_last)
  nmap <buffer> <CR>  <Plug>(deol_execute_line)
  nmap <buffer> <C-p> <Plug>(deol_previous_prompt)
  nmap <buffer> <C-n> <Plug>(deol_next_prompt)
  nmap <buffer> <C-y> <Plug>(deol_paste_prompt)
endfunction

function! s:deol.init_edit_buffer() abort
  setlocal hidden
  setlocal bufhidden=hide
  setlocal buftype=nofile
  resize 5

  " Set filetype
  let command = fnamemodify(self.command, ':t:r')
  let default_filetype = {
        \ 'ash': 'sh',
        \ 'bash': 'zsh',
        \ 'fish': 'fish',
        \ 'ksh': 'sh',
        \ 'sh': 'sh',
        \ 'zsh': 'zsh',
        \ }
  if has_key(default_filetype, command)
    let &l:filetype = default_filetype[command]
  endif

  let self.bufedit = bufnr('%')

  nnoremap <buffer><silent> <Plug>(deol_execute_line)
        \ :<C-u>call <SID>send_editor()<CR>
  inoremap <buffer><silent> <Plug>(deol_execute_line)
        \ <ESC>:call <SID>send_editor()<CR>o

  nmap <buffer> <CR> <Plug>(deol_execute_line)
  nmap <buffer> q :<C-u>close!<CR>
  imap <buffer> <CR> <Plug>(deol_execute_line)
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
  call t:deol.jobsend("\<C-u>" . getline('.') . "\<CR>")
endfunction

function! s:execute_line() abort
  if g:deol#prompt_pattern == ''
    return
  endif

  let cmdline = s:get_cmdline()
  call t:deol.jobsend(cmdline . "\<CR>")
  startinsert
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
  if g:deol#prompt_pattern == ''
    return
  endif

  let cmdline = s:get_cmdline()
  call t:deol.jobsend("\<C-u>" . cmdline)
  startinsert
endfunction

function! s:start_insert(mode) abort
  let prompt = s:get_prompt()
  if prompt == ''
    return a:mode
  endif

  return 'i' . repeat("\<Right>", len(s:get_cmdline()))
        \ . repeat("\<Left>", len(s:get_cmdline()) - len(s:get_input())
        \ + (a:mode ==# 'i' ? 1 : 0))
endfunction

function! s:get_cmdline() abort
  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  return substitute(getline('.'), pattern, '', '')
endfunction

function! s:get_prompt() abort
  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  return matchstr(getline('.'), pattern)
endfunction

function! s:get_input() abort
  let input = matchstr(getline('.'), '^.*\%' . (col('.') + 1) . 'c')
  return input[len(s:get_prompt()):]
endfunction


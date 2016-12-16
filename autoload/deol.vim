"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let g:deol#prompt_pattern = get(g:, 'deol#prompt_pattern', '')

function! deol#start(options) abort
  if exists('t:deol')
    let id = win_findbuf(t:deol.bufnr)
    if empty(id)
      execute 'buffer' t:deol.bufnr
    else
      call win_gotoid(id[0])
    endif
    if has_key(a:options, 'cwd')
      call t:deol.cd(a:options.cwd)
    else
      call s:cd(t:deol.cwd)
    endif
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
    return
  endif

  let t:deol = deol#_new(cwd, options.command)
  call t:deol.init_buffer()
endfunction

function! deol#cd(directory) abort
  if exists('t:deol')
    call t:deol.cd(a:directory)
  endif
endfunction

function! deol#_new(cwd, command) abort
  let deol = copy(s:deol)
  let deol.command = a:command
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
  let self.cwd = fnamemodify(a:directory, ':p')
  call s:cd(self.cwd)
  if exists('b:terminal_job_id')
    call jobsend(b:terminal_job_id,
          \ "\<C-u>cd " . fnameescape(self.cwd) . "\<CR>")
  endif
endfunction

function! s:deol.init_buffer() abort
  execute 'terminal' self.command
  setlocal bufhidden=hide
  setlocal filetype=deol
  let self.bufnr = bufnr('%')

  nnoremap <buffer><silent> <Plug>(deol_execute_line)
        \ :<C-u>call <SID>execute_line()<CR>
  nnoremap <buffer><silent> <Plug>(deol_previous_prompt)
        \ :<C-u>call <SID>search_prompt('bWn')<CR>
  nnoremap <buffer><silent> <Plug>(deol_next_prompt)
        \ :<C-u>call <SID>search_prompt('Wn')<CR>
  nnoremap <buffer><silent> <Plug>(deol_paste_prompt)
        \ :<C-u>call <SID>paste_prompt()<CR>

  nmap <buffer> <CR> <Plug>(deol_execute_line)
  nmap <buffer> <C-p> <Plug>(deol_previous_prompt)
  nmap <buffer> <C-n> <Plug>(deol_next_prompt)
  nmap <buffer> <C-y> <Plug>(deol_paste_prompt)
endfunction

function! s:execute_line() abort
  if g:deol#prompt_pattern == ''
    return
  endif

  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  let cmdline = substitute(getline('.'), pattern, '', '')
  call jobsend(b:terminal_job_id, cmdline . "\<CR>")
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

  let pattern = '^\%(' . g:deol#prompt_pattern . '\m\)'
  let cmdline = substitute(getline('.'), pattern, '', '')
  call jobsend(b:terminal_job_id, "\<C-u>" . cmdline)
  startinsert
endfunction

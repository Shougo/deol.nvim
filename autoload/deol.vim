"=============================================================================
" FILE: deol.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

let g:deol#prompt_pattern = get(g:, 'deol#prompt_pattern', '')

function! deol#start(command) abort
  if exists('t:deol')
    execute 'buffer' t:deol.bufnr
    execute 'lcd' fnameescape(t:deol.cwd)
    startinsert
    return
  endif

  let cwd = expand(input('Current directory: ', getcwd(), 'dir'))
  if cwd == '' || !isdirectory(cwd)
    return
  endif

  let t:deol = deol#_new(cwd, a:command)
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
  let deol.bufnr = bufnr('%')
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

let s:deol = {}

function! s:deol.cd(directory) abort
  let self.cwd = fnamemodify(a:directory, ':p')
  execute (exists(':tchdir') ? 'tchdir' : 'lcd') fnameescape(self.cwd)
  if exists('b:terminal_job_id')
    call jobsend(b:terminal_job_id,
          \ "\<C-u>cd " . fnameescape(self.cwd) . "\<CR>")
  endif
endfunction

function! s:deol.init_buffer() abort
  execute 'terminal' self.command
  setlocal bufhidden=hide

  nnoremap <buffer><silent> <Plug>(deol_execute_line)
        \ :<C-u>call <SID>execute_line()<CR>
  nnoremap <buffer><silent> <Plug>(deol_previous_prompt)
        \ :<C-u>call <SID>search_prompt('bWn')<CR>
  nnoremap <buffer><silent> <Plug>(deol_next_prompt)
        \ :<C-u>call <SID>search_prompt('Wn')<CR>

  nmap <buffer> <CR> <Plug>(deol_execute_line)
  nmap <buffer> <C-p> <Plug>(deol_previous_prompt)
  nmap <buffer> <C-n> <Plug>(deol_next_prompt)
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

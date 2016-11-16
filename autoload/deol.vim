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
  if executable('nvr')
    let editor_command =
          \ printf('nvr %s --remote-tab-wait-silent',
          \   (v:servername == '' ? '' : ' --servername='.v:servername))
    let $EDITOR = editor_command
    let $GIT_EDITOR = editor_command
  endif

  return deol
endfunction

let s:deol = {}

function! s:deol.cd(directory) abort
  let self.cwd = fnamemodify(a:directory, ':p')
  execute 'lcd' fnameescape(self.cwd)
  if exists('b:terminal_job_id')
    call jobsend(b:terminal_job_id,
          \ "\<C-u>cd " . fnameescape(self.cwd) . "\<CR>")
  endif
endfunction

function! s:deol.init_buffer() abort
  execute 'terminal' self.command
  setlocal bufhidden=hide
endfunction

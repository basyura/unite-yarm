" redmine source for unite.vim
" Version:     0.0.1
" Last Change: 25 Nov 2010
" Author:      basyura <basyrua at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
" }}}
"
" variables
"
if !exists('g:unite_yarm_server_url')
  let g:unite_yarm_server_url = 'http://localhost:3000'
endif
"
if !exists('g:unite_yarm_per_page')
  let g:unite_yarm_per_page = 25
endif
" hi - source を読み込み直すと消えちゃう
highlight yarm_ok guifg=white guibg=blue
"
" source
"
function! unite#sources#redmine#define()
  return s:unite_source
endfunction
" cache
let s:candidates_cache  = []
"
let s:unite_source      = {}
let s:unite_source.name = 'redmine'
let s:unite_source.default_action = {'common' : 'open'}
let s:unite_source.action_table   = {}
" create list
function! s:unite_source.gather_candidates(args, context)
  " clear cache if Unite redmine:!
  if len(a:args) > 0 && a:args[0] == '!'
    let s:candidates_cache = []
  endif
  " return cache if exist
  if !empty(s:candidates_cache)
    return s:candidates_cache
  endif
  " cache issues
  call s:info('now caching issues ...')
  let s:candidates_cache = 
        \ map(s:get_issues() , '{
        \ "word"          : v:val.unite_word,
        \ "source"        : "redmine",
        \ "source__issue" : v:val,
        \ }')
  return s:candidates_cache
endfunction
"
" action table
"
let s:action_table = {}
let s:unite_source.action_table.common = s:action_table
" 
" action - open
"
let s:action_table.open = {'description' : 'open issue'}
function! s:action_table.open.func(candidate)
  call s:load_issue(a:candidate.source__issue)
endfunction
"
" action - browser
"
let s:action_table.browser = {'description' : 'open issue with browser'}
function! s:action_table.browser.func(candidate)
  call s:open_browser(a:candidate.source__issue.id)
endfunction
"
" action - reget
"
let s:action_table.reget = {'description' : 'reget issue'}
function! s:action_table.reget.func(candidate)
  call s:load_issue(s:reget_issue(a:candidate.source__issue.id))
endfunction
"
" autocmd
"
augroup RedmineGroup
  autocmd! RedmineGroup
  autocmd FileType redmine call s:redmine_issue_settings()
augroup END  

function! s:redmine_issue_settings()
  nmap <silent> <buffer> <CR> :call <SID>redmine_issue_buffer_action()<CR>
endfunction

function! s:redmine_issue_buffer_action()
  let matched = matchlist(expand('<cWORD>') , 'https\?://\S\+')
  if len(matched) != 0
    execute "OpenBrowser " . matched[0]
  endif
endfunction

function! s:redmine_put_issue()
  if input('update ? (y/n) : ') != 'y'
    return s:info('update was canceled')
  endif
  " cached issue
  let issue = b:unite_yarm_issue
  " i want display progress
  call s:info('now updating #' . issue.id . ' ...')
  " reget lastest issue
  let pre   = s:get_issue(issue.id)
  " check latest
  if pre.updated_on != issue.updated_on
    return s:echoerr('issue #' . issue.id . ' is already updated')
  endif
  " backup
  call s:backup_issue(pre)
  " 最後の改行が削られるので \n を付ける
  let body  = '<issue><description>' 
                \ . join(getline(14,'$') , "\n") . "\n"
                \ . '</description></issue>'
  " put issue
  let res   = http#post(issue.rest_url , body , {'Content-Type' : 'text/xml'} , 'PUT')
  " split HTTP/1.0 200 OK
  if split(res.header[0])[1] == '200'
    " :wq 保存して閉じる 
    " :w  チケットを取り直して再描画
    call s:load_issue(s:reget_issue(issue.id))
    call s:info('#' . issue.id . ' - ' . res.header[0])
  else
    redraw
    call s:error('failed - ' . res.header[0])
  endif
endfunction

" - private functions -

"
" get issues with api
"
function! s:get_issues()
  let url = g:unite_yarm_server_url . '/issues.xml?' . 
                  \ 'per_page=' . g:unite_yarm_per_page
  if exists('g:unite_yarm_access_key')
    let url .= '&key=' . g:unite_yarm_access_key
  endif
  let issues = []
  let res = http#get(url)
  " check status code
  if split(res.header[0])[1] != '200'
    call s:error(res.header[0])
    return []
  endif
  " convert xml to dict
  for dom in xml#parse(res.content).childNodes('issue')
    call add(issues , s:to_issue(dom))
  endfor
  return issues
endfunction
"
" get issue with api
"
function! s:get_issue(id)
  let url = g:unite_yarm_server_url . '/issues/' . a:id . '.xml'
  if exists('g:unite_yarm_access_key')
    let url .= '?key=' . g:unite_yarm_access_key
  endif
  return s:to_issue(xml#parseURL(url))
endfunction
"
" load issue to buffer
"
function! s:load_issue(issue)
  "exec 'new redmine_' . a:issue.id
  exec 'edit! redmine_' . a:issue.id
  silent %delete _
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal fileencoding=utf-8 
  setlocal fileformat=unix
  setfiletype redmine
  " append issue's fields
  call append(0 , [
      \ '<< ' . a:issue.project . ' - #' . a:issue.id . ' ' . a:issue.subject . ' >>' ,
      \ '' ,
      \ 'tracker         : ' . a:issue.tracker ,
      \ 'status          : ' . a:issue.status ,
      \ 'priority        : ' . a:issue.priority ,
      \ 'author          : ' . a:issue.author ,
      \ 'start_date      : ' . a:issue.start_date ,
      \ 'due_date        : ' . a:issue.due_date ,
      \ 'estimated_hours : ' . a:issue.estimated_hours ,
      \ 'done_ratio      : ' . a:issue.done_ratio ,
      \ 'created_on      : ' . a:issue.created_on ,
      \ 'updated_on      : ' . a:issue.updated_on ,
      \ ])
  " add description
  for line in split(a:issue.description,"\n")
    call append(line('$') , substitute(line , '' , '' , 'g'))
  endfor
  " check access key.
  if !exists('g:unite_yarm_access_key')
    setlocal buftype=nofile
    setlocal nomodifiable
  else
    setlocal buftype=acwrite
    setlocal nomodified
    " cache issue for update
    let b:unite_yarm_issue = a:issue
    " add put command
    augroup RedmineBufCmdGroup
      autocmd! RedmineBufCmdGroup
      autocmd BufWriteCmd <buffer> call <SID>redmine_put_issue()
    augroup END
  endif
  " move cursor to top
  :1
  stopinsert
endfunction
"
" open browser with issue's id
"
function! s:open_browser(id)
  execute "OpenBrowser " . g:unite_yarm_server_url . '/issues/' . a:id
endfunction
"
" reget issue
"
function! s:reget_issue(id)
  let issue = s:get_issue(a:id)
  for cache in s:candidates_cache
    " update cache
    if cache.source__issue.id == a:id
      let cache.word          = issue.unite_word
      let cache.source__issue = issue
      break
    endif
  endfor
  return issue
endfunction
"
" backup issue
"
functio! s:backup_issue(issue)
  if !exists('g:unite_yarm_backup_dir')
    return
  endif

  let body = split(a:issue.description , "\n")
  let path = g:unite_yarm_backup_dir . '/' . a:issue.id
        \ . '.' . strftime('%Y%m%d%H%M%S')
        \ . '.txt'
  call writefile(body , path)

endfunction
"
" xml to issue
"
function! s:to_issue(xml)
  " i want this to be inner function
  function! s:to_value(v)
    return empty(a:v) ? '' : a:v[0]
  endfunction
  let issue = {
        \ 'id'              : s:to_value(a:xml.childNode('id').child) ,
        \ 'project'         : a:xml.childNode('project').attr['name'] ,
        \ 'tracker'         : a:xml.childNode('tracker').attr['name'] ,
        \ 'status'          : a:xml.childNode('status').attr['name'] ,
        \ 'priority'        : a:xml.childNode('priority').attr['name'] ,
        \ 'author'          : a:xml.childNode('author').attr['name'] ,
        \ 'subject'         : s:to_value(a:xml.childNode('subject').child) ,
        \ 'description'     : s:to_value(a:xml.childNode('description').child) ,
        \ 'start_date'      : s:to_value(a:xml.childNode('start_date').child) ,
        \ 'due_date'        : s:to_value(a:xml.childNode('due_date').child) ,
        \ 'estimated_hours' : s:to_value(a:xml.childNode('estimated_hours').child) ,
        \ 'done_ratio'      : s:to_value(a:xml.childNode('done_ratio').child) ,
        \ 'created_on'      : s:to_value(a:xml.childNode('created_on').child) ,
        \ 'updated_on'      : s:to_value(a:xml.childNode('updated_on').child) ,
        \}
  " unite_word
  let issue.unite_word = '#' . issue.id . ' ' . issue.subject
  " url for CRUD
  let rest_url = g:unite_yarm_server_url . '/issues/' . issue.id . '.xml?format=xml'
  if exists('g:unite_yarm_access_key')
    let rest_url .= '&key=' . g:unite_yarm_access_key
  endif
  let issue.rest_url = rest_url

  return issue
endfunction
"
" echo info log
"
function! s:info(msg)
  echohl yarm_ok | echo a:msg | echohl None
  return 1
endfunction
"
" echo error log
"
function! s:error(msg)
  echohl ErrorMsg | echo a:msg | echohl None
  return 0
endfunction

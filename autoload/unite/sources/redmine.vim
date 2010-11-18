" redmine source for unite.vim
" Version:     0.0.1
" Last Change: 17 Nov 2010
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

if !exists('g:unite_yarm_server_url')
  let g:unite_yarm_server_url = 'http://localhost:3000'
endif

if !exists('g:unite_yarm_per_page')
  let g:unite_yarm_per_page = 25
endif
" cache
let s:candidates_cache = []

let s:unite_source = {}
let s:unite_source.name = 'redmine'
let s:unite_source.default_action = {'common' : 'open'}
let s:unite_source.action_table = {}
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
  let s:candidates_cache = 
        \ map(s:get_issues() , '{
        \ "word"          : v:val.unite_word,
        \ "source"        : "redmine",
        \ "source__issue" : v:val,
        \ }')

  return s:candidates_cache
endfunction
" action table
let s:action_table = {}
let s:unite_source.action_table.common = s:action_table
" action - open
let s:action_table.open = {'description' : 'open issue'}
function! s:action_table.open.func(candidate)
  let issue = a:candidate.source__issue
  exec 'new redmine_' . issue.id
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal fileencoding=utf-8 
  setlocal fileformat=unix
  setfiletype redmine
  " append issue's fields
  call append(0 , [
      \ '<< ' . issue.project . ' - #' .issue.id . ' ' . issue.subject . ' >>' ,
      \ 'tracker         : ' . issue.tracker ,
      \ 'status          : ' . issue.status ,
      \ 'priority        : ' . issue.priority ,
      \ 'author          : ' . issue.author ,
      \ 'start_date      : ' . issue.start_date ,
      \ 'due_date        : ' . issue.due_date ,
      \ 'estimated_hours : ' . issue.estimated_hours ,
      \ 'done_ratio      : ' . issue.done_ratio ,
      \ 'created_on      : ' . issue.created_on ,
      \ 'updated_on      : ' . issue.updated_on ,
      \ '' 
      \ ])
  " is this ok? => append だと改行コードが出ちゃう・・・
  for line in split(issue.description,"\n")
    "silent execute 'normal i' . line
    call append(line('$') , line)
  endfor
  " move cursor to top
  normal! 1G
endfunction

let s:action_table.browser = {'description' : 'open issue with browser'}
function! s:action_table.browser.func(candidate)
  let issue = a:candidate.source__issue
  let url   = g:unite_yarm_server_url . '/issues/' . issue.id
  execute "OpenBrowser " . url
endfunction

" source
function! unite#sources#redmine#define()
  return s:unite_source
endfunction


augroup RedmineGroup
  autocmd! RedmineGroup
  autocmd FileType redmine call s:redmine_issue_settings()
augroup END  

function! s:redmine_issue_settings()
  nmap <silent> <buffer> <CR> :call <SID>redmine_issue_buffer_action()<CR>
endfunction

function! s:redmine_issue_buffer_action()
  let matched = matchlist(expand('<cWORD>') , 'https\+://\S\+')
  if len(matched) != 0
    execute "OpenBrowser " . matched[0]
  endif
endfunction


" private functions
function! s:get_issues()
  let url = g:unite_yarm_server_url . '/issues.xml?' . 
                  \ 'per_page=' . g:unite_yarm_per_page
  if exists('g:unite_yarm_access_key')
    let url = url . '&key=' . g:unite_yarm_access_key
  endif
  let issues = []
  for dom in xml#parseURL(url).childNodes('issue')
    call add(issues , s:to_issue(dom))
  endfor
  return issues
endfunction

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
  let issue.unite_word = '#' . issue.id . ' ' . issue.subject

  return issue
endfunction


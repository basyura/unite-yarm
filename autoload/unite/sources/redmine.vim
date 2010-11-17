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

let s:unite_source = {}
let s:unite_source.name = 'redmine'
let s:unite_source.default_action = {'common' : 'open_issue'}
let s:unite_source.action_table = {}
" create list
function! s:unite_source.gather_candidates(args, context)
  
  let issues = s:get_issues()

  return map(issues, '{
        \ "word"          : v:val.unite_word,
        \ "source"        : "redmine",
        \ "source__issue" : v:val,
        \ }')
endfunction
" action table
let s:action_table = {}
let s:unite_source.action_table.common = s:action_table
" action - open_issue
let s:action_table.open_issue = {'description' : 'open issue'}
function! s:action_table.open_issue.func(candidate)
  let issue = a:candidate.source__issue
  exec 'new redmine_' . issue.id
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal fileencoding=utf-8 
  setfiletype redmine
  silent execute 'normal i' . '<< ' . issue.project . 
        \ ' - #' .issue.id
        \ ' ' . issue.subject . '>>'
  silent execute 'normal o' . 'tracker         : ' . issue.tracker
  silent execute 'normal o' . 'status          : ' . issue.status
  silent execute 'normal o' . 'priority        : ' . issue.priority
  silent execute 'normal o' . 'author          : ' . issue.author
  silent execute 'normal o' . 'start_date      : ' . issue.start_date
  silent execute 'normal o' . 'due_date        : ' . issue.due_date
  silent execute 'normal o' . 'estimated_hours : ' . issue.estimated_hours
  silent execute 'normal o' . 'done_ratio      : ' . issue.done_ratio
  silent execute 'normal o' . 'created_on      : ' . issue.created_on
  silent execute 'normal o' . 'updated_on      : ' . issue.updated_on
  silent execute 'normal o' . ''
  silent execute 'normal o' . ''
  " is this ok?
  for line in split(issue.description,"\n")
    silent execute 'normal i' . line
  endfor
        
endfunction

" source
function! unite#sources#redmine#define()
  return s:unite_source
endfunction


" private functions

function! s:get_issues()
  let url = g:unite_yarm_server_url . '/issues.xml'
  if exists('g:unite_yarm_access_key')
    let url = url . '?key=' . g:unite_yarm_access_key
  endif
  let xml = xml#parseURL(url)
  let issues = []
  for dom in xml.childNodes('issue')
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


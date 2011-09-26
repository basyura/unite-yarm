
if exists('b:current_syntax')
  finish
endif

runtime! syntax/textile.vim

syntax match yarm_title "^<< .* >>$"

syntax match yarm_tool_reload '\[R\]'
syntax match yarm_tool_open   '\[O\]'
syntax match yarm_tool_write  '\[W\]'

syntax match yarm_link  "\<http://\S\+"  
syntax match yarm_link  "\<https://\S\+"

syntax match yarm_field "^tracker\s\+: "
syntax match yarm_field "^status\s\+: "
syntax match yarm_field "^priority\s\+: "
syntax match yarm_field "^author\s\+: "
syntax match yarm_field "^fixed_version\s\+: "
syntax match yarm_field "^assigned_to\s\+: "
syntax match yarm_field "^start_date\s\+: "
syntax match yarm_field "^due_date\s\+: "
syntax match yarm_field "^estimated_hours\s\+: "
syntax match yarm_field "^spent_hours\s\+: "
syntax match yarm_field "^done_ratio\s\+: "
syntax match yarm_field "^created_on\s\+: "
syntax match yarm_field "^updated_on\s\+: "

syntax match yarm_wiki_link "[[.*?]]"

syntax region yarm_pre start="<pre>"  end="</pre>" 

highlight default link yarm_title       Statement
highlight default link yarm_tool_reload String
highlight default link yarm_tool_open   String
highlight default link yarm_tool_write  String
highlight default link yarm_link        Underlined
highlight default link yarm_field       Constant
highlight default link yarm_pre         Type
highlight default link yarm_wiki_link   Underlined

highlight yarm_ok guifg=white guibg=blue

let b:current_syntax = 'yarm'

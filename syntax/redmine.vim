
" 効果が分からん
if exists('b:current_syntax')
  finish
endif

syntax match redmine_title "^<< .* >>$"
syntax match redmine_link  "\<http://\S\+"  
syntax match redmine_link  "\<https://\S\+"

syntax match redmine_field "^tracker\s\+: "
syntax match redmine_field "^status\s\+: "
syntax match redmine_field "^priority\s\+: "
syntax match redmine_field "^author\s\+: "
syntax match redmine_field "^start_date\s\+: "
syntax match redmine_field "^due_date\s\+: "
syntax match redmine_field "^estimated_hours\s\+: "
syntax match redmine_field "^done_ratio\s\+: "
syntax match redmine_field "^created_on\s\+: "
syntax match redmine_field "^updated_on\s\+: "

syntax match redmine_h2 "^h2\..*"
syntax match redmine_h3 "^h3\..*"

highlight default link redmine_title Statement
highlight default link redmine_link  Underlined
highlight default link redmine_field Constant
highlight default link redmine_h2    Underlined
highlight default link redmine_h3    Statement

let b:current_syntax = 'redmine'

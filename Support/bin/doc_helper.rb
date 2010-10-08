#!/usr/bin/env ruby 
require ENV['TM_BUNDLE_SUPPORT'] +"/lib/haxe_env"
require "ftools"
cw = ENV['TM_CURRENT_WORD']
fp = ENV['TM_FILEPATH']
li = ENV['TM_LINE_INDEX'].to_i
cl = ENV['TM_CURRENT_LINE']
pj = ENV['TM_PROJECT_DIRECTORY']

TextMate.exit_show_tool_tip "This doesn't look like a valid Class (first letter is uncapitalized).  I can't find documentation for it." if !cw.match(/[A-Z]\w*/)

first = cl[0,li][/[\w\.]+$/]
last = cl[li,cl.length][/^[\w\.]+/]

TextMate.exit_show_tool_tip 'No valid word selected' if first == nil || last == nil

search = first + last

file_content = IO.read(fp)
dirs = ""

# Is the current word a class in the current file?
arr_match = search.match(/(^[a-z\.]+)/)

if arr_match
  dirs = arr_match[1].sub(/\./,'/')  
  dirs.chomp!('/')
elsif file_content.match("(class|interface|extern)\s+#{cw}")
  # is there a current package?
	if arr = file_content.match(/package\s+([\w\.]+)/)
		dirs = arr[1].sub(/\./,'/')
	end
else
  # is the class imported from somewhere else?
	file_content.scan(/import\s+([\w\.]+)/) {|import|
    if import[0].match(cw)
      arr_imp = import[0].split('.');
      arr_imp.pop()
      dirs = arr_imp.join('/')
    end
  }	
end
final_dir = dirs+'/'+cw

if ! File.exists?("#{pj}/.haxedoc/content/#{final_dir}.html")
   TextMate.exit_show_tool_tip "The documentation does not exist for #{cw} at #{final_dir}.  Please generate or regenerate the documentation using Control-Shift-H."
end
`open #{pj}/.haxedoc/content/#{final_dir}.html`
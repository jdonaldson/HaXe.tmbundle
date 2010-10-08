#!/usr/bin/env ruby -wKU
# encoding: utf-8

require ENV['TM_BUNDLE_SUPPORT'] +'/lib/haxe_env'

cw = ENV['TM_CURRENT_WORD']
li = ENV['TM_LINE_INDEX'].to_i
cl = ENV['TM_CURRENT_LINE']
ln = ENV['TM_LINE_NUMBER'].to_i

# there must be a valid word to import on
if cw == nil || cw.match(/[^\w]/)
   TextMate.exit_show_tool_tip "Please select a valid word to search for class names with."
end

# read in the current file and check to see if the class has already been imported or defined
cur_file_str = STDIN.read
if cur_file_str.match(/(import|using|class)\s*((\w*?\.)*)?#{cw}\b/) && !cl[0,li].match('import|using')
  TextMate.exit_show_tool_tip "The class #{cw} has already been imported or defined"
end

# get the hxml file to find extra defined class paths
pj = ENV['TM_PROJECT_DIRECTORY']
Dir.chdir(pj)
hxml_build = HaxeMate::get_hxml(true,true)
filestr = IO.read(hxml_build)

cps = HaxeMate::get_hxml_dirs(filestr)




if ENV.key?('HAXE_LIBRARY_PATH')
  cps.push(ENV['HAXE_LIBRARY_PATH'].gsub(/:|\./,'')) # add in the custom library path
else
  cps.push('/usr/lib/haxe/std/') # add in default haxe lib location
end


# add in specific libs from hxml
libs = filestr.scan(/^\s*-lib\s+([\w\/]+)/)
libs.map!{|x| x[0]}
libs.each{|x| cps.push('/usr/lib/haxe/lib/' + x)}




result = Array.new
# TextMate.exit_show_tool_tip cps.join(' ')

cps.each{|dir|
  
  result_str =  `find #{dir} -name "*.hx" 2>/dev/null`
  result.concat(result_str.split("\n"))

}
# TextMate.exit_show_tool_tip result.join(' ')


# build a class name => package hash
h = Hash.new
result.each{|x|
  cls =  x.match(/(\w+)\.hx$/)[1] # match the class name (sans .hx)
  h[x] = cls
  }



# partial word match on the current word
h.reject!{|key,value| !value.match("#{cw}") }

# TextMate.exit_show_tool_tip h.keys().join(' ')

TextMate.exit_show_tool_tip "No classes found that match this word"  if h.empty?

packages = Hash.new

h.each{|key,value|
  file_str = IO.read(key)
  matches = file_str.match(/(\n|^)\s*package\s*([\w\.]*)/)
  if matches
    package = matches[2] + '.' + value
  else
    package = value
  end
  
  if !packages.member?(package) || packages[package] < key
    packages[package] = key
  end
  }



sort_keys = packages.keys.sort()

if packages.length > 1
  selection = TextMate::UI.menu(sort_keys)
  if selection == nil
    TextMate.exit_discard 
  end
else
  selection = 0
end


package = sort_keys[selection]


file_lines = cur_file_str.split("\n")

cur_line =  file_lines[ln-1]
start = cur_line.index(cw, [li-cw.length,0].max)
caret_pos = cur_line[0,start] + package + ';'
if cl[0,li].match('import')
  file_lines[ln-1] = cur_line[0,start] + package + ';' + cur_line[start+cw.length,cur_line.length]
  print file_lines.join("\n")
  pid = fork do
  	STDOUT.reopen(open('/dev/null'))
  	STDERR.reopen(open('/dev/null'))
  	TextMate.go_to( :column => caret_pos.length+1)
  end
  Process.exit
else
  file_lines[ln-1] = cur_line[0,start] + package[/\w+$/] + cur_line[start+cw.length,cur_line.length]
end
pkg = /^\s*package\b\s*([\w+\.]*)/
cls = /^\s*(public)?\s*\b(class|interface|enum)\b/
imp = /^\s*(import|using)\b\s*([\w+\.]*)/

pkg_found = false

file_lines.each{|x|  
  if x.match(imp)
    x.replace(x  + "\nimport #{package};")
    break
  elsif x.match(pkg)
    x.replace(x + "\nimport #{package};") 
    break
  elsif x.match(cls)
    file_lines.unshift("import #{package};") 
    break
  end

}

print file_lines.join("\n")
pid = fork do
	STDOUT.reopen(open('/dev/null'))
	STDERR.reopen(open('/dev/null'))
	TextMate.go_to(:line => ln+1, :column => caret_pos.length)
end

  
  
  
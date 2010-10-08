#!/usr/bin/env ruby -wKU
# encoding: utf-8

require ENV['TM_BUNDLE_SUPPORT'] +'/lib/haxe_env'

cw = ENV['TM_CURRENT_WORD']
li = ENV['TM_LINE_INDEX'].to_i
cl = ENV['TM_CURRENT_LINE']
ln = ENV['TM_LINE_NUMBER'].to_i

# there must be a valid word to import on
if cw == nil || cw.match(/[^\w]/)
   TextMate.exit_show_tool_tip "Please select a valid word to open a class with."
end

# read in the current file and check to see if the class has already been imported or defined
cur_file_str = STDIN.read

if cur_file_str.match(/class\s#{cw}/)
  TextMate.exit_show_tool_tip "The class #{cw} is in the file that is currently open."
end

# get the hxml file to find extra defined class paths
pj = ENV['TM_PROJECT_DIRECTORY']
Dir.chdir(pj)
hxml_build = HaxeMate::get_hxml(true,true)
filestr = IO.read(hxml_build)

cps = HaxeMate::get_hxml_dirs(filestr)

cps.push('/usr/lib/haxe/std/') # add in default haxe lib location

# add in specific libs from hxml
libs = filestr.scan(/^\s*-lib\s+([\w\/]+)/)
libs.map!{|x| x[0]}
libs.each{|x| cps.push('/usr/lib/haxe/lib/' + x)}

result = Array.new
cps.each{|dir|
  result_str =  `find #{dir} -name "*.hx" 2>/dev/null`
  result.concat(result_str.split("\n"))
}

# add in other child classes from imports
cur_file_str.scan(/import\s+([\w\.]+)/) {|import|
  
}


# build a class name => package hash
h = Hash.new
result.each{|x|
  cls =  x.match(/(\w+)\.hx$/)[1] # match the class name (sans .hx)
  h[x] = cls
  }


# partial word match on the current word
#h.reject!{|key,value| !value.match("#{cw}") }
# full word match on the current word
h.reject!{|key,value| !value.match(/(\A|\s|\.)#{cw}$/) }

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

if packages.length > 1
  selection = TextMate::UI.menu(packages.keys)
  if selection == nil
    TextMate.exit_discard 
  end
else
  selection = 0
end

package = packages.keys[selection]
uri = packages.values[selection]

matches = uri.match(/\A\//)
if matches
  TextMate.go_to :file => "#{uri}"
else
  TextMate.go_to :file => "#{pj}/#{uri}"
end
exit
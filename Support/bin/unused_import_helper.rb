#!/usr/bin/env ruby -wKU
# encoding: utf-8
require ENV['TM_BUNDLE_SUPPORT'] +'/lib/haxe_env'
include TextMate;
file_str = STDIN.read

file_lines = file_str.split("\n")

imp = /^\s*import\b\s*(\w+\.)*(\w+\s*;)/
new_lines = Array.new
file_lines.each{|x|
  matches = x.match(imp)
  if matches
    cls = matches[2]
    if file_str.scan(/\b#{cls}\b/).length <=1
      confirmed = UI.request_confirmation( :prompt => "Do you wish to remove the import for #{cls[/\w+/]}?",
                                  :title => "Unused Import Removal",
                                  :button1 => "Remove")                
      if confirmed
        x.gsub!(imp,'')
        new_lines.push(x) if x.strip != '' 
      else
        new_lines.push(x)
      end
    else
      new_lines.push(x)
    end   
  else
    new_lines.push(x)
  end

}

print new_lines.join("\n")
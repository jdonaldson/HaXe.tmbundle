#!/usr/bin/ruby

DIALOG = ENV['TM_SUPPORT_PATH'] + '/bin/tm_dialog'
require ENV['TM_BUNDLE_SUPPORT'] +"/lib/haxe_env"

require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require 'rexml/document'
require 'open3'
require 'cgi'

for i in ['TM_LINE_NUMBER', 'TM_FILEPATH', 'TM_PROJECT_DIRECTORY', 'TM_LINE_INDEX', 'TM_CURRENT_LINE', 'TM_BUNDLE_SUPPORT']
  if ENV[i] == nil
    TextMate.exit_show_tool_tip "Textmate environment variables missing: " + i
  end
end

# necessary environment variables
ln = ENV['TM_LINE_NUMBER'].to_i
fp = ENV['TM_FILEPATH'] 
pj = ENV['TM_PROJECT_DIRECTORY']
li = ENV['TM_LINE_INDEX'].to_i
cl = ENV['TM_CURRENT_LINE']
bs = ENV['TM_BUNDLE_SUPPORT']
cw = ENV['TM_CURRENT_WORD']
doc_bytes = 0

# get byte offset
if ln != 1
  execute = "head -n" + (ln-1).to_s + ' "' + fp + '" | wc -c'
  doc_bytes = `#{execute}`.to_i
end


doc_bytes += li

# partial word
if cw != nil && !cl[li-1,1].match(/\.|\(/)
  partial_word = cw
  partial_word.chop() if partial_word.match(/\(/)
  doc_bytes -= partial_word.length
end


hxml_build = HaxeMate::get_hxml(true, true)
Dir.chdir(pj)
# call the haxe --display function
execute = 'haxe "' + hxml_build + '" --display "' + fp + '@' + doc_bytes.to_s + '" 2>&1'

maybe_xml = `#{execute}`

#try to parse the results.  If it can't be parsed, pass on the message from result 
begin
 doc = REXML::Document.new(maybe_xml)
rescue Exception => e
  TextMate.exit_show_tool_tip "No completion available:\n" + result + " (couldn't parse compiler xml output) " 
end


if doc.elements['list'] == nil && doc.elements['type'] == nil 
  
  TextMate.exit_show_tool_tip "There is an error preventing autocompletion: \n" + maybe_xml
end 

# helper function that converts haxe compiler --display output into an array of arguments (plus return)
def strType2Arr (str_type)
  args = str_type.scan(/[\?\w]+ : \([\?\(\w<\-> ]+\)|[\?\w]+ : [\w<>\.]+|\b[A-Z][\w<>\.]*|\([^\)]+\)/)
  # p str_type
  # p args
  # args.reject!{|n| n == '>'}
  args.map!{|n| n == 'Void' ? '' : n} # get rid of Void values
  args.map!{|n| n.sub(/[a-z]\w*\.([A-Z]+)/, '\1')} # get rid of parameterized type prefixes  
  return args
end

# helper function that creates a snippet from a given array of arguments
def args2Snippet (args_arr,format)
  args = args_arr.dclone
  
  if args.length == 0
    return ''
  elsif args.length == 1
    return ''
  else
    ret = args.pop
    snippet_str = ''
    args.reject!{|n| n ==''}
    i = 0
    snippet_args = args.map{|n| 
      "${#{i+=1}\:#{args[i-1]}}"
    }
    return format ? 'insert = "('+snippet_args.join(', ') +')";' : snippet_args.join(', ')
  end
end

# helper function that creates a display entry for the given field + arguments
def args2Display (match, args_arr)
  args = args_arr.dclone
  if args.length == 0
    display = match
  elsif args.length == 1
    display = match + ' : ' + args[0]
  else  
    ret = args.pop
    args_str = args.join(', ')
    args_str == '' ? args_str = '()' : args_str = '( ' + args_str + ' )'
    ret = ret == '' ? '' : ' : ' + ret
    display = match + args_str + ret 
  end
  return 'display = "' + display +'";'
end

# Helper function to go through each of the elements in the xml, creating argument arrays, and snippets

def field_complete (doc,partial_word,bs)
  last_snippet = ''
  last_match = ''
  last_args_length = 0
  results = Array.new
  doc.elements.each("list/i") do |element| # parse the xml document of possible fields
     match = element.attributes['n']
     next if partial_word != nil && match.slice(0,partial_word.length) != partial_word
     img_str = ''
     element.elements.each("t") do |t| 
       t.text = '' if t.text == nil
       args = strType2Arr(CGI.unescapeHTML(t.text))
       if args.length == 0
         if match.match(/^[A-Z]\w*/)
           img_str = 'hxClass'
         else
           img_str = 'hxPackage'
         end
       elsif args.length == 1 
         img_str = 'hxProperty'
       else
         img_str = 'hxFunction'
       end
        
       display = args2Display(match, args)
       last_match = match
       snippet = args2Snippet(args,true)
       last_snippet = args2Snippet(args,false)
       last_arg_length = args.length
    

       match.slice!(0, partial_word.length) if partial_word != nil
       results.push(  "{#{display} #{snippet} match = #{match}; image = #{img_str};}")
     end
  end
  if results.length == 1
    if last_args_length > 1
      TextMate.exit_insert_snippet(last_match+'(' + last_snippet + ')') 
    else
      TextMate.exit_insert_snippet(last_match)
    end 
  end
  TextMate.exit_show_tool_tip('No fields match the partial field given.') if results.length == 0



  # register small images to use in the popup
  register = "$DIALOG images --register \"{ hxClass = '#{bs}/icons/Class.png'; hxPackage = '#{bs}/icons/Package.png'; hxProperty = '#{bs}/icons/Property.png'; hxFunction = '#{bs}/icons/Function.png';}\""
  `#{register}`  

  # call the popup command
  command = '$DIALOG popup --suggestions ' + "'(" + results.join(', ') + ")'"
  `#{command}`
end

def function_complete (doc)
  doc.elements.each('type') do |element|
     args = strType2Arr(element.text.strip)
     TextMate.exit_insert_snippet( args2Snippet(args,false))
  end
  
end

doc.elements['list'] != nil ? field_complete(doc,partial_word,bs) : function_complete(doc)





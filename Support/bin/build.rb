#!/usr/bin/env ruby -wKU -W0
require ENV["TM_SUPPORT_PATH"] + "/lib/tm/executor"
require ENV["TM_SUPPORT_PATH"] + "/lib/tm/save_current_document"
require ENV['TM_BUNDLE_SUPPORT'] +'/lib/haxe_env'
require 'uri'

pd = ENV['TM_PROJECT_DIRECTORY']
if pd == nil || !File.exists?(pd) || !File.directory?(pd)
	TextMate.exit_show_tool_tip "Project Directory does not exist.\nPlease run the compile command from a HaXe project."
end
Dir.chdir(ENV['TM_PROJECT_DIRECTORY'])
if ENV['TM_FILEPATH'].match(/\.hxml$/)
  hxml_build = ENV['TM_FILEPATH']
else
  hxml_build = HaxeMate::get_hxml()  
end


TextMate.save_current_document


file_str = IO.read(hxml_build)

javascript = <<jscript
<SCRIPT type="text/javascript">
function handle_err(e){
  var num = e.keyCode-48;
  if (num >= 0 && num <= 9){
    if (num == 0) {
      num = 10;
    }
    var k = document.getElementById('err'+num).children[0].attributes['href'].value;
    TextMate.system("open '" + k + "'", null);
    return false;
  }

}

document.onkeyup = handle_err;
</SCRIPT>

jscript


err_num = 0
TextMate::Executor.run('haxe', hxml_build) do |str, type|
  case type
  when :err
	line_err = str.match(/([\/\w\.\-]+):(\d+): (characters|lines) (\d+)/)
     if line_err

        if line_err[1].match(/^\//)
	        url_loc =  line_err[1] + '&line='+ line_err[2] + '&column=' + (line_err[4].to_i+1).to_s
	      else
	        url_loc = ENV['TM_PROJECT_DIRECTORY'] + '/' + line_err[1] + '&line='+ line_err[2] + '&column=' + (line_err[4].to_i+1).to_s
	      end
	      url_loc = URI.escape(url_loc)	
    	  str =  "<span class=\"stderr\" id=\"err#{err_num+=1}\"><a href=txmt://open/?url=file://#{url_loc}>#{htmlize(str)}</a></span>"
    	  if err_num == 1
          str = javascript + str
        end
        str     
     else
        str
     end 	  
  end

end

print <<HXML
<div id = "tm_webpreview_content">

<pre>
<h3>Executed HXML</h3>
#{CGI.escapeHTML(file_str)}
</pre>
</div>
HXML


Process.exit if err_num > 0




Process.exit if not file_str.match(/^\s*#\s*@tm-preview/) 

# add in some additional arbitrary html
matches = file_str.scan(/^\s*#\s*(@tm-html)\s+(.+)$/)
if matches.length > 0
  print <<HTML
  <div id = "tm_webpreview_content">
    <div class="executor">
          <div id="_executor_output">
  	<h3>tm-html</h3>
HTML
  matches.each do |x|
    print x[1]
  end
  print <<HTML2
  		    </div>
        </div>
      </div>
HTML2
end

# output js traces here
matches = file_str.scan(/^\s*-js?\s+([\w+\.\/]+)/)
if matches.length > 0


    print <<JS1
    <div id = "tm_webpreview_content">
      <div class="executor">
        <pre>
            <div id="_executor_output">
			<h3>JS Output </h3>

			<div id='haxe:trace'></div>
JS1
  matches.each{|x|
    js_file = "#{ENV['TM_PROJECT_DIRECTORY']}/#{x}"
    print "<h3>JS File Location: <a href=file://#{js_file}>#{js_file}</a></h3>"
    print "<script language='javascript' src='file://#{js_file}'></script>"
}
print <<JS2
		 </div>
        </pre>
      </div>
    </div>
JS2

  
end








# output swf traces here
matches = file_str.scan(/^\s*-swf9?\s+([\w+\.\/]+)/)
matches.each{|x|
  if (x[0].match(/^\//))
    swf_file = x[0]
  else
    swf_file = "#{ENV['TM_PROJECT_DIRECTORY']}/#{x[0]}"
  end
  print <<SWF
  <div id = "tm_webpreview_content">
    <div class="executor">
      <pre>
          <div id="_executor_output">
              <h3>SWF Output: <a href=file://#{swf_file}>#{swf_file}</a></h3>
              <embed src="file://#{swf_file}" width="550" height="400"></embed>
          </div>
      </pre>
    </div>
  </div>
SWF
}





#!/usr/bin/env ruby -wKU
# encoding: utf-8

# Utility module which collects together common tasks used by commands within the
# Haxe Bundles.
#
module HaxeMate

	class << self

		# ==================
		# = TEXTMATE UTILS =
		# ==================

		# Make sure an environment variable is set.
		#
		def require_var(evar)
			unless ENV[evar]

				TextMate::HTMLOutput.show(:title => "Missing Environment Variable", :sub_title => "" ) do |io|

					io << '<h2>Environment var missing</h2>'
					io << "<p>Please define the environment variable <code>#{evar}</code>.<br><br>"
					io << configuration_help()
					io << "</p>"

				end

			end
		end

		# Make sure a file exists at the defined location.
		#
		def require_file(file)
			unless File.exist?(file)

				TextMate::HTMLOutput.show(:title => "File not found", :sub_title => "" ) do |io|

					io << "<h2>#{file} 404</h2>"
					io << "<p>The environment variable <code>#{file}</code> does not resolve to an actual file.<br><br>"
					io << configuration_help()
					io << "</p>"

				end

			end
		end

		# Preferences window
		#

		# Checks that the supplied environmental variables and files that they point
		# to exist. When they don't a html window is invoked and each failure is
		# listed.
		#
		def required_settings(settings={})

			failed_evars = []
			failed_files = []
			
			base_path = settings[:base_path] || ''
			files = settings[:files] || []
			evars = settings[:evars] || []

			files.each { |f|				
				failed_files << f unless ENV[f]
				failed_files << f unless File.exist?( base_path + '/' + ENV[f].to_s || "" )
			}

			evars.each { |e|
				failed_evars << e unless ENV[e]
			}

			unless failed_evars.empty? && failed_files.empty?

				TextMate::HTMLOutput.show(:title => "Missing Settings", :sub_title => "" ) do |io|

					io << "<h2>Missing Settings</h2>"

					failed_files.each { |f| io << "<p>The environment variable <code>#{f}</code> does not resolve to an actual file.<br>" }
					failed_evars.each { |e| io << "<p>The environment variable <code>#{e}</code> was not defined.<br>" }

					io << '<br/>'+configuration_help

				end

				TextMate.exit_show_html

			end

		end

		# Returns html link to configuration help.
		#
		def configuration_help
			"Configuration help can be found <a href='tm-file://#{e_url(ENV['TM_SUPPORT_PATH'])}/html/help.html#conf'>here.</a>"
		end

		# As many of the commands only work from a project scope this runs a check
		# that TM_PROJECT_DIRECTORY exist before continuing.
		#
		def require_tmproj

			unless ENV['TM_PROJECT_DIRECTORY']
				TextMate.exit_show_tool_tip "This Command should only be run from within a saved TextMate Project."
			end

		end
		
		# When using fcsh a path will fail if it contains a space.
		#
		def check_valid_paths(paths)
			
			paths.each { |p|
				if p =~ /\s/
				
					TextMate::HTMLOutput.show(:title => "FCSH Path Error", :sub_title => "" ) do |io|

						io << "<h2>FCSH Path Error</h2>"
						io << "<p>Warning fsch cannot handle paths containing a space."
						io << " "
						io << "/path_to/app.mxml works"
						io << "/path to/app.mxml fails as there is a space between path and to"
						io << " "
						io << "The path that caused the problem was"
						io << " "
						io << "#{p}"
						io << " "
						io << "See bundle help for more information."		
						io << "</p>"

					end
				
				end
			}
			
		end
		

		
		# =================
		# = SNIPPET UTILS =
		# =================

		# Converts Haxe method paramaters and 'snippetises' them for use
		# with TextMate.
		#
		def snippetize_method_params(str)
			i=0
			str.gsub!( /\n|\s/,"")
			str.gsub!( /([a-zA-Z0-9\:\.\*=]+?)([,\)])/ ) {
				"${" + String(i+=1) + ":" + $1 + "}" + $2
			}
			str
		end

		# ===============
		# = UI + DIALOG =
		# ===============

		# Show a DIALOG 2 tool tip if dialog 2 is available.
		# Used where a tooltip needs to be displayed in conjunction with another
		# exit type.
		#
		def tooltip(message)

			return unless message

			if has_dialog2
				`"$DIALOG" tooltip --text "#{message}"`
			end

		end

		# Invoke the completions dialog.
		#
		# This method is a customised version of the complete method found in ui.rb
		# in the main support folder. It double checks incoming data, links
		# images to Dialog 2 and automatically snippetizes output when a method is
		# selected by the user.
		#
		def complete(choices,filter=nil,exit_message=nil, &block)

			TextMate.exit_show_tool_tip("Completions need DIALOG2 to function.") unless self.has_dialog2

			if choices[0]['display'] == nil
				puts "Error, was expecting Dialog2 compatable data."
				exit
			end

      # self.register_completion_images

			pid = fork do

				STDOUT.reopen(open('/dev/null'))
				STDERR.reopen(open('/dev/null'))

				command = "#{TM_DIALOG} popup --returnChoice"
				command << " --alreadyTyped #{e_sh filter}" if filter != nil
				command << " --additionalWordCharacters '_'"

				to_insert = ''
				result    = nil

				::IO.popen(command, 'w+') do |io|
					io << { 'suggestions' => choices }.to_plist
					io.close_write
					result = OSX::PropertyList.load io rescue nil
				end

				# Use a default block if none was provided
				block ||= lambda do |choice|

					suffix = choice['data'].sub!( "#{choice['match']}", '')
					suffix = self.snippetize_method_params(suffix)
					suffix += ";" if choice['typeof'] == "void"

				end

				# The block should return the text to insert as a snippet
				to_insert << block.call(result).to_s

				# Insert the snippet if necessary
				`"$DIALOG" x-insert --snippet #{e_sh to_insert}` unless to_insert.empty?

				self.tooltip(exit_message)

			end

		end

		# Returns true if Dialog 2 is available.
		#
		def has_dialog2
			tm_dialog = e_sh ENV['DIALOG']
			! tm_dialog.match(/2$/).nil?
		end

		# ======================
		# = SYSTEM/ENVIRONMENT =
		# ======================

		# Returns true if OS X 10.5 (Leopard) is available.
		#
		def check_for_leopard

			os = `defaults read /System/Library/CoreServices/SystemVersion ProductVersion`

			return true if os =~ /10\.5\./
			return false

		end

		# =======================
		# = Project Preferences =
		# =======================
    
    def get_hxml(use_existing = true, completion=false)

      require 'tempfile'  
      pd = ENV['TM_PROJECT_DIRECTORY']
      tmbuild =   pd + '/.tmbuild'
      
      
      # existing tmbuild file
      if File.exists?(tmbuild) && use_existing && File.exists?(IO.read(tmbuild))
        project_build = IO.read(tmbuild)
        return project_build if !IO.read(project_build).match('--next')

      # existing build.hxml file (default)
      elsif File.exists?(pd +'/build.hxml') && use_existing
        tmfile = File.open(tmbuild,'w')
        tmfile.write(pd +'/build.hxml')
        project_build = pd + '/build.hxml'
        return pd +'/build.hxml' if !IO.read(pd +'/build.hxml').match('--next')
      # neither
      else 

        finder = "find \"#{pd}\" -name *.hxml"
        hxmls = `#{finder}`.split("\n")
        hxmls.map!{|n| n.slice!(pd.length+1,n.length)}
        hxmls.reject!{|n| n.match(/\.tm-autocomplete.hxml/)}
        hxmls.reject!{|n| n.match(/\.haxedoc\/haxedoc.hxml/)}
        TextMate.exit_show_tool_tip("No hxml found anywhere in the project directory. Project directory is #{pd}.") if hxmls.length == 0
        project_build = TextMate::UI.request_item(
          :title => "Select HXML",
          :prompt => "Select an HXML file for this project:",
          :items => hxmls,
          :button1 => 'Select'
        ) 
        f = File.open(pd + '/.tmbuild','w')
        f.write(pd+'/'+project_build)
      end


      return project_build if !completion
      
      # if the selected build files contain '--next' commands, this handles them
      # as a separate hxml file.
      hxml_blocks = IO.read(project_build).split("--next")
      auto = hxml_blocks.select{|x| x.match('\n\s*-D\s*tm-autocomplete')}[0]
      auto = hxml_blocks[0] if auto == nil
      completion_build = File.open(pd+'/.tm-autocomplete.hxml',"w")
      completion_build.write(auto)
      completion_build.close()
      return completion_build.path
    end
    
    # get -lib and -cp dirs from the hxml file
    def get_hxml_dirs(hxml_file, cp = true, lib = true)
      file_str = hxml_file.split("\n")
      results = Array.new
      file_str.each{|x|
        matches = x.match(/^\s*((-cp)|(-lib))\s+([\w\/"'-_]+)/)

        if matches
          if (matches[1] == '-cp' && cp) || (matches[1] == '-lib' && lib)
            results.push(matches[4])
          end       
        end 
      }

      return results

    end

		# ====================
		# = User Popreferences =
		# ====================

		def get_preference(key)
			p = self.preferences
			p.transaction { p[key] }
		end

		def set_preference(key,value)
			p = self.preferences
			p.transaction { p[key] = value }
		end

		def preferences
			require "pstore"
			PStore.new(File.expand_path( "~/Library/Preferences/com.macromates.textmate.flexmate"))
		end

	end

end

if __FILE__ == $0

  #   require "../flex_env"
  # 
  # puts "\nsnippetize_method_params:"
  # puts FlexMate.snippetize_method_params( "method(one:Number,two:String,three:*, four:Test=10, ...rest)")
  # puts FlexMate.snippetize_method_params( "method(one:Number,
  #                       two:String,
  #                         three:*,
  #                           four:Test, ...rest);")
  # 
  # #TODO/FIX: Following line fails.
  # puts FlexMate.snippetize_method_params( "method(zero:Number,four:String=\"chalk\",six:String=BIG_EVENT,three:Boolean=true)")
  # 
  # print "\ncheck_for_leopard: "
  # puts FlexMate.check_for_leopard
  # 
  # FlexMate.tooltip("Test Message")
  # 
  # puts "\nhas_dialog2:"
  # puts FlexMate.has_dialog2.to_s

	#ENV['TM_FLEX_FILE_SPECS'] = '/Users/simon/Desktop/golf_plus.xml'
	#ENV['TM_FLEX_OUTPUT'] = '/Users/simon/Desktop/golf_plus.swf'
	#
	#v = ['TM_FLEX_OUTPUT']
	#f = ['TM_FLEX_FILE_SPECS']
	#s = { :files => f, :evars => v }
	##s = {}
	#
	#FlexMate.required_settings(s)


end

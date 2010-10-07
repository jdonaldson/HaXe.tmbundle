#!/usr/bin/env ruby -wKU
# encoding: utf-8

# Used as a common require to set up the environment for commands. 

SUPPORT = "#{ENV['TM_SUPPORT_PATH']}"
#BUN_SUP = File.expand_path(File.dirname(__FILE__))

$: << File.expand_path(File.dirname(__FILE__))
#$: << File.expand_path("#{ENV['TM_SUPPORT_PATH']}")



require SUPPORT + '/lib/escape'
require SUPPORT + '/lib/exit_codes'
require SUPPORT + '/lib/textmate' 
require SUPPORT + '/lib/ui'
require SUPPORT + '/lib/tm/htmloutput'

require 'hm/haxe_mate'
require 'hm/template_machine' #Used

# require 'hx/completions/completions_list' #Only used by AutoComplete
require 'hx/templates/snippet_builder'
require 'hx/templates/snippet_controller'
require 'hx/templates/snippet_provider'

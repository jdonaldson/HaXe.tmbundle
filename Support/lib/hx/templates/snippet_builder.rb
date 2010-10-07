#!/usr/bin/env ruby -wKU
# encoding: utf-8

require "erb"

# HaXe snippet builder. Separates the construction of snippets 
# from their representation so the same construction process can create 
# different representations.
#
require 'date'
class SnippetBuilder
  
	private

	def initialize(tp=nil)
		@hx_doc = ENV['TM_HXDOC_GENERATION']
		@t = tp ? tp : SnippetProvider.new
	end

	public
	
	# =========
	# = HXDoc =
	# =========
	
	def doc(tag,check_doc=false)

		return "" if check_doc && include_docs == false

		b = binding
		d = File.read(@t.doc)
		t = ERB.new(d)
		t.result b

	end

	def class_doc(class_name = '', check_doc=false)

		return "" if check_doc && include_docs == false
    
		full_name = ENV['TM_FULLNAME']
    # date = `date +%d.%m.%Y`.chop
    date = Date.today.to_s
		b = binding
		d	= File.read(@t.class_doc)
		t = ERB.new(d)
		t.result b

	end
  
	# ===========
	# = Methods =
	# ===========

	def method(name="name",ns="public",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.method)
	end

	def o_method(name="name",ns="public",doc_tag="inheritDoc")
		generate_method(name,ns,doc_tag,@t.o_method)
	end

	def getter(name="name",ns="public",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.get)
	end

	def setter(name="name",ns="public",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.set)
	end

	def i_getter(name="name",ns="public",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.i_get)
	end

	def i_setter(name="name",ns="public",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.i_set)
	end

	def i_method(name="name",ns="public",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.i_method)
	end
  
	def var(name="name",ns="public",doc_tag="private")
		if ns == "public"
			generate_method(name,ns,doc_tag,@t.property)
		else
			generate_method(name,ns,doc_tag,@t.var)
		end
	end
  
  def f_method(name="name",ns="final",doc_tag="private")
		generate_method(name,ns,doc_tag,@t.method)
  end

	# =============================
	# = Package, Interface, Class =
	# =============================

	def class(name="NewClass",ns="public")
		generate_class(name,ns,@t.class)
	end

	def interface(name="NewClass",ns="public")
		generate_class(name,ns,@t.interface)
	end
  
	def f_class(name="NewClass",ns="final")
		generate_class(name,ns,@t.class)		
	end

	private
	
	def include_docs
		@hx_doc ? true : false
	end
	
	def generate_method(name,ns,doc_tag,file=nil)

		return "ERROR" unless file

    name = "name" if name.empty?

		hxdoc = doc(doc_tag,true)

		b = binding
		d = File.read(file)
		t = ERB.new(d)
		t.result b

	end

	def generate_class(name,ns,file=nil)

		fn = ENV['TM_FILENAME']
		name = File.basename(fn,".hx") if fn != nil

		hxdoc = class_doc(true)
		doc = doc("constructor",true)

		b = binding
		d = File.read(file)
		t = ERB.new(d)
		t.result b

	end

end

if __FILE__ == $0

	ENV['TM_HXDOC_GENERATION'] = "true"
  # ENV['TM_FILENAME'] = "/test/path/to/src/DummyClass.as"

	t = SnippetBuilder.new

	puts t.interface
	puts t.class
	puts t.f_class
	puts t.method
	puts t.method('custom','protected','testing')
	puts t.o_method
	puts t.getter
	puts t.setter
	puts t.i_getter
	puts t.i_setter
	puts t.i_method
	puts t.var
	puts t.var('private')
	puts t.const   
	puts t.f_method

end

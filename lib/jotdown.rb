# frozen_string_literal: true

require_relative "jotdown/version"

module Jotdown
  class Error < StandardError; end
  class Render
     attr_accessor :next_p, :tokens

     def initialize(source)
       @tokens = []
       @source = source.split("\n")
       @result =[]
       @style  =[]
       @nxt_line = 0
     end

     def start_tokenization
       while @nxt_line <= @source.length
         tokenize(@source[@nxt_line])
         @nxt_line += 1
       end
       [@result.join(" "),@style.join(",")]
     end

     private

     def tokenize(text)
       case text
       when /^[h|H]\d+\./
         header(text)
       when /^table\./
         table(text)
       when /^[p|P]\./
         paragraph(text)
       when /^\*/
         list(text)
       end
     end

     def header(text)
       tag = text.slice!(/^[h|H]\d+/)
       option = text.gsub!(/^\./, "").slice!(/^\{.*\}/)

       @result << "<#{tag} id=\"tag_#{@nxt_line}\">#{text.strip}</#{tag}>"
       @style << "\#tag_#{@nxt_line} #{option} \n"
     end

     def paragraph(text)
       tag = text.slice!(/^[p|P]/)
       option = text.gsub!(/^\./, "").slice!(/^\{.*\}/)

       @result << "<p id=\"tag_#{@nxt_line}\">#{inline_process(text.strip)}</p>"
       @style << "\#tag_#{@nxt_line} #{option} \n"
     end

     def table(text)
       tag = text.slice!(/^table/)
       option = convert_to_hash(text.gsub!(/^\./, "").slice!(/^\{.*\}/))

       head = "<tr>"
       text.split(",").each do |i|
         head << "<th>#{i}</th>"
       end
       head << "</tr>"

       body = []
       option["col"].to_i.times do
         body << "<tr>"
         body << "<td>" + @source[@nxt_line + 1].gsub!(/\,/, "</td><td>") + "</td>"
         body << "</tr>"
         @nxt_line += 1
       end

       table_content = "<thead>" + head + "</thead>" + "<tbody>" + body.join("") + "</tbody>"

       @result << "<table id=\"tag_#{@nxt_line}\">#{table_content}</table>"
       @style << "\#tag_#{@nxt_line} #{option} \n"

     end

     def list(text)
       tmp = Array(text.gsub!(/^\*\s*/,''))
       while @source[@nxt_line + 1] =~ (/^\*/)
         @nxt_line += 1
         tmp << @source[@nxt_line].gsub!(/^\*\s*/,'')
       end

       ul = "<ul id=\"tag_#{@nxt_line}\">"
       tmp.each do |i|
         ul << "<li>#{i}</li>"
       end
       ul << "</ul>"
       @result << ul
     end

     def inline_process(text)
       text.gsub!(/\*\*([^\*]+)\*\*/, '<b>\1</b>')
       text.gsub!(/\_\_([^\_]+)\_\_/, '<i>\1</i>')
       text.gsub!(/\+([^\+]+)\+/, '<ins>\1</ins>')
       text.gsub!(/\^([^\^]+)\^/, '<sup>\1 </sup>')
       text.gsub!(/\?\?([^\?]+)\?\?/, '<sub>\1</sub>')
       text.gsub!(/\~([^\~]+)\~/, '<cite>\1</cite>')
       text.gsub!(/\%([^\%]+)\%/, '<span>\1</span>')
       text.gsub!(/\@([^\@]+)\@/, '<code>\1</code>')
       text.gsub!(/\!\[(.*)\]\((.*)\)/, '<p><img src="\2"/>\1</p>')
       text.gsub!(/\[(.*)\]\((.*)\)/, '<a href="\2">\1</a>')
       # math_tmp =text.slice!(/\$\$(.*)\$\$}/)
       # text.gsub!(/\$\$(.*)\$\$/, inline_math(math_tmp))
       text
     end

     def inline_math(exp)
       formula = Plurimath::Math.parse(exp, :latex)
       formula.to_mathml
     end

     def convert_to_hash(str)
       return unless str.is_a?(String)

       hash_arg = str.gsub(/[^'"\w\d]/, " ").split.map { |x| x.gsub(/['"]/, "") }
       Hash[*hash_arg]
     end
   end




  class Html
     def self.render(content = " ",style = " ",language = "en", title = "index")
       return <<-HTML
       <!DOCTYPE html>
       <html lang="#{language}">
       <head>
         <meta charset="utf-8">
         <meta http-equiv="x-ua-compatible" content="ie=edge">
         <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

         <title>#{title}</title>
         <style>
         #{style}
         </style>
       </head>
       <body>
       #{content}
       </body>
       </html>
       HTML
     end
   end
  
end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |input|
    file_name = input.sub(".jd",".html")
    r,s = Jotdown::Render.new(File.read(input)).start_tokenization
    File.write("#{file_name}", Jotdown::Html.render(r,s))
  end
end
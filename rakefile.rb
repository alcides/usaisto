require "RedCloth"
require 'find'
require 'ftools'
require 'fileutils'
require "erb"

$input_folder = "interviews"
$static_folder = "static"
$output_folder = "usaisto.com"
$template = "templates/interview.html.erb"
$index_template = "templates/index.html.erb"


def titlefy(src)
  src.split("/").last.split(".").slice(0,2).map{ |x| x.capitalize }.join(" ")
end

def linkify(src)
  p = src.split("/").last.split(".").slice(0,2).join(".")
  "http://#{p}.usaisto.com/"
end

def tagify(src)
  f = File.open(src)
  f.readlines.each do |l|
    if l.start_with? "p(summary)."
      return l.sub("p(summary). ","").strip
    end
  end
  ""
end

def datify(src)
    catchy = "<time datetime=\""
  f = File.open(src)
  f.readlines.each do |l|
    if l.start_with? catchy
      return l.sub(catchy,"").split("\"").first.strip
    end
  end
  ""
end


def convert_to_textile(src,dest)
  
  puts "Converting #{src}" if Rake.application.options.trace

  src_file = File.open(src)
  textiled = RedCloth.new src_file.read
  src_file.close
  
  template_file = File.open($template)
  template = template_file.read
  template_file.close
  
  content = textiled.to_html.sub!("src=\"images","src=\"http://usaisto.com/interviews/images")
  title = titlefy src

  html = ERB.new(template).result(binding)
  
  dest_file = File.open( dest ,"w")
  dest_file.write html
  dest_file.close
  
  content
  
end


task :generate_docs do
  
  if not File.directory? $output_folder
    Dir.mkdir $output_folder
    puts "Creating #{$output_folder} directory" if Rake.application.options.trace
  end

  d = Dir.new $output_folder
  
  # delete all files from destiny
  d.each do |file|
    fullfile = File.expand_path(file, d.path)
    
    next if file == '.' or file == '..'
    FileUtils.rm_rf fullfile,  :verbose => Rake.application.options.trace
  end
  
  # Static stuff
  Find.find("./#{$static_folder}/") do |f|
    nf = f.sub($static_folder + "/","")
    copy_file = File.expand_path("#{$output_folder}/#{nf}")
    if File.directory? f
      puts "Creating #{copy_file}" if Rake.application.options.trace
      File.makedirs copy_file
    else
      puts "Copying #{copy_file}" if Rake.application.options.trace
      File.copy(f, copy_file)    
    end
  end
  
  files = []
  contents = Hash.new
  Find.find("./#{$input_folder}/") do |f|
    copy_file = File.expand_path("#{$output_folder}/#{f}")
    
    if f.include? ".textile"
      copy_file.sub!('.textile', '.html')
      files << f
      contents[f] = convert_to_textile f, copy_file
    else
      if File.directory? f
        puts "Creating #{copy_file}" if Rake.application.options.trace
        File.makedirs copy_file
      else
        puts "Copying #{copy_file}" if Rake.application.options.trace
        File.copy(f, copy_file)    
      end
    
    end
  end
  
  d = Dir.new $output_folder
  
  template_file = File.open($index_template)
  template = template_file.read
  template_file.close
  
  html = ERB.new(template).result(binding)
  dest_file = File.open( $output_folder + "/index.html" ,"w")
  dest_file.write html
  dest_file.close
  
  # rss
  
  require 'rss/maker'

  version = "2.0" # ["0.9", "1.0", "2.0"]
  destination = $output_folder + "/feed.xml"

  content = RSS::Maker.make(version) do |m|
    m.channel.title = "Usa Isto.com"
    m.channel.link = "http://usaisto.com"
    m.channel.description = "Entrevistas com os geeks portugueses sobre o que usam para inovar."
    m.items.do_sort = true # sort items by date

    files.each do |f|
      i = m.items.new_item
      i.title = titlefy f
      i.link = linkify f
      i.date = Time.parse(datify(f))
      i.summary = contents[f]
    end
  end

  File.open(destination,"w") do |f|
    f.write(content)
  end
  
  
end

task :deploy do 
  `scp -r usaisto.com vps:sites`
end

task :default => :generate_docs
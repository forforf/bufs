
require File.dirname(__FILE__) + '/bufs_file_system'
require File.dirname(__FILE__) + '/bufs_file_view_reader'
#require File.dirname(__FILE__) + '/files_finder'

#TODO: Update spec to test the individual parts rather than comparing to a known static output
#FIXME: Spec doesn't check for dot files
class BufsViewBuilder
WorkPackage = Struct.new(:working_dir, :nodes)
FilesOfChildrenDirName = "__bfs_AllFiles"
 
  def initialize
    @working_queue = []
    @nodes_with_views = {}
    @model_dir = nil
  end

  def build_view(parent_dir, top_level_nodes, all_nodes, model_dir)
    @model_dir = model_dir
    raise "No nodes found to create view" if top_level_nodes.size == 0
    @all_nodes = all_nodes
    @all_nodes.each do |n|
      print '.'
      print n.my_category if n.attached_files?
    end
    #TODO: Figure out more elegant way than deleting and rebuilding (also see doc on rm_rf)
    dirs_to_delete = Dir.glob("#{parent_dir}*") - [@model_dir]
    FileUtils.rm_rf(dirs_to_delete)
    #TODO: Test with various permissions
    FileUtils.mkdir(parent_dir) unless File.exist?(parent_dir) 

    build_view_layer(parent_dir, top_level_nodes)
    add_file_list(parent_dir)
    add_html_links(parent_dir)
  end

  def build_view_layer(parent_dir, nodes)
    puts "Building Layer with:"
    nodes.each do |node|
      puts "-- #{node.my_category}"
    end
    #assumes parent dir already exists
    nodes.each do |node|
      puts "iterating over nodes to build view"
      this_dir = parent_dir + '/' + node.my_category
      if @nodes_with_views[node] #view already created for node
	puts "- node view already created"
        add_repeated_view_entry(this_dir, node)
      else
	puts "- new node view for #{node.my_category}"
        @nodes_with_views[node] = this_dir
        work_package = add_fresh_view_entry(this_dir, node)
	puts "-- work package: #{work_package.working_dir.inspect}" if work_package
	if work_package
	  work_package.nodes.each do |n|
	    puts "--- node:#{n.my_category}"
	  end
        end
        @working_queue << work_package if work_package
      end
    end
    next_layer = @working_queue.shift
    #view_of_files_from_subdirs(parent_dir)
    build_view_layer(next_layer.working_dir, next_layer.nodes) if next_layer
  end

  def add_fresh_view_entry(this_dir, node)
    FileUtils.mkdir_p(this_dir) unless File.exist? this_dir
    puts " --- file?: #{node.attached_files?.inspect}"
    if node.attached_files?
      node.list_attached_files.each do |att_full_filename|
        att_basename = File.basename(att_full_filename)
        #att_full_filename may == model_file_location
        puts "Attachment Names"
        puts "-- From Node: #{att_full_filename.inspect}"
        model_file_location = @model_dir + node.my_category + '/' + att_basename
        puts "-- Created Here: #{model_file_location}"
        this_link_name = this_dir + '/' +  att_basename
        puts "---> Linked #{model_file_location.inspect}"
        puts "---> Link Name #{this_link_name.inspect}"
        FileUtils.ln_s(model_file_location, this_link_name) unless File.exist?(this_link_name)
      end
    end
    if node.list_links
      html_link = node.list_links.map {|link| "<a href=\"#{link}\">#{link}</a>"}
      html_str = html_link.join("<br />")
      File.open("#{this_dir}/links.html", 'w') {|f| f.write(html_str)}   
    end
    #TODO: Refactor this and base models so that links, description are arbitrary data
    #      rather than the data structure being hard coded and hard managed like here
    if node.description
      File.open("#{this_dir}/.description.txt", 'w') {|f| f.write(node.description)}
    end
    sub_nodes = @all_nodes.select{ |n|n.parent_categories.include? node.my_category }
    work_package = WorkPackage.new(this_dir, sub_nodes) if sub_nodes && sub_nodes.size > 0
  end  

  def add_repeated_view_entry(this_dir, node) #don't create work_package
    puts "--- Creating Link #{this_dir} -> #{@nodes_with_views[node]}"
    if File.dirname(this_dir) == @nodes_with_views[node]
      raise "Trying to recreate self, this dir: #{this_dir.inspect}, node dir: #{@nodes_with_views[node]}"
    end
    FileUtils.remove_dir(this_dir) if File.exists?(this_dir)
    FileUtils.ln_s(@nodes_with_views[node], this_dir)
  end

  #TODO: Deal with duplicate file names
  def add_file_list(dir)
    file_list = BufsFileViewReader.new(dir).file_list
    file_list.each do |file_model, view_dirs|
      view_dirs.each do |view_dir|
        FileUtils.mkdir(view_dir) unless File.exists?(view_dir)
        lnk_name = File.join(view_dir, File.basename(file_model))
        FileUtils.ln_sf(file_model, lnk_name) unless File.exists?(lnk_name)
      end
    end
  end

  #DRY this with add_file_list

  def add_html_links(dir)
    html_links = BufsFileViewReader.new(dir).html_link_list
    html_links.each do |view_dir, html_links|
      FileUtils.mkdir(view_dir) unless File.exists?(view_dir)
      #links_fname = File.join(view_dir, File.basename(file_model))
      #TODO Make the magic string into a constant
      link_fname =File.join(view_dir, 'all_links.html')
      link_data = html_links.join("<br />\n")
      File.open(link_fname,'w'){|f| f.write link_data} #unless File.exists?(lnk_name)
    end
  end
=begin
    #remove existing 
    #existing = Dir.glob(File.join(dir, "**/#{FilesOfChildrenDirName}"))
    #existing.each do |d|
    #  FileUtils.rm_rf(d)
    #end    
    files_finder = FileFinder.new
    all_child_files = files_finder.find_files(dir)
    #raise all_child_files.inspect
    child_dir = File.join(dir, FilesOfChildrenDirName)
    FileUtils.mkdir(child_dir) unless File.exist?(child_dir)
    all_child_files.each do |fname, linkname|
      #TODO: Fix this so it isn't forced 
      FileUtils.ln_sf(fname, File.join(child_dir, linkname)) if linkname
    end
=end
end

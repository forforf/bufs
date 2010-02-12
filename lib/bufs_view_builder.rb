
require File.dirname(__FILE__) + '/bufs_file_system'

class BufsViewBuilder
WorkPackage = Struct.new(:working_dir, :nodes)
 
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
    FileUtils.rm_rf(parent_dir)
    FileUtils.mkdir(parent_dir)

    build_view_layer(parent_dir, top_level_nodes)
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
    build_view_layer(next_layer.working_dir, next_layer.nodes) if next_layer
  end

  def add_fresh_view_entry(this_dir, node)
    FileUtils.mkdir_p(this_dir) unless File.exist? this_dir
    puts " --- file?: #{node.attached_files?.inspect}"
    if node.attached_files?
      node.attached_files.each do |att_full_filename|
        att_basename = File.basename(att_full_filename)
        #att_full_filename may == model_file_location
        puts "Attachment Names"
        puts "-- From Node: #{att_full_filename.inspect}"
        model_file_location = @model_dir + node.my_category + '/' + att_basename
        puts "-- Created Here: #{model_file_location}"
        this_link_name = this_dir + '/' +  att_basename
        FileUtils.ln_s(model_file_location, this_link_name) unless File.exist?(this_link_name)
      end
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
end

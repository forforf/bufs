require File.join(File.dirname(__FILE__), 'grapher')
RootNode = Struct.new(:my_category, :parent_categories)

class BufsFileViewMaker
  LinksFileName = "links.html"
  AllFilesInTreeDirName = "borged_files"
  AllLinksInTreeFileName = "borged_links.html"
  attr_accessor :tree, :tree_data, :root_node, :base_dir
  
  def initialize(user_id, node_list, base_dir)
    @base_dir = base_dir
    @root_node= RootNode.new(user_id, [])
    @all_nodes = node_list
    @keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
    graph_type = :tree
    #@tree = Grapher.new(node_list, keys, :tree, root_data)
    
    #nodes_with_root = @all_nodes
    #nodes_with_root << root_node if root_node
    
    @tree_data = Grapher.new(@all_nodes, @keys, graph_type, @root_node).graph_data
    @tree = @tree_data[:graph]
    
  end
  
  #convert this maker's tree into a file system
  def make_file_view(base_dir = @base_dir)
    @node_map = {}
    @files_in_tree = {}
    @files_in_subdirs = {}
    @links_in_tree = {}
    @links_data = {}
    
    tw_root_node = @tree.detect{|n| true}
    #TODO: fix to work with a specified key, rather than hardcoded
    top_nodes = @tree.adjacent_vertices(tw_root_node)
    top_nodes.each do |n|
      build_static_node_view(n, base_dir)
    end
    
    #convert from node name to file system location as key for the file lists
    #require 'pp'
    #pp @files_in_tree    
    
    create_file_accumulators(@tree)

    create_links_accumulators(@tree)
    
    @tree.vertices.each do |n|
      next if n.is_root_node
      build_linked_node_view(n, base_dir)
    end
  end
  
  def build_static_node_view(node, parent_dir)
    puts "Node (Static): #{node.node_name}"

    #make directory
    node_dir = File.join(parent_dir, node.node_name)
    #puts "Making Node Dir: #{node_dir}"
    FileUtils.mkdir_p(node_dir)
    #update the node map
    @node_map[node.node_name] = node_dir

    create_attached_files(node, node_dir)

    create_link_data_and_file(node, node_dir)
    
    #all files in subdirs
    #TODO: make the file search more efficient 
    #a tree 3 layers down is iterated over 3 separate times to get
    #the same files
    subtree = @tree.bfs_search_tree_from(node)
    subtree_files = find_all_files_in_tree(subtree)
    subtree_links = find_all_links_in_tree(subtree)
    #require 'pp'
    #pp subtree_files
    
    @files_in_tree[node] = subtree_files
    @links_in_tree[node] = subtree_links

    
    #recurse through the descendants
    static_children = node.normal_descendants
    #puts " --> static children: #{static_children.map{|c| c.node_name}.inspect}"
    static_children.each do |child|
      next unless node
      build_static_node_view(child, node_dir)
    end
  end
  
  def create_attached_files(node, node_dir)
    #puts "Filename to write:"
    attached_files = node.node_content.attached_files
    attached_files = attached_files || [] 
    attached_files.each do |f|
      fname = File.join(node_dir,f)
      data = node.node_content.get_raw_data(f)
      File.open(fname, "w"){|fn| fn.write(data)}
    end    
  end
  
  def create_link_data_and_file(node, node_dir)
        #create files for links
    links = node.node_content.links
    link_data = create_links_file(links)
    #puts link_data
    if link_data
      links_filename = File.join(node_dir, LinksFileName)
      File.open(links_filename, 'w'){|f| f.write(link_data)}
    end
  end

  def find_all_files_in_tree(tree)
    #format of file list {dir to put all files in => files}
    #files_list = {}
    #TODO: Create a generic function that can be used for files and bufs web UI
    #returns list of file paths (not compatible with web UI)
    tree.vertices.map{|v| {v => v.node_content.attached_files} }.compact
  end

  def find_all_links_in_tree(tree)
    #format of file list {dir to put all files in => files}
    #files_list = {}
    #TODO: Create a generic function that can be used for files and bufs web UI
    #returns list of file paths (not compatible with web UI)
    tree.vertices.map{|v| {v => v.node_content.links} }.compact
  end

  def create_links_file(links)
    link_file_data = ""
    return nil unless links
    #links format {"http:\\dest.com" => "label"}
    
    links.each do |url, label|
      next unless ( url || label) 
      #link.each do |url, label|
        #htmlify the data
        link_html = "<a href='#{url}'>#{label}</a>\n"
        link_file_data << link_html
      #end
    end
    link_file_data
  end
  
  def create_file_accumulators(tree)
    #iterate through the tree
    tree.vertices.each do |v|
      next if v.is_root_node
      all_files_dir_name = AllFilesInTreeDirName
      #directory for the current node we're iterating on
      node_dir = @node_map[v.node_name]
      raise "Can't find directory for Node: #{v.node_name}" unless node_dir
      raise "Can't find node dir: #{node_dir.inspect}" unless File.exist?(node_dir)
      #directory to put accumulated files
      all_files_dir = File.join(@node_map[v.node_name], all_files_dir_name)
            
      subtree_files_kvp = @files_in_tree[v]    #@files_in_tree.each do |top_tw_node, subtree_files_kvp|
        #node_to_nodes_with_attached_files = node_to_nodes_with_attached_files || {}
        #node_to_nodes_with_attached_files.each do |top_node, tw_node_with_files|
      next unless subtree_files_kvp
        subtree_files_kvp.each do |tw_nodes_with_files|
          #puts "tw_node"
          #tw_node.each do |k,v|
          #  puts "Key Class: #{k.class}"
          #  puts "Val Class: #{v.class}"
          #end
          tw_nodes_with_files.each do |tw_node, attached_file_names|
            node = tw_node.node_content
            attached_files = attached_file_names || []
            #puts "attached files: #{attached_files.inspect}"
            if attached_files.empty?
              #no need to make dir
            else
              FileUtils.mkdir(all_files_dir) unless File.exist?(all_files_dir)
            end
            attached_files.each do |att_name|
              path_name = File.join(all_files_dir, att_name)
              #puts "node: #{node.my_category} fname: #{att_name.inspect}"
              File.open(path_name, 'w'){|f| f.write(node.get_raw_data(att_name))}
            end #each attached_files
          end#each tw_nodes_with_files
        end#each subtree_files_kvp
      #end
      #@files_in_subdirs[@node_map[v.node_name]] = @files_in_tree[v.node_name]
    end #each tree_vertices
    #require 'pp'
    #puts "Files in Subdirs"
    #pp @files_in_subdirs
  end#def

  
  def create_links_accumulators(tree)
    #iterate through the tree
    
    tree.vertices.each do |v|
      @links_data = []  #FIXME:Change this to local variable  
      next if v.is_root_node
      all_links_file_name = AllLinksInTreeFileName
      #directory for the current node we're iterating on
      node_dir = @node_map[v.node_name]
      raise "Can't find directory for Node: #{v.node_name}" unless node_dir
      raise "Can't find node dir: #{node_dir.inspect}" unless File.exist?(node_dir)
      #directory to put accumulated files
      all_links_file_path = File.join(@node_map[v.node_name], all_links_file_name)
           
      subtree_nodes_with_links = @links_in_tree[v]    #@files_in_tree.each do |top_tw_node, subtree_files_kvp|
        #node_to_nodes_with_attached_files = node_to_nodes_with_attached_files || {}
        #node_to_nodes_with_attached_files.each do |top_node, tw_node_with_files|
      next unless subtree_nodes_with_links
          subtree_nodes_with_links.each do |node_with_link_data|
          #puts "node_with_link_data"
          node_with_link_data.each do |k,v|
            puts "Key Class: #{k.node_name}"
            puts "Val Class: #{v.inspect}"
          end
          next unless node_with_link_data
          node_with_link_data.each do |tw_node, link_data|
            next unless link_data
            puts "Merge: #{@links_data.inspect} with #{link_data.inspect}"
            @links_data += link_data.to_a
            @links_data.uniq!
            puts "Result: #{@links_data.inspect}"
            #link_data.each do |url, label|
              
              #node = tw_node.node_content
              
              #link_html_data = "<a href='#{url}'>#{label}</a>\n"
    
              #attached_files = attached_file_names || []
              #puts "attached files: #{attached_files.inspect}"
            #  puts "opening: #{all_links_file_path}   to add:"
            #  puts link_html_data
            #  if url || label
            #    File.open(all_links_file_path, 'a'){|f| f.write(link_html_data)}
            #  end
              #attached_files.each do |att_name|
                
              #  path_name = File.join(all_files_dir, att_name)
                #puts "node: #{node.my_category} fname: #{att_name.inspect}"
                
               # File.open(path_name, 'w'){|f| f.write(node.get_raw_data(att_name))}
              #end
            #end
          end
        end
      #end
      #@files_in_subdirs[@node_map[v.node_name]] = @files_in_tree[v.node_name]
      #puts "Node: #{v.node_name}: Links: #{@links_data}"
      links_html_ary = @links_data.map{|url_label| "<a href='#{url_label[0]}'>#{url_label[1]}</a>"}
      #puts "Links Html Array: #{links_html_ary.inspect}"
      links_html = links_html_ary.join("\n")
      #puts links_html

      #write it to file
      if links_html_ary && links_html_ary.size > 0
        File.open(all_links_file_path,'w'){|f| f.write(links_html)}
      end
    end
    
    #require 'pp'
    #puts "Files in Subdirs"
    #pp @files_in_subdirs
  end
  
  def build_linked_node_view(node, parent_dir)
    #puts "Build Node View -----------------"
    #puts "Node (Check for links): #{node.node_name}"
    node_dir = File.join(parent_dir, node.node_name)
    #puts "LINK to: #{node_dir}"
    linked_children = node.linked_descendants
    #puts " --> linked children: #{linked_children.map{|c| c.node_name}.inspect}"
    linked_children.each do |child|
      next unless node
      #puts "---building link"
      dest = @node_map[child.node_name]
      #puts "     link_dest: #{dest.inspect}"
      link_name = File.join(@node_map[node.node_name], child.node_name)
      #puts "   ^---- link name: #{link_name.inspect}"
      #puts "making link in 10 seconds"
      #10.times do
      #  print "."
      #  sleep 1
      #end
      #puts ""
      if File.exist?(dest) && File.exist?(link_name) && File.readlink(link_name) == dest
        #skip making the link
      elsif File.exist?(dest) && File.exist?(link_name) && File.readlink(link_name) != dest
        raise "Error creating a new link with the same name, but different destination file"
      elsif File.exist?(dest) &&!File.exist?(link_name)
        FileUtils.ln_s(dest, link_name)
      elsif !File.exist?(dest)
        raise "Unable to link to file: #{dest} destination file doesn't exist"  #ln_s would raise error too
      else
        raise "Unknown file linking error. Link Name:#{link_name} Target File: #{dest}"
      end
      #raise "Dest: #{dest} Link: #{link_name} ReadLink: #{File.readlink(link_name).inspect}" if File.exist?(File.join(@base_dir, "b/ba/ba"))
      build_linked_node_view(child, node_dir)
    end
  end  

  
  
end


=begin
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
    node_links = node.list_links
    if node_links
      #html_link = node.list_links.map {|link| "<a href=\"#{link}\">#{link}</a>"}
      #html_str = html_link.join("<br />")
      html_link = ""
      html_str = ""
      node_links.keys.each do |src|
        node_links[src].uniq!
      end
      node_links.each do |src, labels|
        #next unless labels
        labels.each do |label|
          html_link = "<a href=\"#{src}\">#{label}</a><br />\n"
          html_str += html_link
        end
      end
      File.open("#{this_dir}/links.html", 'w') {|f| f.write(html_str)}   
    end
    #TODO: Refactor this and base models so that links, description are arbitrary data
    #      rather than the data structure being hard coded and hard managed like here
    if node.respond_to?(:description) && node.description
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
      #raise "#{html_links.inspect}"
      link_data = ""
      html_links.each do |src, labels|
        labels.each do |label|
          link_el = "<a href=\"#{src}\">#{label}</a><br />"
          link_data += link_el + "\n"
        end
      end
      #link_data = html_links.join("<br />\n")
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
#=end
end
=end

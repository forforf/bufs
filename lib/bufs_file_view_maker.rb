#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require Bufs.lib 'grapher'
#RootNode = Struct.new(:my_category, :parent_categories)

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
  
  #TODO: Works, but needs optimization and refactoriation
  def build_static_node_view(node, parent_dir)
    #make directory
    node_dir = File.join(parent_dir, node.node_name)
    FileUtils.mkdir_p(node_dir)
    #update the node map
    @node_map[node.node_name] = node_dir

    create_attached_files(node, node_dir)
    create_link_data_and_file(node, node_dir)

    #TODO: make the file search more efficient 
    #a tree 3 layers down is iterated over 3 separate times to get
    #the same files
    
    #borg assimilates all node elements at the current node and below
    #works with directed graphs with cycles as well
    borg = Borg.new(@all_nodes, @keys)  #Borg is part of grapher
    subtree_files = borg.ify(node, :attached_files)
    subtree_links = borg.ify(node, :links)

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

  def create_links_file(links)
    link_file_data = ""
    return nil unless links
    #links format {"http:\\dest.com" => "label"}
    
    links.each do |url, labels|
      next unless ( url || labels) 
      #link.each do |url, label|
        #htmlify the data
        #FIXME: This is a hack to avoid changing data structure
        #which constructively adds, but now only want to replace
        #puts "Creating Links File with #{labels.inspect}"
        if labels.respond_to?(:join)
          label = labels.join(",")
        else
          label = labels
        end
        #puts "Creating Link File with #{label.inspect}"
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
      
      #FIXME: 
            
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
            #puts "Key Class: #{k.node_name}"
            #puts "Val Class: #{v.inspect}"
          end
          next unless node_with_link_data
          node_with_link_data.each do |tw_node, link_datas|
            next unless link_datas
            link_data = {}
            #FIXME: Ugly hack to deal with string and array data structures
            link_datas.each do |k,v|
              if v.respond_to?(:join)
                link_data[k] = v.join(",")
              else
                link_data[k] = v
              end              
            end#each

            #puts "Link Data class: #{link_data.class.name}"
            #puts "Merge: #{@links_data.inspect} with #{link_data.inspect}"
            @links_data += link_data.to_a
            @links_data.uniq!
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
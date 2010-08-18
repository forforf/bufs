require 'hpricot'
require 'tree'
#require File.dirname(__FILE__) + '/bufs_file_system'

#opening up tree node for new method for finding nodes
class Tree::TreeNode

  def find_nodes(node_name)
    #finds all nodes in order of closest to root
    found = []
    self.breadth_each do |node|
      puts "#{node.name} <-> #{node_name}"
      found << node if node.name == node_name
    end
    found
  end
  
  #TODO: Add to Spec
  def breadth_each_reverse(node=self)
    node_list = []
    node.breadth_each {|node| node_list << node}
    node_list.reverse
  end
end

class BufsFileViewReader
WorkPackage = Struct.new(:paths, :parent_node)
#TODO: move ignore list to be more like apache, git, etc
IgnoreList =  [/^__bfs*/] #[/^links\.html/, /^__bfs*/]

  def initialize(view_root_dir)
    @tree = nil
    @work_list = []
    build_tree(view_root_dir)
  end

  def in_ignore_list?(f)
    rtn = false
    IgnoreList.each do |regex|
      rtn = rtn||(File.basename(f) =~ regex)
    end
    rtn
  end

  def build_tree(top_dir)
    view_tree = Tree::TreeNode.new(top_dir)
    top_dir_glob = File.join(top_dir, "*")
    top_level_paths = Dir.glob(top_dir_glob)
    build_tree_layer(top_level_paths, view_tree)
    @tree = view_tree
  end

  def build_tree_layer(layer_paths, node_to_build_under)
    layer_paths.delete_if {|f| in_ignore_list?(f)}
    layer_paths.each do |path|
       raise "Path: #{path.inspect}" if File.dirname(path) =~ /^\./
       add_content_to_node(path, node_to_build_under) if File.stat(path).file?
       if File.stat(path).directory?
         new_node = add_node_to_tree(path, node_to_build_under)
         add_sub_paths_to_work_list(path, new_node) if new_node
       end
    end
    next_work = @work_list.shift
    next_paths = next_work.paths if next_work
    node_over_paths = next_work.parent_node if next_work
    build_tree_layer(next_paths, node_over_paths) if next_work
  end

  def add_content_to_node(fname, tree_node)
    if File.basename(fname) =~ /^links\.html$/
      add_link_to_node(fname, tree_node)
    else
      add_file_to_node(fname, tree_node)
    end
  end

  #TODO Needs to be added to spec
  def add_link_to_node(link_file, tree_node)
    #raise "adding html link to node: #{link_file}"
    links_to_add = {}
    #File.open(link_file, "r"){|f| f.each_line {|link| html_links_to_add << link}}
    link_file = File.open(link_file, "r"){|f| f.read}
    link_hdoc = Hpricot(link_file)
    (link_hdoc/"a").each do |el|
      src = el[:href]
      label = el.inner_html
      existing_labels = links_to_add[src]
      if existing_labels
        links_to_add[src] << label
      else
        links_to_add[src] = [label]
      end
      links_to_add[src].uniq!
    end
    #raise "#{links_to_add.inspect}"
    #TODO: merging may create a hard to find label bug where some labels disappear, but need to verify if this happens
    if tree_node.content && tree_node.content["html_links"]
      #tree_node.content += links_to_add
      tree_node.content["html_links"].merge(links_to_add)
      
    elsif tree_node.content #hash exists but not links
      tree_node.content["html_links"] = links_to_add
    else
      tree_node.content = {"html_links" => links_to_add}
    end
    #  tree_node.content 
    #end
  end

  def add_file_to_node(fname, tree_node)
    if tree_node.content && tree_node.content["files"]
      tree_node.content["files"] << fname
    elsif tree_node.content #hash exists, but no files
      tree_node.content["files"] = [fname]
    else #content does not exist at all
      tree_node.content = {"files" => [fname]}
    end
  end

  def add_node_to_tree(path, tree_node)
    node_name = File.basename(path)
    parentage = tree_node.parentage || []
    parent_names = parentage.map {|p| p.name}
    new_node = nil
    unless parent_names.include?(node_name)
      new_node = Tree::TreeNode.new(node_name) 
      tree_node << new_node
    end
    #TODO: refactor description, links, attachments to be more clean
    desc_fname = File.join(path, ".description.txt")
    if File.exist? desc_fname
      desc_txt = File.open(desc_fname, 'r'){|f| f.read}
      if tree_node.content
        tree_node.content["description"] = desc_txt
      else
        tree_node.content = {"description" => desc_txt}
      end
    end
    new_node
  end

  def add_sub_paths_to_work_list(parent_path, current_node)
    path_glob = File.join(parent_path, "*")
    paths = Dir.glob(path_glob)
    @work_list << WorkPackage.new(paths, current_node)
  end  

  #or read accessor
  def tree
    @tree
  end

  def print_tree
    @tree.printTree
  end

  def tree_node_path(node=@tree)
    raise "Argument given was nil, not a tree node" unless node
    node_path ="/"
    working_node = node
    until working_node.parent.isRoot?
       node_path = '/' + working_node.name.to_s + node_path
       working_node = working_node.parent
    end
    node_path
  end



  def file_list(node = @tree) #parse tree for files and location
    file_list = {} #links and source
    file_list_dir = "__bufs_All_Files"
    top_link_dir = node.root.name
    #node.breadth_each do |node|
     node.breadth_each_reverse.each do |node|
      if node.isRoot?
        #do nothing #top_link_dir = node.name
      elsif node.content && node.content["files"]
        node.content["files"].each do |cont_fname|
          relative_path = tree_node_path(node)
          link_name = File.join(top_link_dir, relative_path, file_list_dir)
          if File.symlink?(cont_fname)
            src_file = File.readlink(cont_fname)
          elsif File.file?(cont_fname)
            src_file = cont_fname
          else
            src_file = "Not File: #{cont_fname.to_s}"
          end
          existing_links = file_list[src_file]
          #add to file_list for current node
          if existing_links
             file_list[src_file] << link_name#cont_fname
          else
             file_list[src_file] = [link_name]#[cont_fname]
          end
          #add to file list for parent nodes
          node.parentage.each do |node|
            if node.isRoot?
              root_path = File.join(top_link_dir, file_list_dir)
              file_list[src_file] << root_path 
            else #add file to file list for ancestor
              relative_path = tree_node_path(node)
              link_name = File.join(top_link_dir, relative_path, file_list_dir)
              file_list[src_file] << link_name #parent file list
            end
          end
          file_list[src_file].uniq!
        end
      end
      
    end
    file_list
  end

  #TODO: DRY up file_list and html_link_list
  def html_link_list(node = @tree)
    html_link_list = {} #links and source
    html_link_list_dir = "__bufs_All_Links"
    html_links_to_add = nil #may not be necessary
    top_link_dir = node.root.name
    #node.breadth_each do |node|
    node.breadth_each_reverse.each do |node|
      if node.isRoot?
        #do nothing #top_link_dir = node.name
      elsif node.content && node.content["html_links"]
        relative_path = tree_node_path(node)
        view_html_list_dir = File.join(top_link_dir, relative_path, html_link_list_dir)
        existing_list = html_link_list[view_html_list_dir]
        html_links_to_add = node.content["html_links"]
        if existing_list
          #TODO Merge may overwrite existing label data, check to make sure
          html_link_list[view_html_list_dir].merge!(html_links_to_add)
          #html_link_list.merge(html_links_to_add)
          #html_link_list[view_html_list_dir].uniq!
        else
          html_link_list[view_html_list_dir] = html_links_to_add
        end
        #html_link_list[view_html_list_dir].uniq!
        #html_links_to_add.uniq!
=begin
        node.content["files"].each do |cont_fname|
          relative_path = tree_node_path(node)
          link_name = File.join(top_link_dir, relative_path, file_list_dir)
          if File.symlink?(cont_fname)
            src_file = File.readlink(cont_fname)
          elsif File.file?(cont_fname)
            src_file = cont_fname
          else
            src_file = "Not File: #{cont_fname.to_s}"
          end
          existing_links = file_list[src_file]
          #add to file_list for current node
          if existing_links
             file_list[src_file] << link_name#cont_fname
          else
             file_list[src_file] = [link_name]#[cont_fname]
          end
          #add to file list for parent nodes
=end
        node.parentage.each do |node|
          if node.isRoot?
            root_path = File.join(top_link_dir, html_link_list_dir)
            if html_link_list[root_path]
              html_link_list[root_path].merge!( html_links_to_add)
              #html_link_list.merge(html_links_to_add)
            else
              html_link_list[root_path] = html_links_to_add
              #html_link_list = html_links_to_add
            end
            #html_link_list[root_path].uniq!
          else #add file to file list for ancestor
            relative_path = tree_node_path(node)
            view_html_list_dir = File.join(top_link_dir, relative_path, html_link_list_dir)
            if html_link_list[view_html_list_dir]
              html_link_list[view_html_list_dir].merge!(html_links_to_add)
              #html_link_list[view_html_list_dir] += html_links_to_add
              #html_link_list.merge(html_links_to_add)
            else
              html_link_list[view_html_list_dir] = html_links_to_add
              #html_link_list = html_links_to_add
            end
            #html_link_list[view_html_list_dir].uniq!
          end
          #html_link_list[view_html_list_dir].uniq!
        end
      end

    end
    html_link_list
  end

end

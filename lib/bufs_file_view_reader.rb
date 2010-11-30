#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../lib/helpers/require_helper')

require Bufs.helpers 'filesystem_helpers'

require 'hpricot'
#require 'tree'
#require File.dirname(__FILE__) + '/bufs_file_system'


class ProtoNode
  #@@node_list = {}
  
  attr_accessor :_user_data, :files_to_attach, :node_name, :attached_files
    
  def initialize(node_name, entry_data)
    #@entry_datas = entry_data
    raise "invalid node name: #{node_name.inspect}" unless node_name
    @files_to_attach = []
    @node_name = node_name
    my_cat = {:my_category => node_name}
    user_data = entry_data.merge(my_cat)
    @_user_data = user_data
    @attached_files = nil
    update(entry_data)
  end
  
  def update(entry_data)
    entry_data.each do |key, value|
      #update_my_category(key, value) if key == :my_category
      update_parent_categories(key, value) if key == :parent_categories
      update_links(key, value) if key == :linkfile
      update_attachments(key, value) if key == :attached_file
    end
    #@entry_datas.merge(entry_data)
  end  
  
  def update_parent_categories(pc_label, pcs)
    raise "Mismatched labels, :parent_categories and #{pc_label.inspect}" unless pc_label == :parent_categories
    if @_user_data[:parent_categories]
      @_user_data[:parent_categories] += [pcs].flatten
    else
      @_user_data[:parent_categories] = [pcs].flatten
    end
      @_user_data[:parent_categories].uniq!
  end
  
  def update_links(link_label, link_file_name)
    link_file = File.open(link_file_name, "r"){|f| f.read}
    link_hdoc = Hpricot(link_file)
    (link_hdoc/"a").each do |el|
      src = el[:href]
      label = el.inner_html
      if @_user_data[:links]
        @_user_data[:links].merge( {src => label} )
      else
        @_user_data[:links] = { src => label }
      end
    end
  end
  
  def update_attachments(att_label, filename)
    @files_to_attach << filename
  end
end

class ProtoNodeCollection
  attr_accessor :node_list, :node_class
  
  def initialize(node_list = {})
    @node_class = ProtoNode
    @node_list = node_list
  end
  
  def update_node(node_name, entry_data)
    if @node_list[node_name]
      @node_list[node_name].update(entry_data)
    else
      @node_list[node_name] = @node_class.new(node_name, entry_data)
    end
  end
  
  def all_nodes
    @node_list
  end
end

class BufsFileViewReader
  attr_accessor :build_list
  
  URLFile = "links.html"

  def initialize(top_dir=nil, user_node_class)
    @top_dir = top_dir
    @dirf= DirFilter.new([/^borg/, /Dropbox/])
    @node_grp = ProtoNodeCollection.new
    @user_node_class = user_node_class
  end
  
  def read_view(top_dir = @top_dir)
    init_nodes = @dirf.filter_entries(top_dir)
    parent_path = top_dir
    parse_directory(init_nodes, parent_path)
    #puts "All Nodes: #{@node_grp.all_nodes.inspect}"
    @node_grp.all_nodes.each do |node_name, proto_node|
      #make bufs node
      node = @user_node_class.__create_from_other_node(proto_node)
      node.__save
      proto_node.files_to_attach.each do |fname|
        node.files_add( {:src_filename => fname } )
      end
    end
  end
  
  private
  
  def parse_directory(node_names, parent_path)
    node_names.each do |node_name|
      build_node(node_name, parent_path)
    end
  end
  
  def build_node(node_name, parent_path)
    #Need something to check if node already exists or not
    parent_cat = File.basename(parent_path)
    @node_grp.update_node(node_name, {:parent_categories => [parent_cat]} )
    this_dir = File.join(parent_path, node_name)
    this_entries = @dirf.filter_entries(this_dir)
    evaluate_entries(this_entries, this_dir, node_name)
  end
  
  def evaluate_entries(entries, current_dir, node_name)
    entries.each do |entry|
      parent_name = File.basename(current_dir)
      path = File.join(current_dir, entry)
      if entry == URLFile
        #file with list of links
        linkfile_name = File.join(current_dir, entry)
        @node_grp.update_node(node_name, {:linkfile => linkfile_name} )
      elsif File.ftype(path) == "link"
        #it's a symlink to main node
        @node_grp.update_node(entry, {:my_category => entry, :parent_categories => [parent_name]} )
      elsif File.ftype(path) == "file"
        filename = File.join(current_dir, entry)
        @node_grp.update_node(node_name, {:attached_file => filename} )
      elsif File.ftype(path) == "directory"
        #puts "Do this again for #{entry}"
        build_node(entry, current_dir)
      else
        raise "Unknown File type, path: #{path} filename: #{entry}"
      end#if (entry type)
    end#each (entries)
  end#def
end

#ANSrcLocation = '/media-ec2/ec2a/projects/bufs/src/'

#TestDirBaseLocation = 'C:/Documents and Settings/dmartin/My Documents/tmp/'

require File.dirname(__FILE__) + '/bufs_file_system'
require File.dirname(__FILE__) + '/bufs_info_doc'
#require ANSrcLocation + 'bufs_info_file_view_builder.rb'




class AbstractNode
  #include Comparable
  #class << self 
  #  attr_accessor :node_models
  #end

  NodeModels = [BufsInfoDoc, BufsFileSystem]
  #AbstractNodeClasses = {'BufsInfoDoc' => DBDocNode, 'BufsFileSystem' => FileSystemDocNode }

  attr_accessor :my_category, :parent_categories, :description, :file_metadata, :node_model

  #TODO: Change Abstract Node name to align with Model name, to allow dynamic additions
  def self.create(node)
    case node.class.to_s
      when 'BufsInfoDoc'
        return DBDocNode.new(node)
      when 'BufsFileSystem'
        return FileSystemDocNode.new(node)
      else
        raise "Abstract Node could not create node, unknown Node Type of: #{node.class.to_s.inspect}"
    end
  end

  def self.all
    abstract_node_list = []
    NodeModels.each do |node_class|
      node_class.all.each do |node|
        abstract_node_list << [node.my_category, AbstractNode.create(node)]
      end
    end
    return abstract_node_list
  end

  def self.sync(nodes)
    abstract_node_classes = {'BufsInfoDoc' => DBDocNode, 'BufsFileSystem' => FileSystemDocNode } #figure out better way
    #validate that cat is the same for all nodes or is nil
    #non_nil_nodes = nodes.select {|n| n}
    node_my_cats = (nodes.map{|n| n.my_category if n}).compact.uniq
    raise "Can't find any node categories" if node_my_cats.size < 1
    raise "Only a single node category is allowed for sync, multiple found" if node_my_cats.size > 1
    my_cat = node_my_cats.first
    
    #determine node classes for any nil nodes by deleting known classes from supported classes
    unless nodes.size == nodes.compact.size
      available_node_classes = NodeModels.dup  #is dup necessary?
      nodes.each do |node|
        available_node_classes.delete(node.node_model.class) if node
      end
      #available_node_classes now contains models that didn't match any nodes
      #match nil items to available node classes
      nil_nodes = nodes.select{|n| n.nil?}
      raise "Empty Nodes does not match available models" unless nil_nodes.size == available_node_classes.size
      #think about ways to allow mis-matched sizes
      puts "--- creating new model in sync"
      nodes.map! do |node|
        if node
          node
        else
          model_node = available_node_classes.pop.new({:my_category => my_cat, :parent_categories => ['synced']})
          model_node.save
          abstract_node_class = abstract_node_classes[model_node.class.to_s]
          abstract_node_class.new(model_node)
        end
      end
    end
    puts "--- nodes:"
    nodes.each {|n| p n}
    #merge parent categories
    puts "--- merging parent categories"
    all_parent_categories = []
    nodes.each do |node|
      all_parent_categories += node.parent_categories if node
    end
    merged_parent_categories = all_parent_categories.uniq
    nodes.each do |node|
      node.add_parent_categories(merged_parent_categories)
    end

    #update to latest data for all nodes
    puts "Nodes: #{nodes.size}"
    p nodes
    file_comparison = []
    nodes.each do |node|
      file_comparison << node.file_metadata
    end
    file_comparison.uniq!
    puts "Compared Nodes: #{file_comparison.size}"
    
    #spin this into a different method
    #self.merge_files(nodes) if file_comparison.size > 1  #files out of sync
    puts "--- file comparison"
    p file_comparison.size
    if file_comparison.size > 1
      freshest_data_node_index = nil
      freshest_data_time = Time.at(0)
      freshest_file_name = nil
      freshest_metadata = nil

      puts "node classes: #{nodes.each{|n| p n.class}}"
 
      nodes.each_with_index do |node, i|
        #iterate over attached data (should only be one item)
        if node.file_metadata
          puts "node file metadata: #{node.file_metadata.inspect}"
          node.file_metadata.each do |dataname, md|
            mod_time = Time.parse(md['file_modified'])
            if mod_time > freshest_data_time
              freshest_data_node_index = i
              freshest_data_time = mod_time
              freshest_file_name = dataname
              freshest_metadata = node.file_metadata
            end
          end
        else
          puts "No Metadata found for node: #{node.inspect}"
        end
      end
 
      puts "--- updating nodes"    
      freshest_node = nodes[freshest_data_node_index]
      nodes_to_update = nodes.dup #may not need to dup
      nodes_to_update.delete_at(freshest_data_node_index)
      nodes_to_update.each do |stale_node|
        puts "--- retrieving updated data from #{freshest_node.class} - #{freshest_node.my_category}"
        puts "--- using: #{freshest_file_name}"
        freshest_data = freshest_node.get_file_data(freshest_file_name)
        puts "--- updating node: #{stale_node.class}  with retrieved data"
        stale_node.update_file_content(freshest_file_name, freshest_data, freshest_metadata)
      end
    end
  end

  def initialize(node)
    @node_model = @node = node
    @my_category = node.my_category
    @parent_categories = node.parent_categories
    @description = node.description
    @file_metadata = nil  # {fname -> {metadata fields -> metadata values}}
  end

  def save
    @node.save
  end

  def add_parent_categories(parent_categories)
    @node.add_parent_categories(parent_categories)
  end

  def get_file_data(*args)
    #returns attachment/file data
    raise "Called an abstracted method that has not beein initialized in subclass"
  end

  def update_file_content(*args)
    raise "Called an abstracted method that has not beein initialized in subclass"
  end

  def same_node_reference(other_node)
    if self.my_category == other_node.my_category
      return true
    else
      return false
    end
  end

  #override equality so we can tell when two nodes are equivalent
  def eql?(other)
    self.hash == other.hash
  end

  def hash
    equiv_attrib = [self.my_category, self.parent_categories.sort, self.file_metadata]
    #puts "Hash created from #{equiv_attrib.inspect}"
    return equiv_attrib.hash
  end

  def ==(other)
    self.eql?(other)
  end

end

class DBDocNode < AbstractNode

  def self.by_my_category(cat_name)
    bids = BufsInfoDoc.by_my_category(cat_name)
    raise "Database has duplicate categories of #{cat_nam}" unless bids.size == 1
    bid = bids.first
    db_doc = self.new(bid)
  end

  def initialize(node)
    super(node)
    bia = BufsInfoAttachment.get(node.attachment_doc_id)
    #what about content_type? is that included?
    @file_metadata = bia['md_attachments'] if bia
    #if @file_metadata.class == Hash   #is there a better way to ensure a hash of nils is nil?
    #  @file_metadata = nil unless @file_metadata.keys.inject(0) {|r, k|  k||r}
    #end
  end
 
  def get_file_data(file_name)
    @node.get_file_data(file_name)
    #return CouchDB.fetch_attachment(@node, file_name)
  end

  def update_file_content(file_name, raw_data, metadata)
    content_type = metadata[file_name]['content_type']
    modified_time = metadata[file_name]['modified_time']
    @node.add_raw_data(file_name, content_type, raw_data, modified_time)
  end

end

class FileSystemDocNode < AbstractNode

  def self.by_my_category(cat_name)
    bfs = BufsFileSystem.by_my_category(cat_name)
    fs_doc = self.new(bfs)
  end

  def initialize(node)
    super(node)
    if node.filename || node.file_metadata
      raise "Can not initialize #{self.class} without filename" unless node.filename
      @file_metadata = {node.filename => node.file_metadata}
    else
      @file_metadata = nil
    end
  end

  def get_file_data(file_name)
    @node.get_file_data  #currently this node can only hold a single file
  end

  def update_file_content(file_name, raw_data, metadata)
    #raise "multiple file attachments not supported yet" unless file_name == my_cat
    my_cat = self.my_category
    md = self.file_metadata
    puts "FSDoc medatata: #{metadata.inspect}"
    #TODO: Fix it so content type is reliably passed as metadata
    content_type = metadata[file_name]['content_type'] || nil
    modified_time = metadata[file_name]['file_modified']
    puts "updating file contents in BufsFSDoc"
    #TODO: This method is slightly different thatn the DBDocNode one, rationalize them
    @node.add_raw_data(file_name, my_cat, raw_data, modified_time)
  end
end 

=begin
class SyncNode < AbstractNode
  attr_accessor :file_node, :dbdoc_node

  def initialize(node_a, node_b = nil)
    raise "It doesn't make sense to sync nodes of the same type" if node_a.class == node_b.class
    @sync_nodes = [node_a, node_b]
    @file_node = nil
    @dbdoc_node = nil
    @sync_nodes.each do |unknown_node_type|
      node_type = unknown_node_type.class.to_s
      case node_type
        when 'FileSystemDocNode'
          @file_node = unknown_node_type
        when 'DbDocNode'
          @dbdoc_node = unknown_node_type
        else
          raise "Unknown Node Type: #{unknown_node_type.class.inspect}"
      end
    #compare nodes, and update to be identical
    end
  end

  def save
    @sync_nodes.each do |node|
      node.save
    end
  end

  def merge_nodes(nodes = @sync_nodes)
    #make sure all nodes have the same my_category value
    my_cats = nodes.map{|node| node.my_category}
    merged_my_cats = my_cats.uniq
    raise "Merging nodes with differing my_category values" if merged_my_cats.size > 1
    my_cat = merged_my_cats.first

    #merge parent categories
    all_parent_categories = []
    nodes.each {|node| all_parent_categories += node.parent_categories}
    merged_parent_categories = all_parent_categories.uniq
    nodes.each {|node| node.parent_categories = merged_parent_categories}
    
    #does any node have file data?
    #file_present = nodes.inject(nil) { |f, node| f = f||node.file_metadata }
    #find latest metadata
    latest_node = nil
    latest_modified_time = Time.at(0)  #file modified times can't be older than this!
    nodes.each do |node|
      if node.file_metadata
        file_mod_time = Time.parse(node.file_metadata(my_cat)['file_modified'])
        if file_mod_time > latest_modified_time
          latest_node = node
          latest_modified_time = file_mod_time
        end
      end
    end 

    #c
    nodes.each do |node|
      if node.file_metadata
        file_mod_time = Time.parse(node.file_metadata(my_cat)['file_modified'])
        if file_mod_time < latest_modified_time
          node.file_metadata = latest_node.file_metadata

          #This needs updated methods in the respective subclasses
          node.update_file_content(latest_node.get_file_data)
        end
      end
    end
  end

  def get_file_data_from_node(node = @sync_nodes.first) 
    if node.file_metadata
      node.get_file_data(first_node.my_category)
    else
      nil
    end
  end
=end


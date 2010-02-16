#ANSrcLocation = '/media-ec2/ec2a/projects/bufs/src/'

#TestDirBaseLocation = 'C:/Documents and Settings/dmartin/My Documents/tmp/'

require File.dirname(__FILE__) + '/bufs_file_system'
require File.dirname(__FILE__) + '/bufs_info_doc'
#require ANSrcLocation + 'bufs_info_file_view_builder.rb'

class ReadOnlyNode
  #abstract class for all read only nodes
  #TODO: Change this to an include rather than 
  #force an arbitrary inheritance
  def my_category
    raise "#{self.class}.my_category is abstract and must be overridden in a sub-class"
  end

  def parent_categories
    raise "#{self.class}.parent_categories is abstract and must be overridden in a sub-class"
  end

  def file_metadata
    raise "#{self.class}.file_metadata is abstract and must be overridden in a sub-class"
  end

  def get_file_data(file_name)
    raise "#{self.class}.get_file_data is abstract and must be overridden in a sub-class"
  end
end


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

  #sync methods
  def self.validate_nodes(nodes)
       #validate that my_category is the same for all nodes or is nil
    node_my_cats = (nodes.map{|n| n.my_category if n}).compact.uniq
    raise "Can't find any node categories" if node_my_cats.size < 1
    raise "Only a single node category is allowed for sync, multiple found" if node_my_cats.size > 1
    @my_cat = node_my_cats.first

    #validate that there no node classes are duplicated
    #no nils, so everything must be uniq
    node_classes = nodes.map{|n| n.class}
    node_classes.uniq!
    raise "Node Classes are not unique" unless nodes.size == node_classes.size

    #validate that only known node classes are used
    nodes.each do |node|
      if (node.class != DBDocNode) && (node.class != FileSystemDocNode)
        unless node.class.ancestors.include? ReadOnlyNode
          raise "Unknown Node Type: #{node.class}"
        end
      end
    end

    #each node is of a unique class of one of the known node classes
    return @my_cat
  end 

  #Not implmented yet.  Current sync approach will overwrite any nodes not explicilty
  #passed to the sync function, that have the same category.
  #This may be desirable in some cases, and not in others
  def self.sync_newest(nodes)
    my_cat = self.validate_nodes(nodes)  #this isn't the DRYest approach
  end

  def self.sync(nodes) #, read_only_nodes=[])
    #future: allow choosing of which nodes can by synced
    #for now, all supported node types will by synced (node types not
    #supplied will be created and synced to freshest node supplied)
    
    #all_nodes = nodes + read_only_nodes

    #ignore null values
    nodes.compact!

    #These are the node types that will be created when the node is not provided
    abstract_node_classes = {'BufsInfoDoc' => DBDocNode, 'BufsFileSystem' => FileSystemDocNode } #figure out better way

    my_cat = self.validate_nodes(nodes)
=begin
    #validate that my_category is the same for all nodes or is nil
    node_my_cats = (nodes.map{|n| n.my_category if n}).compact.uniq
    raise "Can't find any node categories" if node_my_cats.size < 1
    raise "Only a single node category is allowed for sync, multiple found" if node_my_cats.size > 1
    my_cat = node_my_cats.first

    #validate that there no node classes are duplicated
    #no nils, so everything must be uniq
    node_classes = nodes.map{|n| n.class}
    node_classes.uniq!
    raise "Node Classes are not unique" unless nodes.size == node_classes.size

    #validate that only known node classes are used
    nodes.each do |node|
      if (node.class != DBDocNode) && (node.class != FileSystemDocNode)
	unless node.class.ancestors.include? ReadOnlyNode
	  raise "Unknown Node Type: #{node.class}"
	end
      end
    end

    #each node is of a unique class of one of the known node classes
=end    

    #merge parent categories
    puts "--- merging parent categories"
    all_parent_categories = []
    nodes.each do |node|
      all_parent_categories += node.parent_categories if node
    end
    merged_parent_categories = all_parent_categories.uniq


    #nodes.each do |node|
    #  node.add_parent_categories(merged_parent_categories) unless node.class.ancestors.include? ReadOnlyNode
    #end


    #compare file data
    #check to see if there is any new file data
    #is this superfluous since files aren't updated if the data is older anyway???
    puts "Nodes: #{nodes.size}" #" Read Only Nodes #{read_only_nodes.size}"
    p nodes
    file_comparison = []
    nodes.each do |node|
      file_comparison << node.file_metadata  if node
    end
    file_comparison.uniq!
    puts "Compared Nodes: #{file_comparison.size}"
    
    #if all nodes have the same file data, then no file updates are needed
    #Note: ReadOnly complicates things slightly since it can have old file information
    #which will trigger an update, even though none of the updatable nodes were outdated
    #
    #spin this into a different method?
    #if file_comparison.size > 1  => files out of sync
    

    freshest = {}
    puts "--- file comparison"
    
    puts "Nodes Size: #{nodes.size}, NodeModel Size: #{NodeModels.size}, File comparison: #{file_comparison.size}"
    #if file_comparison.size > 1
      freshest[:node_index] = nil
      freshest[:time] = Time.at(0)
      freshest[:file_name] = nil
      freshest[:metadata] = nil

      puts "node classes: #{nodes.each{|n| p n.class}}"
 
      nodes.each_with_index do |node, i|
        #iterate over attached data (should only be one item)
        if node.file_metadata
          puts "node file metadata: #{node.file_metadata.inspect}"
          node.file_metadata.each do |dataname, md|
            mod_time = Time.parse(md['file_modified'])
            if mod_time > freshest[:time]
              freshest[:node_index] = i
              freshest[:time] = mod_time
              freshest[:file_name] = dataname
              freshest[:metadata] = node.file_metadata
              freshest[:node] = node
            end
          end
        else
          puts "No Metadata found for node: #{node.inspect}"
        end
      end
    #end

    #update nodes

    #determine nodes to update
    #don't need read only nodes, but we do need to add any missing node types
    nodes_to_update = nodes.dup
    updated_nodes = []
    node_models_available = NodeModels.dup

    #delete read only nodes
    nodes_to_update.delete_if {|n| n.class.ancestors.include? ReadOnlyNode}

    #need to add in any missing node classes that should be synced
    nodes_to_update_classes = nodes_to_update.map{|n| n.node_model.class}
    puts "--updating nodes"
    #TODO Fix Hack because using == threw an error about comparing classes to each other
    unless nodes_to_update_classes.size ==  node_models_available.size  #no missing node types
      puts "---adding missing node types"
      nodes_to_update.each do |node|
        node_models_available.delete(node.node_model.class) if node
      end
      #node_models_available now contains model classes that didn't match any nodes
      p node_models_available
      puts "--- creating new model of missing type(s)"
      #TODO: Think about creating a node "sync_#{Time.now}"  with parent_category of 'synced'
      
      node_models_available.each do |missing_node_class|
        model_node = missing_node_class.new({:my_category => my_cat, :parent_categories => ['systag-synced']})
        model_node.save
        abstract_node_class = abstract_node_classes[model_node.class.to_s]
        nodes_to_update << abstract_node_class.new(model_node)
      end
    end
    puts "--- nodes to update:"
    nodes_to_update.each {|n| p n}



    puts "--- updating nodes"
    updated_nodes << freshest[:node] if freshest[:node]
    #freshest_node = freshest[:node]
    #puts "----freshest node: #{freshest_node}"
    nodes_to_update.each do |stale_node|
      puts "---- updating parent categories"
      p stale_node
      stale_node.add_parent_categories(merged_parent_categories)
      #stale_node.save
      p stale_node
      puts "---- updating file from freshest node:"
      p freshest
      if freshest[:node] && freshest[:node].file_metadata
        freshest_node = freshest[:node]
        puts "----- updating metadata"
        stale_node.file_metadata = freshest_node.file_metadata
        puts "----- retrieving updated data from #{freshest_node.class} - #{freshest_node.my_category}"
        puts "----- using: #{freshest[:file_name]} metadata: #{freshest[:metadata]}"
        freshest_data = freshest_node.get_file_data(freshest[:file_name])
        puts "----- updating node: #{stale_node.class}  with retrieved data: #{freshest[:metadata]}"
	#puts "------  data: #{freshest_data.inspect}"
        stale_node.update_file_content(freshest[:file_name], freshest_data, freshest[:metadata])
      end
      puts "---- finished updating node"
      p stale_node
      stale_node.save
      updated_nodes << stale_node
    end
    return updated_nodes
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

  def remove_parent_categories(categories_to_remove)
    #NodeModels.each do |node|
    # node.remove_parent_categories(categories_to_remove)
    #end
  end

  def destroy_node
    @node.destroy_node
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

  def inspect
   "<#{self.class}:#{self.hash}> \n my_category: #{self.my_category.inspect}\n parent_categories: #{self.parent_categories.inspect}\n  file_metadata: #{self.file_metadata.inspect}" 
  end


  #override equality so we can tell when two nodes are equivalent
  def eql?(other)
    self.hash == other.hash
  end

  def hash
    parent_cats_wo_systag = self.parent_categories.dup
    parent_cats_wo_systag.delete_if {|cat| cat.match(/^systag-.*/)}
    equiv_attrib = [self.my_category, parent_cats_wo_systag.sort, self.file_metadata]
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



require File.dirname(__FILE__) + '/abstract_node'


module AddNameSpace
  def full_name_space
    self.class.to_s
  end
end

module NodeComparisonOperations

  def merge_parent_categories(nodes)
    all_parent_categories = []
    nodes.each do |node|
      all_parent_categories += node.parent_categories if node
    end
    return all_parent_categories.uniq
  end

  def data_in_sync?(nodes, data_name) #TODO Change method name to compare_file_metadata
    comparison = []
    nodes.each do |node|
      comparison << node.__send__(data_name.to_sym) if node
    end
    comparison.uniq!
    if comparison.size == 1
      return true
    elsif comparison.size > 1
      return false
    else
      raise "No values found found for #{comparison.inspect}"
    end
  end

  def file_data_in_sync?(nodes)
    data_in_sync?(nodes, :file_metadata)
  end

  def node_with_freshest_file_data(nodes)
    freshest = {}
    freshest[:node_index] = nil
    freshest[:time] = Time.at(0)
    freshest[:file_name] = nil
    freshest[:metadata] = nil

    nodes.each_with_index do |node, i|
      #iterate over attached data 
      if node.file_metadata
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
        #puts "No Metadata found for node: #{node.inspect}"
      end
    end
    return freshest
  end
end

class SyncNode
  include NodeComparisonOperations
#create class instance variable
  #that will contain the set of nodes to by synced across
  #must have independent namespaces ... but how to distinguish 
  #between them? (was using different classes before) so that
  #when a node is passed into the sync functions, all other node types
  #are updated.  Maybe dynamic class names?
  #For now, only seperate classes are supported (not individual namespaces)
  
  #I don't think this is thread safe :(
  #move to an object instance?  Test thouroughly if you do
  #sync_set_types hold the AbstractNode derived classes (ie DbDocNode, FileSystemDocNode)
  class << self
    attr_accessor :sync_set_types, :sync_set_reverse_lookup #oops set as in math, not set as in assign change
    SyncNode.sync_set_types = nil
    SyncNode.sync_set_reverse_lookup = {}
  end

  attr_accessor :my_category, :parent_categories, :description, :synced_nodes

  def self.set_sync_set_types(abstract_node_classes)
    abstract_node_classes.each do |an_class|
      SyncNode.sync_set_reverse_lookup[an_class.base_model_class] = an_class
      SyncNode.sync_set_types = abstract_node_classes
    end
  end

  def initialize(nodes_to_keep_in_sync)
    @synced_nodes = []
    raise ArgumentError, "Cannot sync nil" if nodes_to_keep_in_sync == nil
    raise NameError, "The set of node types (classes) has not been set" unless SyncNode.sync_set_types
    @synced_nodes = [nodes_to_keep_in_sync].flatten!  #allows a single node to be passed without array wrapper
    @synced_nodes.compact! #ignore null values
    self.validate_synchronizable(@synced_nodes)
    @my_category = self.validate_node_categories(@synced_nodes)
    @parent_categories = self.merge_parent_categories(@synced_nodes)
    nodes_to_sync = self.normalize_syncable_node_list(@synced_nodes, @my_category)
    freshest_file_data = self.node_with_freshest_file_data(nodes_to_sync)
    @synced_nodes = self.sync_nodes(@synced_nodes, freshest_file_data)
  end

  def validate_node_categories(nodes)
    raise ArgumentError, "Nodes to validate cannot be nil" if nodes == nil
           #validate that my_category is the same for all nodes or is nil
    node_my_cats = (nodes.map{|n| n.my_category if n}).compact.uniq
    raise ArgumentError, "Can't find any node categories" if node_my_cats.size < 1
    raise ArgumentError, "Only a single node category is allowed for sync, multiple found" if node_my_cats.size > 1
    @my_cat = node_my_cats.first
  end

  def validate_synchronizable(nodes)
    #validate that there no node classes are duplicated
    #no nils, so everything must be uniq
    #node_classes = nodes.map{|n| n.class}
    #node_classes.uniq!
    #raise "Node Classes are not unique" unless nodes.size == node_classes.size

    #validate that only known node classes and unique name spaces are used
    nodes.each do |node|
      begin
        node.full_name_space
      rescue
        AddNameSpace.__send__(:extend_object, node) #creates name space based on class name
      end

      raise NoMethodError, "#{node.class} does not respond to 'full_name_space'" unless node.full_name_space
      read_only_class = node.class if node.class.ancestors.include? ReadOnlyNode
      valid_classes_to_sync = [AbstractNode, read_only_class] + SyncNode.sync_set_types 
      unless valid_classes_to_sync.include?(node.class)#was SyncNode.sync_set_types.include?(node.class)    #was (node.class != DBDocNode) && (node.class != FileSystemDocNode)
        #unless node.class.ancestors.include? ReadOnlyNode
          raise TypeError, "Unknown Node Type: #{node.class}"
        #end
      end
    end
    name_spaces = nodes.map{|n| n.full_name_space}
    name_spaces.uniq!
    raise TypeError, "Name spaces were not unique across all nodes to by synced" unless nodes.size == name_spaces.size

    #each node is of a unique class of one of the known node classes
    return @my_cat
  end

  #this method will build the set of nodes that need to be
  #synchronized.  It will create missing nodes and ignore
  #read only nodes
  def normalize_syncable_node_list(nodes, node_category)
    nodes_to_update = nodes.dup #to avoid clobbering node data
    node_models_available = []
    #FIXME: The below is based on unique classes per model (no namespace support)
    SyncNode.sync_set_types.each do |an_concrete_class|
      raise "No base model class found for #{an_concrete_class.inspect}" unless an_concrete_class.base_model_class
      node_models_available << an_concrete_class.base_model_class
    end
    
    #remove read-only nodes from the update list
    nodes_to_update.delete_if{|n| n.class.ancestors.include? ReadOnlyNode}
    
    nodes_to_update_classes = nodes_to_update.map{|n| n.node_model.class}
    puts "Nodes to Update Classes: #{nodes_to_update_classes.inspect}"
    puts "Node Models Available: #{node_models_available.inspect}"

    #TODO: Fix so that it's assured that there's a 1:1 match between nodes and available classes
    # note that == for classes does not work, so I'll probably have to convert to string or something
    unless nodes_to_update_classes.size == node_models_available.size #no missing node types
      nodes_to_update.each do |node|
        node_models_available.delete(node.node_model.class) if node
      end
      #node_models_available now contains model classes that didn't match any nodes
      p node_models_available
      puts "--- creating new model of missing type(s)"
      #TODO: Think about creating a node "sync_#{Time.now}"  with parent_category of 'synced'

      node_models_available.each do |missing_node_class|
        model_node = missing_node_class.new({:my_category => node_category, :parent_categories => ['systag-synced']})
        model_node.save
	puts "Reverse Lookup Hash: #{SyncNode.sync_set_reverse_lookup.inspect}"
        abstract_node_class = SyncNode.sync_set_reverse_lookup[model_node.class]
        nodes_to_update << abstract_node_class.new(model_node)
      end
    end
    puts "--- nodes to update:"
    nodes_to_update.each {|n| p n}
    return nodes_to_update
  end

  def sync_nodes(nodes_to_update, freshest)
    updated_nodes = []
    freshest[:node].add_parent_categories(@parent_categories) if freshest[:node]
    updated_nodes << freshest[:node] if freshest[:node] 
    #freshest_node = freshest[:node]
    #puts "----freshest node: #{freshest_node}"
    nodes_to_update.each do |stale_node|
      puts "---- updating parent categories"
      p stale_node
      stale_node.add_parent_categories(@parent_categories)
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
end

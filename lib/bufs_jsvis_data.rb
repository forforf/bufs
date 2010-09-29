require 'json'
require File.join(File.dirname(__FILE__), 'grapher')
#require File.dirname(__FILE__) + '/bufs_info_doc'

class DefaultNode < Hash
  #TODO This is a bit hackish and really dependent upon the underlying model, decouple if possible
  attr_accessor :parent_categories, :my_category, :description, :_model_metadata
  def initialize(my_cat)
    #self['_id'] = 'dummy_' + my_cat
    @parent_categories = nil
    @my_category = my_cat
    @description = 'This node is organizational only'
    @_model_metadata = {:_id => 'dummy_' + my_cat}
  end
end

RootNode = Struct.new(:my_category, :parent_categories)

class BufsJsvisData
  attr_accessor :graph, :graph_data
  
  #TODO: Rather than using instance variables, pass explicitly
  def initialize(user_id, node_list)
    #user_id.gsub!(/BufsNodeFactory::Bufs(File|InfoNode)/, "") # A bit hacky
    root_node= RootNode.new(user_id, [])
    @all_nodes = node_list
    @keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
    #TODO: To support multiple vis types, have this move to a parameter
    graph_type = :digraph
    @graph_data = Grapher.new(@all_nodes, @keys, graph_type, root_node).graph_data
    @graph = @graph_data[:graph]
    raise "Graph is nil!!!" unless @graph
    #@no_parents = @graph_data[:no_parents]
    parents_to_nodes = @graph.vertices.map{|v| [v.node_content.__send__(@keys[:parent_key]), v]}
    @parent_to_nodes = []
    parents_to_nodes.each do |ps, node|
      ps.each do |p|
        @parent_to_nodes << [p, node]
      end
    end
  end

  #Caller may not have access ruby object structure, so need to use the node_id
  def json_vis_tree(top_node_id, depth)
     all_graph_nodes = {}
     top_nodes_existing = @all_nodes.select{|n| n.__send__(@keys[:node_id_key]) == top_node_id}
     raise "Key: #{@keys[:node_id_key]} is supposed to be unique, found #{top_nodes_existing.size} records" if top_nodes_existing.size > 1
     top_node = top_nodes_existing.first || DefaultNode.new(top_node_id)
     make_jsvis_tree_from_node(top_node, depth)
  end
  
  def make_jsvis_tree_from_node(twnode, depth)
    jsvis_model = {} #JsvisModel.new
  
    return nil if depth < 0
    #TODO Implement a real node id, don't reuse the name
    #something like this: node_id = node._model_metadata[:_id]
    if twnode.class == TreeWrapper
      node = twnode.unwrap
    else
      node = twnode
    end
    jsvis_model['id'] = node.__send__(@keys[:node_id_key])
    jsvis_model['name'] = node.__send__(@keys[:node_id_key])
    #TODO Complete the generalization of this so that custom data can be selected
    jsvis_model['data'] = {}#node.description
    jsvis_model['children'] = get_node_children(node).map {|cn| make_jsvis_tree_from_node(cn, depth-1)}
    jsvis_model['children'].compact!
    jsvis_model
  end

  def get_node_children(node)
    childrens_parent = node.__send__(@keys[:node_id_key])  #I am my childrens' parent
    ch_nodes = @parent_to_nodes.select {|n| n[0] == childrens_parent}.map{|i| i.last}
  end
end

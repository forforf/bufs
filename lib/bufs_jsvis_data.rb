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
  
  def initialize(user_id, node_list)
    #user_id.gsub!(/BufsNodeFactory::Bufs(File|InfoNode)/, "") # A bit hacky
    @root_node= RootNode.new(user_id, [])
    @all_nodes = node_list
    keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
    #TODO: To support multiple vis types, have this move to a parameter
    graph_type = :digraph
    @graph_data = Grapher.new(@root_node, @all_nodes, keys, graph_type).graph_data
    @graph = @graph_data[:graph]
    @no_parents = @graph_data[:no_parents]
  end


  def json_vis(top_node_name, depth)
     puts "TODO: need to support setting user information to top node"
     all_graph_nodes = {}
     pp @graph.vertices.map {|v| v.node_name}
    @graph.vertices.each do |v|
        all_graph_nodes[v.node_name] = v
    end
     top_node = all_graph_nodes[top_node_name] #== @root_node.my_category #a bit hacky
     puts "Top Node:"
     pp top_node
     puts "All Nodes:"
     pp all_graph_nodes.map{|nn,nc| nn}
     bfs = @graph.bfs_iterator(top_node)
     puts "Hello from BFS Iterator"
     bfs.attach_distance_map
     #ts = @graph.topsort_iterator
     nodes_depths = []
     data_bfs = {}  #what kind of data I don't know yet
     jsm = bfs.each do |v|
       puts "I'm on node #{v.node_name} at depth: #{bfs.distance_to_root(v)}"
       data_bfs[v.node_name] = Hash[*(@graph.adjacent_vertices(v).map{|v| v.node_name}.map{|_a| [_a,nil]}).flatten]
       #push each node => children
     end
     puts "BFS Data result"
     pp data_bfs
     jsm = hash_builder(data_bfs)
     pp jsm
     data_dfs = {}
     dfs = @graph.dfs_iterator(top_node)
     dfs.each do |v|
       puts "I'm on node #{v.node_name}"
       data_dfs[v.node_name] = @graph.adjacent_vertices(v).map{|v| v.node_name}
     end
     puts "DFS Data result"
     pp data_dfs
     #examine top
     #populate top data
     #get children
     #for each child populate child data
     #get children
     #for each child
     #populate child data
     
     #bfs.each do |v|
     # id = v id
     # children = v children( v iv, children)
          
  end
  #def json_vis(top_node_parent_cat, depth)
  #  json_vis_nodes = nil
  #  top_node = @nodes_by_cat[top_node_parent_cat]||DefaultNode.new(top_node_parent_cat)
  #  jsm = make_json_vis_from_node(top_node, depth) 
  #end
  
  def make_jsvis_from_node(parent_node, current_node)
=begin
  def make_json_vis_from_node(node, depth, current_model = nil)
    jsvis_model = {} #JsvisModel.new
    #raise node.inspect
    return nil if depth < 0
    #TODO: Figure out a better dummy node than this hack
    node_id = node._model_metadata[:_id]
    jsvis_model['id'] = node.my_category
    jsvis_model['name'] = node.my_category
    jsvis_model['data'] = {}#node.description
    jsvis_model['children'] = get_node_children(node).map {|cn| make_json_vis_from_node(cn, depth-1)}
    jsvis_model['children'].compact!
    return jsvis_model
  end
=end
  end
  def get_category_children_nodes(parent_cat)
    @nodes_by_parent_cat.select{|n| n[0] == parent_cat}.map{|i| i.last}
  end

  def get_node_children(node)
    childrens_parent_category = node.my_category  #I am my childrens' parent
    @nodes_by_parent_cat.select {|n| n[0] == childrens_parent_category}.map{|i| i.last}
  end
end

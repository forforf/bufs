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
    @keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
    #TODO: To support multiple vis types, have this move to a parameter
    graph_type = :digraph
    @graph_data = Grapher.new(@all_nodes, @keys, graph_type, @root_node).graph_data
    @graph = @graph_data[:graph]
    raise "Graph is nil!!!" unless @graph
    @no_parents = @graph_data[:no_parents]
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
     puts "=================="
     p top_node_id
     p top_nodes_existing.map{|n| n.my_category}
     puts "=================="
     make_jsvis_tree_from_node(top_node, depth)
=begin
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
=end          
  end
  #def json_vis(top_node_parent_cat, depth)
  #  json_vis_nodes = nil
  #  top_node = @nodes_by_cat[top_node_parent_cat]||DefaultNode.new(top_node_parent_cat)
  #  jsm = make_json_vis_from_node(top_node, depth) 
  #end
  
  def make_jsvis_tree_from_node(twnode, depth)
    puts "about to make stuff"
    #puts "node children: #{get_node_children(parent_node)}"
   
#=begin
#  def make_json_vis_from_node(node, depth, current_model = nil)
    jsvis_model = {} #JsvisModel.new
    #raise node.inspect
  
    return nil if depth < 0
    #TODO Implement a real node id, don't reuse the name
    #node_id = node._model_metadata[:_id]
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
    return jsvis_model
#  end
#=end
  end
  #def get_category_children_nodes(parent_node) #(parent_cat)
    #p @graph.vertices.map{|v| v.node_name}
    #@nodes_by_parent_cat.select{|n| n[0] == parent_cat}.map{|i| i.last}
  #end

  def get_node_children(node)
     #p @graph.map{|v| v.node_name}
     #p @parent_to_nodes.map{|pn| pn[0]}.first
    childrens_parent = node.__send__(@keys[:node_id_key])  #I am my childrens' parent
    ch_nodes = @parent_to_nodes.select {|n| n[0] == childrens_parent}.map{|i| i.last}
  end
end

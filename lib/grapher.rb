#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require 'rgl/adjacency'
require 'rgl/traversal'
require 'rgl/topsort'
require 'rgl/implicit'
require 'rgl/dot'

require Bufs.lib 'bufs_node_factory'
require Bufs.helpers 'hash_helpers'


#TODO: Find a better place to store this helper (helpers?) (it's used by dependent files)
RootNode = Struct.new(:my_category, :parent_categories)

class TreeWrapper
  attr_accessor :assigned_to_tree, :normal_descendants,
                :linked_descendants, :node_name, :node_content, :node_parents
  attr_reader :is_root_node
                       
  
  def initialize(node_name, node_content = nil, node_parents=[], is_root_node=false)
    @assigned_to_tree = false
    @normal_descendants = []
    @linked_descendants = []
    @node_name = node_name
    @node_content = node_content
    @node_parents = node_parents
    @is_root_node = is_root_node
  end
  
  #TODO: Needs spec
  def unwrap
    self.node_content
  end
  
end

class Borg
  def initialize(node_list, keys)
    @graph_type = :digraph
    @dummy_root = RootNode.new("dummy", [])
    @keys = keys
    @node_list = node_list
  end
  
  #borg.ify
  def ify(top_node, node_element)
    new_grapher = Grapher.new(@node_list, @keys, @graph_type, top_node)

    new_tree_data = new_grapher.graph_data
    new_tree = new_tree_data[:graph]
    
    #Hack until grapher is refactored to use ids rather than full nodes
    top_node = TreeWrapper.new(top_node.my_category, top_node) unless top_node.class == TreeWrapper
    
    base_nodes = new_tree.vertices.select{|v| v.node_name == top_node.node_name}
    raise "Wrong number of key nodes found: #{base_nodes.size} for #{top_node.node_name.inspect}" unless base_nodes.size <= 1
    return nil if base_nodes.size == 0
    
    base_node = base_nodes.first
    #puts "Node: #{base_node.node_name.inspect}"
    #puts "Node Obj: #{base_node.object_id.inspect}"
    
    subtree = new_tree.bfs_search_tree_from(base_node)
#pp subtree.vertices if top_node.node_name == 'bc'
    borged_data  = subtree.vertices.map do |v|
      if (v.node_content && v.node_content.respond_to?(node_element.to_sym) )
        element_content = v.node_content.__send__(node_element.to_sym)
        { v => element_content }
      end
    end
    borged_data.compact!
#pp borged_data if top_node.node_name == 'bc'
    borged_data
    #Verify that this is returning the refined data expected
    #i.e., just the elements, rather than a complex hash
    #subtree_files = find_all_files_in_tree(subtree)
    #subtree_links = find_all_links_in_tree(subtree)
  end
  
end

#opening up tree node for new method for finding nodes
class Grapher
  RootId = :root
  attr_accessor :key, :parent_key,  :graph, :graph_data,
                      :nodes_by_name, :nodes_by_parent_cat, :converted_root_node

  def initialize(node_data, keys, graph_type=:tree, root_node=nil)
    
    #TODO: refactor @root_node -> @native_root_node
    #puts "Grapher Node Data: #{node_data.map{|n| n.my_category}.inspect}"
    @root_node = root_node || RootId
    @key = keys[:node_id_key]
    @parent_key = keys[:parent_key]
    @all_nodes = wrap_nodes(node_data, @key, @parent_key)
    
    #puts "All Nodes Size: #{@all_nodes.size}"
    
    #organize nodes by key like this {node key => node, ... }
    # duplicates model structure, but faster
    @nodes_by_name = organize_by_name(@all_nodes)
    
    #puts "Nodes by Name: #{@nodes_by_name.map{|nm_nd| [nm_nd[0], nm_nd[1].node_name]}.inspect}"
        
    #organize by parents like this [ [par_cat, node] ... ]
    @nodes_by_parent_cat = organize_by_parents(@all_nodes, @nodes_by_name.keys)
    
    #puts "Nodes by Parent Cat: #{@nodes_by_parent_cat.map{|pcat_nd| [pcat_nd[0], pcat_nd[1].node_name]}.inspect}"
   
    nodes_with_parents = @nodes_by_parent_cat.map {|pcat_nd_pr| pcat_nd_pr[1]}.uniq
    nodes_with_no_parents = @all_nodes - nodes_with_parents
    
    #puts "Grapher: Nodes with Parents: #{nodes_with_parents.map{|n| n.node_name}.inspect}"
    #puts "Grapher: Nodes with No Parents: #{nodes_with_no_parents.map{|n| [n.node_name, n.node_parents]}.inspect}"

    @nodes_by_parent_node = @nodes_by_parent_cat.map do |par_cat_node_pair|
      parent_node = @nodes_by_name[par_cat_node_pair[0]]
      #replace the parent category name with the actual node
      [parent_node, par_cat_node_pair[1] ]
    end
    
    #puts "Grapher: Nodes by Parent: #{@nodes_by_parent_node.inspect}"
    
    adj_list = make_adjacency(@nodes_by_parent_node)
    
    #puts "Graph Adj List Keys: #{adj_list.keys.inspect}"
    #only children and grandchildren are counted
    ordered_by_descendant_size = order_nodes(adj_list, nodes_with_no_parents, wroot_node=nil)
    
    #puts "Ordered: #{ordered_by_descendant_size.map{|n| n.node_name}.inspect}"
    
    #TODO: viw -> model -> graph -> view  OR   view => (graph & model) => view ... (I kinda like the first)
    base_graph = RGL::DirectedAdjacencyGraph.new
    @graph_data = {}
    @graph_data[:no_parents] = nodes_with_no_parents.map{|n| n.node_content}
    @graph_data[:graph] = case graph_type
     
      when :tree
        make_tree(base_graph, ordered_by_descendant_size, adj_list, @root_node ) #root data not implemented yet
      when :digraph
        make_digraph(base_graph, ordered_by_descendant_size, adj_list)
      else
        raise "Unknown graph type"
    end
    raise "No Graph!!!" unless @graph_data[:graph]  
    @graph = @graph_data[:graph]  
  end
    
  #structure: { node.node_name => node}
  def organize_by_name(nodes)
    hsh = {}
    nodes.each {|n| hsh[n.node_name] = n }
    hsh
  end
  
  #structure: [ node[parent_key], node] , for bufs [ node.parent_categories.each, node ]
  def organize_by_parents(nodes, node_keys)
    by_parent_cat = []
    by_parent_cat_array = nodes.map {|n| [n.node_parents, n] }
    by_parent_cat_array.each do |cat_ary, node|
      cat_ary.each do |par_cat|
        by_parent_cat << [par_cat, node]
      end
    end
    
    #deleting parents that are just labels, since they won't be part of the graph structure (yet).
    by_parent_cat.delete_if do |par_cat_node_pair|
      parent_cat = par_cat_node_pair[0]
      node = par_cat_node_pair[1]
      if node_keys && (node_keys.include? parent_cat)
        #puts "Delete #{parent_cat} in #{node_keys.inspect}? NO!!"
        false
      else
        #puts "Delete #{parent_cat} in #{node_keys.inspect}: YES!!"
        true
      end
    end
    by_parent_cat
  end
  
  def make_adjacency(adj_pairs)
    adj_hash = {}
    adj_pairs.each do |pair|
      if adj_hash[pair[0]]
        adj_hash[pair[0]] << pair[1]
      else
        adj_hash[pair[0]] = [ pair[1] ]
      end
    end
    adj_hash
  end

  #weighting counts the number of children and grandchildren to make a guess at the best nodes to have near the top
  def node_weighting(node, adj_list)
    weight = 0
    weight += adj_list[node].size if adj_list[node]
    adj_list[node].each do |child|
      if adj_list[child] && adj_list[child] != node
        weight += adj_list[child].size
      end
    end
    weight
  end

  def order_nodes(adj_list, no_parents, wroot_node)
    weights = []  #[node, weight]
    adj_list.each do |node, children|
      node_weight = node_weighting(node, adj_list)
      weights << [node, node_weight]
    end
    node_order = weights.sort{|x,y|  y[1] <=> x[1]}
    order_wo_roots = node_order.map{|np| np[0]}
    no_parents.each{|r| order_wo_roots.delete(r)} 
    order = no_parents + order_wo_roots
    order
  end
  
  def wrap_nodes(nodes, name_key, parent_key, is_root_node=false)
    nodes = [nodes].flatten
    raise "Can only be one root node: #{nodes.inspect}}" if is_root_node && nodes && nodes.size >1
    raise "node list must be unique!" if nodes.uniq.size != nodes.size
    wrapped_nodes = nodes.map do |n|
			nk = n.__send__(name_key)
			pk = n.__send__(parent_key)
			TreeWrapper.new(nk, n, pk, is_root_node) unless n.class == TreeWrapper
		end
  end

  def make_tree(base_graph, ordered_nodes, adj_list, root_data)
    tw_root_data = TreeWrapper.new(root_data.my_category, nil, [], true)
    #TODO: move the formatting of the root data into a general method, rather than by graph type
    @converted_root_node = tw_root_data
    tree = base_graph
    ordered_nodes.each do |tw_node|
      #puts "Adding Node: #{tw_node.node_name}"
      tw_children = adj_list[tw_node]
      if tree.has_vertex?(tw_node)
        #should be safe to silently skip since the node of the trees are objects
        #this means that the exact object is already on the tree, no need to readd it
      else
         #puts "Adding link to Root Node: #{tw_node.node_name}"
        #raise "making tree from root data (is it wrapped?): #{root_data.class.inspect}" if root_data
        tree.add_edge(tw_root_data, tw_node)
        tw_node.assigned_to_tree = true
      end #if
      
      if tw_children
        tw_children.each do |tw_child|
          if tree.has_vertex?(tw_child)
            tw_node.linked_descendants << tw_child
          else
            tree.add_edge(tw_node, tw_child)
            tw_node.normal_descendants << tw_child
          end #if
        end #each
      end #if
    end #each
    #return a tree with a root to connect any unconnected data into a common tree structure
    tree
  end #def
  
  def make_digraph(base_graph, ordered_nodes, adj_list)
    #Logic flaws
    #ToDo:
    #Separate no parents from ordered nodes
    #If there is only node with no parents than it is root
    #If there are multiple nodes with no parents then build a digraph for each??
    #If all nodes have parents then top node in ordered list is root
    #assume root is first node
    root = ordered_nodes.shift
    digraph = base_graph
    ordered_nodes.each do |node|
      children = adj_list[node]
    end
    adj_list.each do |node, children|
      children.each do |child|
        digraph.add_edge(node, child)
      end
    end
    digraph
  end
  
end
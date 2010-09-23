DirTreeView = File.dirname(__FILE__)

require File.join(DirTreeView, 'bufs_node_factory')
require 'rgl/adjacency'
require 'rgl/traversal'
require 'rgl/topsort'
require 'rgl/implicit'

class TreeWrapper
  attr_accessor :assigned_to_tree, :normal_descendants,
                :linked_descendants, :node_name, :node_content, :node_parents
                       
  
  def initialize(node_name, node_content = nil, node_parents=[])
    @assigned_to_tree = false
    @normal_descendants = []
    @linked_descendants = []
    @node_name = node_name
    @node_content = node_content
    @node_parents = node_parents
  end
  
end

#opening up tree node for new method for finding nodes
class Grapher
  attr_accessor :key, :parent_key,  :nodes_by_name, :graph,
                :nodes_by_parent_cat, :nodes_by_parent_node

  def initialize(root_data, node_data, keys, graph_type=:tree)
    @key = keys[:node_id_key]
    @parent_key = keys[:parent_key]
    @all_nodes = wrap_nodes(node_data, @key, @parent_key)
    
    #organize nodes by key like this {node key => node, ... }
    # duplicates model structure, but faster
    @nodes_by_name = organize_by_name(@all_nodes)
    
    #organize by parents like this [ [par_cat, node] ... ]
    @nodes_by_parent_cat = organize_by_parents(@all_nodes, nodes_by_name.keys)
    
    nodes_with_parents = @nodes_by_parent_cat.map {|pcat_nd_pr| pcat_nd_pr[1]}.uniq
    nodes_with_no_parents = @all_nodes - nodes_with_parents
    #p nodes_with_no_parents.map {|n| n.node_name}
    #puts "NBP:"
    #@nodes_by_parent_cat.each do |par_node_pair|
    #  puts "#{par_node_pair[0].inspect} -> #{par_node_pair[1].node_name.inspect}"
    #end
    
    @nodes_by_parent_node = @nodes_by_parent_cat.map do |par_cat_node_pair|
      parent_node = @nodes_by_name[par_cat_node_pair[0]]
      #replace the parent category name with the actual node
      [parent_node, par_cat_node_pair[1] ]
    end
    
    adj_list = make_adjacency(@nodes_by_parent_node)
    
    #only children and grandchildren are counted
    ordered_by_descendant_size = order_nodes(adj_list, nodes_with_no_parents)
    #if this is only used by the tree type, move to where the tree is made (and change the argument)
    #also there has to be a way to optimize this
    #wrapped_adj_list = wrap_nodes(ordered_by_descendant_size, adj_list, @key)
    #wrapped_ordered_nodes = ordered_by_descendant_size.map do |n|
    #  TreeWrapper.new(n.__send__(@key), n)
    #end
    
    #TODO: Add support for graph operations?
    base_graph = RGL::DirectedAdjacencyGraph.new
    #base_digraph = RGL::DirectedAdjacencyGraph.new
		#@graph[:tree] = make_tree(base_graph, ordered_by_descendant_size, adj_list )
    #@graph[:digraph] = make_digraph(base_graph, adj_list)
    @graph = case graph_type
      when :tree
        make_tree(base_graph, ordered_by_descendant_size, adj_list )
      #TODO: Digraph needs adding to spec in more robust way
      when :digraph
        make_digraph(base_graph, adj_list)
      else
        raise "Unknown graph type"
    end
  end
    
# { node.node_name => node}
  def organize_by_name(nodes)
    hsh = {}
    nodes.each {|n| hsh[n.node_name] = n }
    hsh
  end
  
# [ node[parent_key], node] , for bufs [ node.parent_categories.each, node ]
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
    #puts "Adj List:"
    #adj_hash.each {|n,c| puts "#{n.node_name} -> #{c.map{|n| n.node_name}.inspect}"}
    adj_hash
  end

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

  def order_nodes(adj_list, no_parents)
    weights = []  #[node, weight]
    adj_list.each do |node, children|
      node_weight = node_weighting(node, adj_list)
      weights << [node, node_weight]
    end
    node_order = weights.sort{|x,y|  y[1] <=> x[1]}
    order_wo_roots = node_order.map{|np| np[0]}
    no_parents.each{|r| order_wo_roots.delete(r)} 
    order = no_parents + order_wo_roots
    #puts "Order: #{order.map{|n| n.my_category}.inspect}"
    #order
  end
  
  def wrap_nodes(nodes, name_key, parent_key)
    raise "node list must be unique!" if nodes.uniq.size != nodes.size
    raise "Node must have method or accessor named #{name_key} to identify the node" unless nodes.first.respond_to? name_key
    raise "Node must have method or accessor named #{parent_key} to identify parents of the node" unless nodes.first.respond_to? name_key
    wrapped_nodes = nodes.map do |n|
			nk = n.__send__(name_key)
			pk = n.__send__(parent_key)
			TreeWrapper.new(nk, n, pk) unless n.class == TreeWrapper
		end
  end

  def make_tree(base_graph, ordered_nodes, adj_list)
    #puts "Making Tree"
    tree = base_graph
    #puts "ON: #{ordered_nodes.map{|n| n.node_name}.inspect}"
    ordered_nodes.each do |tw_node|
      #puts "Iterating on: #{tw_node.node_name.inspect}"
      #puts "Checking Adj List"
      #adj_list.each {|n,c| puts "#{n.node_name}:#{c.map {|c| c.node_name} if c}"}
      #puts "Checking on Adj List [ current iterator ]"
      #puts "iterator class: #{tw_node.class.name}"
      #puts "Adj List Keys Class: #{adj_list.keys.first.class.name}"
      #puts "#{adj_list[tw_node].class.name}"
      tw_children = adj_list[tw_node]
      #puts "---> Children: #{tw_children.map{|c| c.node_name}.inspect if tw_children}"
      if tree.has_vertex?(tw_node)
        #do anything? if we get here is it an error?
      else
        tree.add_edge(:root, tw_node)
        tw_node.assigned_to_tree = true
      end #if
      
      if tw_children
        #puts "Children Exist #{tw_children.map{|c| c.node_name}.inspect}" if tw_children
        tw_children.each do |tw_child|
          if tree.has_vertex?(tw_child)
            #puts "Linked #{tw_node.node_name} to: #{tw_child.node_name}, exists in tree"
            #create virtual link in tw_node only
            tw_node.linked_descendants << tw_child
          else
            #puts "Child added #{tw_child.node_name.inspect} not in graph yet"
            #tree.add_vertex(tw_child.node_name)
            tree.add_edge(tw_node, tw_child)
            tw_node.normal_descendants << tw_child
          end #if
        end #each
      end #if
      #puts "Checking Node: Normal: #{tw_node.normal_descendants.size} Linked: #{tw_node.linked_descendants.size}"
    end #each
    tree
  end #def
  
  def make_digraph(base_graph, adj_list)
    digraph = base_graph
    adj_list.each do |node, children|
      children.each do |child|
        digraph.add_edge(node, child)
      end
    end
    digraph
  end
end
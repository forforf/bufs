DirTreeView = File.dirname(__FILE__)

require File.join(DirTreeView, 'bufs_node_factory')
require 'rgl/adjacency'
require 'rgl/traversal'
require 'rgl/topsort'
require 'rgl/implicit'
require 'rgl/dot'
require 'pp'

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

#opening up tree node for new method for finding nodes
class Grapher
  RootId = :root
  attr_accessor :key, :parent_key,  :nodes_by_name, :graph, :graph_data,
                :nodes_by_parent_cat, :nodes_by_parent_node

  def initialize(root_node, node_data, keys, graph_type=:tree)
    @key = keys[:node_id_key]
    @parent_key = keys[:parent_key]
    @all_nodes = wrap_nodes(node_data, @key, @parent_key)
    #wroot_node = wrap_root_node(root_node, @key, @parent_key, true) if root_node
    #puts "Root Node: #{wroot_node.inspect}"
    @graph_data = {}
    
    #organize nodes by key like this {node key => node, ... }
    # duplicates model structure, but faster
    @nodes_by_name = organize_by_name(@all_nodes)
    
    #organize by parents like this [ [par_cat, node] ... ]
    @nodes_by_parent_cat = organize_by_parents(@all_nodes, @nodes_by_name.keys)
   
    nodes_with_parents = @nodes_by_parent_cat.map {|pcat_nd_pr| pcat_nd_pr[1]}.uniq
    nodes_with_no_parents = @all_nodes - nodes_with_parents
=begin
    #insert root node into node list
    if wroot_node
      puts "Wrapping Root Node and adding it to node list"
      nodes_with_no_parents.each do |w_node|
        w_node.node_parents = [wroot_node.node_name]
      end
      @all_nodes.push wroot_node
      @nodes_by_name = organize_by_name(@all_nodes)
      @nodes_by_parent_cat = organize_by_parents(@all_nodes, @nodes_by_name.keys)
    end
=end    
     
    #puts "All Nodes - After"
    #pp @all_nodes.map{|n| [n.node_name, n.node_parents]}
    
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
    ordered_by_descendant_size = order_nodes(adj_list, nodes_with_no_parents, wroot_node=nil)
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
    @graph_data[:no_parents] = nodes_with_no_parents.map{|n| n.node_content}
    @graph_data[:graph] = case graph_type
      #
      when :tree
        make_tree(base_graph, ordered_by_descendant_size, adj_list, wroot_node ) #root data not implemented yet
      #TODO: Digraph needs adding to spec in more robust way
      when :digraph
        make_digraph(base_graph, ordered_by_descendant_size, adj_list)
      else
        raise "Unknown graph type"
    end
    raise "No Graph!!!" unless @graph_data[:graph]  
    #FIXME: Hackety hack hack - fix why it might be nil in the first place
    #update it was nile because I was calling from an invalid receiver    
    #@graph_data[:graph].vertices.each do |v|
    #  @graph_data[:graph].remove_vertex(v) unless v  
    #end      
    @graph = @graph_data[:graph]  
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

  def order_nodes(adj_list, no_parents, wroot_node)
    #puts "ON Root: #{wroot_node.node_name}" if wroot_node
    #adj_list.each do |k,v|
    #  puts "#{k.node_name} #{k.is_root_node} - > #{v.map{|c| c.node_name}}"
    #end
    #adj_list.delete(wroot_node)
    #puts "[]][[[[[[[[[[[[[[[["
    #adj_list.each do |k,v|
    #  puts "#{k.node_name} #{k.is_root_node} - > #{v.map{|c| c.node_name}}"
    #end

    #pp root_node.node_name 
    #root_node = content_list.select{|class_node_pr| class_node_pr[0] == RootNode}[1]
    #pp wroot_node.node_name
    weights = []  #[node, weight]
    adj_list.each do |node, children|
      node_weight = node_weighting(node, adj_list)
      weights << [node, node_weight]
    end
    #puts "Weights: #{weights.map{|nw| [nw[0].node_name, nw[1]]}.inspect}"
    node_order = weights.sort{|x,y|  y[1] <=> x[1]}
    order_wo_roots = node_order.map{|np| np[0]}
    no_parents.each{|r| order_wo_roots.delete(r)} 
    order = no_parents + order_wo_roots
    #order.unshift(wroot_node)
    #puts "Order: #{order.map{|n| n.node_name}.inspect}"
    order
  end
  
  #def wrap_root_node(root_node, dummy1, dummy2, is_root=true)
    #TreeWrapper.new(root_node[:tree_root_id], root_node[:tree_root_content], [], true)
  #  TreeWrapper.new(root_node[:my_category], root_node, [], true)
  #end
  
  def wrap_nodes(nodes, name_key, parent_key, is_root_node=false)
    nodes = [nodes].flatten
    raise "Can only be one root node: #{nodes.inspect}}" if is_root_node && nodes && nodes.size >1
    raise "node list must be unique!" if nodes.uniq.size != nodes.size
    #raise "Node must have method or accessor named #{name_key} to identify the node: #{nodes.first.inspect}" unless nodes.first.respond_to? name_key.to_sym
    #raise "Node must have method or accessor named #{parent_key} to identify parents of the node: #{nodes.first.inspect}" unless nodes.first.respond_to? name_key.to_sym
    wrapped_nodes = nodes.map do |n|
			nk = n.__send__(name_key)
			pk = n.__send__(parent_key)
			TreeWrapper.new(nk, n, pk, is_root_node) unless n.class == TreeWrapper
		end
  end

  def make_tree(base_graph, ordered_nodes, adj_list, root_data)
    #root_data not implemented yet
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
        #raise "making tree from root data (is it wrapped?): #{root_data.class.inspect}" if root_data
        tree.add_edge(RootId, tw_node)
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
    #return a tree with a root to connect any disjoint data into a common tree structure
    tree
  end #def
  
  def make_digraph(base_graph, ordered_nodes, adj_list)
    #assume root is first node
    #puts "nodes"
    #p ordered_nodes.map{|on| on.node_name}
    root = ordered_nodes.shift
    #p ordered_nodes.map{|on| on.node_name}
    digraph = base_graph
    ordered_nodes.each do |node|
      children = adj_list[node]
      #for handling root, but not needed in digraph (root-less)
      #if digraph.has_vertex?(node)
        #see if children are all there?
      #else
        #digraph.add_edge(root, node)
        #puts "Added Adge to root #{root.node_name} -> #{node.node_name}"
      #end
    end
    adj_list.each do |node, children|
      children.each do |child|
        #puts "Added edge for #{node.node_name} -> #{child.node_name}"
        digraph.add_edge(node, child)
      end
      #puts "Digraph Vertices and children:"
      #digraph.vertices.each do |v|
      #  puts "V: #{v.node_name} -> CH: #{digraph.adjacent_vertices(v).map{|av| av.node_name}}"
      #end
      #puts "Digraph Edges"
      #digraph.each_edge do |u,v|
      #  puts "#{u.node_name} -> #{v.node_name}"
      #end
    end
    digraph
  end
end
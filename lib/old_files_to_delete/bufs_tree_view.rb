DirTreeView = File.dirname(__FILE__)

require 'tree'
require File.join(DirTreeView, 'bufs_node_factory')

#opening up tree node for new method for finding nodes
class Tree::TreeNode

  def find_nodes(node_name)
    #finds all nodes in order of closest to root
    found = []
    self.breadth_each do |node|
      puts "#{node.name} <-> #{node_name}"
      found << node if node.name == node_name
      puts "#{found.map{|f| f.name}}.inspect"
    end
    found
  end
  

  #TODO: Add to Spec
  def breadth_each_reverse(node=self)
    node_list = []
    node.breadth_each {|node| node_list << node}
    node_list.reverse
  end
end


class BufsTreeView

  def initialize(root_data, node_data, keys)
    @key = keys[:node_id_key]
    @parent_key = keys[:parent_key]
    @all_nodes = node_data
    # organize nodes by cat like this {node cat => node, ... }
    # duplicates model structure, but faster
    @nodes_by_cat = organize_by_cat(@all_nodes)
    #organize by parents like this [ [par_cat, node] ... ]
    @nodes_by_parents = organize_by_parents(@all_nodes)
    
    root_id = root_data[:tree_root_id]
    root_content = root_data[:tree_root_content]
    root = Tree::TreeNode.new(root_id, root_content)
    trees = make_trees(@all_nodes)
     
  end

  def organize_by_cat(nodes)
    hsh = {}
    nodes.each {|n| hsh[n.__send__(@key)] = n }
    hsh
  end

  def organize_by_parents(nodes)
    nodes.map {|n| [n.__send__(@parent_key), n] }
  end

  def make_tree_node(node)
    Tree::TreeNode.new(node.__send__(@key), node)
  end

  def make_trees(nodes)
    working_trees = []
    nodes.each do |node|
      par_nodes = find_parents(node)
      tiny_tree = make_tree_node(node)
      par_nodes.each do |par_node|
         tiny_tree << make_tree_node(par_node)
         #do parents have any parents?
      end
      working_trees << tiny_tree
    end
    collapsed_trees = collapse(working_trees)
    invert_trees(collapsed_trees)
  end

  def find_parents(node)
    par_nodes = []
    node.parent_categories.each do |par_cat|
      par_nodes << @nodes_by_cat[par_cat]  
    end
    par_nodes.compact
  end

  def collapse(trees)
    tree_strings = {}
    trees.each do |tree|
      tree_strings[tree.name] =  leaf_parentages(tree)
    end
    puts "tree strings: #{tree_strings.inspect}"
    collapsed_tree_strings = collapse_tree_strings(tree_strings)
    collapsed_trees = []
    collapsed_tree_strings.each do |name, parent_string| 
      trees.each do |tree|
        collapsed_trees << tree if tree.name == name
      end
    end
    puts "collapsed trees: #{(collapsed_trees.map {|t| t.name}).inspect}"
    collapsed_trees
  end
 
  #create a string representation of the leaves parentage
  #note that tree parents = bufs children
  def leaf_parentages(tree)
    #TODO: change seperator to less common 
    leaf_parentages = []
    tree.each_leaf do |leaf|
       parents_string = full_parentage(leaf).join("-")
       #parents_string.insert(0, "-")
       #parents_string << "-"
       leaf_parentages << parents_string
    end
    leaf_parentages #_strings = leaf_parentages.join("--")
  end

  def collapse_tree_strings(tree_strings)
    tree_strings.each do |name, leaf_strings|
      other_tree_strings = tree_strings.dup
      other_tree_strings.delete(name)
      puts "This: #{leaf_strings.inspect}"
      puts "Others: #{other_tree_strings.inspect}"
      #tree_strings.delete_if do |name, leaf_strings|
      other_tree_strings.each do |other_name, other_leaf_strings|
        parentage_exists_in_other_tree_strings = false
        other_leaf_strings.each do |other_leaf_parentage|
          #this can probably be simplified with inject
          #portion_of_leaf_matches = false
          leaf_matches = true #_results = []
          leaf_strings.each do |this_leaf_parentage|
            #puts "This Parents: #{this_leaf_parentage.inspect}"
            #puts "Other Parents: #{other_leaf_parentage.inspect}"
            this_parent_string = this_leaf_parentage
            #this_parent_string.insert(0,"-")
            #this_parent_string << "-"
            unless other_leaf_parentage.include? this_parent_string
              leaf_matches = false
            end
            #puts "match: #{leaf_matches.inspect}"
            #if other_leaf_parentage.include? this_leaf_parentage
            #  part_of_leaf_matches = part_of_leaf_matches && true #_results << true
            #else
            #  part of leaf_matches = part_ofLeaf_matches && false
          end
          parentage_exists_in_other_tree_strings = leaf_matches
          #puts "This LS: #{leaf_strings.sort.inspect}"
          #puts "OtherLS: #{other_leaf_strings.sort.inspect}"
          #if leaf_strings.sort == other_leaf_strings.sort
          #   parentage_exists_in_other_tree_strings = true
          #end
        end
        puts "name: #{name.inspect}  ols: #{other_leaf_strings.inspect}" 
        puts "Tree exists in other tree?: #{parentage_exists_in_other_tree_strings}"
        #leaf_strings.each do  #do all leaf strings have to exist or just one
        tree_strings.delete(name) if parentage_exists_in_other_tree_strings
      end
    end
    #p tree_strings
    tree_strings
  end

  def full_parentage(node)
    parents = node.parentage || []
    parent_names = parents.map {|p| p.name}
    full_parentage = parent_names.push(node.name)
  end
  
  def invert_trees(trees)
    inverted_trees = []
    trees.each do |tree|
      tree.each_leaf do |leaf|
        leaf = leaf.detached_copy
        new_tree = nil
        branch = leaf.parentage || []
        add_branch_to(new_tree, branch, leaf)
      end
    end
  end
  
  def add_branch_to(tree, branch, leaf)
    puts "Adding Branch To:"
    tree.printTree if tree
    puts "xxxx"
    found_leaf_in_tree = tree.find_nodes(leaf.name) if tree
    found_leaf_in_tree = [] unless found_leaf_in_tree
    puts "Found leaves: #{found_leaf_in_tree.inspect}"
    if found_leaf_in_tree.size == 1
      tree = found_leaf_in_tree.first
    elsif found_leaf_in_tree.size > 1
      raise "Mulitple identical nodes found in same tree"
    else
      tree = leaf
    end
    puts "just leaf is the tree right now"
    tree.breadth_each do |node|
      puts "#{node.name}:#{node.level}"
    end
    branch.each do |node|
      node = node.detached_copy
      tree << node
    end
    puts "Inverted Tree Root: #{tree.name}"
    tree.breadth_each do |node|
      puts "#{node.name}: #{node.level}"
    end
=begin    
    branch.each do |node|
      puts "node: #{node.name}"
      puts "searching tree:"
      p tree.name
      p tree.size
      found_node_in_tree = tree.find_nodes(node.name)
      puts "Search for: #{node.name} Found: #{found_node_in_tree.size}  in #{tree.name.inspect}"
      if found_node_in_tree.size == 1
        puts "Grafting #{node.name}"
        puts "Tree: 
      #  graft_branch(found_node_in_tree, node)
      elsif found_node_in_tree.size == 0
        puts "Adding node #{node.name}"
        puts "Tree Size #{tree.size}"
        node.printTree
        puts "Node.size #{node.size}"
        tree << node
      else
        raise "Found too many nodes: #{found_node_in_tree.inspect}"
      end
    end
=end
  end
end


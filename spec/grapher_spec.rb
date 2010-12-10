#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require Bufs.lib 'grapher'
require Bufs.spec_helpers 'bufs_test_environments'

module MakeUserClasses
    @user1_id = "CouchUser001"
    @user2_id = "CouchUser002"
    @user3_id = "FileSysUser003"
    @user4_id = "FileSysUser004"
    node_class_id1 = "BufsInfoNode#{@user1_id}"
    node_class_id2 = "BufsInfoNode#{@user2_id}"
    node_class_id3 = "BufsFile#{@user3_id}"
    node_class_id4 = "BufsFile#{@user4_id}"
    node_env1 = CouchRestNodeHelpers.env_builder(node_class_id1, CouchDB, @user1_id)
    node_env2 = CouchRestNodeHelpers.env_builder(node_class_id2, CouchDB2, @user2_id)
    node_env3 = FileSystemNodeHelpers.env_builder(node_class_id3, FileSystem1, @user3_id)
    node_env4 = FileSystemNodeHelpers.env_builder(node_class_id4, FileSystem2, @user4_id)
    User1Class =  BufsNodeFactory.make(node_env1)
    User2Class =  BufsNodeFactory.make(node_env2)
    User3Class =  BufsNodeFactory.make(node_env3)
    User4Class =  BufsNodeFactory.make(node_env4)
end

module GrapherSpecHelpers
  include NodeHelpers
  include MakeUserClasses
 
  def data_for_simple_tree(user_class)
    nodes = []
    top = make_doc_no_attachment(user_class, :my_category => 'top')
    #top.__save
    child1_params = {:my_category => 'child1',
                     :parent_categories => ['top', 'just_a_label1']}
    child2_params = {:my_category => 'child2',
                     :parent_categories => ['top', 'just_a_label2']}
    child1 = make_doc_no_attachment(user_class, child1_params)
    child2 = make_doc_no_attachment(user_class, child2_params)
    #child1.__save
    #child2.__save
    nodes = [top, child1, child2]
  end
  
  def two_simple_trees(user_class)
    #tree1
    top1 = make_doc_no_attachment(user_class, :my_category => 'top1')
    #top1.__save
    child11_params = {:my_category => 'child11',
                     :parent_categories => ['top1', 'just_a_label11']}
    child12_params = {:my_category => 'child12',
                     :parent_categories => ['top1', 'just_a_label2']}
    child11 = make_doc_no_attachment(user_class, child11_params)
    child12 = make_doc_no_attachment(user_class, child12_params)
    #child11.__save
    #child12.__save    
    #tree2
    top2 = make_doc_no_attachment(user_class, :my_category => 'top2')
    #top2.__save
    child21_params = {:my_category => 'child21',
                     :parent_categories => ['top2', 'just_a_label11']}
    child22_params = {:my_category => 'child22',
                     :parent_categories => ['top2', 'just_a_label2']}
    child21 = make_doc_no_attachment(user_class, child21_params)
    child22 = make_doc_no_attachment(user_class, child22_params)
    #child21.__save
    #child22.__save  
    nodes = [top1, child21, top2, child12, child11, child22]
  end
  
  def two_simple_trees_with_link1(user_class)
    simple_trees = two_simple_trees(user_class)
    #create_link
    #between child12 and child22, specifically child12 would be a child of child22
    simple_trees[3].parent_categories_add 'child22'
    simple_trees
  end

  def two_simple_trees_with_inf_loop(user_class)
    looped_trees = two_simple_trees(user_class)
    looped_trees[0].parent_categories_add 'child22'
    looped_trees[2].parent_categories_add 'child11'
    looped_trees
  end
  
  def save_all(nodes)
    nodes.each do |node|
      node.__send__(:__save)
    end
  end
end



describe Grapher do
  include MakeUserClasses
  include GrapherSpecHelpers

  before(:each) do
    @user_classes = [User1Class, User2Class, User3Class, User4Class]
    @root_data = RootNode.new(:root, :root_data)
  end

  after(:each) do
    @user_classes.each {|uc| uc.destroy_all}
  end

  it "should initialize properly" do
    @user_classes.each do |user_class|
      #save to the persistence layer data to make a simple tree
      #not assigned to a variable because we'll pull it from the 
      #persistence layer later
      save_all data_for_simple_tree(user_class)
    end
    #check initial conditions
    @user_classes.each do |user_class|
      tops = user_class.call_view(:my_category, 'top')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top')
      childs.size.should == 2 
    end
    #test
    user_graph = {}
    keys = {:node_id_key => :my_category,
                :parent_key => :parent_categories }
    @user_classes.each do |user_class|
      nodes = user_class.all
      user_graph[user_class] = Grapher.new(nodes, keys, :tree, @root_data)
    end
    #verify results
    @user_classes.each do |user_class|
      my_tree = user_graph[user_class]
      my_tree.key.should == keys[:node_id_key]
      my_tree.parent_key.should == keys[:parent_key]
      my_tree.nodes_by_parent_cat.each do |parent_node_pair|
        parent_cat = parent_node_pair[0]
        parent_node_pair[1].node_parents.should include
        my_tree.nodes_by_name[parent_cat].node_name
      end
    end
  end
  
  it "should create a very simple tree" do
    #initial conditions
    @user_classes.each do |user_class|
      save_all data_for_simple_tree(user_class) #saved to model
    end
    #check initial conditions
    @user_classes.each do |user_class|
      tops = user_class.call_view(:my_category, 'top')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top')
      childs.size.should == 2 
    end
    #test
    user_graph = {}
    @user_classes.each do |user_class|
      model_nodes = user_class.all
      model_nodes.size.should > 1
      
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
      user_graph[user_class] = Grapher.new(model_nodes, keys, :tree, @root_data)
    end
    #verify results
    @user_classes.each do |user_class|
      #puts "User Class to build graph: #{user_class.inspect}"
      my_grapher = user_graph[user_class]
      tree = my_grapher.graph
      
      root_id =my_grapher.converted_root_node
      #puts "Root Nodes: #{root_id.inspect}"
      #puts "Working Tree: #{tree.vertices.map{|v| v.class.inspect}}"
      #puts "Verts: #{tree.vertices.map{|v| v.node_content.class.name}.inspect}"
      bfs = tree.bfs_iterator(root_id)
      #puts "BFS Tree size: #{bfs.vertices.map{|v| v.node_name.inspect}}"
      tree_order = []
      bfs.each {|v| tree_order << v}
      #tree_order.should == []
      tree_order[0].should == root_id
      tree_order[1].node_name.should == 'top'
      ['child1', 'child2'].should include tree_order[2].node_name 
      ['child1', 'child2'].should include tree_order[2].node_name 
      tree_order[2].node_name.should_not == tree_order[3].node_name
      tree_order[1].normal_descendants.map{|d| d.node_name}.sort.should == ['child1', 'child2']
    end
  end    

  it "should create a two simple trees (connected by root)" do
    #initial conditions
    @user_classes.each do |user_class|
      save_all two_simple_trees(user_class) #saved to model
    end
    #check initial conditions
    @user_classes.each do |user_class|
      tops = user_class.call_view(:my_category, 'top1')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top1')
      childs.size.should == 2 
      tops = user_class.call_view(:my_category, 'top2')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top2')
      childs.size.should == 2       
    end
    #test
    user_graph = {}
    @user_classes.each do |user_class|
      model_nodes = user_class.all
      model_nodes.size.should > 1
      #root_data = {:tree_root_id => user_class.name,
      #             :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
	    user_graph[user_class] = Grapher.new(model_nodes, keys, :tree, @root_data)
    end
    #verify results
    @user_classes.each do |user_class|
      my_grapher = user_graph[user_class]
      tree = my_grapher.graph
      root_nodes = tree.vertices.select{|v| v == my_grapher.converted_root_node}
      #raise "vertex not found for #{@root_data.class.name}. Verts: #{tree.vertices.map{|v| v.node_content.class.name}.inspect}"
      raise "Wrong number of root nodes: #{root_nodes.size}" unless root_nodes.size == 1
      root_node = root_nodes.first
      bfs = tree.bfs_iterator(root_node)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == root_node
      tree_order[1].node_name.should == 'top1'
      tree_order[2].node_name.should == 'top2'
      tree_order[3].node_name.should == 'child11'
      tree_order[4].node_name.should == 'child12'
      tree_order[5].node_name.should == 'child21'
      tree_order[6].node_name.should == 'child22'
      tree_order[1].normal_descendants.map{|d| d.node_name}.sort.should == ['child11', 'child12']
      tree_order[2].normal_descendants.map{|d| d.node_name}.sort.should == ['child21', 'child22']
    end
  end    

  it "should create a two simple trees with a single link" do
    #initial conditions
    @user_classes.each do |user_class|
      save_all two_simple_trees_with_link1(user_class) #saved to model
    end
    #check initial conditions
    @user_classes.each do |user_class|
      tops = user_class.call_view(:my_category, 'top1')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top1')
      childs.size.should == 2 
      tops = user_class.call_view(:my_category, 'top2')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top2')
      childs.size.should == 2       
      child12 = user_class.call_view(:my_category, 'child12').first
      child12.parent_categories.should include 'child22'
    end
    #test
    user_graph = {}
    @user_classes.each do |user_class|
      model_nodes = user_class.all
      model_nodes.size.should > 1
      root_data = {:tree_root_id => user_class.name,
                   :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
      user_graph[user_class] = Grapher.new(model_nodes, keys, :tree, @root_data)
    end
    #verify results
    @user_classes.each do |user_class|
      my_grapher = user_graph[user_class]
      tree = my_grapher.graph
      root_nodes = tree.vertices.select{|v| v == my_grapher.converted_root_node}
      #raise "vertex not found for #{@root_data.class.name}. Verts: #{tree.vertices.map{|v| v.node_content.class.name}.inspect}"
      raise "Wrong number of root nodes: #{root_nodes.size}" unless root_nodes.size == 1
      root_node = root_nodes.first
      bfs = tree.bfs_iterator(root_node)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == root_node
      tree_order[1].node_name.should == 'top1'
      tree_order[2].node_name.should == 'top2'
      tree_order[3].node_name.should == 'child11'
      tree_order[4].node_name.should == 'child12'
      tree_order[5].node_name.should == 'child21'
      tree_order[6].node_name.should == 'child22'
      tree_order[1].normal_descendants.map{|d| d.node_name}.sort.should == ['child11', 'child12']
      tree_order[2].normal_descendants.map{|d| d.node_name}.sort.should == ['child21', 'child22']
      tree_order[6].normal_descendants.map{|d| d.node_name}.should == []
      tree_order[6].linked_descendants.map{|d| d.node_name}.should == ['child12']
      normal_ds = []
      linked_ds = []
      #tree_order.map{|tw_node| normal_ds << tw_node.normal_descendants.map{|n| n.node_name} unless tw_node == :root}
      #normal_ds.should == 'blah'
      #tree_order.map{|tw_node| linked_ds << tw_node.linked_descendants.map{|n| n.node_name} unless tw_node == :root}
      #linked_ds.should == 'blah'
    end
  end
  
   it "should create a two simple trees with an infinitely looped link" do
    #initial conditions
    @user_classes.each do |user_class|
      save_all two_simple_trees_with_inf_loop(user_class) #saved to model
    end
    #check initial conditions
    @user_classes.each do |user_class|
      top1 = user_class.call_view(:my_category, 'top1')
      top1.size.should == 1
      child1 = user_class.call_view(:parent_categories, 'top1')
      child1.size.should == 2 
      top2 = user_class.call_view(:my_category, 'top2')
      top2.size.should == 1
      child2 = user_class.call_view(:parent_categories, 'top2')
      child2.size.should == 2       
      top1.first.parent_categories.should include 'child22'
      top2.first.parent_categories.should include 'child11'
    end
    #test
    user_tree = {}
    user_digraph = {}
    @user_classes.each do |user_class|
      model_nodes = user_class.all
      model_nodes.size.should > 1
      #root_data = {:tree_root_id => user_class.name,
      #             :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
      user_tree[user_class] = Grapher.new(model_nodes, keys, :tree, @root_data)
    end
    #verify results
    @user_classes.each do |user_class|
      #rough verify of digraph
      
      my_grapher = user_tree[user_class]
      tree = my_grapher.graph
      root_nodes = tree.vertices.select{|v| v == my_grapher.converted_root_node}
      #raise "vertex not found for #{@root_data.class.name}. Verts: #{tree.vertices.map{|v| v.node_content.class.name}.inspect}"
      raise "Wrong number of root nodes: #{root_nodes.size}" unless root_nodes.size == 1
      root_node = root_nodes.first
      bfs = tree.bfs_iterator(root_node)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == my_grapher.converted_root_node
      tree_order[1].node_name.should == 'top1'
      tree_order[2].node_name.should == 'top2'
      tree_order[3].node_name.should == 'child11'
      tree_order[4].node_name.should == 'child12'
      tree_order[5].node_name.should == 'child21'
      tree_order[6].node_name.should == 'child22'
      tree_order[1].normal_descendants.map{|d| d.node_name}.sort.should == ['child11', 'child12']
      tree_order[2].normal_descendants.map{|d| d.node_name}.sort.should == ['child21', 'child22']
      tree_order[6].normal_descendants.map{|d| d.node_name}.should == []
      tree_order[6].linked_descendants.map{|d| d.node_name}.should == ['top1']
      tree_order[3].normal_descendants.map{|d| d.node_name}.should == []
      tree_order[3].linked_descendants.map{|d| d.node_name}.should == ['top2']
      normal_ds = []
      linked_ds = []
      #tree_order.map{|tw_node| normal_ds << tw_node.normal_descendants.map{|n| n.node_name} unless tw_node == :root}
      #normal_ds.should == 'blah'
      #tree_order.map{|tw_node| linked_ds << tw_node.linked_descendants.map{|n| n.node_name} unless tw_node == :root}
      #linked_ds.should == 'blah'
    end
  end

   it "should create a directed graph with an infinitely looped link" do
    #initial conditions
    @user_classes.each do |user_class|
      save_all two_simple_trees_with_inf_loop(user_class) #saved to model
    end
    #check initial conditions
    @user_classes.each do |user_class|
      top1 = user_class.call_view(:my_category, 'top1')
      top1.size.should == 1
      child1 = user_class.call_view(:parent_categories, 'top1')
      child1.size.should == 2 
      top2 = user_class.call_view(:my_category, 'top2')
      top2.size.should == 1
      child2 = user_class.call_view(:parent_categories, 'top2')
      child2.size.should == 2       
      top1.first.parent_categories.should include 'child22'
      top2.first.parent_categories.should include 'child11'
    end
    #test
    user_digraph = {}
    @user_classes.each do |user_class|
      model_nodes = user_class.all
      model_nodes.size.should > 1
      #root_data = {:tree_root_id => user_class.name,
      #             :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
      user_digraph[user_class] = Grapher.new(model_nodes, keys, :digraph, @root_data)
    end
    #verify results
    @user_classes.each do |user_class|
      #rough verify of digraph
      my_digraph = user_digraph[user_class]
      digraph = my_digraph.graph
      dg_node_names = digraph.vertices.map{|v| v.node_name}.sort
      dg_node_names.should == ['top1', 'child21', 'top2',
                                'child12', 'child11', 'child22'].sort
      digraph.acyclic?.should == false
      this_node = my_digraph.nodes_by_name['top1']
      nbrs = digraph.adjacent_vertices(this_node)
      nbrs.size.should == 2
      nbrs.each do |nbr_node|
        ['child11', 'child12'].should include nbr_node.node_name
      end
      this_node = my_digraph.nodes_by_name['top2']
      nbrs = digraph.adjacent_vertices(this_node)
      nbrs.size.should == 2
      nbrs.each do |nbr_node|
        ['child21', 'child22'].should include nbr_node.node_name
      end
      this_node = my_digraph.nodes_by_name['child22']
      nbrs = digraph.adjacent_vertices(this_node)
      nbrs.size.should == 1
      nbrs.each do |nbr_node|
        ['top1'].should include nbr_node.node_name
      end
      this_node = my_digraph.nodes_by_name['child11']
      nbrs = digraph.adjacent_vertices(this_node)
      nbrs.size.should == 1
      nbrs.each do |nbr_node|
        ['top2'].should include nbr_node.node_name
      end
      #dgbfs = digraph.bfs_iterator[top1_node]
      #dgbfs.attach_distance_map
    end
  end
end

describe Borg do
  include MakeUserClasses
  include GrapherSpecHelpers
 
  before(:each) do
    @user_classes = [User1Class, User2Class, User3Class, User4Class]
    #@root_data = RootNode.new(:root, :root_data)
    @keys = {:node_id_key => :my_category,
             :parent_key => :parent_categories}
  end

  after(:each) do
    @user_classes.each {|uc| uc.destroy_all}
  end

  it "should initialize properly" do
    @user_classes.each do |user_class|
      #save to the persistence layer data to make a simple tree
      #not assigned to a variable because we'll pull it from the
      #persistence layer later
      save_all data_for_simple_tree(user_class)
      tops = user_class.call_view(:my_category, 'top')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top')
      childs.size.should == 2
    end
    #test (not a full test, since Borg doesn't do much on init)
    @user_classes.each do |user_class|
      node_list = user_class.all
      borg = Borg.new(node_list, @keys)
    end
    #verify results
    #ok if it doesn't crash on initialization
    #the borg object may have attributes in the future
  end

  it "should borg.ify all descendant data for each node for a simple tree" do
    @user_classes.each do |user_class|
      #save to the persistence layer data to make a simple tree
      #not assigned to a variable because we'll pull it from the
      #persistence layer later
      save_all data_for_simple_tree(user_class)
      tops = user_class.call_view(:my_category, 'top')
      tops.size.should == 1
      childs = user_class.call_view(:parent_categories, 'top')
      childs.size.should == 2
    end
    #test and verify with empty data
    @user_classes.each do |user_class|
      node_list = user_class.all
      borg = Borg.new(node_list, @keys)
      top_node = user_class.call_view(:my_category, 'top').first
      desc_links = borg.ify(top_node, :links)
      desc_links.should == []
    end
    #add a link and test
    @user_classes.each do |user_class|
      select_category = 'child2'
      achild = user_class.call_view(:my_category, select_category).first
      achild.my_category.should == select_category
      achild.__set_userdata_key(:links, nil)
      new_link = {"http://www.google.com" => "Google"}
      achild.links_add(new_link)
      achild.__save
      achild_from_db = user_class.call_view(:my_category, select_category).first
      achild_from_db.links.should == new_link
      node_list = user_class.all
      borg = Borg.new(node_list, @keys)
      #Borg needs to refine the data better 
      top_node = user_class.call_view(:my_category, 'top').first
      desc_node_data = borg.ify(top_node, :links)
      desc_node_data.size.should == 3
      all_links = []
      desc_node_data.each do |data|
        all_links << data.values
      end
      all_links.flatten!
      all_links.compact!
      all_links.first.should == new_link
    end

  end

end

DirBufsTreeViewSpec = File.dirname(__FILE__)
require File.join(DirBufsTreeViewSpec, '../lib', 'grapher')
require File.join(DirBufsTreeViewSpec, 'helpers/bufs_test_environments')


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
    simple_trees = two_simple_trees(user_class)
    simple_trees[0].parent_categories_add 'child22'
    simple_trees[2].parent_categories_add 'child11'
    simple_trees
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
    @user_classes = [User3Class]
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
      root_data = {:tree_root_id => user_class.name,
                         :tree_root_content => user_class}
      
	    user_graph[user_class] = Grapher.new(root_data, nodes, keys, :tree)
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
      root_data = {:tree_root_id => user_class.name,
                   :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
      user_graph[user_class] = Grapher.new(root_data, model_nodes, keys, :tree)
    end
    #verify results
    @user_classes.each do |user_class|
      my_grapher = user_graph[user_class]
      tree = my_grapher.graph
      bfs = tree.bfs_iterator(:root)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == :root
      tree_order[1].node_name.should == 'top'
      tree_order[2].node_name.should == 'child2'
      tree_order[3].node_name.should == 'child1'
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
      root_data = {:tree_root_id => user_class.name,
                   :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
	    user_graph[user_class] = Grapher.new(root_data, model_nodes, keys, :tree)
    end
    #verify results
    @user_classes.each do |user_class|
      my_grapher = user_graph[user_class]
      tree = my_grapher.graph
      bfs = tree.bfs_iterator(:root)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == :root
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
      user_graph[user_class] = Grapher.new(root_data, model_nodes, keys, :tree)
    end
    #verify results
    @user_classes.each do |user_class|
      my_grapher = user_graph[user_class]
      tree = my_grapher.graph
      bfs = tree.bfs_iterator(:root)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == :root
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
  
   it "should create a two simple trees with an looped link" do
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
      root_data = {:tree_root_id => user_class.name,
                   :tree_root_content => user_class}
      keys = {:node_id_key => :my_category,
              :parent_key => :parent_categories}
      user_tree[user_class] = Grapher.new(root_data, model_nodes, keys, :tree)
      user_digraph[user_class] = Grapher.new(root_data, model_nodes, keys, :digraph)
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
      top1_node = my_digraph.nodes_by_name['top1']
      nbrs = digraph.adjacent_vertices(top1_node)
      nbrs.size.should == 2
      p nbrs.map{|n| n.node_name}.inspect
      nbrs.each do |node|
        nbrs1 = digraph.adjacent_vertices(node)
        p nbrs1.map{|n| n.node_name}.inspect
      end
     
      #dgbfs = digraph.bfs_iterator[top1_node]
      #dgbfs.attach_distance_map

        
      
      my_grapher = user_tree[user_class]
      tree = my_grapher.graph
      bfs = tree.bfs_iterator(:root)
      tree_order = []
      bfs.each {|v| tree_order << v}
      tree_order[0].should == :root
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
end

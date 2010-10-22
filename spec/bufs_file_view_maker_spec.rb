require File.join(File.dirname(__FILE__) , 'helpers/bufs_sample_dataset')
require File.join(File.dirname(__FILE__), '../lib/bufs_file_view_maker')



BFVMBaseDir = "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/bufs_file_view_maker_spec/"
describe BufsFileViewMaker do
  before(:all) do
    sample_data = PopulatePersistenceModels::Sample1::DataSet
    ppm = PopulatePersistenceModels
    @user_classes = ppm.add_data_set_to_model(sample_data)
    @keys = {:node_id_key => :my_category, :parent_key => :parent_categories}
  end
  
  before(:each) do
    @user_base_dir_list = {}
    user_base_dir = nil
    @user_classes.each do |user_class|
      #TODO: Fix - The below creates an artificial dependendency between naming and functionality
      user_id = user_class.myGlueEnv.user_id
      if user_id =~ /FileSys/
        user_base_dir = user_class.myGlueEnv.namespace
      else
        user_base_dir = File.join(BFVMBaseDir, user_id)
        FileUtils.mkdir_p(user_base_dir) unless File.exist?(user_base_dir)
      end
      raise "user base dir not set" unless user_base_dir
      @user_base_dir_list[user_class] = user_base_dir
    end
    @user_base_dir_list #has been set
  end
  
  it "should initialize from data provided by the persistence models" do
    @user_classes.each do |user_class|
      node_list = user_class.all
      view_dir = @user_base_dir_list[user_class]
      view_tree = BufsFileViewMaker.new(user_class.name, node_list, view_dir)
      
      view_tree.tree.class.should == RGL::DirectedAdjacencyGraph
      view_tree.tree.acyclic?.should == true
      view_tree.tree.size.should == 14 #13?
      #p view_tree.tree.vertices.map{|v| v.node_name } #if v.respond_to? :node_name}
      no_parents = view_tree.tree_data[:no_parents]
      no_parents.size.should == 2 #3?
      no_parents.first.class.name.should =~ /^BufsNodeFactory::Bufs/
    end
  end
  
  it "should provide a tree structure" do
    @user_classes.each do |user_class|
      node_list = user_class.all
      view_dir = @user_base_dir_list[user_class]
      view_tree = BufsFileViewMaker.new(user_class.name, node_list, view_dir)
      
      top_nodes = view_tree.tree.vertices.select{|v| v.is_root_node}
      top_nodes.size.should == 1
      root_node = top_nodes.first
      root_node.node_name.should =~ /^BufsNodeFactory::Bufs/
      
      #subtrees
      subtrees = view_tree.tree.each_adjacent(root_node)
      subtrees.length.should == 3
      subtrees.each do |v|
        ["aa", "b", "c"].should include v.node_name
        case v.node_name
          when "aa"
            aa_branch = view_tree.tree.bfs_search_tree_from(v)
            #node "bbb" has two parents and for couch ends up under the b parent, and for files ends up under the aaa parent
            aa_branch.vertices.each{|v| ["aa", "a", "aaa", "ab", "ac", "bbb"].should include v.node_name}
          when "b"
            b_branch = view_tree.tree.bfs_search_tree_from(v)
            #node "bbb" has two parents and for couch ends up under the b parent, and for files ends up under the aaa parent
            b_branch.vertices.each{|v| ["b", "ba", "bb", "bc", "bcc", "bbb"].should include v.node_name}
          when "c"
            c_branch = view_tree.tree.bfs_search_tree_from(v)
            c_branch.vertices.each{|v| ["c", "cc"].should include v.node_name}
        end
      end
    end
  end
  
   it "should create links where loops occur" do
    @user_classes.each do |user_class|
      node_list = user_class.all
      view_dir = @user_base_dir_list[user_class]
      view_tree = BufsFileViewMaker.new(user_class.name, node_list, view_dir)
      vertices_with_links = view_tree.tree.vertices.select{|v| v.linked_descendants.size > 0}
      vertices_with_links.each do |vert_w_link|
        case vert_w_link
          when "a"
            vert_w_link.linked_descendants.each {|lv| ["aa"].should include lv.node_name}
          when "aaa"
            vert_w_link.linked_descendants.each {|lv| ["ab", "bbb"].should include lv.node_name}
          when "ab"
            vert_w_link.linked_descendants.each {|lv| ["ba"].should include lv.node_name}
          when "bbb"
            vert_w_link.linked_descendants.each {|lv| ["bc"].should include lv.node_name}
          when "bb"
            vert_w_link.linked_descendants.each {|lv| ["ab"].should include lv.node_name}
        end
      end
      #subtrees
    end
  end
  
  it "should find a root node and iterate the subtrees" do
    @user_classes.each do |user_class|
      node_list = user_class.all
      view_dir = @user_base_dir_list[user_class]
      view_tree = BufsFileViewMaker.new(user_class.name, node_list, view_dir)
      view_tree.make_file_view
    end
  end
end
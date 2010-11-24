#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../lib/helpers/require_helper')

require Bufs.spec_helpers 'bufs_sample_dataset'
require Bufs.lib 'bufs_file_view_maker'
require Bufs.lib 'bufs_file_view_reader'

class DirFinder
  class << self; attr_accessor :dir_list; end
  @dir_list = {}
end

module MakeReaderClasses
  node_db_name = "http://127.0.0.1:5984/read_view_data/"
  SampleCouchDB = CouchRest.database!(node_db_name)
  SampleCouchDB.compact!

  FileSystem = "/home/bufs/bufs/sandbox_for_specs/read_view_data"
    @user1_id = "SampleCouchReader001"
    #@user2_id = "SampleCouchReader002"
    @user3_id = "SampleFileSysReader003"
    #@user4_id = "SampleFileSysReader004"
    node_class_id1 = "BufsInfoNode#{@user1_id}"
    #node_class_id2 = "BufsInfoNode#{@user2_id}"
    node_class_id3 = "BufsFile#{@user3_id}"
    #node_class_id4 = "BufsFile#{@user4_id}"
    node_env1 = CouchRestNodeHelpers.env_builder(node_class_id1, SampleCouchDB, @user1_id)
    #node_env2 = CouchRestNodeHelpers.env_builder(node_class_id2, SampleCouchDB, @user2_id)
    node_env3 = FileSystemNodeHelpers.env_builder(node_class_id3, FileSystem, @user3_id)
    #node_env4 = FileSystemNodeHelpers.env_builder(node_class_id4, FileSystem, @user4_id)
    User1Class =  BufsNodeFactory.make(node_env1)
    #User2Class =  BufsNodeFactory.make(node_env2)
    User3Class =  BufsNodeFactory.make(node_env3)
    #User4Class =  BufsNodeFactory.make(node_env4)
end

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
    DirFinder.dir_list = @user_base_dir_list #has been set
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
      view_dir.should == DirFinder.dir_list[user_class]
    end
  end
end

describe BufsFileViewReader do

  before(:each) do
    @user_classes = DirFinder.dir_list.keys
  end
  
  it "should have a models and views to work with" do
    @user_classes.each do |user_class|
      #TODO: Fix - The below creates an artificial dependendency between naming and functionality
      user_id = user_class.myGlueEnv.user_id
      if user_id =~ /FileSys/
        DirFinder.dir_list[user_class].should == user_class.myGlueEnv.namespace
      else
        DirFinder.dir_list[user_class].should == File.join(BFVMBaseDir, user_id)
        #FileUtils.mkdir_p(user_base_dir) unless File.exist?(user_base_dir)
      end
      File.exist?(DirFinder.dir_list[user_class]).should == true
      Dir.entries(DirFinder.dir_list[user_class]).size.should > 0
    end
  end
  
  it "should create a model from a directory" do
    @user_classes.each do |user_class|
      user_dir = DirFinder.dir_list[user_class]
      node_class = ProtoNode
      
      
      new_bufs_classes = [MakeReaderClasses::User1Class, MakeReaderClasses::User3Class]
      new_bufs_classes.each do |new_user_class|
        viewer = BufsFileViewReader.new(user_dir, new_user_class)
        viewer.read_view  #should create model
      end
      
      #verify
      new_bufs_classes.each do |new_user_class|
        new_nodes = new_user_class.all
        orig_nodes = user_class.all
        
        orig_nodes.size.should == new_nodes.size
        
        new_my_cats = new_user_class.all.map{|n| n.my_category}.sort
        orig_my_cats = user_class.all.map{|n| n.my_category}.sort
        orig_my_cats.should == new_my_cats
        
        orig_my_cats.each do |my_cat|
          orig_node = user_class.call_view(:my_category, my_cat).first
          new_node = user_class.call_view(:my_category, my_cat).first
          orig_node.parent_categories.sort.should == new_node.parent_categories.sort
          if orig_node.respond_to?(:links) && orig_node.links
            orig_node.links.sort.should == new_node.links.sort
          end
          if orig_node.respond_to?(:attached_files) && orig_node.attached_files
            orig_node.attached_files.should == new_node.attached_files
          end#if
        end#each (my_category key)
      end#each (new nodes)
    end#each (orig nodes)
  end#it (spec)
  
end
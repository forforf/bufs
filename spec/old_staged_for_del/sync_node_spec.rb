
require 'couchrest'

require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
CouchDB = BufsFixtures::CouchDB

module SyncNodeSpec
    LibDir = File.dirname(__FILE__) + '/../lib/'
    FileModelDir = File.dirname(__FILE__) + '/../sandbox_for_specs/sync_node_spec/model'
end


require SyncNodeSpec::LibDir + 'sync_node'


#mock classes
=begin
class MockDbModel
end
class MockFileModel
end

class MockAbsNode #concrete abstract node class mockup
  attr_accessor :my_category,
                :parent_categories,
                :description

  def full_name_space
    "#{self.class}-MockDBNode_name_space"
  end


  def initialize(my_cat, parent_cats, desc)
    @my_category = my_cat
    @parent_categories = parent_cats
    @description = desc
  end
end

class MockDbNode < MockAbsNode
  class << self
    attr_accessor :base_model_class
    @base_model_class = MockDbModel
  end
end
class MockFileNode < MockAbsNode
  class << self
    attr_accessor :base_model_class
    @base_model_class = MockFileModel
  end
end
class MockNoNameSpaceNode < MockAbsNode
 attr_accessor :my_category,
                :parent_categories,
                :description

  def initialize(my_cat, parent_cats, desc)
    @my_category = my_cat
    @parent_categories = parent_cats
    @description = desc
  end
end
=end

module SyncSpecHelpers
  BufsInfoDoc.set_name_space(CouchDB)
  BufsFileSystem.set_name_space(SyncNodeSpec::FileModelDir)
  def create_db_doc(init_data, data_file=nil)
    init_data_dup = init_data.dup #for couchrest weirdness
    bid = BufsInfoDoc.new(init_data_dup)
    p bid
    bid.save
    if data_file
      bid.add_data_file(data_file)
      bid.save
    end
    return_bid = BufsInfoDoc.get(bid['_id'])
  end

  def create_file_model(init_data, data_file=nil)
    bfs = BufsFileSystem.new(init_data)
    bfs.save
    if data_file
      bfs.add_data_file(data_file)
      bfs.save
    end
    puts bfs.my_category
    return_bfss = BufsFileSystem.by_my_category(bfs.my_category)
    raise "Multiple File Model Directories with same category name #{bfs.my_category} \n #{return_bfss.inspect}" if return_bfss.size > 1
    raise "No File Model found for #{bfs.my_category}" if return_bfss.size == 0
    return_bfs = return_bfss.first
  end

  def set_db_attachment_time(db_doc ,att_name, time)
    att = BufsInfoAttachment.get(db_doc.my_attachment_doc_id)
    att['md_attachments'][att_name]['file_modified'] = time
    att.save
    return_att = BufsInfoAttachment.get(db_doc.my_attachment_doc_id)
  end

  def get_db_attachment_time(db_doc, att_name)
    att = BufsInfoAttachment.get(db_doc.my_attachment_doc_id)
    att_time = Time.parse(att['md_attachments'][att_name]['file_modified'])
  end

  def set_file_model_file_time(file_model, full_file_name, time)
    puts "Current file time: #{File.mtime(full_file_name)}"
    puts "Updating file time to: #{time}"
    File.utime(time, time, full_file_name)
    puts "Updated file time: #{File.mtime(full_file_name)}"
    puts "File location updating: #{full_file_name.inspect}"

    #reload the updated file
    return_bfss = BufsFileSystem.by_my_category(file_model.my_category)
    raise "Multiple File Model Directories with same category name #{bfs.my_category}" if return_bf
    raise "No File Model found for #{bfs.my_category}" if return_bfss.size == 0
    return_bfs = return_bfss.first
  end

  def refresh_file_model_node(file_node, full_file_name, new_data)
    #TODO add capability of replacing with new data
    #update fresh file - File
    #making_fresh = file_loc
    #delay = 4
    #sleep delay
    now = Time.now
    puts "Current file time: #{File.mtime(full_file_name)}"
    puts "Updating file time to: #{now}"
    File.utime(now, now, full_file_name)
    puts "Updated file time: #{File.mtime(full_file_name)}"
    puts "File location updating: #{full_file_name.inspect}"

    #reload the updated file
    refreshed_file_nodes = BufsFileSystem.by_my_category(file_node.my_category)
    refreshed_file_nodes.size.should == 1
    refreshed_file_node = refreshed_file_nodes.first
  end

  class TestReadOnlyNode < ReadOnlyNode
    def initialize
      @test_file = "imaginary_read_only_node_file_location"
    end
    def my_category
      'read_only_node_test'
    end
    def parent_categories
      ['read only orphan']
    end
    def file_metadata
      test_file_basename = @test_file
      esc_basename = CGI.escape(test_file_basename)
      {esc_basename => {"file_modified" => Time.now.to_s}}
    end

    def get_file_data(file_name)
      "So fresh it hasn't even made it to the file yet"
    end
  end
end


describe SyncNode, "initializaton" do
  include SyncSpecHelpers
  before(:each) do
    db_node_data = {:my_category => 'common_cat',
                    :parent_categories => ['db_parent1', 'db_parent2'],
		    :description => 'desc db node data'}
    db_base_model = create_db_doc(db_node_data)
    @abs_node_from_db = AbstractNode.new(db_base_model)

    file_node_data = {:my_category => 'common_cat',
                      :parent_categories => ['file_parent1', 'file_parent2'],
		      :description => 'desc file node data'}
    file_base_model = create_file_model(file_node_data)
    @abs_node_from_file = AbstractNode.new(file_base_model)

=begin
    @mock_node1 = MockDbNode.new('_common_cat', 
			         ['_parent_cat11', '_parent_cat12'], 
				 nil)
    @mock_node2 = MockFileNode.new('_common_cat',
				   ['_parent_cat21', '_parent_cat22'],
				     nil)
=end
  end

  it "should not initialize unless it has a set of node types to sync across" do
    sync_nodes = [@abs_node_from_db]
    lambda {SyncNode.new(sync_nodes)}.should raise_error(NameError)
  end

  it "should initialize if the set of nodes to sync across has been set" do
    #Node classes being set are from abstract_node.rb
    SyncNode.set_sync_set_types([DBDocNode, FileSystemDocNode])
    sync_nodes = [@abs_node_from_db]
    SyncNode.new(sync_nodes).should_not == nil
  end

  it "should have at least one node to initialize" do
    sync_nodes = nil
    lambda {SyncNode.new(sync_nodes)}.should raise_error(ArgumentError)
  end

  it "needs to use a common category (my_category) to tie nodes together" do
    db_diff_cat_data = {:my_category => 'different_cat',
                        :parent_categories => ['db_parent1', 'db_parent2'],
                        :description => 'desc db node data'}
    db_diff_cat_base_model = create_db_doc(db_diff_cat_data)
    abs_node_from_db_diff_cat_data = AbstractNode.new(db_diff_cat_base_model)

    sync_nodes1 = [abs_node_from_db_diff_cat_data, @abs_node_from_file]
    lambda {SyncNode.new(sync_nodes1)}.should raise_error(ArgumentError)

    #mock_node_diff_my_cat = MockDbNode.new('_diff_cat', ['_parent_cat1', '_parent_cat2'], nil, '_diff_ns')
    #sync_nodes2 = [@mock_node1, mock_node_diff_my_cat]
    #lambda {SyncNode.new(sync_nodes2)}.should raise_error(ArgumentError)

    #sync_nodes3 = [mock_node_diff_my_cat, @mock_node1, @mock_node2]
    #lambda {SyncNode.new(sync_nodes3)}.should raise_error(ArgumentError)

    correct_nodes = [@abs_node_from_db, @abs_node_from_file]
    sync_node = SyncNode.new(correct_nodes)
    sync_node.my_category.should == @abs_node_from_db.my_category
    sync_node.my_category.should == @abs_node_from_file.my_category
    #sync_node.my_category.should == '_common_cat'
  end

  it "should be able to create a name space method for a node if one is missing"
    #need better mocks, or set up real node to test this
    #no_ns_node = MockNoNameSpaceNode.new(@mock_node1.my_category, ['_no_ns_parent_cat'], nil)

    #SyncNode.sync_set_types = [MockDbNode, MockFileNode, MockNoNameSpaceNode]
    #sync_nodes = [@mock_node1, @mock_node2, no_ns_node]
    #sync_node = SyncNode.new(sync_nodes)
    #sync_node.synced_nodes.each do |node|
    #  if node.class == no_ns_node.class
    #	node.full_name_space.should == no_ns_node.class.to_s
    #  end
    #end
  #end

  it ", nodes to synchronize should be unique" do
    dup_node = @abs_node_from_db.dup
    sync_nodes = [@abs_node_from_db, @abs_node_from_file, dup_node]
    lambda {SyncNode.new(sync_nodes)}.should raise_error(TypeError)
    #how to test the below with realistic data?
    #dup_mock_node.full_name_space = 'uniq_name_space'
    #sync_node = SyncNode.new(sync_nodes)
    #sync_node.synced_nodes.each do |node|
    #  sync_node.my_category.should == node.my_category
    #end
  end

end

describe NodeComparisonOperations do
  include SyncSpecHelpers
  before(:each) do
    db_node_data = {:my_category => 'common_cat',
                    :parent_categories => ['db_parent1', 'db_parent2'],
                    :description => 'desc db node data'}
    db_base_model = create_db_doc(db_node_data)
    @abs_node_from_db = AbstractNode.new(db_base_model)

    file_node_data = {:my_category => 'common_cat',
                      :parent_categories => ['file_parent1', 'file_parent2'],
                      :description => 'desc file node data'}
    file_base_model = create_file_model(file_node_data)
    @abs_node_from_file = AbstractNode.new(file_base_model)
    
    MockNode = Struct.new(:my_category, :parent_categories, :description)
    MockDbNode = MockNode
    MockFileNode = MockNode

    @mock_node1 = MockDbNode.new('_common_cat', ['_parent_cat11', '_parent_cat12'], nil)
    @mock_node2 = MockFileNode.new('_common_cat', ['_parent_cat21', '_parent_cat22'], nil)
  end

  it "should merge the parent categories across all synced nodes" do
    sync_nodes = [@mock_node1, @mock_node2]
    _dummy = Class.new
    _dummy.extend NodeComparisonOperations
    merged_parent_cats = _dummy.merge_parent_categories(sync_nodes)
    merged_parent_cats.sort.should == (@mock_node1.parent_categories + @mock_node2.parent_categories).uniq.sort
  end

  it "should be able to compare data elements" do
    mock_node_like1 = MockDbNode.new('_common_cat', ['_parent_cat31', '_parent_cat32'], nil)
    sync_nodes = [@mock_node1, mock_node_like1]
    _dummy = Class.new
    _dummy.extend NodeComparisonOperations
    _dummy.data_in_sync?(sync_nodes, :my_category).should == true
    _dummy.data_in_sync?(sync_nodes, :parent_categories).should == false
    #_dummy.data_in_sync?(sync_nodes, :full_name_space).should == true
    _dummy.data_in_sync?(sync_nodes, :description).should == true
  end

  it "should be able to compare file metadata"

  it "shold be able to identify the node with the freshest data"

end

describe "with more realistic test data" do
  before(:each) do
    BufsInfoDoc.set_name_space(CouchDB)
    BufsFileSystem.set_name_space(AbsNodeSpec::FileModelDir)
    @test_files = BufsFixtures.test_files
  end

end

describe SyncNode, "operations" do
  include SyncSpecHelpers

  before(:each) do
    db_node_data1 = {:my_category => 'common_cat',
                    :parent_categories => ['db_parent1', 'db_parent2'],
                    :description => 'desc db node data'}
    db_base_model1 = create_db_doc(db_node_data1)
    @abs_node_from_db1 = AbstractNode.new(db_base_model1)
    db_node_data2 = {:my_category => 'uniq_cat_db2',
                    :parent_categories => ['db_parent1', 'db_parent2'],
                    :description => 'desc db node data'}
    db_base_model2 = create_db_doc(db_node_data2)
    @abs_node_from_db2 = AbstractNode.new(db_base_model2)

    file_node_data1 = {:my_category => 'uniq_cat_file1',
                      :parent_categories => ['file_parent1', 'file_parent2'],
                      :description => 'desc file node data'}
    file_base_model1 = create_file_model(file_node_data1)
    @abs_node_from_file1 = AbstractNode.new(file_base_model1)

    file_node_data2 = {:my_category => 'common_cat',
                      :parent_categories => ['file_parent1', 'file_parent2'],
                      :description => 'desc file node data'}
    file_base_model2 = create_file_model(file_node_data2)
    @abs_node_from_file2 = AbstractNode.new(file_base_model2)

    @db_list = [@abs_node_from_db1, @abs_node_from_db2]
    @file_list = [@abs_node_from_file1, @abs_node_from_file2]

    @master_list_manual = {'common_cat' => [@abs_node_from_db1, @abs_node_from_file2],
                   'uniq_cat_db2' => [@abs_node_from_db2],
                   'uniq_cat_file1' => [@abs_node_from_file1] }

  end

  it "should be able to take multiple node lists and create a combined list for syncing" do
    #set initial conditions
    #test/check
    SyncNode.master_list([@db_list, @file_list]).should == @master_list_manual
  end

  it "should take a combined list for syncing and create a list (hash) of sync nodes" do
    #set initial conditions
    master_list = SyncNode.master_list([@db_list, @file_list])
    #test
    sync_master_list = SyncNode.sync_master_list(master_list)
    #check
    @master_list_manual.each do |my_cat, nodes|
      sync_master_list[my_cat].my_category.should == nodes.first.my_category
      sync_master_list[my_cat].class.should == SyncNode
    end
  end

  it "should sync across the entire set creating new nodes if parts of the set are missing"
  it "should be able to create a full set of syncable nodes from a partial set"
end


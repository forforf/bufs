
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'


require 'couchrest'
#doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!

module BufsDocSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end


#TestFileLocation = 'C:/Documents and Settings/dmartin/My Documents/tmp/'
#ProjectLocation = '/media-ec2/ec2a/projects/bufs/'
#TestFileLocation = ProjectLocation + 'sandbox_for_specs/db_doc_specs/'

#SrcLocation = ProjectLocation + 'src/'


require BufsDocSpec::LibDir + 'bufs_info_doc'

BufsInfoDoc.set_name_space(CouchDB)

describe BufsInfoDoc do
  before(:all) do
    @test_files = BufsFixtures.test_files
    @all_possible_fields = [:my_category, :parent_categories, :description, :file_metadata]
    @required_fields = {:my_category => 'test_1', :parent_categories => ['dad','mom']}
    @optional_fields = {:description => 'a lovely shade of indigo'}
    @initial_fields = @required_fields.merge(@optional_fields) #or should this be the other way?
    @baseline_fields = @initial_fields.dup #needed because of couchrest weirdness
    @bufs_info_doc = BufsInfoDoc.new(@initial_fields)
    @initial_db_size = BufsInfoDoc.all.size
  end


  it "should have initialized" do
    @bufs_info_doc.my_category.should == @baseline_fields[:my_category]
    @bufs_info_doc.parent_categories.should == @baseline_fields[:parent_categories]
  end

  it "should not save if required fields don't exist" do
    orig_db_size = BufsInfoDoc.all.size
    bad_bufs_info_doc1 = BufsInfoDoc.new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
    bad_bufs_info_doc2 = BufsInfoDoc.new(:my_category => 'no_parent_categories',
                                          :description => 'some description',
                                          :file_metadata => {})
    lambda { bad_bufs_info_doc1.save }.should raise_error(ArgumentError)
    lambda { bad_bufs_info_doc2.save }.should raise_error(ArgumentError)
    
    BufsInfoDoc.all.size.should == orig_db_size
  end

  it "should save (not testing ScoutInfoDoc really)" do
    @bufs_info_doc.save
    @all_possible_fields.each do |field|
      db_field = CouchDB.get(@bufs_info_doc['_id'])[field]
      @bufs_info_doc[field] == db_field
      #test accessor
      @bufs_info_doc.__send__(field) == db_field
    end
  end

  it "should have records in the model" do
    BufsInfoDoc.all.size.should > 0
  end


#adding categories
  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    new_cat = 'new category test1'
    @bufs_info_doc.add_parent_categories(new_cat)
    @bufs_info_doc.parent_categories.should include new_cat
    @all_possible_fields.each do |field|
      db_field = CouchDB.get(@bufs_info_doc['_id'])[field]
      @bufs_info_doc[field] == db_field
      #test accessor
      @bufs_info_doc.__send__(field) == db_field
    end
  end

  it "should add categories to existing categories and existing doc" do
    pre_existing_categories = BufsInfoDoc.get(@bufs_info_doc['_id']).parent_categories
    new_cat2 = 'new category test2'
    @bufs_info_doc.add_parent_categories(new_cat2)
    @bufs_info_doc.parent_categories.should include new_cat2
    all_uniq_categories = (@bufs_info_doc.parent_categories + pre_existing_categories).uniq.sort
    CouchDB.get(@bufs_info_doc['_id'])['parent_categories'].sort.should == all_uniq_categories
  end

  it "should work using add_category alias for add_parent_categories" do
    pre_existing_categories = BufsInfoDoc.get(@bufs_info_doc['_id']).parent_categories
    new_cat3 = 'new category test3'
    @bufs_info_doc.add_category(new_cat3)
    all_uniq_categories = (@bufs_info_doc.parent_categories + pre_existing_categories).uniq.sort
    CouchDB.get(@bufs_info_doc['_id'])['parent_categories'].sort.should == all_uniq_categories
  end

  it "should work using add_categories alias for add_parent_categories" do
    pre_existing_categories = BufsInfoDoc.get(@bufs_info_doc['_id']).parent_categories
    new_cat4 = 'new category test4'
    @bufs_info_doc.add_categories(new_cat4)
    @bufs_info_doc.parent_categories.should include new_cat4
    all_uniq_categories = (@bufs_info_doc.parent_categories + pre_existing_categories).uniq.sort
    CouchDB.get(@bufs_info_doc['_id'])['parent_categories'].sort.should == all_uniq_categories
  end

  it "should work for adding an array of categories" do
    pre_existing_categories = BufsInfoDoc.get(@bufs_info_doc['_id']).parent_categories
    multi_cats = ['cat5', 'cat6']
    @bufs_info_doc.add_parent_categories(multi_cats)
    multi_cats.each do |cat|
      @bufs_info_doc.parent_categories.should include cat
    end
    all_uniq_categories = (@bufs_info_doc.parent_categories + pre_existing_categories).uniq.sort
    CouchDB.get(@bufs_info_doc['_id'])['parent_categories'].sort.should == all_uniq_categories
  end

  it "should only have unique categories" do
    duped_cats = ['new category test1', 'cat7', 'cat7']
    @bufs_info_doc
    orig_size = @bufs_info_doc.parent_categories.size
    expected_size = orig_size + 1 #the cat7
    @bufs_info_doc.add_parent_categories(duped_cats)
    expected_size.should == @bufs_info_doc.parent_categories.size
    CouchDB.get(@bufs_info_doc['_id'])['parent_categories'].sort.should == @bufs_info_doc.parent_categories.sort
  end

  it "should not create separate records in the database" do
    records = BufsInfoDoc.by_my_category(:key => 'test_1')
    records.size.should == 1
  end

#adding data files
  it "save data files as an attachment with metadata" do
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    @bufs_info_doc.add_data_file(test_filename)

    att_doc_id = BufsInfoDoc.get(@bufs_info_doc['_id']).attachment_doc_id 
    #puts "Attachment Doc ID: #{att_doc_id}"
    att_doc = BufsInfoAttachment.get(att_doc_id)
    #puts "Attachment Doc: #{att_doc.inspect}"
    #p att_doc['_attachments'].keys
    att_doc['_attachments'].keys.should include CGI.escape(test_basename)
    att_doc['md_attachments'][test_basename]['file_modified'].should == File.mtime(test_filename).to_s
  end

  it "should create an attachment from raw data" do
    data_file = @test_files['binary_data3_pptx']
    binary_data = File.open(data_file, 'rb'){|f| f.read}
    binary_data_content_type = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    attach_name = File.basename(data_file)
    metadata = @bufs_info_doc.add_raw_data(attach_name, binary_data_content_type, binary_data)
    
    att_doc_id = BufsInfoDoc.get(@bufs_info_doc['_id']).attachment_doc_id
    #puts "Attachment Doc ID: #{att_doc_id}"
    att_doc = BufsInfoAttachment.get(att_doc_id)
    #puts "Attachment Doc: #{att_doc.inspect}"
    #p att_doc['_attachments'].keys
    esc_att_name = CGI.escape(attach_name)
    att_doc['_attachments'].keys.should include esc_att_name
    puts "Raw Data Metadata:" +  metadata.inspect
    file_mod_time = att_doc['md_attachments'][esc_att_name]['file_modified']
    Time.parse(file_mod_time).should > (Time.now - 2) #2 seconds should be enough time
    att_doc['_attachments'][esc_att_name]['content_type'].should == binary_data_content_type
  end

#creating a db doc from a directory entry
  it "should create a full doc from a node object without" do
    NodeMock = Struct.new(:my_category, :parent_categories, :description, :files)
    node_obj_mock_no_files = NodeMock.new('node_mock_category',
                                          ['mock_mom', 'mock_dad'],
                                          'mock description')
    bid = BufsInfoDoc.create_from_node(node_obj_mock_no_files)
    bid.my_category.should == node_obj_mock_no_files.my_category
    bid.parent_categories.should == node_obj_mock_no_files.parent_categories
    bid.description.should == node_obj_mock_no_files.description
  end

  it "should create a full doc from a node object with files" do
    test_filename = @test_files['binary_data3_pptx']
    test_basename = File.basename(test_filename)
    NodeMock = Struct.new(:my_category, :parent_categories, :description, :files)
    node_obj_mock_with_files = NodeMock.new('node_mock_category',
                                          ['mock_mom', 'mock_dad'],
                                          'mock description',
                                           [test_filename])
    bid = BufsInfoDoc.create_from_node(node_obj_mock_with_files)
    bid.my_category.should == node_obj_mock_with_files.my_category
    bid.parent_categories.should == node_obj_mock_with_files.parent_categories
    bid.description.should == node_obj_mock_with_files.description
    att_doc_id = BufsInfoDoc.get(bid['_id']).attachment_doc_id
    #puts "Attachment Doc ID: #{att_doc_id}"
    att_doc = BufsInfoAttachment.get(att_doc_id)
    puts "Attachment Doc: #{att_doc.inspect}"
    #p att_doc['_attachments'].keys
    att_doc['_attachments'].keys.should include CGI.escape(test_basename)
    att_doc['md_attachments'][test_basename]['file_modified'].should == File.mtime(test_filename).to_s
  end

  #more of a test of couchrest
  it "should be able to return documents by its category" do
    test_nodes = BufsInfoDoc.by_my_category(:key => @baseline_fields[:my_category])
    test_nodes.each do |node|
      node.my_category.should == @baseline_fields[:my_category]
    end
  end

  it "should only have a single entry for each doc category" do
    all_nodes = BufsInfoDoc.all
    all_nodes.each do |doc|
      BufsInfoDoc.by_my_category(:key => doc.my_category).size.should == 1
    end
  end

  #it "should return all model data when queried by the model's category name (my_category)" do
  #  ScoutInfoDoc.node_by_title('test_spec1.pptx').should == ScoutInfoDoc.by_title('test_spec1.pptx')
  #end

end


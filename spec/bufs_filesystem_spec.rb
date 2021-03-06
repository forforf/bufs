#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../lib/helpers/require_helper')

require Bufs.fixtures 'bufs_fixtures'
require Bufs.spec_helpers 'bufs_node_builder'
require Bufs.lib 'bufs_base_node'

#BufsDoc Libraries
BufsFileLibs = [Bufs.glue('bufs_filesystem_glue_env')]

TestFSModelBaseDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/file_system_specs'

  ModelDir = "tmp_test" #'BufsFileSystem_DefaultModel'
  FSDummyUserID = 'StubID1'
  BufsFileIncludes = [:FileSystemEnv]
  FileEnvironment = {:bufs_file_system_env => {:path => File.join(TestFSModelBaseDir,ModelDir),
                                               :user_id => FSDummyUserID},
                        :requires => BufsFileLibs,
                        :includes => BufsFileIncludes,
                        :glue_name => "BufsFileSystemEnv" }  #may not be final form


#TODO Tesing CouchRest implementation, need generic spec
#invoked this way for spec since we're testing the abstract class
#BufsBaseNode.__send__(:include, BufsInfoDocEnvMethods)
BufsBaseNode.set_environment(FileEnvironment, FileEnvironment[:glue_name])

describe BufsBaseNode, "Basic Document Operations (no attachments)" do
  include BufsNodeBuilder

  before(:each) do
    BufsBaseNode.destroy_all
  end

  it "should have its namespace set up correctly" do
    #TODO: Figure out if both datastore selector and datastore id are necessary (may require integration of other models)
    #TODO:  retrieve base model from BufsBaseNode glue env
    base_model_dir = ".model"
    BufsBaseNode.myGlueEnv.user_datastore_selector.should == File.join(TestFSModelBaseDir, ModelDir, FSDummyUserID, base_model_dir)
    BufsBaseNode.myGlueEnv.user_datastore_id.should == File.join(TestFSModelBaseDir, ModelDir, FSDummyUserID, base_model_dir)
  end

  it "should initialize correctly" do
    #check initial conditions
    BufsBaseNode.all.size.should == 0
    #test
    default_bid = BufsBaseNode.new(get_default_params)
    #check results (instance variables were dynamically generated from data)
    my_params = [:my_category, :parent_categories, :description]
    my_params.each do |my_param|
      default_bid.__send__(my_param).should == get_default_params[my_param]
      default_bid._user_data[my_param].should == get_default_params[my_param]
    end
    #we haven't saved it to the database yet
    BufsBaseNode.all.size.should == 0
  end

  it "should be able to remove dynamically generated data" do
    #check initial conditions
    BufsBaseNode.all.size.should == 0
    default_bid = BufsBaseNode.new(get_default_params)
    default_bid.my_category.should == get_default_params[:my_category]
    default_bid.parent_categories.should == get_default_params[:parent_categories]
    default_bid.description.should == get_default_params[:description]
    #test
    default_bid.__unset_userdata_key(:description)
    #verify results
    default_bid.my_category.should == get_default_params[:my_category]
    default_bid.parent_categories.should == get_default_params[:parent_categories]
    lambda {default_bid.description}.should raise_error(NameError)
    default_bid._user_data[:description].should == nil
  end

  it "should not save if required fields don't exist" do
    #set initial condition
    orig_db_size = BufsBaseNode.all.size
    #test
    lambda { bad_bufs_info_doc1 = BufsBaseNode.new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
            }.should raise_error(ArgumentError)

    #not tested, not sure whether to enforce parent cats or not yet
    #bad_bufs_info_doc2 = BufsBaseNode.new(:my_category => 'no_parent_categories',
    #                                      :description => 'some description',
    #                                      :file_metadata => {})
                                      
    #test
    #lambda { bad_bufs_info_doc1.save }.should raise_error(ArgumentError)
    #removed validation check for parent categories, not clear this is an issue
    #lambda { bad_bufs_info_doc2.save }.should raise_error(ArgumentError)

    #check results    
    BufsBaseNode.all.size.should == orig_db_size
  end

  it "should save" do
    #set initial conditions
    orig_db_size = BufsBaseNode.all.size
    orig_db_size.should == 0
    doc_params = get_default_params.merge({:my_category => 'save_test'})
    doc_to_save = make_doc_no_attachment(doc_params.dup)

    #test
    doc_to_save.__save
    
    #check results
    doc_params.keys.each do |param|
      #TODO convert to datastore selector if possible
      namespace = BufsBaseNode.myGlueEnv.user_datastore_id
      node_id = doc_to_save.my_category
      doc_id = BufsBaseNode.myGlueEnv.generate_model_key(namespace, node_id)
      db_param = doc_to_save.class.get(doc_id).__send__(param.to_sym)
      doc_to_save._user_data[param].should == db_param
      #test accessor method
      doc_to_save.__send__(param).should == db_param
    end
    BufsBaseNode.all.size.should == orig_db_size + 1
  end

  #TODO Can my_cat handle slashes???
  #TODO Add to couchrest too
  it "should handle strange characters (SUCH AS :: ) in my_cat" do
    #set initial conditions
    orig_db_size = BufsBaseNode.all.size
    orig_db_size.should == 0
    #TODO: characters -> :: cause my_cat to fail
    doc_params = get_default_params.merge({:my_category => 'save::test'})
    doc_to_save = make_doc_no_attachment(doc_params.dup)
    #test
    doc_to_save.__save
    #verify results
    puts "doc to save: #{doc_to_save.my_category}"
    puts "doc to save id: #{doc_to_save._model_metadata[:_id]}"
    saved_doc = BufsBaseNode.get(doc_to_save._model_metadata[:_id])
    doc_to_save.my_category.should == saved_doc.my_category
  end

  it "dynamic operations shouldn't modify my_category (the primary key)" do
    #set initial conditions
    my_cat = 'cat_test1'
    parent_cats = ['parent cat']
    doc_params = get_default_params.merge({:my_category => my_cat, :parent_categories => parent_cats})
    doc = make_doc_no_attachment(doc_params)
    #test
    doc.my_category_add('dont_add_this')#.should == my_cat
    doc.my_category.should == my_cat
    doc.my_category_subtract('dont_subtract_this')#.should == my_cat
    doc.my_category.should == my_cat
  end

 it "dynamic operations shouldn add new parent categories" do
    #set initial conditions
    my_cat = 'cat_test1'
    parent_cats = ['parent cat']
    doc_params = get_default_params.merge({:my_category => my_cat, :parent_categories => parent_cats})
    doc = make_doc_no_attachment(doc_params)
    doc.parent_categories.should == parent_cats
    #test
    new_parent_cat = "new_parent_cat"
    doc.parent_categories_add(new_parent_cat)
    doc.parent_categories.should == parent_cats + [new_parent_cat]
    doc.my_category_subtract('dont_subtract_this').should == my_cat
    doc.my_category.should == my_cat
 end

  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    #set initial conditions
    orig_parent_cats = ['old parent cat']
    doc_params = get_default_params.merge({:my_category => 'cat_test1', :parent_categories => orig_parent_cats})
    doc_with_new_parent_cat = make_doc_no_attachment(doc_params)
    new_cat = 'new parent cat'
    initial_rev = doc_with_new_parent_cat._model_metadata[:_rev]
    #test
    doc_with_new_parent_cat.parent_categories_add(new_cat)
    after_save_rev = doc_with_new_parent_cat._model_metadata[:_rev]
    #check results
    #check doc in memory
    doc_with_new_parent_cat.parent_categories.should include new_cat
    #check database
    doc_params.keys.each do |param|
      node = doc_with_new_parent_cat
      node_id = node._model_metadata[:_id]
      persistent_node = node.class.get(node_id)
      #puts "Node Id: #{node_id.inspect}\n All: #{node.class.all.inspect}"
      db_param = persistent_node.__send__(param.to_sym)
      #db_param = doc_with_new_parent_cat.class.get(doc_with_new_parent_cat._model_metadata[:_id]).__send__(param.to_sym)
      #doc_with_new_parent_cat[param].should == db_param
      #test accessor method
      doc_with_new_parent_cat.__send__(param).should == db_param
    end
    #check revs
    initial_rev.should == nil  #we never saved it
    after_save_rev.should_not == initial_rev
  end

  it "shouldn't update parent categories in the db if the data is unchanged" do
    orig_parent_cats = ['old parent cat']
    doc_params = get_default_params.merge({:my_category => 'cat_test1',
                                           :parent_categories => orig_parent_cats})
    doc_with_new_parent_cat = make_doc_no_attachment(doc_params)
    new_cat = 'old parent cat'
    doc_with_new_parent_cat.__save
    initial_rev = doc_with_new_parent_cat._model_metadata[:_rev]
    #test
    doc_with_new_parent_cat.parent_categories_add(new_cat)
    after_save_rev = doc_with_new_parent_cat._model_metadata[:_rev]
    #check results
    #check doc in memory
    doc_with_new_parent_cat.parent_categories.should include new_cat
    #check database
    doc_params.keys.each do |param|
      db_param = doc_with_new_parent_cat.class.get(doc_with_new_parent_cat._model_metadata[:_id]).__send__(param.to_sym)
      #doc_with_new_parent_cat[param].should == db_param
      #test accessor method
      doc_with_new_parent_cat.__send__(param).should == db_param
    end
    initial_rev.should_not == nil
    initial_rev.should == after_save_rev
  end

  it "should add categories to existing categories and existing doc" do
    #set initial conditions
    orig_parent_cats = ['orig_cat1', 'orig_cat2']
    doc_params = get_default_params.merge({:my_category => 'cat_test2', :parent_categories => orig_parent_cats})
    doc_existing_new_parent_cat = make_doc_no_attachment(doc_params)
    doc_existing_new_parent_cat.__save
    #verify initial conditions
    doc_params.keys.each do |param|
      db_param = doc_existing_new_parent_cat.class.get(doc_existing_new_parent_cat._model_metadata[:_id]).__send__(param.to_sym)
      #doc_existing_new_parent_cat[param].should == db_param
      #test accessor method
      doc_existing_new_parent_cat.__send__(param).should == db_param
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    #doc_rev0 = doc_existing_new_parent_cat._model_metadata['_rev']
    doc_existing_new_parent_cat.parent_categories_add(new_cats)
    #doc_existing_new_parent_cat.__save
    #doc_rev1 = doc_existing_new_parent_cat._model_metadata['_rev']
    #doc_rev0.should_not == doc_rev1
    #check results
    #check doc in memory
    new_cats.each do |new_cat|
      existing_cats = doc_existing_new_parent_cat.parent_categories
      doc_existing_new_parent_cat.parent_categories.should include new_cat
      #ex_cats = existing_cats
      #ex_cats.should include new_cat
    end
    #check database
    parent_cats = doc_existing_new_parent_cat.class.get(doc_existing_new_parent_cat._model_metadata[:_id]).__send__(:parent_categories)
    new_cats.each do |cat|
      parent_cats.should include cat
    end
    #check all cats are there and are unique
    parent_cats.sort.should == (orig_parent_cats + new_cats).uniq.sort
  end


  it "should be able to remove parent categories" do
    #set initial conditions
    orig_parent_cats = ['orig_cat3', 'orig_cat4', 'del_this_cat1', 'del_this_cat2']
    doc_params = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats})
    doc_remove_parent_cat = make_doc_no_attachment(doc_params)
    doc_remove_parent_cat.__save
    #verify initial conditions
    doc_params.keys.each do |param|
      db_param = doc_remove_parent_cat.class.get(doc_remove_parent_cat._model_metadata[:_id]).__send__(param.to_sym)
      #doc_remove_parent_cat[param].should == db_param
      #test accessor method
      doc_remove_parent_cat.__send__(param).should == db_param
    end
    #continue with initial conditions
    remove_multi_cats = ['del_this_cat1', 'del_this_cat2']
    remove_multi_cats.each do |cat|
      doc_remove_parent_cat.parent_categories.should include cat
    end

    #test
    doc_remove_parent_cat.parent_categories_subtract(remove_multi_cats)

    #verify results
    remove_multi_cats.each do |cat|
      doc_remove_parent_cat.parent_categories.should_not include cat
    end
    cats_in_db = doc_remove_parent_cat.class.get(doc_remove_parent_cat._model_metadata[:_id]).__send__(:parent_categories)
    remove_multi_cats.each do |removed_cat|
      cats_in_db.should_not include removed_cat
    end
  end
 
  it "should only have unique categories" do
    #verify initial state
    BufsBaseNode.all.size.should == 0
    #set initial conditions
    orig_parent_cats = ['dup cat1', 'dup cat2', 'uniq cat1']
    doc_params = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats})
    doc_uniq_parent_cat = make_doc_no_attachment(doc_params)
    doc_uniq_parent_cat.__save
    orig_size = doc_uniq_parent_cat.parent_categories.size
    new_cats = ['dup cat1', 'dup cat2', 'uniq_cat2']
    expected_size = orig_size + 1 #uniq_cat2
    #test
    doc_uniq_parent_cat.parent_categories_add(new_cats)
    #verify results
    expected_size.should == doc_uniq_parent_cat.parent_categories.size
    doc_uniq_parent_cat.class.get(doc_uniq_parent_cat._model_metadata[:_id]).__send__(:parent_categories).sort.should == doc_uniq_parent_cat.parent_categories.sort
    #"can't query on :my_category".should == "test should have way to query based on :my_category"
    records = BufsBaseNode.call_view(:my_category , doc_uniq_parent_cat.my_category)
    records = [records].flatten
    records.size.should == 1
  end

  it "should allow new data fields to be added to the data structure" do
    #set initial conditions
    parent_cats = ['dynamic data structure']
    my_cat = 'doc_dyndata'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    new_key_field = :links
    #new_data = "http:\\\\to.somewhere.blah"
    #test for new field
    basic_node.__set_userdata_key(new_key_field, nil)
    #verify new field exists and works 
    basic_node.respond_to?(new_key_field).should == true
    basic_node.__send__(new_key_field).should == nil
    #initial conditions for  adding data
    #NOTE: :links has a special operations for add and subtract
    #defined in the Node Operations (see midas directory)
    new_data = {:link_name => "blah", :link_src =>"http:\\\\to.somewhere.blah"}
    add_method = "#{new_key_field}_add".to_sym
    LinkAddOp = NodeElementOperations::LinkAddOp
    #test adding new data
    basic_node.__send__(add_method, new_data)
    #verify new data was added appropriately
    updated_data = basic_node.__send__(new_key_field)
    updated_data.should == new_data  #old links version it would not be equal
    magically_transformed_data = LinkAddOp.call(nil, new_data)[:update_this]
    updated_data.should == magically_transformed_data
  end
end

describe BufsBaseNode, "Attachment Operations" do
  include BufsNodeBuilder

  before(:all) do 
    @test_files = BufsFixtures.test_files
  end

  before(:each) do
    BufsBaseNode.destroy_all
  end

  it "should save data files with metadata" do
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    #check initial conditions
    BufsBaseNode.get(basic_node._model_metadata[:_id]).attached_files.should == nil
    #test (single file)
    basic_node.files_add(:src_filename => test_filename)
    #check results
    att_node_id = basic_node._model_metadata[:_id]
    att_node = BufsBaseNode.get(att_node_id)
    att_node.attached_files.size.should == 1
    att_node._user_data.should == basic_node._user_data
    att_node.attached_files.should == basic_node.attached_files
  end

  it "should remove specified data files" do
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basenames.first.should == BufsEscape.escape(test_basename)
    #test
    basic_node.files_subtract(attached_basenames)
    #check_results
    basic_node.attached_files.size.should == 0
    root_path = basic_node.my_GlueEnv.user_datastore_selector
    node_loc = basic_node._user_data[basic_node.my_GlueEnv.node_key]
    node_path = File.join(root_path, node_loc)
    attached_filenames = attached_basenames.map{|b| 
                           File.join(node_path, BufsEscape.escape(b))}
    attached_filenames.each {|f| File.exists?(f).should == false}
    att_node_id = basic_node._model_metadata[:_id]
    att_node = BufsBaseNode.get(att_node_id)
    att_node.attached_files.size.should == 0
  end

  it "should not have orphaned attachments when node is deleted" do
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basenames.first.should == BufsEscape.escape(test_basename)
    #test
    basic_node.__destroy_node
    #check results
    att_node_id = basic_node._model_metadata[:_id]
    att_node = BufsBaseNode.get(att_node_id)
    att_node.should == nil
    root_path = basic_node.my_GlueEnv.user_datastore_selector
    node_loc = basic_node._user_data[basic_node.my_GlueEnv.node_key]
    node_path = File.join(root_path, node_loc)
    File.exists?(node_path).should == false #any attachments would be in that dir too
  end

  it "should remove all attachments" do
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basenames.first.should == BufsEscape.escape(test_basename)
    #test
    basic_node.files_remove_all
    #verify results
    basic_node.attached_files.should == nil
    att_node_id = basic_node._model_metadata[:_id]
    att_node = BufsBaseNode.get(att_node_id)
    att_node.attached_files.should == nil
  end

  it "should list attachments" do
    list = []
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    list << BufsEscape.escape(test_basename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basenames.first.should == BufsEscape.escape(test_basename)
    #test
    #  performed in code
    #verify results
    basic_node.attached_files.sort.should == list.sort
  end

  it "should avoid creating hellish names when escaping and unescaping" do
    test_filename = @test_files['strange_characters_in_file_name']
    test_basename = File.basename(test_filename)
    list = [test_basename]
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1_esc_test'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    #test
    basic_node.files_add(:src_filename => test_filename)
    #check results
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basenames.first.should == BufsEscape.escape(test_basename)
  end

  it "should create an attachment from raw data" do
    #set initial conditions
    data_file = @test_files['binary_data3_pptx'] #@test_files['strange_characters_in_file_name']
    binary_data = File.open(data_file, 'rb'){|f| f.read}
    binary_data_content_type = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    attach_name = File.basename(data_file)
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1_raw_data'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    #test
    basic_node.add_raw_data(attach_name, binary_data_content_type, binary_data)
    #check results
    att_node_id = basic_node._model_metadata[:_id]
    att_node = BufsBaseNode.get(att_node_id)
    att_node.attached_files.size.should == 1
    att_node.attached_files.first.should == BufsEscape.escape(attach_name)
  end

  it "should find the attachment record for the node (internal)" do
    list = []
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    list << BufsEscape.escape(test_basename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basenames.first.should == BufsEscape.escape(test_basename)
    #test
    att_doc = basic_node._files_mgr.moab_interface.class.get_att_doc(basic_node)
    #moab specific internal test
    File.basename(att_doc.first).should == BufsEscape.escape(test_basename)
  end

  it "should be able to retrieve the metadata for an attachment" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basename = attached_basenames.first
    attached_basename.should == BufsEscape.escape(test_basename)
    #test
    moab_att_metadata = basic_node.__get_attachments_metadata
    md = moab_att_metadata[test_basename.to_sym]
    md[:file_modified].should == File.mtime(test_filename).to_s
    #TODO Test for content type match too
  end

  it "should be able to retrieve the metadata for a single attachments" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basename = attached_basenames.first
    attached_basename.should == BufsEscape.escape(test_basename)
    #test
    moab_att_metadata = basic_node.__get_attachment_metadata(test_basename)
    #file_raw_data = File.open(test_filename, "r"){|f| f.read}
    moab_att_metadata[:file_modified].should == File.mtime(test_filename).to_s
    moab_att_metadata[:content_type].should =~ /text\/plain/
    #TODO Test for content type match too
  end


  it "should be able to retrieve the raw data for all attachments" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basename = attached_basenames.first
    attached_basename.should == BufsEscape.escape(test_basename)
    #test
    moab_raw_data = basic_node.get_raw_data(attached_basename)
    file_raw_data = File.open(test_filename, "r"){|f| f.read}
    moab_raw_data.should == file_raw_data
  end

  it "should have an export function for attachments" do
      test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    basic_node.files_add(:src_filename => test_filename)
    #check initial conditions
    data = File.open(test_filename, 'r'){|f| f.read}
    data.should == 'Simple Text File'
    node_ns = basic_node.my_GlueEnv.namespace
    node_dir = File.join(node_ns, '.model', basic_node.my_category)
    node_file = File.join(node_dir, test_basename)
    puts "Node File to test: #{node_file.inspect}"
    node_exist = File.exist?(node_file)
    node_exist.should == true
    node_file_data = File.open( node_file, 'r'){|f| f.read}
    node_file_data.should == 'Simple Text File'
    attached_basenames = basic_node.attached_files
    attached_basenames.size.should == 1
    attached_basename = attached_basenames.first
    attached_basename.should == BufsEscape.escape(test_basename)
    #test
    exported_att_data = basic_node.__export_attachment(attached_basename)
    exported_att_data[:metadata].should == basic_node.__get_attachment_metadata(attached_basename)
    exported_att_data[:raw_data].should == basic_node.get_raw_data(attached_basename)
  end

  it "should have an import function for attachments" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes with attachments']
    my_cat = 'doc_w_att1'
    params = {:my_category => my_cat, :parent_categories => parent_cats}
    node_params = get_default_params.merge(params)
    basic_node = make_doc_no_attachment(node_params)
    basic_node.__save
    file_modified = File.mtime(test_filename).to_s
    content_type = MimeNew.for_ofc_x(test_filename)
    metadata = {:file_modified => file_modified, :content_type => content_type}
    raw_data = File.open(test_filename, "r"){|f| f.read}
    import_format = {:raw_data => raw_data, :metadata => metadata}
    att_name = BufsEscape.escape(test_basename)
    #test
    basic_node.__import_attachment(att_name, import_format)
    #verify results
    basic_node.attached_files.size.should == 1
    basic_node.attached_files.first.should == att_name
  end


end


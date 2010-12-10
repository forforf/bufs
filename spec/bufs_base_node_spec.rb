#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require Bufs.fixtures 'bufs_fixtures'
require Bufs.spec_helpers 'bufs_node_builder'
require Bufs.lib 'bufs_base_node'

CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!

#BufsDoc Libraries
BufsDocLibs = [Bufs.glue('bufs_couchrest_glue_env')]

#BufsBaseNode.set_name_space(CouchDB)
=begin
module BufsBaseNodeSpecHelpers
  DefaultDocParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultDocParams.dup #to avoid a couchrest weirdness don't use the params directly
  end
  
  def make_doc_no_attachment(override_defaults={})
    #default_params = {:my_category => 'default', 
    #                  :parent_categories => ['default_parent'],
    #		      :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return BufsBaseNode.new(init_params)
  end
end
=end

module BufsBaseNodeSpec
  StubsForSpec = BufsDocLibs = [File.dirname(__FILE__) + '/../lib/glue_envs/base_class_stub_for_spec']
  
  DummyUserID = 'BaseStubID1'
  StubIncludes = [:PersistentModelEnv]
  StubModelEnv = {:persistent_model_env => {:pers_mod_param1 => :param1,
                                               :pers_mod_param2 => :param2,
                                               :user_id => DummyUserID},
                        :requires => StubsForSpec,
                        :includes => StubIncludes,
                        :glue_name => "GlueStub"}  #may not be final form
                        
  
end

describe BufsBaseNode, "Base Class initialization with stubs" do
  #include BufsBaseNodeSpec
  
  before(:each) do
    @user_class = BufsBaseNode
  end
  
  it "should have a persistent model environment set up" do
    my_env = BufsBaseNodeSpec::StubModelEnv
    BufsBaseNode.set_environment(my_env, my_env[:glue_name])
    GlueStub::IsLoaded.should == true
    @user_class.metadata_keys.should == [:model_metadata]
  end
  
  it "should be able to query all native records associated with the class" do
    @user_class.all_native_records.should == "returns all records in native form"
  end
  
  it "should fail to initialize if validations aren't met"
  
  it "should be able to intialize" do
    initial_params = {:node_id => 'node_new',
        :model_content => 'native data new',
        :model_metadata => 'n/a to base node new',
        :content_to_remove => 'bye, bye new'}
    new_node = @user_class.new(initial_params)
    new_node.class.should == @user_class
    #TODO: More verifications should be added
  end
  
  it "should be able to query all records and return them in base class form" do
    data_structure_changes = {:add => {:new_dynamic_key => 'default dynamic value'},
                                          :remove => [:model_metadata]}
    nodes = @user_class.all(data_structure_changes)
    #data defined in  GlueStub
    nodes.each do |node|
      ['node1', 'node2'].should include node.node_id
      ['native data 1', 'native data 2'].should include node.model_content
      node.new_dynamic_key.should == 'default dynamic value'
      #TODO: Create test to show it would be there otherwise
      node.respond_to?(:model_metadata).should == false
    end
  end
  
  it "should be able to filter records from the model using call view"
  it "should be able to find records from the model by an id"
  it "should be able to destroy all user records in the model natively"
  it "should be able to create a new node (may not be testable here)"
  it "should have an attachment base id decoupled from the model"
  
  
  
  
end

=begin
#BufsBaseNode.set_environment(CouchDBEnvironment, CouchDBEnvironment[:glue_name])

describe BufsBaseNode, "Basic Document Operations (no attachments)" do
  include BufsBaseNodeSpecHelpers

  before(:each) do
    BufsBaseNode.destroy_all
  end

  it "should have its namespace set up correctly" do
    #raise CouchDB.inspect
    #Namespace and Collection Namespace are identical?
    BufsBaseNode.myClassEnv.namespace.should == "#{CouchDB.name}_#{DummyUserID}"

    db_name_path = CouchDB.uri
    lose_leading_slash = db_name_path.split("/")
    lose_leading_slash.shift
    db_name = lose_leading_slash.join("")
    BufsBaseNode.myClassEnv.collection_namespace.should == "#{db_name}_#{DummyUserID}"
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
      default_bid.user_data[my_param].should == get_default_params[my_param]
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
    default_bid.iv_unset(:description)
    #verify results
    default_bid.my_category.should == get_default_params[:my_category]
    default_bid.parent_categories.should == get_default_params[:parent_categories]
    lambda {default_bid.description}.should raise_error(NameError)
    default_bid.user_data[:description].should == nil
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
    doc_to_save.save
    
    #check results
    doc_params.keys.each do |param|
      namespace = BufsBaseNode.myClassEnv.user_datastore_id
      node_id = doc_to_save.my_category
      doc_id = BufsBaseNode.myClassEnv.generate_model_key(namespace, node_id)
      db_param = CouchDB.get(doc_id)[param]
      doc_to_save.user_data[param].should == db_param
      #test accessor method
      doc_to_save.__send__(param).should == db_param
    end
    BufsBaseNode.all.size.should == orig_db_size + 1
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
    initial_rev = doc_with_new_parent_cat.model_metadata[:_rev]
    #test
    doc_with_new_parent_cat.parent_categories_add(new_cat)
    after_save_rev = doc_with_new_parent_cat.model_metadata[:_rev]
    #check results
    #check doc in memory
    doc_with_new_parent_cat.parent_categories.should include new_cat
    #check database
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_with_new_parent_cat.model_metadata[:_id])[param]
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
    doc_with_new_parent_cat.save
    initial_rev = doc_with_new_parent_cat.model_metadata[:_rev]
    #test
    doc_with_new_parent_cat.parent_categories_add(new_cat)
    after_save_rev = doc_with_new_parent_cat.model_metadata[:_rev]
    #check results
    #check doc in memory
    doc_with_new_parent_cat.parent_categories.should include new_cat
    #check database
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_with_new_parent_cat.model_metadata[:_id])[param]
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
    doc_existing_new_parent_cat.save
    #verify initial conditions
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_existing_new_parent_cat.model_metadata[:_id])[param]
      #doc_existing_new_parent_cat[param].should == db_param
      #test accessor method
      doc_existing_new_parent_cat.__send__(param).should == db_param
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    #doc_rev0 = doc_existing_new_parent_cat.model_metadata['_rev']
    doc_existing_new_parent_cat.add_parent_categories(new_cats)
    #doc_existing_new_parent_cat.save
    #doc_rev1 = doc_existing_new_parent_cat.model_metadata['_rev']
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
    parent_cats = CouchDB.get(doc_existing_new_parent_cat.model_metadata[:_id])[:parent_categories]
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
    doc_remove_parent_cat.save
    #verify initial conditions
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_remove_parent_cat.model_metadata[:_id])[param]
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
    doc_remove_parent_cat.remove_parent_categories(remove_multi_cats)

    #verify results
    remove_multi_cats.each do |cat|
      doc_remove_parent_cat.parent_categories.should_not include cat
    end
    cats_in_db = CouchDB.get(doc_remove_parent_cat.model_metadata[:_id])['parent_categories']
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
    doc_uniq_parent_cat.save
    orig_size = doc_uniq_parent_cat.parent_categories.size
    new_cats = ['dup cat1', 'dup cat2', 'uniq_cat2']
    expected_size = orig_size + 1 #uniq_cat2
    #test
    doc_uniq_parent_cat.add_parent_categories(new_cats)
    #verify results
    expected_size.should == doc_uniq_parent_cat.parent_categories.size
    CouchDB.get(doc_uniq_parent_cat.model_metadata[:_id])['parent_categories'].sort.should == doc_uniq_parent_cat.parent_categories.sort
    #"can't query on :my_category".should == "test should have way to query based on :my_category"
    records = BufsBaseNode.call_view(:my_category , doc_uniq_parent_cat.my_category)
    records = [records].flatten
    records.size.should == 1
  end
end
=end

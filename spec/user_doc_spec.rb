
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'


require 'couchrest'
#doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!
CouchDB2 = BufsFixtures::CouchDB2
CouchDB2.compact!


require File.dirname(__FILE__) + '/../lib/user_doc'

module UserDocSpecHelpers
  DefaultDocParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultDocParams.dup #to avoid a couchrest weirdness don't use the params directly
  end
  
  def make_doc_no_attachment(user_id, override_defaults={})
    #default_params = {:my_category => 'default', 
    #                  :parent_categories => ['default_parent'],
    #		      :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return UserDB.user_to_docClass[user_id].new(init_params)
  end
end

describe UserDB, "Initialization" do
  #include BufsInfoDocSpecHelpers

  before(:each) do
    @user1_id = "User001"
    @user2_id = "User002"
    @user1_db = UserDB.new(CouchDB, @user1_id)
    @user2_db = UserDB.new(CouchDB2, @user2_id)
   
    #all_docs = UserDB.all
    #all_docs.each do |doc|
    #  doc.destroy
    #end
    #UserDB.on(CouchDB2)
  end

  it "should initialize user docs properly" do
    #test
    user1_doc = @user1_db.docClass.new({:user1_doc => "user1_data"})
    user2_doc = @user2_db.docClass.new({:user2_doc => "user2_data"})

    #check results
    #users should be registered in UserDB
    UserDB.user_to_docClass[@user1_id].should == user1_doc.class
    UserDB.user_to_docClass[@user2_id].should == user2_doc.class
    UserDB.docClass_users[user1_doc.class.name].should == [@user1_id]
    UserDB.docClass_users[user2_doc.class.name].should == [@user2_id]
  end
end

describe UserDB, "Basic database operations" do
  include UserDocSpecHelpers

  before(:each) do
    #delete any existing db records
    #TODO This only works if the db entry also exists in UserDB
    #Need to query each user database (how do we know the names?)
    # => need to enforce database naming convention.
    #query for couchrest-type that matches /UserDB::UserDoc*/
    UserDB.docClasses.each do |docClass|
      all_user_docs = docClass.all
      all_user_docs.each do |user_doc|
        user_doc.destroy
      end
    end

    @user1_id = "User001"
    @user2_id = "User002"
    @user1_db = UserDB.new(CouchDB, @user1_id)
    @user2_db = UserDB.new(CouchDB2, @user2_id)
  end

  it "should have the database initialized correctly" do
    #check initial conditions
    UserDB.docClasses.each do |docClass|
      docClass.all.size.should == 0
    end
    #test
    default_docs = []
    UserDB.docClasses.each do |docClass|
      default_docs << docClass.new(get_default_params)
    end
    #check results
    default_docs.each do |default_doc|
      default_doc.my_category.should == get_default_params[:my_category]
      default_doc.parent_categories.should == get_default_params[:parent_categories]
      default_doc.description.should == get_default_params[:description]
    end
    #we haven't saved it to the database yet
    UserDB.docClasses.each do |docClass|
      docClass.all.size.should == 0
    end
  end



  it "should perform basic collection operations properly" do
    user1_doc = @user1_db.docClass.new({:my_category => "user1_data"})
    user2_doc = @user2_db.docClass.new({:my_category => "user2_data"})
    user1_doc.save
    user2_doc.save
    #p UserDB.user_to_docClass
    #TODO: Fix the database state so that these tests are valid
    UserDB.user_to_docClass[@user1_id].all.first[:my_category].should == "user1_data"  #dangerous test, depends on db state
    UserDB.user_to_docClass[@user2_id].all.first[:my_category].should == "user2_data"  #dangerous test dependos on db state
  end

  it "should not save if required fields don't exist" do
    #set initial condition
    orig_db_size = {}
    bad_user_doc = {}
    all_users = UserDB.user_to_docClass.keys
    all_users.each do |user_id|
      orig_db_size[user_id] = UserDB.user_to_docClass[user_id].all.size
      bad_user_doc[user_id] = UserDB.user_to_docClass[user_id].new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
    end

    #test
    all_users.each do |user_id|
      lambda { bad_user_doc[user_id].save }.should raise_error(ArgumentError)
    end
    #removed validation check for parent categories, not clear this is an issue
    #lambda { bad_bufs_info_doc2.save }.should raise_error(ArgumentError)

    #check results
    all_users.each do |user_id|
      UserDB.user_to_docClass[user_id].all.size.should == orig_db_size[user_id]
    end
  end



  it "should save" do
    #set initial conditions
    orig_db_size = {}
    docs_params = {}
    docs_to_save = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      orig_db_size[user_id] = docClass.all.size
      docs_params[user_id] = get_default_params.merge({:my_category => 'save_test'})
      docs_to_save[user_id] = make_doc_no_attachment(user_id, docs_params[user_id].dup)
    end


    #test
    docs_to_save.each do |user_id, doc_to_save|
      doc_to_save.save
    end

    #check results
    UserDB.user_to_docClass.each do |user_id, docClass|
      docs_params[user_id].keys.each do |param|
        db_param = docClass.namespace.get(docs_to_save[user_id]['_id'])[param]
        docs_to_save[user_id][param].should == db_param
        #test accessor method
        docs_to_save[user_id].__send__(param).should == db_param
      end
    end
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.all.size.should == orig_db_size[user_id] + 1
    end 
  end

#adding categories
  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    #set initial conditions
    orig_parent_cats = {}
    doc_params = {}
    docs_with_new_parent_cat = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      orig_parent_cats[user_id] = ['old parent cat']
      new_params = get_default_params.merge({:my_category => "cat_test#{user_id}", :parent_categories => orig_parent_cats[user_id]})
      doc_params[user_id] = new_params
      docs_with_new_parent_cat[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
    end

    new_cat = 'new parent cat'

    UserDB.user_to_docClass.each do |user_id, docClass|
      #p docs_with_new_parent_cat[user_id]
    end

    #test

    UserDB.user_to_docClass.each do |user_id, docClass|
     docs_with_new_parent_cat[user_id].add_parent_categories(new_cat)
    end
    #check results
    UserDB.user_to_docClass.each do |user_id, docClass|
      #check doc in memory
      docs_with_new_parent_cat[user_id].parent_categories.should include new_cat
      #check database
      doc_params[user_id].keys.each do |param|
        db_param = docClass.namespace.get(docs_with_new_parent_cat[user_id]['_id'])[param]
        docs_with_new_parent_cat[user_id][param].should == db_param
        #test accessor method
        docs_with_new_parent_cat[user_id].__send__(param).should == db_param
      end
    end
  end

  it "should add categories to existing categories and existing doc" do
    #set initial conditions
    orig_parent_cats = {}
    doc_params = {}
    doc_existing_new_parent_cats = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      orig_parent_cats[user_id] = ["#{user_id}-orig_cat1", "#{user_id}-orig_cat2"]
      doc_params[user_id] = get_default_params.merge({:my_category => "#{user_id}-cat_test2", :parent_categories => orig_parent_cats[user_id]})
      doc_existing_new_parent_cats[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      doc_existing_new_parent_cats[user_id].save
    end
    #verify initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc_params[user_id].keys.each do |param|
        db_param = docClass.get(doc_existing_new_parent_cats[user_id]['_id'])[param]
        doc_existing_new_parent_cats[user_id][param].should == db_param
        #test accessor method
        doc_existing_new_parent_cats[user_id].__send__(param).should == db_param
      end
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc_existing_new_parent_cats[user_id].add_parent_categories(new_cats)
    end
    #check results
    #check doc in memory
    UserDB.user_to_docClass.each do |user_id, docClass|
      new_cats.each do |new_cat|
        doc_existing_new_parent_cats[user_id].parent_categories.should include new_cat
      end
    end
    #check database
    parent_cats = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = docClass.get(doc_existing_new_parent_cats[user_id]['_id'])[:parent_categories]
      new_cats.each do |cat|
        parent_cats[user_id].should include cat
      end
    end
    #check all cats are there and are unique
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id].sort.should == (orig_parent_cats[user_id] + new_cats).uniq.sort
    end
  end

  it "should be able to remove parent categories" do
    orig_parent_cats = {}
    doc_params = {}
    doc_remove_parent_cats = {}
    #set initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      orig_parent_cats[user_id]  = ['orig_cat3', 'orig_cat4', 'del_this_cat1', "del_this_cat2-#{user_id}"]
      doc_params[user_id] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_id]})
      doc_remove_parent_cats[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      doc_remove_parent_cats[user_id].save
    end
    #verify initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc_params[user_id].keys.each do |param|
        db_param = docClass.get(doc_remove_parent_cats[user_id]['_id'])[param]
        doc_remove_parent_cats[user_id][param].should == db_param
        #test accessor method
        doc_remove_parent_cats[user_id].__send__(param).should == db_param
      end
    end
    #continue with initial conditions
    remove_multi_cats = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      remove_multi_cats[user_id] = ['del_this_cat1', "del_this_cat2-#{user_id}"]
      remove_multi_cats[user_id].each do |cat|
        doc_remove_parent_cats[user_id].parent_categories.should include cat
      end
    end

    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc_remove_parent_cats[user_id].remove_parent_categories(remove_multi_cats[user_id])
    end

    #verify results
    UserDB.user_to_docClass.each do |user_id, docClass|
      remove_multi_cats[user_id].each do |cat|
        doc_remove_parent_cats[user_id].parent_categories.should_not include cat
      end
    end

    cats_in_db = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      cats_in_db[user_id] = docClass.get(doc_remove_parent_cats[user_id]['_id'])['parent_categories']
      remove_multi_cats[user_id].each do |removed_cat|
        cats_in_db[user_id].should_not include removed_cat
      end
    end
  end

  it "should only have unique categories" do
    #verify initial state
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.all.size.should == 0
    end

    orig_parent_cats = {}
    doc_params = {}
    doc_uniq_parent_cats = {}
    orig_sizes = {}
    new_cats = {}
    expected_sizes = {}
    #set initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      orig_parent_cats[user_id] = ['dup cat1', 'dup cat2', 'uniq cat1']
      doc_params[user_id] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_id]})
      doc_uniq_parent_cats[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      doc_uniq_parent_cats[user_id].save
      orig_sizes[user_id] = doc_uniq_parent_cats[user_id].parent_categories.size
      new_cats[user_id] = ['dup cat1', 'dup cat2', 'uniq_cat2']
      expected_sizes[user_id] = orig_sizes[user_id] + 1 #uniq_cat2
    end

    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc_uniq_parent_cats[user_id].add_parent_categories(new_cats[user_id])
    end

    #verify results
    records = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      expected_sizes[user_id].should == doc_uniq_parent_cats[user_id].parent_categories.size
      docClass.get(doc_uniq_parent_cats[user_id]['_id'])['parent_categories'].sort.should == doc_uniq_parent_cats[user_id].parent_categories.sort
      records[user_id]  = docClass.by_my_category(:key => doc_uniq_parent_cats[user_id].my_category)
      records[user_id].size.should == 1
    end
  end
end

describe UserDB, "Document Operations with Attachments" do
  include UserDocSpecHelpers

  before(:all) do
    @test_files = BufsFixtures.test_files
  end

  before(:each) do
    #delete any existing db records
    #TODO This only works if the db entry also exists in UserDB
    #Need to query each user database (how do we know the names?)
    # => need to enforce database naming convention.
    #query for couchrest-type that matches /UserDB::UserDoc*/
    UserDB.docClasses.each do |docClass|
      all_user_docs = docClass.all
      all_user_docs.each do |user_doc|
        user_doc.destroy
      end
    end

    @user1_id = "User001"
    @user2_id = "User002"
    @user1_db = UserDB.new(CouchDB, @user1_id)
    @user2_db = UserDB.new(CouchDB2, @user2_id)
  end

  it "has an attachment class associated with it" do
     UserDB.user_to_docClass.each do |user_id, docClass|
       docClass.user_attachClass.name.should == "UserDB::UserAttach#{user_id}"
     end
   end

  it "should save data files as an attachment with metadatax" do
    #initial conditions (attachment file)
    #TODO: vary filename by user
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with attachments']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save #doc must be saved before we can attach
    end
    #check initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.get(basic_docs[user_id]['_id']['attachment_doc_id']).should == nil
    end
    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      basic_docs[user_id].add_data_file(test_filename)
    end
    #check results
    att_doc_ids = {}
    att_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).attachment_doc_id
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      #puts "Attachment Doc: #{att_docs[user_id].inspect}"
      #p att_docs[user_id]['_attachments'].keys
      docClass.get(basic_docs[user_id]['_id'])['attachment_doc_id'].should == att_docs[user_id]['_id']
      att_docs[user_id]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_basename)
      att_docs[user_id]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
     
    end
  end

  it "should cleanly remove attachments" do
    #initial conditions 
    #TODO: vary filename by user
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with attachments']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save #doc must be saved before we can attach
    end
    UserDB.user_to_docClass.each do |user_id, docClass|
      basic_docs[user_id].add_data_file(test_filename)
    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).attachment_doc_id
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      #puts "Attachment Doc: #{att_docs[user_id].inspect}"
      #p att_docs[user_id]['_attachments'].keys
      docClass.get(basic_docs[user_id]['_id'])['attachment_doc_id'].should == att_docs[user_id]['_id']
      att_docs[user_id]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_base
      att_docs[user_id]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
    #test
    attachment_name = test_basename
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc = docClass.get(basic_docs[user_id]['_id'])
      doc.remove_attachment(attachment_name)
    end
    #check results
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.get(basic_docs[user_id]['_id']).attachment_doc_id.should == nil   #reference to attachment doc from user doc
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])  #attachment doc
      att_docs[user_id].should == nil
    end
  end


  it "should avoid creating hellish names when escaping and unescaping" do
    #initial conditions (attachment file)
    #this file has spaces in the file name
    test_filename = @test_files['strange_characters_in_file_name']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['text file', 'test file']
      doc_params[user_id] = get_default_params.merge({:my_category => 'strange_characters', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save #doc must be saved before we can attach
    end
    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      basic_docs[user_id].add_data_file(test_filename)
    end
    #check results
    att_doc_ids = {}
    att_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).attachment_doc_id
      #puts "Attachment Doc ID: #{att_doc_id}"
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      #puts "Attachment Doc: #{att_doc.inspect}"
      #p att_doc['_attachments'].keys
      att_docs[user_id]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_basename)
      att_docs[user_id]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
  end

  it "should create an attachment from raw data" do
    #TODO organize the test and chekcing results sections
    #set initial conditions
    data_file = @test_files['binary_data3_pptx'] #@test_files['strange_characters_in_file_name']
    binary_data = File.open(data_file, 'rb'){|f| f.read}
    binary_data_content_type = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    attach_name = File.basename(data_file)
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    metadata = {}
    att_doc_ids = {}
    att_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with attachments']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_raw_data_att', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params)
      basic_docs[user_id].save
      metadata[user_id] = basic_docs[user_id].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #puts "Doc ID: #{doc_basic['_id']}"
      #db_doc = BufsInfoDoc.get(doc_basic['_id'])
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).my_attachment_doc_id
      #puts "Attachment Doc ID: #{att_doc_id}"
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      #puts "Attachment Doc: #{att_doc.inspect}"
      #p att_doc['_attachments'].keys
      esc_att_name = BufsEscape.escape(attach_name)
      att_docs[user_id]['_attachments'].keys.should include esc_att_name
      #puts "Raw Data Metadata:" +  metadata.inspect
      file_mod_time = att_docs[user_id]['md_attachments'][esc_att_name]['file_modified']
      Time.parse(file_mod_time).should > (Time.now - 4) #4 seconds should be enough time
      att_docs[user_id]['_attachments'][esc_att_name]['content_type'].should == binary_data_content_type
    end
  end

#creating a db doc from a directory entry
  it "should create a full doc from a node object without files" do
    NodeMock = Struct.new(:my_category, :parent_categories, :description, :files)
    node_obj_mock_no_files = NodeMock.new('node_mock_category',
                                          ['mock_mom', 'mock_dad'],
                                          'mock description')

    docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      docs[user_id] = docClass.create_from_node(node_obj_mock_no_files)
      docs[user_id].my_category.should == node_obj_mock_no_files.my_category
      docs[user_id].parent_categories.should == node_obj_mock_no_files.parent_categories
      docs[user_id].description.should == node_obj_mock_no_files.description
    end
  end

  it "should create a full doc from a node object with files" do
    #initial conditions
    test_filename = @test_files['strange_characters_in_file_name']
    test_basename = File.basename(test_filename)
    NodeMock = Struct.new(:my_category, :parent_categories, :description, :files)
    node_obj_mock_with_files = NodeMock.new('node_mock_category',
                                          ['mock_mom', 'mock_dad'],
                                          'mock description',
                                           [test_filename])
    docs = {}
    att_doc_ids = {}
    att_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      #test
      docs[user_id] = docClass.create_from_node(node_obj_mock_with_files)
      #check results
      docs[user_id].my_category.should == node_obj_mock_with_files.my_category
      docs[user_id].parent_categories.should == node_obj_mock_with_files.parent_categories
      docs[user_id].description.should == node_obj_mock_with_files.description
      att_doc_ids[user_id] = docClass.get(docs[user_id]['_id']).attachment_doc_id
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      att_docs[user_id]['_attachments'].keys.should include BufsEscape.escape(test_basename)
      att_docs[user_id]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
  end

  #more of a test of couchrest
  it "should be able to return documents by its category" do
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['category testing']
      doc_params[user_id]  = get_default_params.merge({:my_category => 'my_cat1', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save
      parent_cats[user_id] = ['category testing']
      doc_params[user_id] = get_default_params.merge({:my_category => 'my_cat2', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save
    end
  
    test_nodes = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      find_cat = 'my_cat1'
      test_nodes[user_id] = docClass.by_my_category(:key => find_cat)
      test_nodes[user_id].each do |node|
        node.my_category.should == find_cat
      end
    end
  end

  it "should only have a single entry for each doc category" do
    all_nodes = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      all_nodes[user_id] = docClass.all
      all_nodes[user_id].each do |doc|
        docClass.by_my_category(:key => doc.my_category).size.should == 1
      end
    end
  end

  it "should be able to delete (destroy) the model" do
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    #set initial conditions (doc with attachment)
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['deletion testing']
      doc_params[user_id] = get_default_params.merge({:my_category => 'delete_test1', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save
      test_filename = @test_files['strange_characters_in_file_name']
      test_basename = File.basename(test_filename)
      basic_docs[user_id].add_data_file(test_filename)
    end
    #verify initial conditions
    docs = {}
    doc_att_ids = {}
    doc_atts = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      docs[user_id] = docClass.by_my_category(:key => 'delete_test1')
      docs[user_id].size.should == 1
      doc = docs[user_id].first
      doc_att_ids[user_id] = docClass.get(doc['_id']).attachment_doc_id
      doc_atts[user_id] = docClass.get(doc_att_ids[user_id])
      doc_atts[user_id].should_not == nil
    end
    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc_latest = docClass.get(basic_docs[user_id]['_id'])
      doc_latest.destroy_node
    end
    #verify results
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc = docs[user_id].first
      doc.my_category.should == 'delete_test1'
      docClass.by_my_category(:key => doc.my_category).size.should == 0
      doc_att_ids[user_id].should_not == nil
      puts "doc_att_doc_id: #{doc_att_ids[user_id]}"
      doc_atts[user_id] = docClass.user_attachClass.get(doc_att_ids[user_id])
      #p bia
      doc_atts[user_id].should == nil
    end
  end


  #it "should return all model data when queried by the model's category name (my_category)" do
  #  ScoutInfoDoc.node_by_title('test_spec1.pptx').should == ScoutInfoDoc.by_title('test_spec1.pptx')
  #end


end

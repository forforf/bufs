
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'


require 'couchrest'
doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!
CouchDB2 = BufsFixtures::CouchDB2
CouchDB2.compact!


require File.dirname(__FILE__) + '/../lib/bufs_node_factory'

module UserNodeSpecHelpers
  BufsDocLibs = [File.dirname(__FILE__) + '/../lib/bufs_couchrest_glue_env',
                 File.dirname(__FILE__) + '/../lib/bufs_info_attachment']
  BufsDocIncludes = [:CouchRestEnv, :DataStoreModels]
end

#for testing CouchRest model
module CouchRestNodeHelpers

  def self.env_builder(node_class_id, db, db_user_id)
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => UserNodeSpecHelpers::BufsDocLibs,
                            :class_env =>
                            Hash[ :includes => UserNodeSpecHelpers::BufsDocIncludes,
                                  :bufs_info_doc_env =>
                                  Hash[ :host => db.host,
                                        :path => db.uri,
                                        :user_id => db_user_id 
                                      ]
                                ]
                          ]
                    ]
  end


  DefaultDocParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultDocParams.dup #to avoid a couchrest weirdness don't use the params directly
  end
  
  def make_doc_no_attachment(user_class, override_defaults={})
    #default_params = {:my_category => 'default', 
    #                  :parent_categories => ['default_parent'],
    #		      :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return user_class.new(init_params)
  end

  def make_doc_w_attach_from_file(user_class, att_fname, override_defaults={})
    test_filename = att_fname 
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    new_doc = make_doc_no_attachment(user_class, override_defaults)
    new_doc.save #doc must be saved before we can attach
    file_data = {:src_filename => test_filename}
    new_doc.files_add(file_data)
    #new_doc.add_data_file(test_filename)
    return new_doc 
  end
end

describe BufsNodeFactory, "Making the Class" do
  #include BufsInfoDocSpecHelpers

  before(:each) do
    @user1_id = "User001"
    @user2_id = "User002"
    node_class_id1 = "BufsInfoDoc#{@user1_id}"
    node_class_id2 = "BufsInfoDoc#{@user2_id}"
    node_env1 = CouchRestNodeHelpers.env_builder(node_class_id1, CouchDB, @user1_id)
    node_env2 = CouchRestNodeHelpers.env_builder(node_class_id2, CouchDB2, @user2_id)

    @user1_class = BufsNodeFactory.make(node_env1) 
    @user2_class = BufsNodeFactory.make(node_env2)
  end

  after(:each) do
    @user1_class.destroy_all
    @user2_class.destroy_all
  end

  it "should initialize user docs properly" do
    #test
    user1_doc = @user1_class.new({:my_category => "user1_data"})
    user2_doc = @user2_class.new({:my_category => "user2_data"})

    #check results
    user1_doc.my_category.should == "user1_data"
    user2_doc.my_category.should == "user2_data"
    #users should be in different databases
    user1_doc.my_GlueEnv.db.should_not == user2_doc.my_GlueEnv.db.should_not
    #users should be registered in UserNode
  end
end


describe BufsNodeFactory, "CouchRest Model: Basic database operations" do
  include CouchRestNodeHelpers

  before(:each) do
    @user1_id = "User001"
    @user2_id = "User002"
    node_class_id1 = "BufsInfoDoc#{@user1_id}"
    node_class_id2 = "BufsInfoDoc#{@user2_id}"
    node_env1 = CouchRestNodeHelpers.env_builder(node_class_id1, CouchDB, @user1_id)
    node_env2 = CouchRestNodeHelpers.env_builder(node_class_id2, CouchDB2, @user2_id)

    @user1_class = BufsNodeFactory.make(node_env1)
    @user2_class = BufsNodeFactory.make(node_env2)

    @docClasses = [@user1_class, @user2_class]
  end

  after(:each) do
    @user1_class.destroy_all
    @user2_class.destroy_all
  end

  it "should have the database initialized correctly" do
    #check initial conditions
    @docClasses.each do |docClass|
      docClass.all.size.should == 0
    end
    #test
    default_docs = []
    @docClasses.each do |docClass|
      default_docs << docClass.new(get_default_params)
    end
    #check results
    default_docs.each do |default_doc|
      default_doc.my_category.should == get_default_params[:my_category]
      default_doc.parent_categories.should == get_default_params[:parent_categories]
      default_doc.description.should == get_default_params[:description]
    end
    #we haven't saved it to the database yet
    @docClasses.each do |docClass|
      docClass.all.size.should == 0
    end
  end

  it "should perform basic collection operations properly" do
    user1_doc = @user1_class.new({:my_category => "user1_data"})
    user2_doc = @user2_class.new({:my_category => "user2_data"})
    user1_doc.save
    user2_doc.save
    @user1_class.all.first.my_category.should == "user1_data"  
    @user2_class.all.first.my_category.should == "user2_data"
  end

  it "should not save if required fields don't exist" do
    #set initial condition
    orig_db_size = {}
    @docClasses.each do |user_class|
      orig_db_size[user_class] = user_class.all.size
      lambda { user_class.new(:parent_categories => ['no_my_category'],
                              :description => 'some description',
                              :file_metadata => {})
             }.should raise_error(ArgumentError)
    end

    @docClasses.each do |user_class|
      user_class.all.size.should == orig_db_size[user_class]
    end
  end

  it "should save" do
    #set initial conditions
    orig_db_size = {}
    docs_params = {}
    docs_to_save = {}
    @docClasses.each do |user_class|
#    @docClasses.each do |user_class|
      orig_db_size[user_class] = user_class.all.size
      docs_params[user_class] = get_default_params.merge({:my_category => 'save_test'})
      docs_to_save[user_class] = make_doc_no_attachment(user_class, docs_params[user_class].dup)
    end


    #test
    docs_to_save.each do |user_class, doc_to_save|
      doc_to_save.save
    end

    #check results
    @docClasses.each do |user_class|
      docs_params[user_class].keys.each do |param|
        doc_id = docs_to_save[user_class].model_metadata[:_id]
        doc_from_db = user_class.myGlueEnv.db.get(doc_id)
        db_param = doc_from_db[param]
        docs_to_save[user_class].user_data[param].should == db_param
        #test accessor method
        docs_to_save[user_class].__send__(param).should == db_param
      end
    end
    @docClasses.each do |user_class|
      user_class.all.size.should == orig_db_size[user_class] + 1
    end 
  end

#adding categories
  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    #set initial conditions
    orig_parent_cats = {}
    doc_params = {}
    docs_with_new_parent_cat = {}
    @docClasses.each do |user_class|
      orig_parent_cats[user_class] = ['old parent cat']
      new_params = get_default_params.merge({:my_category => "cat_test#{user_class}", :parent_categories => orig_parent_cats[user_class]})
      doc_params[user_class] = new_params
      docs_with_new_parent_cat[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
    end

    new_cat = 'new parent cat'

    #test
    @docClasses.each do |user_class|
     docs_with_new_parent_cat[user_class].add_parent_categories(new_cat)
    end
    #check results
    @docClasses.each do |user_class|
      #check doc in memory
      docs_with_new_parent_cat[user_class].parent_categories.should include new_cat
      #check database
      doc_params[user_class].keys.each do |param|
        db_param = user_class.myGlueEnv.db.get(docs_with_new_parent_cat[user_class].model_metadata[:_id])[param]
        docs_with_new_parent_cat[user_class].user_data[param].should == db_param
        #test accessor method
        docs_with_new_parent_cat[user_class].__send__(param).should == db_param
      end
    end
  end

  #TODO Setup a test to verify datastructure can change dynamically
  #i.e. add new parameters, check them, set them and delete them
=begin
  it "should have a dynamic methods set up for user data" do
    #set initial conditions
    orig_parent_cats = {}
    doc_params = {}
    doc_existing_new_parent_cats = {}
    @docClasses.each do |user_class|
      orig_parent_cats[user_class] = ["#{user_class}-orig_cat1", "#{user_class}-orig_cat2"]
      doc_params[user_class] = get_default_params.merge({:my_category => "#{user_class}-cat_test2",
                                                      :parent_categories => orig_parent_cats[user_class]})
      doc_existing_new_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_existing_new_parent_cats[user_class].save
    end
    #verify initial conditions
    @docClasses.each do |user_class|
      doc_params[user_class].keys.each do |param|
        doc_id = doc_existing_new_parent_cats[user_class].model_metadata['_id']
        db_doc = docClass.get(doc_id)
        #raise db_doc.model_metadata.inspect
        db_param = db_doc.node_data_hash[param]
        doc_existing_new_parent_cats[user_class].node_data_hash[param].should == db_param
        #test accessor method
        doc_existing_new_parent_cats[user_class].__send__(param).should == db_param
      end
    end
  end
=end

  it "should add categories to existing categories and existing doc" do
    #set initial conditions
    orig_parent_cats = {}
    doc_params = {}
    doc_existing_new_parent_cats = {}
    @docClasses.each do |user_class|
      orig_parent_cats[user_class]  = ["#{user_class.to_s}-orig_cat1", "#{user_class.to_s}-orig_cat2"]
      doc_params[user_class] = get_default_params.merge({:my_category => "#{user_class.to_s}-cat_test2",
                                                      :parent_categories => orig_parent_cats[user_class]})
      doc_existing_new_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_existing_new_parent_cats[user_class].save
    end
    #verify initial conditions
    @docClasses.each do |user_class|
      doc_params[user_class].keys.each do |param|
        doc_id = doc_existing_new_parent_cats[user_class].model_metadata[:_id]
        db_doc = user_class.get(doc_id)
        #raise db_doc.model_metadata.inspect
        db_param = db_doc.user_data[param]
        doc_existing_new_parent_cats[user_class].user_data[param].should == db_param
        #test accessor method
        doc_existing_new_parent_cats[user_class].__send__(param).should == db_param
      end
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    @docClasses.each do |user_class|
      doc_existing_new_parent_cats[user_class].add_parent_categories(new_cats)
    end
    #check results
    #check doc in memory
    @docClasses.each do |user_class|
      new_cats.each do |new_cat|
        doc_existing_new_parent_cats[user_class].parent_categories.should include new_cat
      end
    end
    #check database
    parent_cats = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = user_class.get(doc_existing_new_parent_cats[user_class].model_metadata[:_id]).parent_categories
      new_cats.each do |cat|
        parent_cats[user_class].should include cat
      end
    end
    #check all cats are there and are unique
    @docClasses.each do |user_class|
      parent_cats[user_class].sort.should == (orig_parent_cats[user_class] + new_cats).uniq.sort
    end
  end

  it "should be able to remove parent categories" do
    orig_parent_cats = {}
    doc_params = {}
    doc_remove_parent_cats = {}
    #set initial conditions
    @docClasses.each do |user_class|
      orig_parent_cats[user_class]  = ['orig_cat3', 'orig_cat4', 'del_this_cat1', "del_this_cat2-#{user_class.to_s}"]
      doc_params[user_class] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_class]})
      doc_remove_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_remove_parent_cats[user_class].save
    end
    #verify initial conditions
    @docClasses.each do |user_class|
      doc_params[user_class].keys.each do |param|
        db_param = user_class.get(doc_remove_parent_cats[user_class].model_metadata[:_id]).user_data[param]
        doc_remove_parent_cats[user_class].user_data[param].should == db_param
        #test accessor method
        doc_remove_parent_cats[user_class].__send__(param).should == db_param
      end
    end
    #continue with initial conditions
    remove_multi_cats = {}
    @docClasses.each do |user_class|
      remove_multi_cats[user_class] = ['del_this_cat1', "del_this_cat2-#{user_class.to_s}"]
      remove_multi_cats[user_class].each do |cat|
        doc_remove_parent_cats[user_class].parent_categories.should include cat
      end
    end

    #test
    @docClasses.each do |user_class|
      doc_remove_parent_cats[user_class].remove_parent_categories(remove_multi_cats[user_class])
    end

    #verify results
    @docClasses.each do |user_class|
      remove_multi_cats[user_class].each do |cat|
        doc_remove_parent_cats[user_class].parent_categories.should_not include cat
      end
    end

    cats_in_db = {}
    @docClasses.each do |user_class|
      doc_id = doc_remove_parent_cats[user_class].model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      cats_in_db[user_class] = db_doc.user_data[:parent_categories].inspect
      remove_multi_cats[user_class].each do |removed_cat|
        cats_in_db[user_class].should_not include removed_cat
      end
    end
  end

  it "should only have unique categories" do
    #verify initial state
    @docClasses.each do |user_class|
      user_class.all.size.should == 0
    end

    orig_parent_cats = {}
    doc_params = {}
    doc_uniq_parent_cats = {}
    orig_sizes = {}
    new_cats = {}
    expected_sizes = {}
    #set initial conditions
    @docClasses.each do |user_class|
      orig_parent_cats[user_class] = ['dup cat1', 'dup cat2', 'uniq cat1']
      doc_params[user_class] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_class]})
      doc_uniq_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_uniq_parent_cats[user_class].save
      orig_sizes[user_class] = doc_uniq_parent_cats[user_class].parent_categories.size
      new_cats[user_class] = ['dup cat1', 'dup cat2', 'uniq_cat2']
      expected_sizes[user_class] = orig_sizes[user_class] + 1 #uniq_cat2
    end

    #test
    @docClasses.each do |user_class|
      doc_uniq_parent_cats[user_class].add_parent_categories(new_cats[user_class])
    end

    #verify results
    records = {}
    @docClasses.each do |user_class|
      expected_sizes[user_class].should == doc_uniq_parent_cats[user_class].parent_categories.size
      doc_id = doc_uniq_parent_cats[user_class].model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      puts "Doc ID searched: #{doc_id.inspect}"
      db_doc.user_data[:parent_categories].sort.should == doc_uniq_parent_cats[user_class].parent_categories.sort
      records[user_class] = user_class.call_view(:parent_categories, 'dup cat2')
      records[user_class].size.should == 1
      records[user_class].first.parent_categories.should include 'dup cat2'
    end
  end
end
=begin
describe UserNode, "Document Operations with Attachments" do
  include UserNodeSpecHelpers

  before(:all) do
    @test_files = BufsFixtures.test_files
  end

  before(:each) do
    #delete any existing db records
    #TODO This only works if the db entry also exists in UserNode
    #Need to query each user database (how do we know the names?)
    # => need to enforce database naming convention.
    #query for couchrest-type that matches /UserNode::UserNode*/
    UserNode.docClasses.each do |docClass|
      attachClass = docClass.user_attachClass
      all_attach_docs = attachClass.all
      all_attach_docs.each do |attach_doc|
        attach_doc.destroy
      end
      docClass.destroy_all
    end

    @user1_id = "User001"
    @user2_id = "User002"
    @user1_db = UserNode.new(CouchDB, @user1_id)
    @user2_db = UserNode.new(CouchDB2, @user2_id)
  end

  it "has an attachment class associated with it" do
     @docClasses.each do |user_class|
       docClass.user_attachClass.name.should == "UserNode::UserAttach#{user_id}"
     end
   end

  it "should save data files as an attachment with metadata" do
    #initial conditions (attachment file)
    #TODO: vary filename by user
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save #doc must be saved before we can attach
    end

    #check initial conditions
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      db_doc.model_metadata['attachment_doc_id'].should == nil
      #(docClass.get(basic_docs[user_class].model_metadata['_id'])['attachment_doc_id']).should == nil
    end
    #test
    #using just the filename
    file_data = {:src_filename => test_filename}
    @docClasses.each do |user_class|
      basic_docs[user_class].files_add(file_data)
    end


    #check results
    att_doc_ids = {}
    att_docs = {}
    @docClasses.each do |user_class|
      id_of_doc_w_att = basic_docs[user_class].model_metadata[:_id]
      doc_w_att = docClass.get(id_of_doc_w_att)
      att_doc_ids[user_class] = doc_w_att.attachment_doc_id
      att_docs[user_class] = docClass.user_attachClass.get(att_doc_ids[user_class])
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      db_doc.attachment_doc_id.should == att_docs[user_class][:_id]
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_basename)
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
     
    end
  end

  it "should cleanly remove all attachments" do
    #initial conditions 
    #TODO: vary filename by user
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_w_attach_from_file(user_class, test_filename, doc_params[user_class])
    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    test_basename = File.basename(test_filename)
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      #raise db_doc.attachment_doc_id.inspect
      att_doc_ids[user_class] = db_doc.attachment_doc_id
      att_docs[user_class] = docClass.user_attachClass.get(att_doc_ids[user_class])
      docClass.get(doc_id).attachment_doc_id.should == att_docs[user_class][:_id]
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_base
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
    #test
    attachment_name = test_basename
    @docClasses.each do |user_class|
      doc = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc.files_subtract(:all)
    end
    #check results
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      lambda {db_doc.attachment_doc_id}.should raise_error NoMethodError   #reference to attachment doc from user doc
      #db_doc.attachment_doc_id.should == nil
      att_docs[user_class] = docClass.get(att_doc_ids[user_class])  #attachment doc
      att_docs[user_class].should == nil
    end
  end


  it "should cleanly remove a single  attachment" do
    #initial conditions
    #TODO: vary filename by user
    test_filename1 = @test_files['binary_data_spaces_in_fname_pptx']
    test_filename2 = @test_files['binary_data2_docx'] 
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att2', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_w_attach_from_file(user_class, test_filename1, doc_params[user_class])
      basic_docs[user_class].files_add(:src_filename => test_filename2)

    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    test_basename1 = File.basename(test_filename1)
    test_basename2 = File.basename(test_filename2)
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      att_doc_ids[user_class] = db_doc.attachment_doc_id
      db = db_doc.my_GlueEnv.db
      att_docs[user_class] = db.get(att_doc_ids[user_class])
      docClass.get(doc_id).attachment_doc_id.should == att_docs[user_class][:_id]
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename1)
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename2) 
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename1)]['file_modified'].should == File.mtime(test_filename1).to_s
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename2)]['file_modified'].should == File.mtime(test_filename2).to_s
    end
    #test
    attachment_name1 = BufsEscape.escape(test_basename1)
    attachment_name2 = BufsEscape.escape(test_basename2)
    @docClasses.each do |user_class|
      doc = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc.files_subtract(attachment_name1)
    end
    #check results
    @docClasses.each do |user_class|
      att_docs[user_class] = docClass.user_attachClass.get(att_doc_ids[user_class])
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      db_doc.attachment_doc_id.should == att_docs[user_class][:_id]   #reference to attachment doc from user doc
      att_docs[user_class]['_attachments'].keys.size.should == 1
      att_docs[user_class]['_attachments'].keys.first.should == BufsEscape.escape(attachment_name2)
    end
    #delete again so that all attachments are deleted
    @docClasses.each do |user_class|
      doc = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc.files_subtract(attachment_name2)
    end
    #check results
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      lambda {db_doc.attachment_doc_id}.should raise_error NoMethodError   #reference to attachment doc from user doc
      #db_doc.attachment_doc_id.should == nil
      att_docs[user_class] = docClass.get(att_doc_ids[user_class])  #attachment doc
      att_docs[user_class].should == nil
    end

  end

  it "should list attachment list" do
    #initial conditions
    #TODO: vary filename by user, support multiple attachments
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_class]})

      basic_docs[user_class] = make_doc_w_attach_from_file(user_class, test_filename, doc_params[user_class])
    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    test_basename = File.basename(test_filename)
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      att_doc_ids[user_class] = db_doc.attachment_doc_id
      att_docs[user_class] = docClass.user_attachClass.get(att_doc_ids[user_class])
      docClass.get(doc_id).attachment_doc_id.should == att_docs[user_class][:_id]
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename) #
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
    #test
    attachment_names = {}
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      attachment_names[user_class] = db_doc.get_attachment_names
    end
    #check results
    @docClasses.each do |user_class|
      attachment_names[user_class].size.should == 1
      attachment_names[user_class].first.should == BufsEscape.escape(test_basename)
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
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['text file', 'test file']
      doc_params[user_class] = get_default_params.merge({:my_category => 'strange_characters', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save #doc must be saved before we can attach
    end
    #test
    @docClasses.each do |user_class|
      basic_docs[user_class].files_add(:src_filename => test_filename)
    end
    #check results
    att_doc_ids = {}
    att_docs = {}
    @docClasses.each do |user_class|
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      att_doc_ids[user_class] = db_doc.attachment_doc_id
      att_docs[user_class] = docClass.user_attachClass.get(att_doc_ids[user_class])
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_basename)
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
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
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_raw_data_att', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params)
      basic_docs[user_class].save
      #test
      #metadata[user_class] = basic_docs[user_class].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #metadata[user_class].should == ["should be the metadata for that user"]
      basic_docs[user_class].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #verify results
      doc_id = basic_docs[user_class].model_metadata[:_id]
      db_doc = docClass.get(doc_id)
      att_doc_ids[user_class] = db_doc.my_attachment_doc_id
      att_docs[user_class] = docClass.user_attachClass.get(att_doc_ids[user_class])
      esc_att_name = BufsEscape.escape(attach_name)
      att_docs[user_class].should_not == nil
      att_docs[user_class]['_attachments'].keys.should include esc_att_name
      file_mod_time = att_docs[user_class]['md_attachments'][esc_att_name]['file_modified']
      Time.parse(file_mod_time).should > (Time.now - 4) #4 seconds should be enough time
      att_docs[user_class]['_attachments'][esc_att_name]['content_type'].should == binary_data_content_type
    end
  end

#recomment out
#=begin
#creatding a db doc from a directory entry
  it "should create a full doc from a node object without files" do
    NodeMock = Struct.new(:my_category, :parent_categories, :description, :list_attached_files)
    node_obj_mock_no_files = NodeMock.new('node_mock_category',
                                          ['mock_mom', 'mock_dad'],
                                          'mock description')

    docs = {}
    @docClasses.each do |user_class|
      docs[user_class] = docClass.create_from_file_node(node_obj_mock_no_files)
      docs[user_class].my_category.should == node_obj_mock_no_files.my_category
      docs[user_class].parent_categories.should == node_obj_mock_no_files.parent_categories
      docs[user_class].description.should == node_obj_mock_no_files.description
    end
  end

  it "should create a full doc from a node object with files" do
    #initial conditions
    test_filename = @test_files['strange_characters_in_file_name']
    test_basename = File.basename(test_filename)
    NodeMock = Struct.new(:my_category, :parent_categories, :description, :list_attached_files)
    node_obj_mock_with_files = NodeMock.new('node_mock_category',
                                          ['mock_mom', 'mock_dad'],
                                          'mock description',
                                           [test_filename])
    docs = {}
    att_doc_ids = {}
    att_docs = {}
    @docClasses.each do |user_class|
      #test
      docs[user_class] = docClass.create_from_file_node(node_obj_mock_with_files)
      #check results
      docs[user_class].my_category.should == node_obj_mock_with_files.my_category
      docs[user_class].parent_categories.should == node_obj_mock_with_files.parent_categories
      docs[user_class].description.should == node_obj_mock_with_files.description
      att_doc_ids[user_class] = docClass.get(docs[user_class]['_id']).attachment_doc_id
      att_docs[user_class] = docClass.get(att_doc_ids[user_class])
      att_docs[user_class]['_attachments'].keys.should include BufsEscape.escape(test_basename)
      att_docs[user_class]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
  end
#=end

  it "should be able to return documents by its category" do
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['category testing']
      doc_params[user_class]  = get_default_params.merge({:my_category => 'my_cat1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save
      parent_cats[user_class] = ['category testing']
      doc_params[user_class] = get_default_params.merge({:my_category => 'my_cat2', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save
    end
  
    test_nodes = {}
    @docClasses.each do |user_class|
      find_cat = 'my_cat1'
      test_nodes[user_class] = docClass.call_view(:my_category, find_cat)
      test_nodes[user_class].each do |node|
        node.my_category.should == find_cat
      end
    end
  end

  it "should only have a single entry for each doc category" do
    all_nodes = {}
    @docClasses.each do |user_class|
      all_nodes[user_class] = docClass.all
      all_nodes[user_class].each do |doc|
        docClass.call_view(:my_category, doc.my_category).size.should == 1
      end
    end
  end

  it "should be able to delete (destroy) the model" do
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    #set initial conditions (doc with attachment)
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['deletion testing']
      doc_params[user_class] = get_default_params.merge({:my_category => 'delete_test1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save
      test_filename = @test_files['strange_characters_in_file_name']
      test_basename = File.basename(test_filename)
      basic_docs[user_class].files_add(:src_filename => test_filename)
    end
    #verify initial conditions
    docs = {}
    doc_att_ids = {}
    doc_atts = {}
    @docClasses.each do |user_class|
      docs[user_class] = docClass.call_view(:my_category, 'delete_test1')
      docs[user_class].size.should == 1
      doc = docs[user_class].first
      doc_att_ids[user_class] = docClass.get(doc.model_metadata[:_id]).attachment_doc_id
      doc_atts[user_class] = docClass.user_attachClass.get(doc_att_ids[user_class])
      doc_atts[user_class].should_not == nil
    end
    #test
    @docClasses.each do |user_class|
      doc_latest = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc_latest.destroy_node
    end
    #verify results
    @docClasses.each do |user_class|
      doc = docs[user_class].first
      doc.my_category.should == 'delete_test1'
      docClass.call_view(:my_category, doc.my_category).size.should == 0
      doc_att_ids[user_class].should_not == nil
      doc_atts[user_class] = docClass.user_attachClass.get(doc_att_ids[user_class])
      doc_atts[user_class].should == nil
    end
  end
end

  #FIXME: Test for links being destroyed  obsolete?
  #it "should return all model data when queried by the model's category name (my_category)" do
  #  ScoutInfoDoc.node_by_title('test_spec1.pptx').should == ScoutInfoDoc.by_title('test_spec1.pptx')
  #end
describe UserNode, "Document Operations with Links" do
  include UserNodeSpecHelpers

  before(:each) do
    #delete any existing db records
    #TODO This only works if the db entry also exists in UserNode
    #Need to query each user database (how do we know the names?)
    # => need to enforce database naming convention.
    #query for couchrest-type that matches /UserNode::UserNode*/
    UserNode.docClasses.each do |docClass|
      #linkClass = docClass.user_linkClass
      #all_link_docs = linkClass.all
      #all_link_docs.each do |link_doc|
      #  link_doc.destroy
      #end
      all_user_docs = docClass.all
      all_user_docs.each do |user_doc|
        puts "WARNING: this doc has :_id of nil" unless user_doc.model_metadata[:_id] #{user_
        puts "WARNING this doc has valid :_id but nil '_rev" if (user_doc.model_metadata[:_id] && user_doc.model_metadata["_rev"].nil?)
        user_doc.destroy_node #unless user_doc["_id"]
        #user_#doc.destroy
      end
    end

    @user1_id = "User001"
    @user2_id = "User002"
    @user1_db = UserNode.new(CouchDB, @user1_id)
    @user2_db = UserNode.new(CouchDB2, @user2_id)
  end

  it "has a link parameter" do
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with links']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_links', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params)
      basic_docs[user_class].respond_to?(:links).should == false
      basic_docs[user_class].iv_set(:links, {})
      #test - it should now have the link instance variable
      basic_docs[user_class].respond_to?(:links).should == true
      #it should also have the dynamically generated methods for add, subtracting and getting links
      dyn_methods = [:links_add, :links_subtract, :links_get]
      basic_docs[user_class].respond_to?(:links_add).should == true
      dyn_methods.each do |meth|
        basic_docs[user_class].respond_to?(meth).should == true
      end
      basic_docs[user_class].save
      doc_latest = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc_latest.links.should == {}
    end
  end

  it "should save links" do
    #initial conditions (attachment file)
    #TODO: vary filename by user
    test_links= {"http://www.google.com" => ["Google"], "http://www.bing.com" => ["Bing"]}
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with links']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_link1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save #doc must be saved before we can add links
    end
    @docClasses.each do |user_class|
      doc_latest = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc_latest.links.should == nil
    end
    #test
    @docClasses.each do |user_class|
      basic_docs[user_class].links_add(test_links)
    end
    #check results
    #link_doc_ids = {}
    #link_docs = {}
    @docClasses.each do |user_class|
      #link_doc_ids[user_class] = docClass.get(basic_docs[user_class]['_id']).my_link_doc_id
      #link_docs[user_class] = docClass.get(link_doc_ids[user_class])
      user_doc_from_db = docClass.get(basic_docs[user_class].model_metadata[:_id])
      #docClass.get(basic_docs[user_class]['_id'])['links_doc_id'].should == link_docs[user_class]['_id']
      #user_doc_from_db.links_doc_id.should == link_docs[user_class]['_id']
      #links_in_user_doc = docClass.user_linkClass.get(user_doc_from_db.links_doc_id)
      #links_in_user_doc.uris.should == test_links
      user_doc_from_db.links.should == test_links
    end
  end

  it "should get links" do

    #initial conditions (attachment file)
    #TODO: vary filename by user
    test_links= {"http://www.google.com" => ["Google"], "http://www.bing.com" => ["Bing"]}
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with links']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_link1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save #doc must be saved before we can add links
    end
    @docClasses.each do |user_class|
      doc_latest = docClass.get(basic_docs[user_class].model_metadata[:_id])
      doc_latest.links.should == nil
    end
    @docClasses.each do |user_class|
      basic_docs[user_class].links_add(test_links)
    end
    #verify initial conditions
    @docClasses.each do |user_class|
      user_doc_from_db = docClass.get(basic_docs[user_class].model_metadata[:_id])
      user_doc_from_db.links.should == test_links
    end
    #test
    link_to_get = "Google"
    @docClasses.each do |user_class|
      user_doc_from_db = docClass.get(basic_docs[user_class].model_metadata[:_id])
      user_doc_from_db.links_get(link_to_get).should == "http://www.google.com"
    end

  end
end


=begin
  it "should remove links do" do
    #initial conditions 
    test_links= { "http://www.google.com" => ["Googs"], "http://www.bing.com" => ["Bings"]}
    remove_link = "Bings"
    remaining_link = { "http://www.google.com" => ["Googs"] }
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @docClasses.each do |user_class|
      parent_cats[user_class] = ['docs with links']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_link2', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].save #doc must be saved before we can add links
    end
    #check initial conditions
    @docClasses.each do |user_class|
      #docClass.get(basic_docs[user_class]['_id']['links_doc_id']).should == nil
      doc_latest = docClass.get(basic_docs[user_class].model_metadata['_id'])
      doc_latest.link.should == nil
    end
    #add links
    @docClasses.each do |user_class|
      basic_docs[user_class].link_add(test_links)
    end
   #check initial conditions
    #link_doc_ids = {}
    #link_docs = {}
    @docClasses.each do |user_class|
      #link_doc_ids[user_class] = docClass.get(basic_docs[user_class]['_id']).my_link_doc_id
      #link_docs[user_class] = docClass.get(link_doc_ids[user_class])
      user_doc_from_db = docClass.get(basic_docs[user_class]['_id'])
      #docClass.get(basic_docs[user_class]['_id'])['links_doc_id'].should == link_docs[user_class]['_id']
      #user_doc_from_db.links_doc_id.should == link_docs[user_class]['_id']
      #links_in_user_doc = docClass.user_linkClass.get(user_doc_from_db.links_doc_id)
      user_doc_from_db.link.should == test_links
    end
    #test
    @docClasses.each do |user_class|
      basic_docs[user_class].link_subtract(remove_link)
    end
    #verify
    @docClasses.each do |user_class|
      link_doc_ids[user_class] = docClass.get(basic_docs[user_class]['_id']).my_link_doc_id
      link_docs[user_class] = docClass.get(link_doc_ids[user_class])
      user_doc_from_db = docClass.get(basic_docs[user_class]['_id'])
      #docClass.get(basic_docs[user_class]['_id'])['links_doc_id'].should == link_d
      user_doc_from_db.links_doc_id.should == link_docs[user_class]['_id']
      links_in_user_doc = docClass.user_linkClass.get(user_doc_from_db.links_doc_id)
      links_in_user_doc.uris.should == remaining_link
    end
  end
end
=end
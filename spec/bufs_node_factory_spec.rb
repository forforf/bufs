DirBufsNodeFactorySpec = File.dirname(__FILE__)
require File.join(DirBufsNodeFactorySpec, 'helpers/bufs_test_environments')

#Test Environments
#The test environments sets up the following:
# 4 seperate persistent layers
# - 2 CouchDB databases using CouchRest 
# - 2 File Systems (just different directories)  using File and FileUtils
# A data structure called Bufs
# 2 "Glue" enviroments that bind the persistent layers to the data structure
# The 4 low level persistent layers  are mapped to a common model framework
# using the glue environments to bind the datastructure and persistent layers 
# to the framework

#Node Helpers
# make_doc_no_attachment - makes a common framework node without attachment
#   arguments: user_class, parameters
# make_doc_w_attach_from_ile - makes a node with the file as an attachment
#   arguments: user_class, filename, parameters)

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

describe BufsNodeFactory, "Making the Class" do
  include MakeUserClasses

  before(:each) do
    @user_classes = [User1Class, User2Class, User3Class, User4Class]
  end

  after(:each) do
    @user_classes.each do |user_class|
      user_class.destroy_all
    end
  end

  it "should initialize user docs properly" do
    user_docs = {}
    #test
    @user_classes.each do |user_class|
      user_docs[user_class] = user_class.new({:my_category => "#{user_class.name}_data"})
    end
    #user2_doc = @user2_class.new({:my_category => "user2_data"})

    #check results
    user_docs.each do |user_class, user_node|
      user_node.my_category.should == "#{user_class.name}_data"
    end 
    #user1_doc.my_category.should == "user1_data"
    #user2_doc.my_category.should == "user2_data"

    #users should be in different databases
    #raise @user_classes.inspect
    couchrest_users = @user_classes.select{|u| u.to_s =~ /BufsInfoNode/}
    couchrest_users.size.should == 2
    couchrest_users[0].myGlueEnv.db.should_not == couchrest_users[1].myGlueEnv.db

    #users should be in different directories
    filesystem_users = @user_classes.select{|u| u.to_s =~ /BufsFile/}
    filesystem_users.size.should == 2
    user_dirs = filesystem_users.map{|f| f.myGlueEnv.user_datastore_selector}
    user_dirs[0].should_not == user_dirs[1]
  end
end


describe BufsNodeFactory, "CouchRest Model: Basic database operations" do
  #include CouchRestNodeHelpers
  include MakeUserClasses
  include NodeHelpers

=begin
  before(:all) do
    @user1_id = "User001"
    @user2_id = "User002"
    node_class_id1 = "BufsInfoNode#{@user1_id}"
    node_class_id2 = "BufsInfoNode#{@user2_id}"
    node_env1 = CouchRestNodeHelpers.env_builder(node_class_id1, CouchDB, @user1_id)
    node_env2 = CouchRestNodeHelpers.env_builder(node_class_id2, CouchDB2, @user2_id)

    @user1_class = BufsNodeFactory.make(node_env1)
    @user2_class = BufsNodeFactory.make(node_env2)

    @user_classes = [@user1_class, @user2_class]
  end
=end
  before(:each) do
    @user_classes = [User1Class, User2Class, User3Class, User4Class]
  end

  after(:each) do
    @user_classes.each do |user_class|
      user_class.destroy_all
    end
    #@user1_class.destroy_all
    #@user2_class.destroy_all
  end

  it "should initialize correctly with no nodes" do
    #check initial conditions
    @user_classes.each do |user_class|
      user_class.all.size.should == 0
    end
    #test
    default_docs = []
    @user_classes.each do |user_class|
      default_docs << user_class.new(get_default_params)
    end
    #check results
    default_docs.each do |default_doc|
      default_doc.my_category.should == get_default_params[:my_category]
      default_doc.parent_categories.should == get_default_params[:parent_categories]
      default_doc.description.should == get_default_params[:description]
    end
    #we haven't saved it to the database yet
    @user_classes.each do |user_class|
      user_class.all.size.should == 0
    end
  end

  it "should perform basic collection operations properly" do
    user_docs = {}
    @user_classes.each do |user_class|
      user_docs[user_class] = user_class.new({:my_category => "#{user_class.name}_data2"})
    end

    #user1_doc = @user1_class.new({:my_category => "user1_data"})
    #user2_doc = @user2_class.new({:my_category => "user2_data"})
    user_docs.each do |user_class, node|
      node.__save
    end
    #user1_doc.__save
    #user2_doc.__save
    #@user1_class.all.first.my_category.should == "user1_data"  
    #@user2_class.all.first.my_category.should == "user2_data"

    @user_classes.each do |user_class|
      user_class.all.first.my_category.should == "#{user_class.name}_data2"
    end
  end

  it "should not save if required fields don't exist" do
    #set initial condition
    orig_size = {}
    @user_classes.each do |user_class|
      orig_size[user_class] = user_class.all.size
      lambda { user_class.new(:parent_categories => ['no_my_category'],
                              :description => 'some description',
                              :file_metadata => {})
             }.should raise_error(ArgumentError)
    end

    @user_classes.each do |user_class|
      user_class.all.size.should == orig_size[user_class]
    end
  end

  it "should save" do
    #set initial conditions
    orig_size = {}
    docs_params = {}
    docs_to_save = {}
    @user_classes.each do |user_class|
#    @user_classes.each do |user_class|
      orig_size[user_class] = user_class.all.size
      docs_params[user_class] = get_default_params.merge({:my_category => 'save_test'})
      docs_to_save[user_class] = make_doc_no_attachment(user_class, docs_params[user_class].dup)
    end


    #test
    docs_to_save.each do |user_class, doc_to_save|
      doc_to_save.__save
    end

    #check results
    @user_classes.each do |user_class|
      docs_params[user_class].keys.each do |param|
        doc_id = docs_to_save[user_class]._model_metadata[:_id]
        doc_from_db = user_class.get(doc_id)
        db_param = doc_from_db.__send__(param)
        docs_to_save[user_class]._user_data[param].should == db_param
        #test accessor method
        docs_to_save[user_class].__send__(param).should == db_param
      end
    end
    @user_classes.each do |user_class|
      user_class.all.size.should == orig_size[user_class] + 1
    end 
  end

  #adding categories
  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    #set initial conditions
    orig_parent_cats = {}
    doc_params = {}
    initial_revs = {}
    aftersave_revs = {}
    docs_with_new_parent_cat = {}
    @user_classes.each do |user_class|
      orig_parent_cats[user_class] = ['old parent cat']
      new_params = get_default_params.merge({:my_category => "cat_test#{(user_class.hash).to_s}", :parent_categories => orig_parent_cats[user_class]})
      doc_params[user_class] = new_params
      docs_with_new_parent_cat[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      initial_revs[user_class] = docs_with_new_parent_cat[user_class]._model_metadata[:_rev]
      #puts "#{user_class.inspect} rev: #{initial_revs[user_class].inspect}"
    end
    new_cat = 'new parent cat'

    #test
    @user_classes.each do |user_class|
     docs_with_new_parent_cat[user_class].parent_categories_add(new_cat)
     aftersave_revs[user_class] = docs_with_new_parent_cat[user_class]._model_metadata[:_rev]
     #puts "AS: #{user_class.inspect} rev: #{aftersave_revs[user_class].inspect}"
    end
    
    #check results
    @user_classes.each do |user_class|
      #check doc in memory
      docs_with_new_parent_cat[user_class].parent_categories.should include new_cat
      #check database
      doc_params[user_class].keys.each do |param|
        node = docs_with_new_parent_cat[user_class]
        node_id = node._model_metadata[:_id]
        model_node = node.class.get(node_id)
        db_param = model_node.__send__(param.to_sym)
        docs_with_new_parent_cat[user_class]._user_data[param].should == db_param
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
    @user_classes.each do |user_class|
      orig_parent_cats[user_class] = ["#{user_class}-orig_cat1", "#{user_class}-orig_cat2"]
      doc_params[user_class] = get_default_params.merge({:my_category => "#{user_class}-cat_test2",
                                                      :parent_categories => orig_parent_cats[user_class]})
      doc_existing_new_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_existing_new_parent_cats[user_class].save
    end
    #verify initial conditions
    @user_classes.each do |user_class|
      doc_params[user_class].keys.each do |param|
        doc_id = doc_existing_new_parent_cats[user_class]._model_metadata['_id']
        db_doc = user_class.get(doc_id)
        #raise db_doc._model_metadata.inspect
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
    @user_classes.each do |user_class|
      orig_parent_cats[user_class]  = ["#{user_class.hash.to_s}-orig_cat1", "#{user_class.hash.to_s}-orig_cat2"]
      doc_params[user_class] = get_default_params.merge({:my_category => "#{user_class.hash.to_s}-cat_test2",
                                                      :parent_categories => orig_parent_cats[user_class]})
      doc_existing_new_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_existing_new_parent_cats[user_class].__save
    end
    #verify initial conditions
    @user_classes.each do |user_class|
      doc_params[user_class].keys.each do |param|
        doc_id = doc_existing_new_parent_cats[user_class]._model_metadata[:_id]
        db_doc = user_class.get(doc_id)
        #raise doc_id unless db_doc #._model_metadata.inspect
        db_param = db_doc._user_data[param]
        doc_existing_new_parent_cats[user_class]._user_data[param].should == db_param
        #test accessor method
        doc_existing_new_parent_cats[user_class].__send__(param).should == db_param
      end
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    @user_classes.each do |user_class|
      doc_existing_new_parent_cats[user_class].parent_categories_add(new_cats)
    end
    #check results
    #check doc in memory
    @user_classes.each do |user_class|
      new_cats.each do |new_cat|
        doc_existing_new_parent_cats[user_class].parent_categories.should include new_cat
      end
    end
    #check database
    parent_cats = {}
    @user_classes.each do |user_class|
      parent_cats[user_class] = user_class.get(doc_existing_new_parent_cats[user_class]._model_metadata[:_id]).parent_categories
      new_cats.each do |cat|
        parent_cats[user_class].should include cat
      end
    end
    #check all cats are there and are unique
    @user_classes.each do |user_class|
      parent_cats[user_class].sort.should == (orig_parent_cats[user_class] + new_cats).uniq.sort
    end
  end

  it "should be able to remove parent categories" do
    orig_parent_cats = {}
    doc_params = {}
    doc_remove_parent_cats = {}
    #set initial conditions
    @user_classes.each do |user_class|
      orig_parent_cats[user_class]  = ['orig_cat3', 'orig_cat4', 'del_this_cat1', "del_this_cat2-#{user_class.to_s}"]
      doc_params[user_class] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_class]})
      doc_remove_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_remove_parent_cats[user_class].__save
    end
    #verify initial conditions
    @user_classes.each do |user_class|
      doc_params[user_class].keys.each do |param|
        db_param = user_class.get(doc_remove_parent_cats[user_class]._model_metadata[:_id])._user_data[param]
        doc_remove_parent_cats[user_class]._user_data[param].should == db_param
        #test accessor method
        doc_remove_parent_cats[user_class].__send__(param).should == db_param
      end
    end
    #continue with initial conditions
    remove_multi_cats = {}
    @user_classes.each do |user_class|
      remove_multi_cats[user_class] = ['del_this_cat1', "del_this_cat2-#{user_class.to_s}"]
      remove_multi_cats[user_class].each do |cat|
        doc_remove_parent_cats[user_class].parent_categories.should include cat
      end
    end

    #test
    @user_classes.each do |user_class|
      doc_remove_parent_cats[user_class].parent_categories_subtract(remove_multi_cats[user_class])
    end

    #verify results
    @user_classes.each do |user_class|
      remove_multi_cats[user_class].each do |cat|
        doc_remove_parent_cats[user_class].parent_categories.should_not include cat
      end
    end

    cats_in_db = {}
    @user_classes.each do |user_class|
      doc_id = doc_remove_parent_cats[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      cats_in_db[user_class] = db_doc._user_data[:parent_categories].inspect
      remove_multi_cats[user_class].each do |removed_cat|
        cats_in_db[user_class].should_not include removed_cat
      end
    end
  end


  it "should only have unique categories" do
    #verify initial state
    @user_classes.each do |user_class|
      user_class.all.size.should == 0
    end

    orig_parent_cats = {}
    doc_params = {}
    doc_uniq_parent_cats = {}
    orig_sizes = {}
    new_cats = {}
    expected_sizes = {}
    #set initial conditions
    @user_classes.each do |user_class|
      orig_parent_cats[user_class] = ['dup cat1', 'dup cat2', 'uniq cat1']
      doc_params[user_class] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_class]})
      doc_uniq_parent_cats[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      doc_uniq_parent_cats[user_class].__save
      orig_sizes[user_class] = doc_uniq_parent_cats[user_class].parent_categories.size
      new_cats[user_class] = ['dup cat1', 'dup cat2', 'uniq_cat2']
      expected_sizes[user_class] = orig_sizes[user_class] + 1 #uniq_cat2
    end

    #test
    @user_classes.each do |user_class|
      doc_uniq_parent_cats[user_class].parent_categories_add(new_cats[user_class])
    end

    #verify results
    records = {}
    @user_classes.each do |user_class|
      expected_sizes[user_class].should == doc_uniq_parent_cats[user_class].parent_categories.size
      doc_id = doc_uniq_parent_cats[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      #puts "Doc ID searched: #{doc_id.inspect}"
      db_doc._user_data[:parent_categories].sort.should == doc_uniq_parent_cats[user_class].parent_categories.sort
      records[user_class] = user_class.call_view(:parent_categories, 'dup cat2')
      records[user_class].size.should == 1
      records[user_class].first.parent_categories.should include 'dup cat2'
    end
  end

  it "should allow new data fields to be added to the data structure" do
    #set initial conditions
    orig_parent_cats = {}
    node_params = {}
    nodes = {}
    @user_classes.each do |user_class|
      orig_parent_cats[user_class] = ['dyn data parent cat']
      new_params = get_default_params.merge({:my_category => "cat_test#{(user_class.hash).to_s}",
                                             :parent_categories => orig_parent_cats[user_class] })
      node_params[user_class] = new_params
      nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
    end
    new_key_field = :links
    #test for new field
    @user_classes.each do |user_class|
      nodes[user_class].__set_userdata_key(new_key_field, nil)
    end
    @user_classes.each do |user_class|
    #verify new field exists and works
      nodes[user_class].respond_to?(new_key_field).should == true
      nodes[user_class].__send__(new_key_field).should == nil
    #initial conditions for  adding data
    #NOTE: :links has a special operations for add and subtract
    #defined in the Node Operations (see midas directory)
      new_data = {:link_name => "blah", :link_src =>"http:\\\\to.somewhere.blah"}
      add_method = "#{new_key_field}_add".to_sym
      link_add_op = NodeElementOperations::LinkAddOp
    #test adding new data
      nodes[user_class].__send__(add_method, new_data)
    #verify new data was added appropriately
      updated_data = nodes[user_class].__send__(new_key_field)
      updated_data.should_not == new_data
      magically_transformed_data = link_add_op.call(nil, new_data)[:update_this]
      updated_data.should == magically_transformed_data
    end
  end

end

describe BufsNodeFactory, "Document Operations with Attachments" do
  include MakeUserClasses
  include NodeHelpers
  #include UserNodeSpecHelpers

  before(:all) do
    @test_files = BufsFixtures.test_files
  end

  before(:each) do
    @user_classes = [User1Class, User2Class,  User3Class, User4Class] #[User1Class, User2Class, User3Class, User4Class]
  end

  after(:each) do
    @user_classes.each do |user_class|
      user_class.destroy_all
    end
  end

  #This spec may not be needed anymore. Originally the models were defining
  #the files manager's methods, but that's been moved into the base node
  #so this test really only is a flag to an interface change (which may be more 
  #annoying than userful)
  it "has a file manager associated with its nodes" do
     _files_mgr_methods = [:add_files, :add_raw_data, :subtract_files, 
                          :get_raw_data, :get_attachments_metadata]
    #set initial conditions
    orig_parent_cats = {}
    node_params = {}
    nodes = {}
    @user_classes.each do |user_class|
      orig_parent_cats[user_class] = ['old parent cat']
      new_params = get_default_params.merge({:my_category => "cat_test#{(user_class.hash).to_s}",
                                             :parent_categories => orig_parent_cats[user_class] })
      node_params[user_class] = new_params
      nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
    end
     
     responds_to_method = {}
     should_respond_to_method = {}
     @user_classes.each do |user_class|
       _files_mgr_methods.each do |meth|
         responds_to_method[meth] = nodes[user_class]._files_mgr.respond_to?(meth)
         should_respond_to_method[meth] = true
         #nodes[user_class]._files_mgr.respond_to?(meth).should == true
       end
       responds_to_method.should == should_respond_to_method
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
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].__save #doc must be saved before we can attach
    end

    #check initial conditions
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc._model_metadata['attachment_doc_id'].should == nil
      #(user_class.get(basic_docs[user_class]._model_metadata['_id'])['attachment_doc_id']).should == nil
    end
    #test
    #using just the filename
    file_data = {:src_filename => test_filename}
    @user_classes.each do |user_class|
      basic_docs[user_class].files_add(file_data)
    end

    #check results
    att_doc_ids = {}
    att_docs = {}
    @user_classes.each do |user_class|
      id_of_doc_w_att = basic_docs[user_class]._model_metadata[:_id]
      doc_w_att = user_class.get(id_of_doc_w_att)
      doc_w_att.attached_files.size.should == 1
      doc_w_att._user_data.should == basic_docs[user_class]._user_data
      doc_w_att.attached_files.should == basic_docs[user_class].attached_files
    end
  end

  it "should cleanly remove all attachments" do
    #initial conditions 
    #TODO: vary filename by user
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_w_attach_from_file(user_class, test_filename, doc_params[user_class])
    end
    #verify initial conditions
    att_doc_ids = {}
    att_files = {}
    test_basename = File.basename(test_filename)
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      #raise db_doc.attachment_doc_id.inspect
      att_files[user_class] = db_doc.attached_files
      att_files[user_class].size.should == 1
      att_files[user_class].first.should == BufsEscape.escape(test_basename)
    end
    #test
    attachment_name = test_basename
    @user_classes.each do |user_class|
      doc = user_class.get(basic_docs[user_class]._model_metadata[:_id])
      doc.files_remove_all
    end
    #check results
    #TODO: Highlight the fact that basic doc still has attachments in memory?
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.should == nil
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
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att2', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_w_attach_from_file(user_class, test_filename1, doc_params[user_class])
      #puts "User Class: #{user_class.inspect}"
      #puts "fname to add: #{test_filename2}"
      #puts "Node Class: #{basic_docs[user_class].class.inspect}"
      #puts "Node Name: #{basic_docs[user_class].my_category.inspect}"
      basic_docs[user_class].files_add(:src_filename => test_filename2)
    end
    #verify initial conditions
    #att_doc_ids = {}
    #att_docs = {}
    test_basename1 = File.basename(test_filename1)
    test_basename2 = File.basename(test_filename2)
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.size.should == 2
      #db_doc.attached_files.first.should == BufsEscape.escape(test_basename)
    end
    #test
    attachment_name1 = BufsEscape.escape(test_basename1)
    attachment_name2 = BufsEscape.escape(test_basename2)
    @user_classes.each do |user_class|
      doc = user_class.get(basic_docs[user_class]._model_metadata[:_id])
      doc.files_subtract(attachment_name1)
    end
    #check results
    @user_classes.each do |user_class|
      #att_docs[user_class] = user_class.user_attachClass.get(att_doc_ids[user_class])
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.size.should == 1
      db_doc.attached_files.first.should == BufsEscape.escape(attachment_name2)
    end
    #delete again so that all attachments are deleted
    @user_classes.each do |user_class|
      doc = user_class.get(basic_docs[user_class]._model_metadata[:_id])
      doc.files_subtract(attachment_name2)
    end
    #check results
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.size.should == 0
    end
  end


  it "should list attachment list" do
    #initial conditions
    #TODO: vary filename by user, support multiple attachments
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_class]})

      basic_docs[user_class] = make_doc_w_attach_from_file(user_class, test_filename, doc_params[user_class])
    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    test_basename = File.basename(test_filename)
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.size.should == 1
      db_doc.attached_files.first.should == BufsEscape.escape(test_basename)
    end
    #test
    attachment_names = {}
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      attachment_names[user_class] = db_doc.attached_files
    end
    #check results
    @user_classes.each do |user_class|
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
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['text file', 'test file']
      doc_params[user_class] = get_default_params.merge({:my_category => 'strange_characters', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].__save #doc must be saved before we can attach
    end
    #test
    @user_classes.each do |user_class|
      basic_docs[user_class].files_add(:src_filename => test_filename)
    end
    #check results
    @user_classes.each do |user_class|
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.first.should == BufsEscape.escape(test_basename)
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
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['docs with attachments']
      doc_params[user_class] = get_default_params.merge({:my_category => 'doc_w_raw_data_att', :parent_categories => parent_cats[user_class]})
      basic_docs[user_class] = make_doc_no_attachment(user_class, doc_params[user_class])
      basic_docs[user_class].__save
      #test
      #metadata[user_class] = basic_docs[user_class].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #metadata[user_class].should == ["should be the metadata for that user"]
      basic_docs[user_class].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #verify results
      doc_id = basic_docs[user_class]._model_metadata[:_id]
      db_doc = user_class.get(doc_id)
      db_doc.attached_files.size.should == 1
      att_file = db_doc.attached_files.first
      att_file.should == BufsEscape.escape(attach_name)
      #TODO: More rigorous testing of attached data from raw data
    end
  end

  it "should be able to retrieve the metadata for a single attachment" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    parent_cats = {}
    node_params = {}
    basic_nodes = {}
    attached_basenames = {}
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['nodes with attachments']
      my_cat = 'doc_w_att1'
      params = {:my_category => my_cat, :parent_categories => parent_cats[user_class]}
      node_params[user_class] = get_default_params.merge(params)
      basic_nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
      basic_nodes[user_class].__save
      basic_nodes[user_class].files_add(:src_filename => test_filename)
    end
    #check initial conditions
    @user_classes.each do |user_class|
      attached_basenames[user_class] = basic_nodes[user_class].attached_files
      attached_basenames[user_class].size.should == 1
      attached_basename= attached_basenames[user_class].first
      attached_basename.should == BufsEscape.escape(test_basename)
      #test
      moab_att_metadata = basic_nodes[user_class].__get_attachment_metadata(attached_basename)
      md = moab_att_metadata
      md[:file_modified].should == File.mtime(test_filename).to_s
      md[:content_type].should =~ /text\/plain/
      #TODO Test for content type match too
    end
  end

  it "should be able to retrieve the metadata for an attachment" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    parent_cats = {}
    node_params = {}
    basic_nodes = {}
    attached_basenames = {}
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['nodes with attachments']
      my_cat = 'doc_w_att1'
      params = {:my_category => my_cat, :parent_categories => parent_cats[user_class]}
      node_params[user_class] = get_default_params.merge(params)
      basic_nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
      basic_nodes[user_class].__save
      basic_nodes[user_class].files_add(:src_filename => test_filename)
    end
    #check initial conditions
    @user_classes.each do |user_class|
      attached_basenames[user_class] = basic_nodes[user_class].attached_files
      attached_basenames[user_class].size.should == 1
      attached_basename= attached_basenames[user_class].first
      attached_basename.should == BufsEscape.escape(test_basename)
      #test
      moab_att_metadata = basic_nodes[user_class].__get_attachments_metadata
      md = moab_att_metadata[test_basename.to_sym]
      md[:file_modified].should == File.mtime(test_filename).to_s
      #TODO Test for content type match too
    end
  end


  it "should be able to retrieve the raw data for an attachment" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    parent_cats = {}
    node_params = {}
    basic_nodes = {}
    attached_basenames = {}
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['nodes with attachments']
      my_cat = 'doc_w_att1'
      params = {:my_category => my_cat, :parent_categories => parent_cats[user_class]}
      node_params[user_class] = get_default_params.merge(params)
      basic_nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
      basic_nodes[user_class].__save
      basic_nodes[user_class].files_add(:src_filename => test_filename)
    end
    #check initial conditions
    @user_classes.each do |user_class|
      attached_basenames[user_class] = basic_nodes[user_class].attached_files
      attached_basenames[user_class].size.should == 1
      attached_basename = attached_basenames[user_class].first
      attached_basename.should == BufsEscape.escape(test_basename)
    #test
      moab_raw_data = basic_nodes[user_class].get_raw_data(attached_basename)
      file_raw_data = File.open(test_filename, "r"){|f| f.read}
      moab_raw_data.should == file_raw_data
    end
  end

  it "should have an export function for attachments" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    parent_cats = {}
    node_params = {}
    basic_nodes = {}
    attached_basenames = {}
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['nodes with attachments']
      my_cat = 'doc_w_att1'
      params = {:my_category => my_cat, :parent_categories => parent_cats[user_class]}
      node_params[user_class] = get_default_params.merge(params)
      basic_nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
      basic_nodes[user_class].__save
      basic_nodes[user_class].files_add(:src_filename => test_filename)
    end
    #check initial conditions
    @user_classes.each do |user_class|
      attached_basenames[user_class] = basic_nodes[user_class].attached_files
      attached_basenames[user_class].size.should == 1
      attached_basename = attached_basenames[user_class].first
      attached_basename.should == BufsEscape.escape(test_basename)
    #test
      exported_att_data = basic_nodes[user_class].__export_attachment(attached_basename)
      exported_att_data[:metadata].should == basic_nodes[user_class].__get_attachment_metadata(attached_basename)
      exported_att_data[:data].should == basic_nodes[user_class].get_raw_data(attached_basename)
    end
  end

  it "should have an import function for attachments" do
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    parent_cats = {}
    node_params = {}
    basic_nodes = {}
    attached_basenames = {}
    att_names = {}
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    @user_classes.each do |user_class|
      parent_cats[user_class] = ['nodes with attachments']
      my_cat = 'doc_w_att1'
      params = {:my_category => my_cat, :parent_categories => parent_cats[user_class]}
      node_params[user_class] = get_default_params.merge(params)
      basic_nodes[user_class] = make_doc_no_attachment(user_class, node_params[user_class])
      basic_nodes[user_class].__save
      file_modified = File.mtime(test_filename).to_s
      content_type = MimeNew.for_ofc_x(test_filename)
      metadata = {:file_modified => file_modified, :content_type => content_type}
      raw_data = File.open(test_filename, "r"){|f| f.read}
      import_format = {:data => raw_data, :metadata => metadata}
      att_names[user_class] = BufsEscape.escape(test_basename)
    #test
      basic_nodes[user_class].__import_attachment(att_names[user_class], import_format)
    end
    #verify results
    @user_classes.each do |user_class|
      basic_nodes[user_class].attached_files.size.should == 1
      basic_nodes[user_class].attached_files.first.should == att_names[user_class]
    end
  end

  it "should be able to create a node from another node" do
    #other node is from the first user class
    test_filename = @test_files['simple_text_file']
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    #set initial conditions
    parent_cats = ['nodes from other nodes']
    my_cat1 = 'doc_w_att_xfer1'
    my_cat2 = 'doc_w_att_xfer2'
    params1 = {:my_category => my_cat1, :parent_categories => parent_cats}
    params2 = {:my_category => my_cat2, :parent_categories => parent_cats}
    node_params1 = get_default_params.merge(params1)
    node_params2 = get_default_params.merge(params2)
    #here is where we create the node from the first user class
    user_class1 = @user_classes[0]
    #TODO: Figure out better way that doesn't break when reconfiguring user classes
    user_class2 = @user_classes[2] #||@user_classes[0]
    raise "User Class is nil" unless (user_class1 && user_class2)
    other_node1 = make_doc_no_attachment(user_class1, node_params1)
    #plus one from a different class
    other_node2 = make_doc_no_attachment(user_class2, node_params2)
    other_node1.__save
    other_node2.__save
    other_node1.files_add(:src_filename => test_filename)
    other_node2.files_add(:src_filename => test_filename)
    #check initial conditions
    other_node1.my_category.should == my_cat1
    other_node1.attached_files.first.should == BufsEscape.escape(test_basename)
    other_node2.my_category.should == my_cat2
    other_node2.attached_files.first.should == BufsEscape.escape(test_basename)
    #test
    this_node = user_class2.__create_from_other_node(other_node1)
    #test_inverse
    this_other_node = user_class1.__create_from_other_node(other_node2)
    #verify results
    this_node.class.should == other_node2.class
    this_node.class.should_not == other_node1.class
    this_node.my_category.should == my_cat1
    this_node.attached_files.first.should == BufsEscape.escape(test_basename)
    #verify inverse
    this_other_node.class.should == other_node1.class
    this_other_node.class.should_not == other_node2.class
    this_other_node.my_category.should == my_cat2
    this_other_node.attached_files.first.should == BufsEscape.escape(test_basename)
  end
end

#TODO:  Need to test boundary conditions


require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
require File.dirname(__FILE__) + '/../lib/user_file_system'

FileSystem1 = "/home/bufs/bufs/sandbox_for_specs/file_system_specs/group1"
FileSystem2 = "/home/bufs/bufs/sandbox_for_specs/file_system_specs/group2"


module UserFileNodeSpecHelpers
  DefaultNodeParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultNodeParams.dup #to avoid a couchrest weirdness don't use the params directly
  end
  
  def make_node_no_attachment(user_id, override_defaults={})
    #default_params = {:my_category => 'default', 
    #                  :parent_categories => ['default_parent'],
    #		      :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return UserFileNode.user_to_nodeClass[user_id].new(init_params)
  end

  def make_node_w_attach_from_file(user_id, att_fname, override_defaults={})
    test_filename = att_fname 
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    new_node = make_node_no_attachment(user_id, override_defaults)
    new_node.save #node must be saved before we can attach?
    new_node.add_data_file(test_filename)
    return new_node 
  end

  def node_data_from_file(nodeClass, mycat)
    node_data = nil
    file_node_path = nodeClass.namespace + '/' + mycat
    data_file_path = file_node_path + '/' + nodeClass.data_file_name
    node_file_data = File.open(data_file_path, 'r'){|f| f.read}
    node_data = JSON.parse(node_file_data)
  end
end

describe UserFileNode, "Initialization" do
  include UserFileNodeSpecHelpers

  before(:each) do
    @user1_id = "User001"
    @user2_id = "User002"
    @user1_fs = UserFileNode.new(FileSystem1, @user1_id)
    @user2_fs = UserFileNode.new(FileSystem2, @user2_id)
  end

  it "should initialize user file nodes properly" do
    #test
    user1_node_data = make_node_no_attachment(@user1_id, { :my_category => 'user1_default'})
    user2_node_data = make_node_no_attachment(@user2_id, { :my_category => 'user2_default'})

    user1_filenode = @user1_fs.nodeClass.new({:user1_filenode => user1_node_data})
    user2_filenode = @user2_fs.nodeClass.new({:user2_filenode => user2_node_data})

    #check results
    #users should be registered in UserDB
    UserFileNode.user_to_nodeClass[@user1_id].should == user1_filenode.class
    UserFileNode.user_to_nodeClass[@user2_id].should == user2_filenode.class
    UserFileNode.nodeClass_users[user1_filenode.class.name].should == [@user1_id]
    UserFileNode.nodeClass_users[user2_filenode.class.name].should == [@user2_id]
  end
end

describe UserFileNode, "Basic file operations" do
  include UserFileNodeSpecHelpers

  before(:each) do
    #delete any existing files
    #TODO This only works if UserFileNode.nodeClasses has been correctly populated
    #Need to query each user filesystem (how do we know the names?)
    # => need to enforce database naming convention.
    UserFileNode.nodeClasses.each do |nodeClass|
      all_user_files = nodeClass.all || []
      all_user_files.each do |user_file|
        user_file.destroy
      end
    end

    @user1_id = "User001"
    @user2_id = "User002"
    @user1_fs = UserFileNode.new(FileSystem1, @user1_id)
    @user2_fs = UserFileNode.new(FileSystem2, @user2_id)
  end

  it "should have the filesystem initialized correctly" do
    #check initial conditions
    UserFileNode.nodeClasses.each do |nodeClass|
      nodeClass.all.size.should == 0
    end
    #test
    default_nodes = []
    UserFileNode.nodeClasses.each do |nodeClass|
      default_nodes << nodeClass.new(get_default_params)
    end
    #check results
    default_nodes.each do |default_node|
      default_node.my_category.should == get_default_params[:my_category]
      default_node.parent_categories.should == get_default_params[:parent_categories]
      default_node.description.should == get_default_params[:description]
    end
    #we haven't saved it yet
    UserFileNode.nodeClasses.each do |nodeClass|
      nodeClass.all.size.should == 0
    end
  end

  it "should perform basic collection operations properly" do
    user1_node_data = { :my_category => 'user1_coll_test'}
    user2_node_data = { :my_category => 'user2_coll_test'}

    user1_node = @user1_fs.nodeClass.new(user1_node_data)
    user2_node = @user2_fs.nodeClass.new(user2_node_data)
    user1_node.save
    user2_node.save
    #TODO: Fix the file system state so that these tests are more valid
    #these tests assume that the file system has been initialized already
    #in other words, this test is dependent on previous tests being run
    #although the data is wiped out between each test, the structure is not
    UserFileNode.user_to_nodeClass[@user1_id].all.first.my_category.should == user1_node_data[:my_category]
    UserFileNode.user_to_nodeClass[@user2_id].all.first.my_category.should == user2_node_data[:my_category]
  end

  it "should not save if required fields don't exist" do
    #set initial condition
    orig_dataset_size = {}
    bad_user_node = {}
    all_users = UserFileNode.user_to_nodeClass.keys
    all_users.each do |user_id|
      orig_dataset_size[user_id] = UserFileNode.user_to_nodeClass[user_id].all.size
      bad_user_node[user_id] = UserFileNode.user_to_nodeClass[user_id].new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
    end

    #test
    all_users.each do |user_id|
      lambda { bad_user_node[user_id].save }.should raise_error(ArgumentError)
    end
    #removed validation check for parent categories, not clear this is an issue
    #lambda { bad_bufs_info_doc2.save }.should raise_error(ArgumentError)

    #check results
    all_users.each do |user_id|
      UserFileNode.user_to_nodeClass[user_id].all.size.should == orig_dataset_size[user_id]
    end
  end


  it "should save" do
    #set initial conditions
    orig_dataset_size = {}
    nodes_params = {}
    nodes_to_save = {}
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      orig_dataset_size[user_id] = nodeClass.all.size
      nodes_params[user_id] = get_default_params.merge({:my_category => 'save_test'})
      nodes_to_save[user_id] = make_node_no_attachment(user_id, nodes_params[user_id].dup)
    end
    #test
    nodes_to_save.each do |user_id, node_to_save|
      node_to_save.save
    end
    #check results
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      nodes_params[user_id].keys.each do |param|
        mycat = nodes_to_save[user_id].my_category
        node_data = node_data_from_file(nodeClass, mycat)
        nodes_params[user_id].keys.each do |parm_key|
          node_data[parm_key.to_s].should == nodes_params[user_id][parm_key]
        end
        #file_param = nodeClass.namespace.get(nodes_to_save[user_id]['_id'])[param]
        nodes_to_save[user_id].to_hash[param].should == nodes_params[user_id][param]
        #test accessor method
        nodes_to_save[user_id].__send__(param).should == nodes_params[user_id][param]
      end
    end
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      nodeClass.all.size.should == orig_dataset_size[user_id] + 1
    end 
  end

#adding categories
  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    #set initial conditions
    orig_parent_cats = {}
    nodes_params = {}
    nodes_with_new_parent_cat = {}
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      orig_parent_cats[user_id] = ['old parent cat']
      new_params = get_default_params.merge({:my_category => "cat_test#{user_id}", :parent_categories => orig_parent_cats[user_id]})
      nodes_params[user_id] = new_params
      nodes_with_new_parent_cat[user_id] = make_node_no_attachment(user_id, nodes_params[user_id])
    end

    new_cat = 'new parent cat'

    #UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      #p nodes_with_new_parent_cat[user_id]
    #end

    #test

    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
     nodes_with_new_parent_cat[user_id].add_parent_categories(new_cat)
    end
    #check results
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      #check doc in memory
      nodes_with_new_parent_cat[user_id].parent_categories.should include new_cat
      #check file system
      mycat = nodes_with_new_parent_cat[user_id].my_category
      nodes_params[user_id].keys.each do |param|
        node_data = node_data_from_file(nodeClass, mycat)
        nodes_with_new_parent_cat[user_id].parent_categories.should include new_cat
        #file_param = nodeClass.namespace.get(nodes_to_save[user_id]['_id'])[par
        nodes_with_new_parent_cat[user_id].parent_categories.should include new_cat
        #test accessor method
        #nodes_with_new_parent_cat[user_id].__send__(param).should == nodes_params[user_id][param]
      end
    end
  end

  it "should add categories to existing categories and existing node" do
    #set initial conditions
    orig_parent_cats = {}
    nodes_params = {}
    node_existing_new_parent_cats = {}
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      orig_parent_cats[user_id] = ["#{user_id}-orig_cat1", "#{user_id}-orig_cat2"]
      nodes_params[user_id] = get_default_params.merge({:my_category => "#{user_id}-cat_test2", :parent_categories => orig_parent_cats[user_id]})
      node_existing_new_parent_cats[user_id] = make_node_no_attachment(user_id, nodes_params[user_id])
      #raise "#{node_existing_new_parent_cats[user_id].my_category.inspect}"
      node_existing_new_parent_cats[user_id].save
      #raise "#{node_existing_new_parent_cats[user_id].my_category.inspect}"

    end
    #verify initial conditions
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      nodes_params[user_id].keys.each do |param|
        key_parm = nodes_params[user_id][:my_category]
        x = node_existing_new_parent_cats[user_id]
        file_node = node_existing_new_parent_cats[user_id].class.by_my_category(key_parm).first
        file_node_data = file_node.to_hash
        node_existing_new_parent_cats[user_id].to_hash[param.to_sym].should == file_node_data[param]
        #test accessor method
        node_existing_new_parent_cats[user_id].__send__(param.to_sym).should == file_node.__send__(param.to_sym)
      end
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      node_existing_new_parent_cats[user_id].add_parent_categories(new_cats)
    end
    #check results
    #check node in memory
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      new_cats.each do |new_cat|
        node_existing_new_parent_cats[user_id].parent_categories.should include new_cat
      end
    end
    #check filesystem
    #parent_cats = {}
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|

      mycat = node_existing_new_parent_cats[user_id].my_category
      new_cats.each do |cat|
        node_data = node_data_from_file(nodeClass, mycat)
        node_existing_new_parent_cats[user_id].parent_categories.should include cat
        #file_param = nodeClass.namespace.get(nodes_to_save[user_id]['_id'])[par
        node_existing_new_parent_cats[user_id].parent_categories.should include cat
        #test accessor method
        #nodes_with_new_parent_cat[user_id].__send__(param).should == nodes_params[user_id][param]
      end
    end

    #check all cats are there and are unique
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      node_existing_new_parent_cats[user_id].parent_categories.sort.should == (orig_parent_cats[user_id] + new_cats).uniq.sort
    end
  end

  it "should be able to remove parent categories" do
    orig_parent_cats = {}
    node_params = {}
    node_remove_parent_cats = {}
    #set initial conditions
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      orig_parent_cats[user_id]  = ['orig_cat3', 'orig_cat4', 'del_this_cat1', "del_this_cat2-#{user_id}"]
      node_params[user_id] = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats[user_id]})
      node_remove_parent_cats[user_id] = make_node_no_attachment(user_id, node_params[user_id])
      node_remove_parent_cats[user_id].save
    end
    #verify initial conditions
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      node_params[user_id].keys.each do |param|
        mycat = node_remove_parent_cats[user_id].my_category
        retrieved_node = nodeClass.by_my_category(mycat).first
        node_param = retrieved_node.node_data_hash[param]
        node_remove_parent_cats[user_id].node_data_hash[param].should == node_param
        #test accessor method
        node_remove_parent_cats[user_id].__send__(param).should == node_param
      end
    end
    #continue with initial conditions
    remove_multi_cats = {}
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      remove_multi_cats[user_id] = ['del_this_cat1', "del_this_cat2-#{user_id}"]
      remove_multi_cats[user_id].each do |cat|
        node_remove_parent_cats[user_id].parent_categories.should include cat
      end
    end

    #test
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      node_remove_parent_cats[user_id].remove_parent_categories(remove_multi_cats[user_id])
    end

    #verify results
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      remove_multi_cats[user_id].each do |cat|
        node_remove_parent_cats[user_id].parent_categories.should_not include cat
      end
    end

    cats_in_file = {}
    UserFileNode.user_to_nodeClass.each do |user_id, nodeClass|
      mycat = node_remove_parent_cats[user_id].my_category
      node_from_file = nodeClass.by_my_category(mycat).first
      cats_in_file[user_id] = node_from_file.parent_categories
      remove_multi_cats[user_id].each do |removed_cat|
        cats_in_file[user_id].should_not include removed_cat
      end
    end
  end

end
=begin

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
      attachClass = docClass.user_attachClass
      all_attach_docs = attachClass.all
      all_attach_docs.each do |attach_doc|
        attach_doc.destroy
      end
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

  it "should cleanly remove all attachments" do
    #initial conditions 
    #TODO: vary filename by user
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with attachments']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_w_attach_from_file(user_id, test_filename, doc_params[user_id])
    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    test_basename = File.basename(test_filename)
    UserDB.user_to_docClass.each do |user_id, docClass|
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).attachment_doc_id
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      docClass.get(basic_docs[user_id]['_id'])['attachment_doc_id'].should == att_docs[user_id]['_id']
      att_docs[user_id]['_attachments'].keys.should include BufsEscape.escape(test_basename) #URI.escape(test_base
      att_docs[user_id]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
    #test
    attachment_name = test_basename
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc = docClass.get(basic_docs[user_id]['_id'])
      doc.remove_attachments(attachment_name)
    end
    #check results
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.get(basic_docs[user_id]['_id']).attachment_doc_id.should == nil   #reference to attachment doc from user doc
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])  #attachment doc
      att_docs[user_id].should == nil
    end
  end

  it "should list attachment list" do
    #initial conditions
    #TODO: vary filename by user, support multiple attachments
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with attachments']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_att1', :parent_categories => parent_cats[user_id]})

      basic_docs[user_id] = make_doc_w_attach_from_file(user_id, test_filename, doc_params[user_id])
    end
    #verify initial conditions
    att_doc_ids = {}
    att_docs = {}
    test_basename = File.basename(test_filename)
    UserDB.user_to_docClass.each do |user_id, docClass|
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).attachment_doc_id
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      docClass.get(basic_docs[user_id]['_id'])['attachment_doc_id'].should == att_docs[user_id]['_id']
      att_docs[user_id]['_attachments'].keys.should include BufsEscape.escape(test_basename) #
      att_docs[user_id]['md_attachments'][BufsEscape.escape(test_basename)]['file_modified'].should == File.mtime(test_filename).to_s
    end
    #test
    attachment_names = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      doc = docClass.get(basic_docs[user_id]['_id'])
      attachment_names[user_id] = doc.get_attachment_names
    end
    #check results
    UserDB.user_to_docClass.each do |user_id, docClass|
      attachment_names[user_id].size.should == 1
      attachment_names[user_id].first.should == BufsEscape.escape(test_basename)
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
      #test
      #metadata[user_id] = basic_docs[user_id].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #metadata[user_id].should == ["should be the metadata for that user"]
      basic_docs[user_id].add_raw_data(attach_name, binary_data_content_type, binary_data)
      #verify results
      att_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).my_attachment_doc_id
      att_docs[user_id] = docClass.get(att_doc_ids[user_id])
      esc_att_name = BufsEscape.escape(attach_name)
      att_docs[user_id].should_not == nil
      att_docs[user_id]['_attachments'].keys.should include esc_att_name
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

  #FIXME: Test for links being destroyed
  #it "should return all model data when queried by the model's category name (my_category)" do
  #  ScoutInfoDoc.node_by_title('test_spec1.pptx').should == ScoutInfoDoc.by_title('test_spec1.pptx')
  #end


end

describe UserDB, "Document Operations with Links" do
  include UserDocSpecHelpers

  before(:each) do
    #delete any existing db records
    #TODO This only works if the db entry also exists in UserDB
    #Need to query each user database (how do we know the names?)
    # => need to enforce database naming convention.
    #query for couchrest-type that matches /UserDB::UserDoc*/
    UserDB.docClasses.each do |docClass|
      linkClass = docClass.user_linkClass
      all_link_docs = linkClass.all
      all_link_docs.each do |link_doc|
        link_doc.destroy
      end
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
      docClass.user_linkClass.name.should == "UserDB::UserLink#{user_id}"
    end
  end

  it "should save links" do
    #initial conditions (attachment file)
    #TODO: vary filename by user
    test_links= ["http://www.google.com", "http://www.bing.com"]
    #intial conditions (doc)
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with links']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_link1', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save #doc must be saved before we can add links
    end
    #check initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.get(basic_docs[user_id]['_id']['links_doc_id']).should == nil
    end
    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      basic_docs[user_id].add_links(test_links)
    end
    #check results
    link_doc_ids = {}
    link_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      link_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).my_link_doc_id
      link_docs[user_id] = docClass.get(link_doc_ids[user_id])
      user_doc_from_db = docClass.get(basic_docs[user_id]['_id'])
      #docClass.get(basic_docs[user_id]['_id'])['links_doc_id'].should == link_docs[user_id]['_id']
      user_doc_from_db.links_doc_id.should == link_docs[user_id]['_id']
      links_in_user_doc = docClass.user_linkClass.get(user_doc_from_db.links_doc_id)
      links_in_user_doc.uris.sort.should == test_links.sort
    end
  end

  it "should remove links do" do
    #initial conditions 
    test_links= ["http://www.google.com", "http://www.bing.com"]
    remove_link = "http://www.bing.com"
    parent_cats = {}
    doc_params = {}
    basic_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      parent_cats[user_id] = ['docs with links']
      doc_params[user_id] = get_default_params.merge({:my_category => 'doc_w_link2', :parent_categories => parent_cats[user_id]})
      basic_docs[user_id] = make_doc_no_attachment(user_id, doc_params[user_id])
      basic_docs[user_id].save #doc must be saved before we can add links
    end
    #check initial conditions
    UserDB.user_to_docClass.each do |user_id, docClass|
      docClass.get(basic_docs[user_id]['_id']['links_doc_id']).should == nil
    end
    #add links
    UserDB.user_to_docClass.each do |user_id, docClass|
      basic_docs[user_id].add_links(test_links)
    end
   #check initial conditions
    link_doc_ids = {}
    link_docs = {}
    UserDB.user_to_docClass.each do |user_id, docClass|
      link_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).my_link_doc_id
      link_docs[user_id] = docClass.get(link_doc_ids[user_id])
      user_doc_from_db = docClass.get(basic_docs[user_id]['_id'])
      #docClass.get(basic_docs[user_id]['_id'])['links_doc_id'].should == link_docs[user_id]['_id']
      user_doc_from_db.links_doc_id.should == link_docs[user_id]['_id']
      links_in_user_doc = docClass.user_linkClass.get(user_doc_from_db.links_doc_id)
      links_in_user_doc.uris.sort.should == test_links.sort
    end
    #test
    UserDB.user_to_docClass.each do |user_id, docClass|
      basic_docs[user_id].remove_links(remove_link)
    end
    #verify
    UserDB.user_to_docClass.each do |user_id, docClass|
      link_doc_ids[user_id] = docClass.get(basic_docs[user_id]['_id']).my_link_doc_id
      link_docs[user_id] = docClass.get(link_doc_ids[user_id])
      user_doc_from_db = docClass.get(basic_docs[user_id]['_id'])
      #docClass.get(basic_docs[user_id]['_id'])['links_doc_id'].should == link_d
      user_doc_from_db.links_doc_id.should == link_docs[user_id]['_id']
      links_in_user_doc = docClass.user_linkClass.get(user_doc_from_db.links_doc_id)
      links_in_user_doc.uris.sort.should == (test_links-[remove_link]).sort
    end
  end
end
=end

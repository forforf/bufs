require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
require File.dirname(__FILE__) + '/../lib/user_file_system'


require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
require File.dirname(__FILE__) + '/../lib/user_doc'

require 'couchrest'
#doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!

FileSystemHome = "/home/bufs/bufs/sandbox_for_specs/file_system_specs/group1"


module UserFileNodeSpecHelpers
  DefaultNodeParams = {:my_category => 'file_default',
                      :parent_categories => ['file_default_parent'],
                      :description => 'file_default description'}

  def get_default_params
    DefaultNodeParams.dup #to avoid a couchrest weirdness don't use the params directly
  end

  def make_node_no_attachment(user_id, override_defaults={})
    #default_params = {:my_category => 'default',
    #                  :parent_categories => ['default_parent'],
    #                 :description => 'default description'}
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

module UserDocSpecHelpers
  DefaultDocParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultDocParams.dup #to avoid a couchrest weirdness don't use the params di
  end

  def make_doc_no_attachment(user_id, override_defaults={})
    #default_params = {:my_category => 'default',
    #                  :parent_categories => ['default_parent'],
    #                 :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return UserDB.user_to_docClass[user_id].new(init_params)
  end

  def make_doc_w_attach_from_file(user_id, att_fname, override_defaults={})
    test_filename = att_fname
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    new_doc = make_doc_no_attachment(user_id, override_defaults)
    #raise "#{new_doc.inspect}"
    new_doc.save #doc must be saved before we can attach
    new_doc.add_data_file(test_filename)
    return new_doc
  end
end

describe UserDB, "convert doc node to file node" do
  include UserDocSpecHelpers

  before(:all) do
    @test_files = BufsFixtures.test_files
  end


  after(:each) do
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
  end

  before(:each) do
    puts "UserDB Classes: #{UserDB.docClasses.inspect}"
    UserDB.docClasses.each do |docClass|
      all_user_docs = docClass.all
      all_user_docs.each do |user_doc|
        user_doc.destroy
      end
    end

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

    @user1_id = "DocUser"
    @user1_doc = UserDB.new(CouchDB, @user1_id)
  end

  it "should convert a doc node to a file node" do
    #initial conditions
    test_filename = @test_files['binary_data_spaces_in_fname_pptx']
    test_basename = File.basename(test_filename)

    init_doc_params = {:my_category => 'doc_node',
                      :parent_categories => ['doc_parents'],
                      :description => ['doc_description']}
    
   
    doc_node = make_doc_w_attach_from_file(@user1_id, test_filename, init_doc_params) 

    #test
    assign_user_a_file_node = UserFileNode.new(FileSystemHome, @user1_id)
    file_nodeClass = UserFileNode.user_to_nodeClass[@user1_id]
    file_node = file_nodeClass.create_from_doc_node(doc_node)

    #verify
    file_node.my_category.should == doc_node.my_category
    file_node.parent_categories.sort.should == doc_node.parent_categories.sort
    file_node.get_attachment_names.sort.should == doc_node.get_attachment_names.sort
  end

end


require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

require File.dirname(__FILE__) + '/../lib/bufs_file_system'
require File.dirname(__FILE__) + '/../lib/bufs_escape'


TestFSModelBaseDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/file_system_specs'

module BufsFileSystemSpecHelpers
  DefaultNodeParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultNodeParams.dup #to avoid any hash weirdness don't use the params directly
  end
  
  def make_node_no_attachment(override_defaults={})
    #default_params = {:my_category => 'default', 
    #                  :parent_categories => ['default_parent'],
    #	      :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return BufsFileSystem.new(init_params)
  end

end


describe BufsFileSystem, "Initial Class Operations" do

  #normally set in dynamic class definitiona
  ModelDir = '/BufsFileSystem_DefaultModel'
  BufsFileSystem.use_directory(TestFSModelBaseDir + ModelDir)

  it "should have a directory to operate in" do
    #test
    BufsFileSystem.namespace.should == TestFSModelBaseDir + ModelDir
    File.exist?(BufsFileSystem.namespace).should == true
  end

  it "should have class method to return all nodes" do
    BufsFileSystem.all.class.should == Array
  end
  
end

describe BufsFileSystem, "Basic Node Operations (no attachments)" do
  include BufsFileSystemSpecHelpers

  ModelDir = '/BufsFileSystem_DefaultModel'
  BufsFileSystem.use_directory(TestFSModelBaseDir + ModelDir)

  before(:each) do
    all_nodes = BufsFileSystem.all
    all_nodes.each do |node|
       node.destroy
    end
  end

  after(:all) do
    all_nodes = BufsFileSystem.all
    all_nodes.each do |node|
       node.destroy
    end
  end


  it "should initialize correctly" do
    #check initial conditions
    BufsFileSystem.all.size.should == 0
    #test
    default_node = BufsFileSystem.new(get_default_params)
    #check results
    default_node.my_category.should == get_default_params[:my_category]
    #we haven't saved anything yet
    BufsFileSystem.all.size.should == 0
  end

  it "should be able to set param values like instance variables" do
    #set initial conditions
    test_node = BufsFileSystem.new(get_default_params)
    #check initial conditions
    test_node.my_category.should == get_default_params[:my_category]
    test_node.parent_categories.should == get_default_params[:parent_categories]
    #test
    new_my_cat = "New my cat"
    #raise "Before set: #{test_node.node_data_hash.inspect}"
    test_node.my_category = new_my_cat
    #raise "After set: #{test_node.node_data_hash.inspect} my cat: #{test_node.my_category.inspect}"
    
    new_parents = ['new_parents']
    test_node.parent_categories = new_parents
    #check results
    test_node.my_category.should == new_my_cat
    test_node.parent_categories.should == new_parents
  end

  it "should not save if required fields don't exist" do
    #set initial conditions
    orig_nodes_size = BufsFileSystem.all.size
    bad_fs_info_node1 = BufsFileSystem.new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
   #test
   lambda { bad_fs_info_node1.save }.should raise_error(ArgumentError)

   #check results
   BufsFileSystem.all.size.should == orig_nodes_size
  end

  it "should save a valid node and be able to retrieve it" do
    #set initial conditions
    orig_nodes_size = BufsFileSystem.all.size
    node_params = get_default_params.merge({:my_category => 'save_test'})
    node_to_save = make_node_no_attachment(node_params.dup)

    #test
    node_to_save.save

    #check results 
    file_node_path = node_to_save.path_to_node_data #node_to_save.class.namespace + '/' + node_to_save.my_category
    File.exists?(file_node_path).should == true
    data_file_path = file_node_path + '/' + BufsFileSystem.data_file_name
    #read node file data
    node_file_data = nil
    File.open(data_file_path, 'r'){|f| node_file_data = f.read}
    node_data = JSON.parse(node_file_data)
    node_params.keys.each do |parm_key|
      node_data[parm_key.to_s].should == node_params[parm_key]
    end
  end

  it "should have a class method for finding a node by its category" do
    #set initial conditions
    node_params = get_default_params.merge({:my_category => 'find_me'})
    node_to_save = make_node_no_attachment(node_params.dup)
    node_to_save.save
    #test
    found_node = BufsFileSystem.by_my_category('find_me').first
    #check results
    node_to_save.node_data_hash.each do |parm_key, parm_val|
      puts "pk: #{parm_key.inspect}, pv: #{parm_val.inspect}"
      puts "fnv: #{found_node.node_data_hash.inspect}"
      parm_val.should == found_node.node_data_hash[parm_key]
    end
  end

  it "should have a class method for finding nodes by parent categories" do
    #set initial conditions
    node_params = []
    node_params[1] = get_default_params.merge({:my_category => 'find_me1',
                                            :parent_categories => ['find_me', 'mom', 'dad']})
    node_params[2] = get_default_params.merge({:my_category => 'find_me2',
                                            :parent_categories => ['find_me', 'mom2', 'dad']})
    node_params[3] = get_default_params.merge({:my_category => 'dont_find_me',
                                          :parent_categories => ['mom', 'dad', 'mom2']})
    node_params.compact!
    node_params.each do |node_param|
      node_to_save = make_node_no_attachment(node_param.dup)
      node_to_save.save
    end
    #test
    found_pc_nodes = BufsFileSystem.by_parent_categories('find_me')
    #check results
    found_pc_nodes.size.should == 2
    found_pc_nodes.each do |found_node|
      found_node.parent_categories.should include 'find_me'
      found_node.parent_categories.should_not include 'dont_find_me'
    end
  end


  #adding categories
  it "should add categories for a new node" do
    #set initial conditions
    init_parent_cats = ['init parent cat']
    new_params = {:my_category => 'cat_test1', :parent_categories => init_parent_cats}
    node_params = get_default_params.merge( new_params )
    test_node = make_node_no_attachment(node_params)
    new_parent_cat = 'new parent category'
    #test
    test_node.add_parent_categories(new_parent_cat)
    #check results
    #check node in memory
    test_node.parent_categories.should include new_parent_cat
    #check file
    file_node_path = test_node.class.namespace + '/' + test_node.my_category
    File.exists?(file_node_path).should == true
    data_file_path = file_node_path + '/' + BufsFileSystem.data_file_name
    #read node file data
    node_file_data = nil
    cats = init_parent_cats + [new_parent_cat]
    File.open(data_file_path, 'r'){|f| node_file_data = f.read}
    node_data = JSON.parse(node_file_data)
    node_data["parent_categories"].should == cats
  end

  it "should add categories to a node, and maintain uniqueness" do
    #set initial conditions
    orig_parent_cats = ['orig_cat1', 'orig_cat2']
    node_params = get_default_params.merge({:my_category => 'cat_test2', :parent_categories => orig_parent_cats})
    node_existing_new_parent_cat = make_node_no_attachment(node_params)
    node_existing_new_parent_cat.save
    #verify initial conditions
    #check file
    file_node_path = node_existing_new_parent_cat.class.namespace + '/' + node_existing_new_parent_cat.my_category
    File.exists?(file_node_path).should == true
    data_file_path = file_node_path + '/' + BufsFileSystem.data_file_name
    node_file_data = nil
    File.open(data_file_path, 'r'){|f| node_file_data = f.read}
    node_data = JSON.parse(node_file_data)
    node_params.keys.each do |parm_key|
      node_data[parm_key.to_s].should == node_params[parm_key]
      #test accessor method
      node_existing_new_parent_cat.__send__(parm_key.to_s).should == node_params[parm_key]
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    node_existing_new_parent_cat.add_parent_categories(new_cats)
    #check results
    #check node in memory
    new_cats.each do |new_cat|
      node_existing_new_parent_cat.parent_categories.should include new_cat
    end
    #check files
    File.open(data_file_path, 'r'){|f| node_file_data = f.read}
    node_data = JSON.parse(node_file_data)
    parent_cats = node_data["parent_categories"]
    new_cats.each do |cat|
      parent_cats.should include cat
    end
    #check all cats are there and are unique
    parent_cats.sort.should == (orig_parent_cats + new_cats).uniq.sort
  end

  it "should be able to remove parent categories" do
    #set initial conditions
    orig_parent_cats = ['orig_cat3', 'orig_cat4', 'del_this_cat1', 'del_this_cat2']
    node_params = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats})
    node_remove_parent_cat = make_node_no_attachment(node_params)
    node_remove_parent_cat.save
    #verify initial conditions
    #check file
    file_node_path = node_remove_parent_cat.class.namespace + '/' + node_remove_parent_cat.my_category
    File.exists?(file_node_path).should == true
    data_file_path = file_node_path + '/' + BufsFileSystem.data_file_name
    node_file_data = nil
    File.open(data_file_path, 'r'){|f| node_file_data = f.read}
    node_data = JSON.parse(node_file_data)
    node_params.keys.each do |parm_key|
      node_data[parm_key.to_s].should == node_params[parm_key]
      #test accessor method
      node_remove_parent_cat.__send__(parm_key.to_s).should == node_params[parm_key]
    end
    #continue with initial conditions
    remove_multi_cats = ['del_this_cat1', 'del_this_cat2']
    remove_multi_cats.each do |cat|
      node_remove_parent_cat.parent_categories.should include cat
    end

    #test
    node_remove_parent_cat.remove_parent_categories(remove_multi_cats)

    #verify results
    #check memory
    remove_multi_cats.each do |cat|
      node_remove_parent_cat.parent_categories.should_not include cat
    end
    #check files
    File.open(data_file_path, 'r'){|f| node_file_data = f.read}
    node_data = JSON.parse(node_file_data)
    parent_cats_in_file = node_data["parent_categories"]
    remove_multi_cats.each do |removed_cat|
      node_remove_parent_cat.parent_categories.should_not include removed_cat
    end
  end

  it "should save data files as a regular file" do
    #set initial conditions    
    test_filename = BufsFixtures.test_files['binary_data_pptx']
    test_basename = File.basename(test_filename)
    node_params = get_default_params.merge({:my_category => 'find_me'})
    node_to_save = make_node_no_attachment(node_params.dup)
    node_to_save.save
    #check initial conditions
    node_to_save.attached_files?.should == false
    #test
    node_to_save.add_data_file(test_filename)
    #check results
    esc_test_basename = BufsEscape.escape(test_basename)
    data_file_location = node_to_save.path_to_node_data + '/' + esc_test_basename
    File.exists?(data_file_location).should == true
    node_to_save.attached_files?.should == true
    node_to_save.file_metadata[test_filename]['file_modified'].should == File.mtime(data_file_location).to_s
    node_to_save.filename.should == esc_test_basename
  end

end

#TestFileLocation = 'C:/Documents and Settings/dmartin/My Documents/tmp/'

describe BufsFileSystem do
  #before(:all) do
  #  @test_files = BufsFixtures.test_files
  #  @all_possible_fields = [:my_category, :parent_categories, :description, :file_metadata]
  #  @all_file_data_fields = [:parent_categories, :description, :file_metadata]
  #  @required_fields = {:my_category => 'test_1', :parent_categories => ['mom', 'dad']}
  #  @optional_fields = {:description => ['desc']}
  #  @initial_fields = @required_fields.merge(@optional_fields)
  #  @baseline_fields = @initial_fields.dup #needed because of couchrest weirdness
  #  @bufs_file_system = BufsFileSystem.new(@initial_fields)
  #  @my_dir = BufsFileSystem.name_space + '/' + @baseline_fields[:my_category] + '/'
  #end

 #it "should have initialized the instance variables" do
    #my_cat = 'test_1'
    #@bufs_file_system.my_category.should == my_cat 
    #@bufs_file_system.parent_categories.should == ['mom', 'dad']
  #end

end
=begin
  
 it "should not save if my_category doesn't exist" do
    bad_bufs_fs1 = BufsFileSystem.new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
    bad_bufs_fs2 = BufsFileSystem.new(:my_category => 'no_parent_categories',
                                          :description => 'some description',
                                          :file_metadata => {})
    lambda { bad_bufs_fs1.save }.should raise_error(ArgumentError)
    lambda { bad_bufs_fs2.save }.should raise_error(ArgumentError)
  end

  it "should save into the appropriate directory structure" do
    @bufs_file_system.save
    
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    JSON.parse(cat_data).should == @bufs_file_system.parent_categories
    desc_file = @my_dir + 'description.txt'
    desc_data = nil
    File.open(desc_file, 'r'){|f| desc_data = f.read}
    JSON.parse(desc_data).should == @bufs_file_system.description
  end

#adding categories
  it  "should add a single category for an initial category setting for a new doc" do
    new_cat = 'new category test1'
    @bufs_file_system.add_parent_categories(new_cat)
    @bufs_file_system.parent_categories.should include new_cat
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    cats_in_file = JSON.parse(cat_data)
    cats_in_file.should == @bufs_file_system.parent_categories
  end

  it "should work using add_category alias for add_parent_categories" do
    new_cat3 = 'new category test3'
    @bufs_file_system.add_category(new_cat3)
    @bufs_file_system.parent_categories.should include new_cat3
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    cats_in_file = JSON.parse(cat_data)
    cats_in_file.should == @bufs_file_system.parent_categories
  end

  it "should work using add_categories alias for add_parent_categories" do
    new_cat4 = 'new category test4'
    @bufs_file_system.add_categories(new_cat4)
    @bufs_file_system.parent_categories.should include new_cat4
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    cats_in_file = JSON.parse(cat_data)
    cats_in_file.should == @bufs_file_system.parent_categories
  end

  it "should work for adding an array of categories" do
    multi_cats = ['cat5', 'cat6']
    @bufs_file_system.add_parent_categories(multi_cats)
    multi_cats.each do |cat|
      @bufs_file_system.parent_categories.should include cat
    end
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    cats_in_file = JSON.parse(cat_data)
    cats_in_file.should == @bufs_file_system.parent_categories
  end

  it "should be able to remove parent categories" do
    remove_multi_cats = ['cat5', 'cat6']
    remove_multi_cats.each do |cat|
      @bufs_file_system.parent_categories.should include cat
    end
    @bufs_file_system.remove_parent_categories(remove_multi_cats)
    remove_multi_cats.each do |cat|
      @bufs_file_system.parent_categories.should_not include cat
    end
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    cats_in_file = JSON.parse(cat_data)
    cats_in_file.should == @bufs_file_system.parent_categories
  end

  it "should only have unique categories" do
    duped_cats = ['new category test1', 'cat7', 'cat7']
    orig_size = @bufs_file_system.parent_categories.size
    expected_size = orig_size + 1 #the cat7
    @bufs_file_system.add_parent_categories(duped_cats)
    expected_size.should == @bufs_file_system.parent_categories.size
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    JSON.parse(cat_data).should == @bufs_file_system.parent_categories
  end

  it "should not create separate records in the database" do
    #enforced by file system since the file system model does not have
    #a separate unique id (so the 'my_category' is used as the 'primary key'
  end

#adding data files
  it "save data files as a regular file" do
    test_filename = @test_files['binary_data_pptx']
    test_basename = File.basename(test_filename)
    @bufs_file_system.attached_files?.should == false
    @bufs_file_system.add_data_file(test_filename)
    esc_test_basename = BufsEscape.escape(test_basename)
    data_file = @my_dir + test_basename
    File.exists?(data_file).should == true
    @bufs_file_system.attached_files?.should == true
    @bufs_file_system.file_metadata['file_modified'].should == File.mtime(data_file).to_s
    @bufs_file_system.filename.should == test_basename
  end

  #returning data files
  it "should return all nodes as an array of BufsFileSystem objects" do
    all_nodes = BufsFileSystem.all
    all_nodes.class.should == Array
    all_nodes.first.class.should == BufsFileSystem
    all_nodes.last.class.should == BufsFileSystem
    p all_nodes.first
    p all_nodes.last
  end

  it "should be able to delete (destroy) the model" do
    this_model_dir = BufsFileSystem.name_space + '/' + @bufs_file_system.my_category
    File.exists?(this_model_dir).should == true
    @bufs_file_system.destroy_node
    File.exists?(this_model_dir).should == false
  end

end
=end

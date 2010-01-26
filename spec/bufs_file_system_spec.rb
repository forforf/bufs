
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

#ProjectLocation = '/media-ec2/ec2a/projects/bufs/'
#TestFileLocation = ProjectLocation + 'sandbox_for_specs/file_system_specs/'

module BufsFSSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end

  

require BufsFSSpec::LibDir + 'bufs_file_system'

FSModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/file_system_specs/raw_data_model_spec'
BufsFileSystem.name_space = FSModelDir



#TestFileLocation = 'C:/Documents and Settings/dmartin/My Documents/tmp/'

describe BufsFileSystem do
  before(:all) do
    @test_files = BufsFixtures.test_files
    @all_possible_fields = [:my_category, :parent_categories, :description, :file_metadata]
    @all_file_data_fields = [:parent_categories, :description, :file_metadata]
    @required_fields = {:my_category => 'test_1', :parent_categories => ['mom', 'dad']}
    @optional_fields = {:description => ['desc']}
    @initial_fields = @required_fields.merge(@optional_fields)
    @baseline_fields = @initial_fields.dup #needed because of couchrest weirdness
    @bufs_file_system = BufsFileSystem.new(@initial_fields)
    @my_dir = BufsFileSystem.name_space + '/' + @baseline_fields[:my_category] + '/'
  end

 it "should set the name space" do
   BufsFileSystem.name_space = nil
   BufsFileSystem.set_name_space(FSModelDir)
   BufsFileSystem.name_space.should == FSModelDir
 end

 it "should have initialized the instance variables" do
    my_cat = 'test_1'
    @bufs_file_system.my_category.should == my_cat 
    @bufs_file_system.parent_categories.should == ['mom', 'dad']
  end
  
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
    JSON.parse(cat_data).should == @bufs_file_system.parent_categories
  end

  it "should work using add_category alias for add_parent_categories" do
    new_cat3 = 'new category test3'
    @bufs_file_system.add_category(new_cat3)
    @bufs_file_system.parent_categories.should include new_cat3
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    JSON.parse(cat_data).should == @bufs_file_system.parent_categories
  end

  it "should work using add_categories alias for add_parent_categories" do
    new_cat4 = 'new category test4'
    @bufs_file_system.add_categories(new_cat4)
    @bufs_file_system.parent_categories.should include new_cat4
    File.exists?(@my_dir).should == true
    cat_file = @my_dir + 'parent_categories.txt'
    cat_data = nil
    File.open(cat_file, 'r'){|f| cat_data = f.read}
    JSON.parse(cat_data).should == @bufs_file_system.parent_categories
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
    JSON.parse(cat_data).should == @bufs_file_system.parent_categories
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
    @bufs_file_system.add_data_file(test_filename)
    esc_test_basename = ::CGI::escape(test_basename)
    data_file = @my_dir + test_basename
    File.exists?(data_file).should == true
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
    @bufs_file_system.destroy
    File.exists?(this_model_dir).should == false
  end

end

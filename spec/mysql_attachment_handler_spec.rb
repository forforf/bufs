#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')
require Bufs.glue 'mysql/mysql_files_mgr'

include MySqlInterface
GlueEnvMock = Struct.new(:model_key, :file_table_name)


describe FilesMgr, "Setup and intialization" do
  before(:all) do
    
    #create test database here (drop it when done)
    #create mock file_table

    @glue_env_mock = GlueEnvMock.new("_id", "fake_file_table_name")
    @node_key = :_id
    
    file1_data = "Example File1\nJust some text"
    file2_data = "Example File2\nJust some more text"
    file1_fname = "/tmp/example_file1.txt"
    file2_fname = "/tmp/example_file2.txt"
    files = {file1_fname => file1_data, file2_fname => file2_data}
    files.each do |fname, data|
      File.open(fname, 'w'){|f| f.write(data)}
    end
    @file_datas = [{:src_filename => file1_fname}, {:src_filename => file2_fname}]
    @node1_data = {:_id => 'spec_test1', :data => 'stuff1'}
  end

  
  it "should initialize" do
    node_key_value = @node1_data[@node_key]
    attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    
    #note actual table is setup in glue_env, not file_mgr
    attach_handler.file_table_name.should == @glue_env_mock.file_table_name
  end
    
end
  
describe FilesMgr, "Basic Operations" do
  before(:all) do
    @file_table_name = "attachment_spec__node_loc"
    file1_fname = "/tmp/example_file1.txt"
    file2_fname = "/tmp/example_file2.txt"
    f1_bname = File.basename(file1_fname)
    f2_bname = File.basename(file2_fname)
    @file_stored_data = { f1_bname => File.open(file1_fname, 'rb'){|f| f.read},
                      f2_bname =>File.open(file2_fname, 'rb'){|f| f.read} }
                      
    @mock_key = :_id
    @nodeMockClass = Struct.new(@mock_key, :my_GlueEnv)
    
    @glue_env_mock = GlueEnvMock.new(@mock_key.to_s,
                                                   @file_table_name)

    #set up table for spec
    
    primary_key = '__pkid-file'
    home_dir = ENV["HOME"]  
    my_pw = File.open("#{home_dir}/.locker/tinkit_mysql"){|f| f.read}.strip
    @dbh = DBI.connect("DBI:Mysql:tinkit:localhost", "tinkit", my_pw)
    
    sql = "CREATE TABLE IF NOT EXISTS `#{@file_table_name}` (
          `#{primary_key}` INT NOT NULL AUTO_INCREMENT,
          node_name VARCHAR(255),
          basename VARCHAR(255) NOT NULL,
          content_type VARCHAR(255),
          modified_at VARCHAR(255),
          raw_content LONGBLOB,
          PRIMARY KEY (`#{primary_key}`),
          UNIQUE KEY (node_name, basename) )"
     @dbh.do(sql)    
    #
    @file_datas = [{:src_filename => file1_fname}, {:src_filename => file2_fname}]
  end
  
  
  before(:each) do
    @node1_data = {:_id => 'spec_test1', :data => 'stuff1'}
    @node_mock = @nodeMockClass.new(@node1_data[@mock_key], 
                                                        @glue_env_mock)
    
    node_key_value = @node1_data[@node_key]
    @attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    #@attach_handler.subtract_files(nil, :all)
  end
  
  after(:all) do
    sql = "DROP TABLE `#{@file_table_name}`"
    @dbh.do(sql)
  end
  
  it "should add and retrieve files" do
    node = @node_mock

    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename])
      data = @attach_handler.get_raw_data(node, file_basename) 
      data.should be_nil
    end
      
    #Add the Files  
    @attach_handler.add_files(node, @file_datas)
    
    #Get the files and verify data
    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename])
      data = @attach_handler.get_raw_data(node, file_basename) 
      data.should == @file_stored_data[file_basename]
    end
  end

  it "should list metadata" do
    
    md = @attach_handler.get_attachments_metadata(@node_mock)
    md.should_not == nil
    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename]) 
      each_md = md[file_basename]
      each_md.should_not == nil
      each_md.keys.should include :content_type
      each_md.keys.should include :file_modified
      
      file_basename = File.basename(file_data[:src_filename])
      md[file_basename][:content_type].should =~ /^text\/plain/
      time_str = md[file_basename][:file_modified]
      Time.parse(time_str).should > Time.now - 1 #should have been modified less than a second ago
    end
  end

end
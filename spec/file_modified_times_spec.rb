require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
#CouchDB = BufsFixtures::CouchDB


require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
  doc_db_name = "http://127.0.0.1:5984/bufs_file_mod_times_test_spec/"
  CouchDB = CouchRest.database!(doc_db_name)
  CouchDB.compact!


module FileModifiedTimesSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
  FileReaderDir = File.dirname(__FILE__) + '/../sandbox_for_specs/file_modified_times_spec/view/'
  FileModelDir = File.dirname(__FILE__) + '/../sandbox_for_specs/file_modified_times_spec/model/'
end


require FileModifiedTimesSpec::LibDir + 'view_directory_reader'
require FileModifiedTimesSpec::LibDir + 'abstract_node'



describe ViewDirectoryReader do

  before(:all) do
    BufsInfoDoc.set_name_space(CouchDB)
    BufsFileSystem.set_name_space(FileModifiedTimesSpec::FileModelDir)    
    @reader = ViewDirectoryReader.new(FileModifiedTimesSpec::FileReaderDir)
  end

  #TODO Make this a real test rather than a manual inspection
  it "should parse the directory" do
    node_dir = @reader.read_directory
    node_dir.each do |node|
      puts "Node: #{node.my_category}"
      puts " -- Type: #{node.class}"
      puts " -- Parents: #{node.parent_categories.inspect}"
      puts " -- Sub Entries: #{node.sub_entries.inspect}"
      puts " --- File Metadata: #{node.file_metadata.inspect}"
      puts " --- File Data: #{node.get_file_data.inspect}"
      puts "Syncing Node"
      AbstractNode.sync([node])
    end
  end
end

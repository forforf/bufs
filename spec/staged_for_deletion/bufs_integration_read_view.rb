require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

  doc_db_name = "http://127.0.0.1:5984/bufs_integration_test_spec/"
  CouchDB = CouchRest.database!(doc_db_name)
  CouchDB.compact!

module ViewDirReaderSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
  #TODO: Figure out a better namespace solution
  FileReaderDir = File.dirname(__FILE__) + '/../sandbox_for_specs/bufs_spec/view/'
  FileModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_spec/model/'
end


require ViewDirReaderSpec::LibDir + 'view_directory_reader'
require ViewDirReaderSpec::LibDir + 'abstract_node'



describe ViewDirectoryReader do

  before(:all) do
    @reader = ViewDirectoryReader.new(ViewDirReaderSpec::FileReaderDir)
  end

  #TODO Make this a real test rather than a manual inspection
  it "should read the view and update the models" do
    BufsInfoDoc.set_name_space(CouchDB)
    BufsFileSystem.set_name_space(ViewDirReaderSpec::FileModelDir)
    node_dir = @reader.read_directory
    node_dir.each do |node|
      puts "Node: #{node.my_category}"
      puts " -- Type: #{node.class}"
      puts " -- Parents: #{node.parent_categories.inspect}"
      puts " -- Sub Entries: #{node.sub_entries.inspect}"
      puts " --- File Metadata: #{node.file_metadata.inspect}"
      puts " --- File Data: #{node.get_file_data.inspect}"
      AbstractNode.sync([node])
    end
  end
end

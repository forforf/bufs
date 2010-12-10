require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
CouchDB = BufsFixtures::CouchDB

module ViewDirReaderSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
  FileReaderDir = File.dirname(__FILE__) + '/../sandbox_for_specs/view_dir_reader_spec/view/'
end


require ViewDirReaderSpec::LibDir + 'view_directory_reader'



describe ViewDirectoryReader do

  before(:all) do
    @reader = ViewDirectoryReader.new(ViewDirReaderSpec::FileReaderDir)
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
    end
  end
end

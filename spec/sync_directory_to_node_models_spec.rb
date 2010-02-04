require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
  doc_db_name = "http://127.0.0.1:5984/bufs_sync_test_spec/"
  CouchDB = CouchRest.database!(doc_db_name)
  CouchDB.compact!

#CouchDB = BufsFixtures::CouchDB

module SyncDirToModelSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
  FileReaderDir = File.dirname(__FILE__) + '/../sandbox_for_specs/view_dir_reader_spec/view/'
  FileModelDir = File.dirname(__FILE__) + '/../sandbox_for_specs/view_dir_reader_spec/model/'
end

require SyncDirToModelSpec::LibDir + 'abstract_node'
require SyncDirToModelSpec::LibDir + 'view_directory_reader'



describe ViewDirectoryReader do

  before(:all) do
    BufsInfoDoc.set_name_space(CouchDB)
    BufsFileSystem.set_name_space(SyncDirToModelSpec::FileModelDir)
    @reader = ViewDirectoryReader.new(SyncDirToModelSpec::FileReaderDir)
  end

  #TODO Make this a real test rather than a manual inspection
  it "should parse the directory and build the directory with the freshest data" do
    node_dir = @reader.read_directory
    node_dir.each do |read_only_node|
      current_bids = BufsInfoDoc.by_my_category(:key => read_only_node.my_category)
      if current_bids && current_bids.size == 1
        current_bid = current_bids.first
      elsif current_bids && current_bids.size > 1
	raise "Multiple Bufs Doc Models with same category"
      else
	current_bid = nil
      end
      current_bf = BufsFileSystem.by_my_category(read_only_node.my_category).first
      if current_bid
        current_db_doc = AbstractNode.create(current_bid)
      else
	current_db_doc = nil
      end
      if current_bf
        current_file_doc = AbstractNode.create(current_bf)
      else
	current_file_doc = nil
      end
      AbstractNode.sync([read_only_node, current_db_doc, current_file_doc])
    end
  end

  it "should parse the directory and build the directory with the node data provided" do
    #node_dir = @read.read_directory
    #node_dir.each do |read_only_node|
    #  AbstractNode.sync([read_only_node])
    #end
  end
end

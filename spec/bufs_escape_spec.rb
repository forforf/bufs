#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require 'couchrest'

require Bufs.fixtures 'bufs_fixtures'
require Bufs.lib 'bufs_escape'

doc_db_name = "http://127.0.0.1:5984/bufs_escape_spec/"
EscapeTestDB = CouchRest.database!(doc_db_name)
EscapeTestDB.compact!

describe BufsEscape do

  before(:each) do
    EscapeTestDB.recreate!
  end

  it "should escape and unescape properly to the database" do
    #set initial conditions
    test_file_name = BufsFixtures.test_files['strange_characters_in_file_name']
    test_file_basename = File.basename(test_file_name)
    test_file_data = File.open(test_file_name) {|f| f.read}
    test_doc_params = {'_id' => 'test_doc'}
    EscapeTestDB.save_doc(test_doc_params)
    doc = EscapeTestDB.get(test_doc_params['_id'])
    #test
    att_name = BufsEscape.escape(test_file_basename)
    EscapeTestDB.put_attachment(doc, att_name, test_file_data)
    #verify results
    couchdb_name = EscapeTestDB.get(test_doc_params['_id'])['_attachments'].keys.first
    bufs_escape_name = BufsEscape.escape(test_file_basename)
    att_name.should == couchdb_name

    #test round trip
    EscapeTestDB.delete_attachment(EscapeTestDB.get(test_doc_params['_id']), att_name)
    EscapeTestDB.put_attachment(EscapeTestDB.get(test_doc_params['_id']), couchdb_name, test_file_data)
    couchdb_name_rt1 = EscapeTestDB.get(test_doc_params['_id'])['_attachments'].keys.first

    #verify results
    att_name.should == couchdb_name_rt1

    EscapeTestDB.delete_doc(EscapeTestDB.get(test_doc_params['_id']))
  end
end


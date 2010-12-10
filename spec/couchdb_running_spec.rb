#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require 'spec'
require 'couchrest'

require Bufs.fixtures 'bufs_fixtures'

describe CouchRest::Database do
  it "should be running and have records" do
    CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
    db_docs = nil
    db_docs = CouchDB.documents
    db_docs['total_rows'].should >= 0
  end
end

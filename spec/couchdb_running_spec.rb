require 'spec'
require 'couchrest'

require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

describe CouchRest::Database do
  it "should be running and have records" do
    CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
    db_docs = nil
    db_docs = CouchDB.documents
    db_docs['total_rows'].should >= 0
  end
end

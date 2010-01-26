require 'spec'
require 'couchrest'

require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

describe CouchRest::Database do
  #doc_db_name = "http://127.0.0.1:5984/bufs_test_spec/"
  CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
  db_docs = nil
  db_docs = CouchDB.documents
  db_docs['total_rows'].should >= 0
end

require 'couchrest'

node_db_name = "http://127.0.0.1:5984/bufs_test_spec/"
db = CouchRest.database!(node_db_name)
p db

puts "Loaded Bufs Fixtures"
#This database has the necessary data for bootstrapping the fixture
require 'couchrest'
fix_db_name = "http://127.0.0.1:5984/bufs_test_fixture_files/"
FixDB = CouchRest.database!(fix_db_name)
FixDB.compact!

BufsFixturesDir = File.dirname(__FILE__) + '/'

module BufsFixtures
  class << self 
    attr_accessor :test_files
  end
  ProjectLocation = BufsFixturesDir + '../'
  TestFileLocation = BufsFixturesDir + 'test_files/'
  doc_db_name = "http://127.0.0.1:5984/bufs_test_spec/"
  CouchDB = CouchRest.database!(doc_db_name)
  CouchDB.compact!
end

FileUtils.mkdir_p(BufsFixtures::TestFileLocation)

BufsFixtures.test_files = {}
FixDB.view('test_files/test_files')['rows'].each do |r|
 doc_id = r['value']['_id']
 att_name = r['value']['_attachments'].keys.first

 file_data = FixDB.fetch_attachment(FixDB.get(doc_id), att_name)
 file_name = BufsFixtures::TestFileLocation + att_name
 File.open(file_name, 'wb'){|f| f.write(file_data)}
 BufsFixtures.test_files[doc_id] = file_name
end


puts "---------------------------------"
puts "- Test Filenames and References -"
puts "---------------------------------"
BufsFixtures.test_files.each do |doc, fname|
  
  puts "#{doc.ljust(33)} ->  #{fname}"
end
puts "---------------------------------"

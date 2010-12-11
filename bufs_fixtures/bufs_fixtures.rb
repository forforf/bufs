#require helper for cleaner require statements
helpers_path = File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/')
require File.join(helpers_path, 'require_helper')

#This database has the necessary data for bootstrapping the fixture
require 'couchrest'
require 'fileutils'
require Bufs.helpers 'mime_types_new'
require Bufs.helpers 'log_helper'

#Set Logger
fix_log = BufsLog.set(File.basename(__FILE__))
#fix_log.level = DEBUG
fix_log.debug {"Loading fixtures"} if fix_log.debug?
fix_db_name = "http://127.0.0.1:5984/bufs_test_fixture_files/"
fix_log.debug {"Using DB: #{fix_db_name}"} if fix_log.debug?
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
  doc_db_name_2 = "http://127.0.0.1:5984/bufs_test_spec_2/"
  CouchDB2 = CouchRest.database!(doc_db_name_2)
  CouchDB2.compact!

  #method to create a File Model
  SpecSandbox = File.join(ProjectLocation, 'sandbox_for_specs')
  SampleFileModelDir = File.join(SpecSandbox, 'sample_model_dir')

  def  self.create_sample_file_model(dir = SampleFileModelDir)
    FileUtils.rm_rf(dir) if File.exist?(dir)
  end
end

BufsFixtures.test_files = {}
FixDB.view('test_files/test_files')['rows'].each do |r|
 doc_id = r['value']['_id']
 att_name = r['value']['_attachments'].keys.first

 file_data = FixDB.fetch_attachment(FixDB.get(doc_id), att_name)
 file_name = BufsFixtures::TestFileLocation + att_name
 File.open(file_name, 'wb'){|f| f.write(file_data)}
 BufsFixtures.test_files[doc_id] = file_name
end


#puts "---------------------------------"
#puts "- Test Filenames and References -"
#puts "---------------------------------"
#BufsFixtures.test_files.each do |doc, fname|
  
#  puts "#{doc.ljust(33)} ->  #{fname}"
#end
#puts "---------------------------------"



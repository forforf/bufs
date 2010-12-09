puts "Loaded Bufs Fixtures"
#This database has the necessary data for bootstrapping the fixture
require 'couchrest'
require 'fileutils'
require File.dirname(__FILE__) + '/../lib/helpers/mime_types_new'

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
  doc_db_name_2 = "http://127.0.0.1:5984/bufs_test_spec_2/"
  CouchDB2 = CouchRest.database!(doc_db_name_2)
  CouchDB2.compact!

  #method to create a File Model
  SpecSandbox = File.join(ProjectLocation, 'sandbox_for_specs')
  SampleFileModelDir = File.join(SpecSandbox, 'sample_model_dir')

  def  self.create_sample_file_model(dir = SampleFileModelDir)
    FileUtils.rm_rf(dir) if File.exist?(dir)
  end
=begin  
  def self.file_path(file_basename)
    File.join(TestFileLocation, file_basename)
  end

  def self.stored_files
  { 'binary_data_pptx' => self.file_path('spec_test1.pptx'),
    'binary_data_spaces_in_fname_pptx'  => self.file_path('spec test2 v1.3.pptx'),
    'binary_data2_docx' => self.file_path('spec test2.docx'),
    'binary_data3_pptx'  => self.file_path('spec_test3.pptx'),
    'fresh_file' => self.file_path('test_modified_time_fresh.txt'),
    'simple_text_file' => self.file_path('simple_text_file1.txt'),
    'simple_text_file2' => self.file_path('simple text file 2.txt'),
    'simple_text_file3' => self.file_path('simple text file 3.txt'),
    'simple_text_file4' => self.file_path('simple text file 4.txt'),
    'stale_file'  => self.file_path('test_modified_time_stale.txt'),
    'strange_characters_in_file_name' => self.file_path('Test%_+- .,^^,. -+_%.txt')
  }
  end

  def self.map_js
    map_js = <<-JS
      function(doc) {
        if (doc['doc_type'] == \"test_file\"){
          emit(null, doc);
        }
      }
    JS
  end

  def self.view_js
    { 'map' => map_js }
  end
  def self.view_id
    "_design/test_files"
  end
#view_name = "test_files"
  def self.view_record
    view_record = { "_id" => BufsFixtures.view_id,
                    :views => { "test_files" => BufsFixtures.view_js } }
  end
=end
end

=begin
#temp_db = CouchRest.database!('http://127.0.0.1:5984/temp_files/')

begin
  FixDB.save_doc(BufsFixtures.view_record)
rescue RestClient::RequestFailed
  puts "Replacing view"
  cur_rcd = FixDB.get(BufsFixtures.view_id)
  FixDB.delete_doc(cur_rcd)
  FixDB.save_doc(BufsFixtures.view_record)
end

BufsFixtures.stored_files.each do |name, fname|
  bname = File.basename(fname)
  begin
    doc_data = { "_id" => name, "doc_type" => "test_file" }
    att_data = { "_attachments" => {
          bname => {
            "content_type" => MimeNew.for_ofc_x(bname),
            "data" => File.open(fname, 'r'){|f| f.read}
          }
        }
    }
    rcd_data = doc_data.merge att_data
    FixDB.save_doc(rcd_data)
  rescue RestClient::RequestFailed
    puts "Replacing test file"
    cur_rcd = FixDB.get(rcd_data['_id'])
    FixDB.delete_doc(cur_rcd)
    FixDB.save_doc(rcd_data)
  end
end   
=end
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



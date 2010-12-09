require 'couchrest'
require 'fileutils'
require 'base64'
require File.dirname(__FILE__) + '/../lib/helpers/mime_types_new'


module InitLoader
  @@test_file_location = File.dirname(__FILE__) + '/test_files/'
  def self.file_path(file_basename)
    File.join(@@test_file_location, file_basename)
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
    view_record = { "_id" => self.view_id,
                    :views => { "test_files" => self.view_js } }
  end
end

newDB = CouchRest.database('http://127.0.0.1:5984/bufs_test_fixture_files/"')
newDB.delete! if newDB
NewDB = CouchRest.database!('http://127.0.0.1:5984/bufs_test_fixture_files/"')
begin
  NewDB.save_doc(InitLoader.view_record)
rescue RestClient::RequestFailed
  puts "Replacing view"
  cur_rcd = NewDB.get(InitLoader.view_id)
  NewDB.delete_doc(cur_rcd)
  NewDB.save_doc(InitLoader.view_record)
end

InitLoader.stored_files.each do |name, fname|
  bname = File.basename(fname)
  begin
    doc_data = { "_id" => name, "doc_type" => "test_file" }
    content_type = {"content_type" => MimeNew.for_ofc_x(fname)}
    att_data = { "_attachments" => {
          bname => {
            "content_type" => MimeNew.for_ofc_x(bname),
            "data" => Base64.decode64("#{File.open(fname, 'rb'){|f| f.read}}")
          }
        }
    }

    if doc_data["_id"] == "simple_text_file"
      p doc_data["_id"]
      p File.open(fname, 'r'){|f| f.read}
      #p att_data["_attachments"][bname]["data"] 
    end
    #rcd_data = doc_data.merge att_data
    data = File.open(fname, 'r'){|f| f.read}
    NewDB.save_doc(doc_data)
    NewDB.put_attachment(doc_data, bname, data, content_type)
  rescue RestClient::RequestFailed
    puts "Replacing test file"
    cur_rcd = NewDB.get(doc_data['_id'])
    NewDB.delete_doc(cur_rcd)
    #NewDB.save_doc(rcd_data)
    NewDB.save_doc(doc_data)
    NewDB.put_attachment(doc_data, bname, fname, content_type)

  end
end


require 'spec'
require 'couchrest'

require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!

module BufsLinkSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end


require BufsLinkSpec::LibDir + 'bufs_info_doc'  #used for getting the link id
require BufsLinkSpec::LibDir+ 'bufs_info_link'

describe BufsInfoLink do 
  before(:all) do
    
  #@test_files = BufsFixtures.test_files
    BufsInfoDoc.use_database CouchDB
    BufsInfoLink.use_database CouchDB

    @test_doc = BufsInfoDoc.new(:my_category => "attach_test_doc",
                                :parent_categories => ["atd_dad", "atd_mom"])
    @test_doc.save
    @test_doc_id = @test_doc['_id']
  end

  after(:all) do
    @test_doc.destroy
  end

  before(:each) do
    @test_link = "http://www.google.com"
    @test_links = ["http://www.yahoo.com", "http:://www.bing.com"]
    BufsInfoLink.all.each do |doc|
      doc.destroy
    end
  end

  it "should initialize correctly" do
    #check initial conditions
    BufsInfoLink.all.size.should == 0
    #test
    new_link = BufsInfoLink.new(:uris => [@test_link])
    #check results
    new_link.uris.should == [@test_link]
    #not saved to database yet
    BufsInfoLink.all.size.should == 0
  end

  it "should be able to be created referencing the main doc" do
    #check initial conditions
    BufsInfoLink.all.size.should == 0
    #test
    BufsInfoLink.create_unsaved(@test_doc)['_id'].should == @test_doc['_id'] + @test_doc.class.link_base_id
    #not saved to database yet
    BufsInfoLink.all.size.should == 0
  end

  it "should be able to be created with links and saved to the db" do
    #check initial conditions
    BufsInfoLink.all.size.should == 0
    #test
    BufsInfoLink.create(@test_doc, @test_link)
    #validate results
    link_id = @test_doc['_id'] + @test_doc.class.link_base_id
    link_doc = BufsInfoLink.get(link_id)  
    link_doc.uris.should == [@test_link]
    #not saved to database yet
    BufsInfoLink.all.size.should == 1
  end

  it "should be able to add links to new or existing link docs" do
    #check initial conditions
    BufsInfoLink.all.size.should == 0
    #test empty doc
    BufsInfoLink.add_links(@test_doc, @test_link)
    BufsInfoLink.all.size.should == 1
    #test existing doc
    BufsInfoLink.add_links(@test_doc, @test_links)
    #check results
    expected_uris = @test_links + [@test_link]
    link_id = @test_doc['_id'] + @test_doc.class.link_base_id
    link_doc = BufsInfoLink.get(link_id)
    link_doc.should_not == nil
    link_doc.uris.should_not == nil
    link_doc.uris.sort!.should == expected_uris.sort!
  end


  it "should not add link if the uri is invalid" do
    #set intitial conditions
    link_db_size = BufsInfoLink.all.size
    bad_uri_1 = nil
    #test
    lambda {BufsInfoLink.add_links(@test_doc, bad_uri_1)}.should raise_error(URI::InvalidURIError)
    #check db
    BufsInfoLink.all.size.should == link_db_size
  end 
   
end
=begin
  it "should create object and update the database with a single attachment if there is no other doc in database" do
    #set initial conditions
    test_file = @test_files['binary_data_pptx']
    test_file_basename = File.basename(test_file)
    test_file_modified_time = File.mtime(test_file)
    test_doc = @test_doc
    test_doc_id = @test_doc_id
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(test_file)
    md_params['file_modified'] = test_file_modified_time.to_s
    data = File.open(test_file, 'rb') {|f| f.read}
    attachs = {test_file_basename => {'data' => data, 'md' => md_params }}
    #test
    bia = BufsInfoAttachment.create_attachment_package(test_doc, attachs )
    #check results
    test_attachment_id = test_doc_id + BufsInfoDoc.attachment_base_id
    bia['_id'].should == test_attachment_id
    #p bia
    #Note the lack of escaping on the file name, this only works
    #because the original file name did not need escaping
    bia['md_attachments'][test_file_basename]['file_modified'].should == test_file_modified_time.to_s
    bia['_attachments'][test_file_basename]['content_type'].should == md_params['content_type']
  end


 it "should handle file names with strange (but somewhat common) characters and convert to more standard form" do
    test_file = @test_files['strange_characters_in_file_name']
    test_file_basename = File.basename(test_file)
    test_file_modified_time = File.mtime(test_file)
    test_doc = @test_doc
    test_doc_id = @test_doc_id
    #test_doc_id = 'dummy_doc_strange_character_file_name'
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(test_file)
    md_params['file_modified'] = test_file_modified_time.to_s
    data = File.open(test_file, 'rb') {|f| f.read}
    attachs = {test_file_basename => {'data' => data, 'md' => md_params }}
    #test
    bia = BufsInfoAttachment.create_attachment_package(test_doc, attachs )
    #check results
    test_attachment_id = test_doc_id + BufsInfoDoc.attachment_base_id
    bia['_id'].should == test_attachment_id
    bia['md_attachments'][BufsEscape.escape(test_file_basename)]['file_modified'].should == test_file_modified_time.to_s
    bia['_attachments'][BufsEscape.escape(test_file_basename)]['content_type'].should == md_params['content_type']
 end

  it "should create multiple attachments in one update" do
    #set initial conditions
    test_file1 = @test_files['binary_data2_docx']
    test_file2 = @test_files['simple_text_file']
    test_file1_basename = File.basename(test_file1)
    test_file2_basename = File.basename(test_file2)
    md_params1 = {}
    md_params2 = {}
    md_params1['content_type'] = MimeNew.for_ofc_x(test_file1)
    md_params2['content_type'] = MimeNew.for_ofc_x(test_file2)
    md_params1['file_modified'] = File.mtime(test_file1).to_s
    md_params2['file_modified'] = File.mtime(test_file2).to_s
    data1 = File.open(test_file1, 'rb') {|f| f.read}
    data2 = File.open(test_file2, 'rb') {|f| f.read}
    attachs = { test_file1_basename => {'data' => data1, 'md' => md_params1},
      test_file2_basename => {'data' => data2, 'md' => md_params2}
    }
    test_doc = @test_doc
    test_doc_id = @test_doc_id
    #test_doc_id = 'dummy_create_multiple_attachments'
    #test
    bia = BufsInfoAttachment.create_attachment_package(test_doc, attachs)
    #verify results
    test_attachment_id = test_doc_id + BufsInfoDoc.attachment_base_id
    bia['_id'].should == test_attachment_id
    bia['md_attachments'][BufsEscape.escape(test_file1_basename)]['file_modified'].should == File.mtime(test_file1).to_s
    bia['_attachments'][BufsEscape.escape(test_file1_basename)]['content_type'].should == md_params1['content_type']
    bia['md_attachments'][BufsEscape.escape(test_file2_basename)]['file_modified'].should == File.mtime(test_file2).to_s
    bia['_attachments'][BufsEscape.escape(test_file2_basename)]['content_type'].should == md_params2['content_type']
  end

  it "should add new files to an existing attachment doc" do
    #set initial conditions existing attachment
    test_file1 = @test_files['binary_data2_docx']
    test_file2 = @test_files['simple_text_file']
    test_file1_basename = File.basename(test_file1)
    test_file2_basename = File.basename(test_file2)
    md_params1 = {}
    md_params2 = {}
    md_params1['content_type'] = MimeNew.for_ofc_x(test_file1)
    md_params2['content_type'] = MimeNew.for_ofc_x(test_file2)
    md_params1['file_modified'] = File.mtime(test_file1).to_s
    md_params2['file_modified'] = File.mtime(test_file2).to_s
    data1 = File.open(test_file1, 'rb') {|f| f.read}
    data2 = File.open(test_file2, 'rb') {|f| f.read}
    attachs = { test_file1_basename => {'data' => data1, 'md' => md_params1},
      test_file2_basename => {'data' => data2, 'md' => md_params2}
    }
    #test_doc_id = 'dummy_add_new_attachments'
    test_doc = @test_doc
    test_doc_id = @test_doc_id
    bia_existing = BufsInfoAttachment.create_attachment_package(test_doc, attachs)
    test_attachment_id = test_doc_id + BufsInfoDoc.attachment_base_id
    #verify attachment exists
    bia_existing['_id'].should == test_attachment_id
    #set initial conditions for test file
    test_file = @test_files['simple_text_file2']
    test_file_modified_time = File.mtime(test_file)
    test_file_basename = File.basename(test_file)
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(test_file)
    md_params['file_modified'] = test_file_modified_time.to_s
    data = File.open(test_file, 'rb') {|f| f.read}
    attachs = {test_file_basename => {'data' => data, 'md' => md_params }}
    bia_existing = BufsInfoAttachment.get(bia_existing['_id'])
    #test
    bia_updated = bia_existing.update_attachment_package(test_doc, attachs)
    #verify results
    #p test_file_basename
    #p BufsEscape.escape(test_file_basename)
    bia_updated['_id'].should == bia_existing['_id']
    bia_updated['md_attachments'][BufsEscape.escape(test_file_basename)]['file_modified'].should == test_file_modified_time.to_s
    bia_updated['_attachments'][BufsEscape.escape(test_file_basename)]['content_type'].should == md_params['content_type']
  end

  it "should replace older attachment data with new ones, but not vice versa" do
    #set initial conditions
    test_file = @test_files['simple_text_file']
    test_file_basename = File.basename(test_file)
    test_file_modified_time = File.mtime(test_file)
    test_doc = @test_doc
    test_doc_id = @test_doc_id
    #test_doc_id = 'dummy_fresh_attachment_replaces_stale'
    test_attachment_id = test_doc_id + BufsInfoDoc.attachment_base_id
    #create a single record
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(test_file)
    md_params['file_modified'] = test_file_modified_time.to_s
    data = File.open(test_file, 'rb') {|f| f.read}
    attachs = {test_file_basename => {'data' => data, 'md' => md_params }}
    bia = BufsInfoAttachment.create_attachment_package(test_doc, attachs )
    #verify initial condition
    bia['_id'].should == test_attachment_id
    bia['md_attachments'][BufsEscape.escape(test_file_basename)]['file_modified'].should == test_file_modified_time.to_s
    bia['_attachments'][BufsEscape.escape(test_file_basename)]['content_type'].should == md_params['content_type']
    
    #set initial conditions for fresh and stale file
    stale_file = @test_files['stale_file']
    fresh_file = @test_files['fresh_file']
    stale_basename = File.basename(stale_file)
    fresh_basename = File.basename(fresh_file)
    stale_modified_time = File.mtime(stale_file)
    fresh_modified_time = File.mtime(fresh_file)
    md_params_stale = {}
    md_params_fresh = {}
    md_params_stale['content_type'] = MimeNew.for_ofc_x(stale_file)
    md_params_fresh['content_type'] = MimeNew.for_ofc_x(fresh_file)
    md_params_stale['file_modified'] = stale_modified_time.to_s
    md_params_fresh['file_modified'] = fresh_modified_time.to_s
    stale_data = File.open(stale_file, 'rb') {|f| f.read}
    fresh_data = File.open(fresh_file, 'rb') {|f| f.read}
    attachs = {stale_basename => {'data' => stale_data, 'md' => md_params_stale},
               fresh_basename => {'data' => fresh_data, 'md' => md_params_fresh}
    }
  
    #for creating, use the sid  and the method create_.... for updateing, use the sia  and the method update...
    bia_updated = BufsInfoAttachment.update_attachment_package(bia, attachs )
    #verify initial conditions
    bia_updated['_id'].should == test_attachment_id
    bia_updated['md_attachments'][BufsEscape.escape(stale_basename)]['file_modified'].should == stale_modified_time.to_s
    bia_updated['_attachments'][BufsEscape.escape(stale_basename)]['content_type'].should == md_params_stale['content_type']
    bia_updated['md_attachments'][BufsEscape.escape(fresh_basename)]['file_modified'].should == fresh_modified_time.to_s
    bia_updated['_attachments'][BufsEscape.escape(fresh_basename)]['content_type'].should == md_params_fresh['content_type']
    #if the above tests pass, then the files and database are synchronized

    sleep 1 #to put some time difference

    unstale_data = stale_data + "\n This data is only for the database"
    unstale_modified_time = Time.now.to_s
    #puts "Unstale Mod Time (db is more recent): #{unstale_modified_time}"
    unstale_content_type = 'text/plain;unstale'
    unstale_params = {'file_modified' => unstale_modified_time, 'content_type' => unstale_content_type}
    unstale_attach = { BufsEscape.escape(stale_basename) => {'data' => unstale_data, 'md'=> unstale_params } }

    BufsInfoAttachment.update_attachment_package(bia, unstale_attach)
    #database should now have more recent information for @stale_basename

    sleep 1 #to put some time difference
    #puts "Fresh File Mod Time (file is more recent): #{File.mtime(@fresh_file)}"

    File.open(fresh_file, 'a'){|f| f.write("\n This data is only for the file")}
    #puts "Fresh File Mod Time (file is more recent): #{File.mtime(@fresh_file)}"
    #file should now have more recent information for @fresh_basename

    #try and update again with both files
    md_params_stale2 = {}
    md_params_fresh2 = {}
    md_params_stale2['content_type'] = MimeNew.for_ofc_x(stale_file)
    fresh_content_type = 'text/plain;fresh'
    md_params_fresh2['content_type'] = fresh_content_type #MimeNew.for_ofc_x(@fresh_file)
    md_params_stale2['file_modified'] = File.mtime(stale_file).to_s
    fresh_modified_time = File.mtime(fresh_file).to_s
    md_params_fresh2['file_modified'] = fresh_modified_time
    stale_data2 = File.open(stale_file, 'rb') {|f| f.read}
    fresh_data2 = File.open(fresh_file, 'rb') {|f| f.read}
    attachs = {BufsEscape.escape(stale_basename) => {'data' => stale_data2, 'md' => md_params_stale2},
      BufsEscape.escape(fresh_basename) => {'data' => fresh_data2, 'md' => md_params_fresh2}
    }
    #test
    new_bia = BufsInfoAttachment.get(bia['_id'])
    fresh_bia = BufsInfoAttachment.update_attachment_package(new_bia, attachs )

    #verify results
    #db should have fresh file, but not stale one (and maintain older db attachment)
    fresh_bia['_id'].should == test_attachment_id
    fresh_bia['md_attachments'][BufsEscape.escape(stale_basename)]['file_modified'].should == unstale_modified_time
    fresh_bia['_attachments'][BufsEscape.escape(stale_basename)]['content_type'].should == unstale_content_type
    fresh_bia['md_attachments'][BufsEscape.escape(fresh_basename)]['file_modified'].should == fresh_modified_time
    fresh_bia['_attachments'][BufsEscape.escape(fresh_basename)]['content_type'].should == fresh_content_type
  end

  it "should combine all attachment metadata when it is retrieved" do
    #set initial conditions
    test_file1 = @test_files['binary_data2_docx']
    test_file2 = @test_files['simple_text_file']
    test_file1_basename = File.basename(test_file1)
    test_file2_basename = File.basename(test_file2)
    test_file1_modified_time = File.mtime(test_file1)
    test_file2_modified_time = File.mtime(test_file2)
    md_params1 = {}
    md_params2 = {}
    md_params1['content_type'] = MimeNew.for_ofc_x(test_file1)
    md_params2['content_type'] = MimeNew.for_ofc_x(test_file2)
    md_params1['file_modified'] = test_file1_modified_time.to_s
    md_params2['file_modified'] =  test_file2_modified_time.to_s
    data1 = File.open(test_file1, 'rb') {|f| f.read}
    data2 = File.open(test_file2, 'rb') {|f| f.read}
    attachs = {test_file1_basename => {'data' => data1, 'md' => md_params1},
               test_file2_basename => {'data' => data2, 'md' => md_params2}
              }
    test_doc = @test_doc
    test_doc_id = test_doc['_id']
    test_attachment_id = test_doc_id + BufsInfoDoc.attachment_base_id
    test_attachment = BufsInfoAttachment.get(test_attachment_id)
    bia = BufsInfoAttachment.create_attachment_package(test_doc, attachs)
    data = BufsInfoAttachment.get_attachments(bia)
    #puts "SIA data: #{data.inspect}"
    data[BufsEscape.escape(test_file1_basename)]['file_modified'].should == test_file1_modified_time.to_s
    data[BufsEscape.escape(test_file1_basename)]['content_type'].should == MimeNew.for_ofc_x(test_file1)
  end
end
=end

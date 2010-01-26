require 'spec'
require 'couchrest'

require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'

#TODO change to bufs.younghawk.org
#doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!

module BufsAttachSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end

#ProjectLocation = '/media-ec2/ec2a/projects/bufs/'
#TestFileLocation = ProjectLocation + 'sandbox_for_specs/attachment_specs/'

#SrcLocation = ProjectLocation + 'src/'

require BufsAttachSpec::LibDir + 'bufs_info_doc'
require BufsAttachSpec::LibDir+ 'bufs_info_attachment'

BufsInfoAttachment.set_name_space(CouchDB)

describe BufsInfoAttachment do
  before(:all) do
    #bufs_fixtures set up test files
    #file identities (fyi ... verify in fixture file or FixDB)
    # simple_text_file
    # binary_data_pptx
    # binary_data2_docx
    # binary_data3_pptx
    # binary_data_spaces_in_fname_pptx
    # stale_file
    # fresh_file
    @test_files = BufsFixtures.test_files
    #@file_basename1 = 'spec_test1.pptx'
    #@file_basename2 = "spec test2.docx"
    #@file_basename3 = 'simple_text_file1.txt'
    #@stale_basename = 'test_modified_time_stale.txt'
    #@fresh_basename = 'test_modified_time_fresh.txt'
    @test_id1 = 'binary_data_pptx'
    @test_id2 = 'binary_data2_docx'
    @test_id3 = 'simple_text_file'
    @stale_id = 'stale_file'
    @fresh_id = 'fresh_file'
    @test_file1 = @test_files[@test_id1]
    @test_file2 = @test_files[@test_id2]
    @test_file3 = @test_files[@test_id3]
    @stale_file = @test_files[@stale_id]
    @fresh_file = @test_files[@fresh_id]
    @file_basename1 = File.basename(@test_file1)
    @file_basename2 = File.basename(@test_file2)
    @file_basename3 = File.basename(@test_file3)
    @stale_basename = File.basename(@stale_file)
    @fresh_basename = File.basename(@fresh_file)
    @file_modified_time1 = File.mtime(@test_files['binary_data_pptx'])
    @file_modified_time2 = File.mtime(@test_files['binary_data2_docx'])
    @file_modified_time3 = File.mtime(@test_files['binary_data3_pptx'])
    @stale_modified_time = File.mtime(@test_files['stale_file'])
    @fresh_modified_time = File.mtime(@test_files['fresh_file'])
    @test_bid_id = 'fake_bid_id'
    @bia_id = @test_bid_id + BufsInfoDoc.attachment_base_id
  end

  after(:all) do
    if CouchDB.documents.size > 10
      CouchDB.delete!
    end
  end

  it "should create object and update the database with a single attachment if there is no other doc in database" do
    #clear out any lingering attachment documents in the database
    BufsInfoAttachment.all.each do |doc|
      doc.destroy
    end
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(@test_file1)
    md_params['file_modified'] = @file_modified_time1.to_s
    data = File.open(@test_file1, 'rb') {|f| f.read}
    attachs = {@file_basename1 => {'data' => data, 'md' => md_params }}
    bia = BufsInfoAttachment.create_attachment_package(@test_bid_id, attachs )
    bia['_id'].should == @bia_id
    p bia
    bia['md_attachments'][@file_basename1]['file_modified'].should == @file_modified_time1.to_s
    bia['_attachments'][CGI.escape(@file_basename1)]['content_type'].should == md_params['content_type']
  end

end #temporary delete with =begin
=begin
  it "should create multiple attachments in one update" do
    ScoutInfoAttachment.all.each do |doc|
      doc.destroy
    end
    md_params1 = {}
    md_params2 = {}
    md_params1['content_type'] = MimeNew.for_ofc_x(@test_file1)
    md_params2['content_type'] = MimeNew.for_ofc_x(@test_file2)
    md_params1['file_modified'] = @file_modified_time1.to_s
    md_params2['file_modified'] =  @file_modified_time2.to_s
    data1 = File.open(@test_file1, 'rb') {|f| f.read}
    data2 = File.open(@test_file2, 'rb') {|f| f.read}
    attachs = {@file_basename1 => {'data' => data1, 'md' => md_params1},
      @file_basename2 => {'data' => data2, 'md' => md_params2}
    }
    sia = ScoutInfoAttachment.create_attachment_package(@test_sid_id, attachs )
    sia['_id'].should == @sia_id
    sia['md_attachments'][@file_basename1]['file_modified'].should == @file_modified_time1.to_s
    p sia['_attachments'][CGI.escape(@file_basename1)]
    sia['_attachments'][CGI.escape(@file_basename1)]['content_type'].should == md_params1['content_type']
    sia['md_attachments'][@file_basename2]['file_modified'].should == @file_modified_time2.to_s
    sia['_attachments'][CGI.escape(@file_basename2)]['content_type'].should == md_params2['content_type']
  end

  it "should add new files to an existing attachment doc" do
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(@test_file3)
    md_params['file_modified'] = @file_modified_time3.to_s
    data = File.open(@test_file3, 'rb') {|f| f.read}
    attachs = {@file_basename3 => {'data' => data, 'md' => md_params }}
    sia = ScoutInfoAttachment.get(@sia_id)
    updated_sia = sia.update_attachment_package(attachs)
    #p updated_sia
    updated_sia['_id'].should == @sia_id
    updated_sia['md_attachments'][@file_basename3]['file_modified'].should == @file_modified_time3.to_s
    updated_sia['_attachments'][@file_basename3]['content_type'].should == md_params['content_type']
  end

  it "should replace older attachment data with new ones, but not vice versa" do
    ScoutInfoAttachment.all.each do |doc|
      doc.destroy
    end

    #create a single record
    md_params = {}
    md_params['content_type'] = MimeNew.for_ofc_x(@test_file3)
    md_params['file_modified'] = @file_modified_time3.to_s
    data = File.open(@test_file3, 'rb') {|f| f.read}
    attachs = {@file_basename3 => {'data' => data, 'md' => md_params }}
    sia = ScoutInfoAttachment.create_attachment_package(@test_sid_id, attachs )
    sia['_id'].should == @sia_id
    sia['md_attachments'][@file_basename3]['file_modified'].should == @file_modified_time3.to_s
    sia['_attachments'][@file_basename3]['content_type'].should == md_params['content_type']
    

    md_params_stale = {}
    md_params_fresh = {}
    md_params_stale['content_type'] = MimeNew.for_ofc_x(@stale_file)
    md_params_fresh['content_type'] = MimeNew.for_ofc_x(@fresh_file)
    md_params_stale['file_modified'] = File.mtime(@stale_file).to_s
    md_params_fresh['file_modified'] = File.mtime(@fresh_file).to_s
    stale_data = File.open(@stale_file, 'rb') {|f| f.read}
    fresh_data = File.open(@fresh_file, 'rb') {|f| f.read}
    attachs = {@stale_basename => {'data' => stale_data, 'md' => md_params_stale},
      @fresh_basename => {'data' => fresh_data, 'md' => md_params_fresh}
    }
    #for creating, use the sid id and the method create_.... for updateing, use the sia id and the method update...
    sia = ScoutInfoAttachment.update_attachment_package(@sia_id, attachs )
    #p sia
    sia['_id'].should == @sia_id
    sia['md_attachments'][@stale_basename]['file_modified'].should == @stale_modified_time.to_s
    sia['_attachments'][@stale_basename]['content_type'].should == md_params_stale['content_type']
    sia['_id'].should == @sia_id
    sia['md_attachments'][@fresh_basename]['file_modified'].should == @fresh_modified_time.to_s
    sia['_attachments'][@fresh_basename]['content_type'].should == md_params_fresh['content_type']
    #if the above tests pass, then the files and database are synchronized

    sleep 1 #to put some time difference

    unstale_data = stale_data + "\n This data is only for the database"
    unstale_modified_time = Time.now.to_s
    #puts "Unstale Mod Time (db is more recent): #{unstale_modified_time}"
    unstale_content_type = 'text/plain;unstale'
    unstale_params = {'file_modified' => unstale_modified_time, 'content_type' => unstale_content_type}
    unstale_attach = { @stale_basename => {'data' => unstale_data, 'md'=> unstale_params } }
    ScoutInfoAttachment.update_attachment_package(@sia_id, unstale_attach)
    #database should now have more recent information for @stale_basename

    sleep 1 #to put some time difference
    #puts "Fresh File Mod Time (file is more recent): #{File.mtime(@fresh_file)}"
    File.open(@fresh_file, 'a'){|f| f.write("\n This data is only for the file")}
    #puts "Fresh File Mod Time (file is more recent): #{File.mtime(@fresh_file)}"
    #file should now have more recent information for @fresh_basename

    #try and update again with both files
    md_params_stale2 = {}
    md_params_fresh2 = {}
    md_params_stale2['content_type'] = MimeNew.for_ofc_x(@stale_file)
    fresh_content_type = 'text/plain;fresh'
    md_params_fresh2['content_type'] = fresh_content_type #MimeNew.for_ofc_x(@fresh_file)
    md_params_stale2['file_modified'] = File.mtime(@stale_file).to_s
    fresh_modified_time = File.mtime(@fresh_file).to_s
    md_params_fresh2['file_modified'] = fresh_modified_time
    stale_data2 = File.open(@stale_file, 'rb') {|f| f.read}
    fresh_data2 = File.open(@fresh_file, 'rb') {|f| f.read}
    attachs = {@stale_basename => {'data' => stale_data2, 'md' => md_params_stale2},
      @fresh_basename => {'data' => fresh_data2, 'md' => md_params_fresh2}
    }
    updated_sia = ScoutInfoAttachment.update_attachment_package(@sia_id, attachs )

    #db should have fresh file, but not stale one (and maintain older db attachment)
    updated_sia['_id'].should == @sia_id
    updated_sia['md_attachments'][@stale_basename]['file_modified'].should == unstale_modified_time
    updated_sia['_attachments'][@stale_basename]['content_type'].should == unstale_content_type
    updated_sia['md_attachments'][@fresh_basename]['file_modified'].should == fresh_modified_time
    updated_sia['_attachments'][@fresh_basename]['content_type'].should == fresh_content_type
  end


  it "should combine all attachment metadata when it is retrieved" do
    ScoutInfoAttachment.all.each do |doc|
      doc.destroy
    end
    md_params1 = {}
    md_params2 = {}
    md_params1['content_type'] = MimeNew.for_ofc_x(@test_file1)
    md_params2['content_type'] = MimeNew.for_ofc_x(@test_file2)
    md_params1['file_modified'] = @file_modified_time1.to_s
    md_params2['file_modified'] =  @file_modified_time2.to_s
    data1 = File.open(@test_file1, 'rb') {|f| f.read}
    data2 = File.open(@test_file2, 'rb') {|f| f.read}
    attachs = {@file_basename1 => {'data' => data1, 'md' => md_params1},
               @file_basename2 => {'data' => data2, 'md' => md_params2}
              }

    sia = ScoutInfoAttachment.create_attachment_package(@test_sid_id, attachs )
    uniq_id = @sia_id  #TODO Put better test procedures, not this hack
    data = ScoutInfoAttachment.get_attachments(uniq_id)
    #puts "SIA data: #{data.inspect}"
    data[@file_basename1]['file_modified'].should == @file_modified_time1.to_s
    data[@file_basename1]['content_type'].should == MimeNew.for_ofc_x(@test_file1)
  end

end
=end

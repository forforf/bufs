#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../lib/helpers/require_helper')

require Bufs.helpers 'filesystem_helpers'

require 'fileutils'

describe DirFilter do
  before(:each) do
    root_test_dir = '/tmp'
    working_dir = 'dir_filter_tests'
    @basenames_to_make = ['keep1', 
                                        'keep2', 
                                        '.dot_file', 
                                        'ignore_this_file', 
                                        'ignore_this_file_too',
                                        'another_file_to_ignore',
                                        'skip_this_one_too',
                                        'but_dont_skip_this_one']
                
    @working_path = File.join(root_test_dir, working_dir)
    @files_to_make = @basenames_to_make.map{|b| File.join(@working_path, b)}
    #create directory for tests
    FileUtils.mkdir_p(@working_path)
    FileUtils.touch(@files_to_make)
  end
  
  after(:each) do
    FileUtils.rm_rf(@working_path)
  end
  
  it "should have made files to test with" do
    expected_entries = @basenames_to_make + [".", ".."]
    Dir.entries(@working_path).sort.should == expected_entries.sort
  end
  
  it "should filter appropriate entries" do
    filter = DirFilter.new([/ignore/, /^skip/])
    filter.filter_entries(@working_path).sort.should == ['but_dont_skip_this_one', 'keep1', 'keep2']
  end
  
end
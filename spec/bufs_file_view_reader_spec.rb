#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../lib/helpers/require_helper')

#require Bufs.spec_helpers 'bufs_sample_dataset'
require Bufs.lib 'bufs_file_view_maker'
require Bufs.spec 'bufs_file_view_maker_spec'

#BFVRBaseDir = "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/bufs_file_view_maker_spec/"

#TODO: Combine view reader and view maker spec since the reader spec is dependent upon the maker spec
#currently just requiring the maker spec, which is not intuitive


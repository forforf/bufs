require "fileutils"

dirs_to_clean = ["/media-ec2/ec2a/projects/bufs/sandbox_for_specs/bufs_file_view_maker_spec/SampleCouchUser001",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/bufs_file_view_maker_spec/SampleCouchUser002",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/sample_data/SampleFileSysUser003/aa",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/sample_data/SampleFileSysUser003/b",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/sample_data/SampleFileSysUser003/c",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/sample_data/SampleFileSysUser004/aa",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/sample_data/SampleFileSysUser004/b",
                 "/media-ec2/ec2a/projects/bufs/sandbox_for_specs/sample_data/SampleFileSysUser004/c"]

dirs_to_clean.each do |dir|
  FileUtils.rm_rf(dir)
end


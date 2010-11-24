require 'rake'
require 'spec/rake/spectask'

task :default => ['specs_with_rcov']

#task :specs => ['spec_set_1', 'spec_set_3', 'spec_set_4']


#Tests that fail in rake but work standalone
spec_set_0 = ['spec/bufs_escape_spec.rb']

#fixture tests
spec_set_1 = ['spec/couchdb_running_spec.rb', 
              'spec/bufs_sample_dataset_spec.rb']

#data structure tests (currently not working)
spec_set_2 = ['spec/node_element_operations_spec.rb']

#model tests for multi-user
spec_set_3 = ['spec/bufs_node_factory_spec.rb']

#model tests for single-user (these will fail under multi-user scenarios)
spec_set_3a = ['spec/couchrest_attachment_handler_spec.rb',
              'spec/bufs_base_node_spec.rb',
              #'spec/node_element_operations_spec.rb',
              'spec/bufs_couchrest_spec.rb',
              'spec/bufs_filesystem_spec.rb']

#graphing tests
spec_set_4 = ['spec/grapher_spec.rb',
              'spec/bufs_jsvis_data_spec.rb']

#file system conversion tests
spec_set_5 = ['spec/bind_user_file_system_spec.rb',
              'spec/bufs_file_view_actions_spec.rb']

desc "Run Specs with RCov"
  Spec::Rake::SpecTask.new('specs_with_rcov') do |t|
    t.spec_files = spec_set_1 + spec_set_3 + spec_set_4 + spec_set_5

    t.rcov = true
    #t.rcov_opts = ['--exclude', 'examples']
  end

desc "Run troublesome specs"
  Spec::Rake::SpecTask.new('spec_set_2') do |t|
    t.spec_files = spec_set_2
    t.rcov = false
  end


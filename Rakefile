require 'rake'
require 'spec/rake/spectask'

task :default => ['specs_with_rcov']

task :specs => ['spec_set_1', 'spec_set_2', 'spec_set_3']


#Tests that fail in rake but work standalone
spec_set_0 = ['spec/bufs_escape_spec.rb']

#fixture tests
spec_set_1 = ['spec/couchdb_running_spec.rb', 
              'spec/bufs_sample_dataset_spec.rb']

#model tests
spec_set_2 = [#'spec/couchrest_attachment_handler_spec.rb',
              #'spec/bufs_base_node_spec.rb',
              #'spec/node_element_operations_spec.rb',
              #'spec/bufs_couchrest_spec.rb',
              #'spec/bufs_filesystem_spec.rb',
              'spec/bufs_node_factory_spec.rb']

#ui integration tests
spec_set_3 = ['spec/grapher_spec.rb',
              'spec/bufs_jsvis_data_spec.rb']

spec_set_4 = ['spec/bufs_view_builder_spec.rb']

desc "Run Specs with RCov"
  Spec::Rake::SpecTask.new('specs_with_rcov') do |t|
    t.spec_files = spec_set_1 + spec_set_2 + spec_set_3

    t.rcov = true
    #t.rcov_opts = ['--exclude', 'examples']
  end

desc "Run troublesome specs"
  Spec::Rake::SpecTask.new('spec_set_1') do |t|
    t.spec_files = spec_set_1
    t.rcov = false
  end

desc "Run troublesome specs"
  Spec::Rake::SpecTask.new('spec_set_2') do |t|
    t.spec_files = spec_set_2
    t.rcov = false
  end

desc "Run troublesome specs"
  Spec::Rake::SpecTask.new('spec_set_3') do |t|
    t.spec_files = spec_set_3
    t.rcov = false
  end


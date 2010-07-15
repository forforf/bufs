require 'rake'
require 'spec/rake/spectask'

task :default => ['specs_with_rcov']

task :specs => ['spec_set_1', 'spec_set_2', 'spec_set_3']


#rake fails when running spec/abstract_node_spec.rb (but the spec works standalone)
spec_set_0 = ['spec/bufs_escape_spec.rb']

spec_set_1 = ['spec/bufs_escape_spec.rb',
              'spec/bufs_info_attachment_spec.rb',
              'spec/bufs_info_doc_spec.rb',
              'spec/bufs_file_system_spec.rb',
              'spec/user_doc_spec.rb',
              'spec/user_file_node_spec.rb',
              'spec/convert_node_type_spec.rb',
              'spec/bind_user_file_system_spec.rb']

spec_set_2 = [#'spec/abstract_node_spec.rb',
              'spec/sync_node_spec.rb']

spec_set_3 = ['spec/abstract_node_spec.rb']

desc "Run Specs with RCov"
  Spec::Rake::SpecTask.new('specs_with_rcov') do |t|
    t.spec_files = spec_set_1

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


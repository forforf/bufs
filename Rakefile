require 'rake'
require 'spec/rake/spectask'

task :default => ['specs_with_rcov']


#rake fails when running spec/abstract_node_spec.rb (but the spec works standalone)
desc "Run Specs with RCov"
Spec::Rake::SpecTask.new('specs_with_rcov') do |t|
  t.spec_files = ['spec/bufs_escape_spec.rb',
                  'spec/bufs_info_attachment_spec.rb',
                  'spec/bufs_info_doc_spec.rb'
                   ] #FileList['examples/**/*.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'examples']
end

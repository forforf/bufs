#The specs in this rake file deal only with the core
#bufs libraries

require 'rake'
require 'spec/rake/spectask'


#Allows clearing of the task environment
class Rake::Task
  def abandon
    @actions.clear
  end
end
#task :default => ['specs_with_rcov']

#Tests that fail in rake but work standalone
spec_set_0 = ['spec/bufs_escape_spec.rb']

#fixture tests
spec_set_1 = ['spec/couchdb_running_spec.rb', 
              'spec/bufs_sample_dataset_spec.rb']

#data structure tests (currently not working)
spec_set_2 = ['spec/node_element_operations_spec.rb']

#model tests for multi-user
spec_set_3 = ['spec/bufs_node_factory_spec.rb']

#These tests would share common variable namespaces
#and will clobber each other if ran in a common environment
spec_set_3aa = ['spec/couchrest_attachment_handler_spec.rb']
              #'spec/bufs_base_node_spec.rb',
spec_set_3a =  [ 'spec/bufs_couchrest_spec.rb']

spec_set_3b = ['spec/bufs_filesystem_spec.rb']

#Set up rake specs by spec sets"
spec_sets = { "spec_set_0" => spec_set_0, 
              "spec_set_1" => spec_set_1,
              "spec_set_2" => spec_set_2,
              "spec_set_3" => spec_set_3,
              "spec_set_3a"=> spec_set_3a,
              "spec_set_3aa"=>spec_set_3aa,
              "spec_set_3b"=> spec_set_3b
            }
              

#creates spec task spec_set_##
spec_sets.each do |name, set|
  desc "Run  #{name}"
     Spec::Rake::SpecTask.new(name) do |t|
        puts "Creating set: #{name}"
        t.spec_files = spec_sets[name]
        t.rcov = false
     end
end
      

desc "Runs all specs in their environments and continues if error is encountered" 
task :spec_sets do
  spec_sets.each do |name, set|
    puts "Running Test on #{name}"
    begin
      Rake::Task[name].invoke
    rescue => e
      puts "Rake Task #{name} Failed" 
      puts "Error message: #{e.inspect}"
      #puts "Trace:\n #{e.backtrace}"
      puts "Moving on to next set"
      next
    end
    puts "Clearing Task"
    Rake::Task[name].abandon
  end
end

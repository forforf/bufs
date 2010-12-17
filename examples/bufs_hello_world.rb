require '../lib/bufs'  #<-- to be replaced by gem

# First we need to describe the environment for bufs
# we will use the file system as our persistend stoe and
# the default data model to simplify things a bit.
env = {:node_class_id => "HelloWorldClass",
       :persist_model => {
         :name => "filesystem",
         :key_fields => {
           :required_keys => [:id],
           :primary_key => :id,
         },
         :env => {
           :user_id => "me",
           :path => "/tmp/bufs_hello_world_test/"
         }
       }
}

MyNodeClass = BufsNodeFactory.make(env)
hello_world_node = MyNodeClass.new( {:id => 'hw_id', :data => "Hello World"} )

#to see your node's data, just call the fields as a method call
p hello_world_node.id
p hello_world_node.data
#to save your node to the data store
hello_world_node.__save

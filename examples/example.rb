require '../lib/bufs'  #<-- eventually will be gem 'bufs'
#require '../lib/moabs/moab_couchrest_env'
#equire '../lib/glue_envs/bufs_couchrest_glue_env'
#require '../lib/midas/node_element_operations'

#We need to define the datastructure we'll be starting with.  We can change it dynamically as well,
#but it is usually helpful to have a defined base to start from

#TODO: Make the appropriate helpers to assist in this
#TODO: define_method might work better, or maybe even just def

#What does this do and why is it needed?
#I wanted something that:
#   - would have Class like methods for collections ala Rails
#   - have the persistence layer be defined dynamically during run-time
#   - be portable across multiple persistence layers
#       -corollary: portability can be dynamic as well (#though not implemented yet)
#   - support multiple users
#   - support customized operations on its data structures
#None of the existing frameworks that I knew of did all of these, so that led to this one

#Thinking about things slightly different
#Define a data structure independent of any underlying model

#TODO: Move these into the main libs.
#Currently spec helpers, but should be part of main lib
#and then removed from specs as helpers, but add specs
#to test them
module NodeHelper
  def self.env_builder(model_name, node_class_id, user_id, path, host = nil)
        #binding data (note this occurs in two different places in the env)
    
    key_fields = {:required_keys => [:id],
                         :primary_key => :id }


    #data model
    field_op_set =nil
    #op_set_mod => <Using default definitions>
    
    data_model = {:field_op_set => field_op_set, :key_fields => key_fields, :views => nil}
    
    #persistence layer model
    pmodel_env = { :host => host,
                          :path => path,
                          :user_id => user_id}
    persist_model = {:name => model_name, :env => pmodel_env}
    
    #final env model
    env = { :node_class_id => node_class_id,
                :data_model => data_model,
                :persist_model => persist_model }
  end
end


#If you have CouchRest:
  #Lets create a couchrest instance to interface to our CouchDB
  require 'couchrest'
  example_couchdb_location = "http://127.0.0.1:5984/example/"
  #example_couchdb_location = "http://bufs.couchone.com/example"
  couchrest_instance = CouchRest.database!(example_couchdb_location)
  
  #while we're at it, lets create a filesystem store as well
  filestore_loc = "/tmp/bufs_test/"

  couch_class_id = :CouchClass
  file_class_id = :FileClass
  sdbs3_class_id = :SdbS3Class
  user_id = "Me"
  
  cr_path = couchrest_instance.uri
  cr_host = couchrest_instance.host
  
  fs_path = filestore_loc
  
  sdbs3_path = "MyDomain"
  #filesystem doesn't require host
  #building the couchrest environment
  couch_env = NodeHelper.env_builder("bufs_couchrest", couch_class_id, user_id, cr_path, cr_host)
  
  #building the filesystem environment
  filesys_env = NodeHelper.env_builder("bufs_filesystem", file_class_id, user_id, fs_path)
  #p couch_env
  
  #building an environment for AWS (Simple DB for data, S3 for attachments)
  sdbs3_env = NodeHelper.env_builder("sdb_s3", sdbs3_class_id, user_id, sdbs3_path)
  
  #Testing with Class for NodeElementOperations
  #node_ops = NewNodeElementOperations.new.data_ops
  
  #In the future you won't need seperate classes for the models.
  
  ExampleCouchClass = BufsNodeFactory.make(couch_env)
  ExampleFileClass = BufsNodeFactory.make(filesys_env)
  ExampleSdbS3Class = BufsNodeFactory.make(sdbs3_env)
  a_couch_node = ExampleCouchClass.new({:id => "My_ID1", :data => "Hello World from couchrest"})
  
  
  a_file_node = ExampleFileClass.new({:id => "My_ID2", :data =>"Hello World from filesystem" })
  
  a_sdbs3_node = ExampleSdbS3Class.new({:id => "My_ID2", :data =>"Hello World from AWS Simple DB (with S3 for files)" })
  puts "Nodes in memory"
  p a_couch_node._user_data
  p a_file_node._user_data
  p a_sdbs3_node._user_data
  
  a_couch_node.__save 
  a_file_node.__save
  a_sdbs3_node.__save
  
  puts "Node in CouchDB"
  #p hello_world_node
  p couchrest_instance.get(a_couch_node._model_metadata[:_id])
  puts
  puts "Or you can get the couch node from the command line using curl:"
  puts "curl -X GET #{example_couchdb_location}/#{CGI.escape(a_couch_node._model_metadata[:_id])}"
  puts
  puts "The file data should be at (look for .node_data.json)"
  puts "ls -al #{File.join(a_file_node._model_metadata[:files_namespace], a_file_node._user_data[:id])}/"
  puts "We can also add a field dynamically, for example a \"tags\" field"
  puts "Node after dynamically adding new data element"
  puts 
  
  #after this hello_world node is the same as a couch node
  hello_world_node = a_couch_node
  hello_world_node.__set_userdata_key(:tags, ["tag1", "tag2"])
  p hello_world_node._user_data
  puts "You don't have to add a field defined in the element operations"
  puts "the \"random_field\" will behave (how? what is the default behavior?"
  #TODO, if no value provided, default to nil (no reason to force user to set it)
  #TODO: Raise an appropriate error if an operation tag is left off (add, subtract, etc)
  #TODO: Provide a default operation set for unspecified tags
  #TODO: Also allow user to set the default  operation to use for undefined tags
  hello_world_node.__set_userdata_key(:random_field, nil)
  #p hello_world_node._user_data
  puts
  puts "Node Element Operations in action"
  puts "Lets Add \"WontAdd\" to the :id field"
  puts "and \"A New Hello World\" to the :data field"
  puts "and \"tag3\" to the tags field"
  hello_world_node.id_add "WontAdd"
  #p hello_world_node
  hello_world_node.data_add "A New Hello World"
  hello_world_node.tags_add "tag3"
  
  #this was testing wrong op names
  #p hello_world_node.tags_blue "taggity tag"
  #p hello_world_node.tagssss
  
  #"We can't add  \"random\" to the random_field field until we define the operation"
  #Is this fixed yet?
  random_op = {:random_field => :replace_ops}
  
  #p hello_world_node.class.data_struc
  hello_world_node.class.data_struc.set_op(random_op)
  hello_world_node.__set_userdata_key(:random_field, nil)
  #p hello_world_node.class.data_struc
  hello_world_node.random_field_add "random"
  p hello_world_node._user_data
  
  puts "Calling views (filtering records)"
  p hello_world_node.class.call_new_view(:id, "My_ID1")
  p a_file_node.class.call_new_view(:data, "Hello World from filesystem")

  
  puts "Ok, now lets subtract (later)"

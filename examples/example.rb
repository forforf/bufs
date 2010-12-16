require '../lib/bufs_node_factory'  #<-- eventually will be gem 'bufs'
require '../lib/moabs/moab_couchrest_env'
require '../lib/glue_envs/bufs_couchrest_glue_env'
require '../lib/midas/node_element_operations'

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

    #TODO: Can't use default key fields due to dependency with model
    #key_fields = nil #it will use default
    
    #data model
    field_op_set =nil
    #op_set_mod => <Using default definitions>
    
    data_model = {:field_op_set => field_op_set, :key_fields => key_fields}
    
    #persistence layer model
    pmodel_env = { :host => host,
                          :path => path,
                          :user_id => user_id}
    persist_model = {:name => model_name, :env => pmodel_env, :key_fields => key_fields}
    
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

  #TODO: Verify whether db_user_id is required, or whether its derived already.
  #TODO: It might be better if the node_class_id should be defaulted to the user name (or derivative)
  node_class_id = :MyExample
  reqs = nil #we aren't using an external file to hold the modules to be included
  
  #changing default configuration
  #incls = nil #[ExampleDataStructure]  #nil uses default

  #include NodeElementOperations
  # this allows us to call the different defined operations
  #This is the default
  #NodeElementOperations.configuration =  {:id => :static_ops, :data => :replace_ops }
  # used to be {:id => StaticFieldOps, :label => ReplaceFieldOps , :tags => ListFieldOps, :kvps=> KVListOps} 
  #set custom node operations 
  
  #incls = {:id => StaticFieldOps, :label => ReplaceFieldOps, :tags => ListFieldOps, :kvps=> KVListOps} 
  incls = {:field_ops_map =>{:id => :static_ops, 
                                         :label => :replace_ops, 
                                         :tags => :list_ops, 
                                         :kvps => :key_value_ops}
              #:field_ops_def_mod => nil }
            }
  user_id = "Me"
  path = couchrest_instance.uri
  host = couchrest_instance.host
  couch_env = NodeHelper.env_builder("couchrest", node_class_id, user_id, path, host)
  #p couch_env
  
  #Testing with Class for NodeElementOperations
  #node_ops = NewNodeElementOperations.new.data_ops
  
  
  ExampleClass = BufsNodeFactory.make(couch_env)
  hello_world_node = ExampleClass.new({:id => "My ID", :data => "Hello World"})
  hello_world_node.__save
  
  puts "Node in memory"
  p hello_world_node._user_data
  puts "Node in CouchDB"
  #p hello_world_node
  p couchrest_instance.get(hello_world_node._model_metadata[:_id])
  puts
  puts "Or you can test it from the command line using curl:"
  puts "curl -X GET #{example_couchdb_location}/#{CGI.escape(hello_world_node._model_metadata[:_id])}"
  puts
  puts "We can also add a field dynamically, for example a \"tags\" field"
  puts "Node after dynamically adding new data element"
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
  
  puts "We can't add  \"random\" to the random_field field until we define the operation"
  random_op = {:random_field => :replace_ops}
  
  #p hello_world_node.class.data_struc
  hello_world_node.class.data_struc.set_op(random_op)
  hello_world_node.__set_userdata_key(:random_field, nil)
  #p hello_world_node.class.data_struc
  hello_world_node.random_field_add "random"
  p hello_world_node._user_data
  puts
  
  puts "Ok, now lets subtract (later)"

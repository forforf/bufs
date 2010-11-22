require '../lib/bufs_node_factory'  #<-- eventually will be gem 'bufs'


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
module ExampleDataStructure
  #We define a field that cannot be modified  #TODO: can this be defaulted??
  StaticFieldAddOp = lambda{|this, other| Hash[:update_this => this] }
  StaticFieldSubtractOp = lambda{|this, other| Hash[:update_this => this]}
  StaticFieldOps = {:add => StaticFieldAddOp, :subtract => StaticFieldSubtractOp}
  
  #We define a field where adding will replace the existing value for that field, and subtracting a matching value will set the value to nil
  ReplaceFieldAddOp = lambda {|this, other|
                                this = other 
                                Hash[:update_this => this]
                           }
                           
  ReplaceFieldSubtractOp = lambda {|this, other|
                                        this = nil if (this == other)
                                        Hash[:update_this => this]
                                  }
                                  
  ReplaceFieldOps = {:add => ReplaceFieldAddOp, :subtract => ReplaceFieldSubtractOp}
  #We define a field where adding will add the value to the existing list, and subtracting will remove matching values from the list
  ListFieldAddOp = lambda {|this,other|
                           this = this || []
                           other = other || []
                           this = this + [other].flatten
                           this.uniq!; this.compact!
                           Hash[:update_this => this]
                         }
                         
  ListFieldSubtractOp = lambda {|this,other| 
                                this = [this] || []
                                other = [other] || []
                                this.flatten!
                                other.flatten!
                                this -= other
                                this.uniq!
                                this.compact!
                                Hash[:update_this => this]
                               }
  ListFieldOps = {:add => ListFieldAddOp, :subtract => ListFieldSubtractOp}
  
  #A bit more complicated is if we have a field that holds key-value pairs, but we want our operations
  #to operate on the underlying values of the key-value pair, and not on the actual key value sets.
  #Here the values are a list type.  What happens is if an existing key is passed, the value is added to the 
  #set of values for the existing key.  If a new key is passed, the new key and its value are added to the list
  KVListValAddOp = lambda {|this, other|
                                 this = this || {}  
                                 other = other || {}
                                 okeys = other.keys
                                 okeys.each {|k| if this[k]
                                                    this[k] = [this[k] ].flatten + [ other[k] ].flatten
                                                  else
                                                    this[k] = [ other[k] ].flatten
                                                  end 
                                                  this[k].uniq!
                                                  this[k].compact! 
                                                  Hash[:update_this => this] }
                                      }
                                                  
  KVListValSubtractOp = lambda {|this, other|
                                                  this = this || {}
                                                  #Hacked together needs thought out (and TESTED!!)
                                                  other = other || {}
                                                  puts "This / Other: #{this.inspect} / #{other.inspect}"
                                                  #srcs = [other].flatten
                                                  other.keys.each do |k|
                                                      #other[s].each {|olnk| this[k].delete(olnk) if this[k]}
                                                      puts "delete #{other[k].inspect} from #{this[k].inspect}"
                                                      #this[k].delete(other[k]) if this[k]
                                                      this.delete(k) 
                                                      #this.delete(k) if (this[k].nil? || this[k].empty?)
                                                  end
                                                  Hash[:update_this => this]
                                            }
  # With the KVP, we might want the keys that contain a given value
  #note that in this case, the return value is not the same as the value stored in the field, hence the explicit return_value parameter
  KVPGetKeyforValueOp = lambda {|this, value|
                                                this = this|| {}
                                                keys = []
                                                this.each{ |k,v| keys << k if v.include? value }
                                                rtn_val = if srcs.size > 1
                                                                {:return_value => keys, :update_this => this}
                                                              else
                                                                {:return_value => nil, :update_this => this}
                                                              end
                                                rtn_val
                                              }

  KVListOps = {:add => KVListValAddOp, :subtract => KVListValSubtractOp, :get_keys => KVPGetKeyforValueOp}
end

#TODO: Move these into the main libs.
#Currently spec helpers, but should be part of main lib
#and then removed from specs as helpers, but add specs
#to test them
module CouchRestNodeHelpers
  def self.env_builder(node_class_id, reqs, incls, db, db_user_id)
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => reqs,
                            :includes => incls,
                            :glue_name => "BufsCouchRestEnv",
                            :class_env =>
                            Hash[ :bufs_info_doc_env =>
                                  Hash[ :host => db.host,
                                        :path => db.uri,
                                        :user_id => db_user_id
                                      ]
                                ]
                          ]
                    ]
  end
end

module FileSystemNodeHelpers
  def self.env_builder(node_class_id, root_path, fs_user_id)
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => UserNodeSpecHelpers::BufsFileLibs,
                            :includes => UserNodeSpecHelpers::BufsFileIncludes,
                            :glue_name => "BufsFileSystemEnv",
                            :class_env =>
                            Hash[ :bufs_file_system_env =>
                                  Hash[ :path => root_path,
                                        :user_id => fs_user_id
                                      ]
                                ]
                          ]
                    ]
  end
end


#If you have CouchRest:
  #Lets create a couchrest instance to interface to our CouchDB
  require 'couchrest'
  example_couchdb_location = "http://bufs.younghawk.org:5984/example/"
  couchrest_instance = CouchRest.database!(example_couchdb_location)

  #TODO: Verify whether db_user_id is required, or whether its derived already.
  #TODO: It might be better if the node_class_id should be defaulted to the user name (or derivative)
  node_class_id = :MyExample
  reqs = nil #we aren't using an external file to hold the modules to be included
  incls = [ExampleDataStructure]
  user_id = "Me"
  couch_env = CouchRestNodeHelpers.env_builder(node_class_id, reqs, incls, couchrest_instance, user_id)

require '../lib/bufs_node_factory'  #<-- eventually will be gem 'bufs'
require '../lib/moabs/moab_couchrest_env'


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

module DataStructureModels
  module Example
    #Required Keys on instantiation
    RequiredInstanceKeys = [:id]
    RequiredSaveKeys = [:id]  #duplicative?
    NodeKey = :id #TODO look at supporting multiple node keys
  end
end

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
  
  Ops = {:id => StaticFieldOps, :label => ReplaceFieldOps, :tags => ListFieldOps, :kvps=> KVListOps}
end

#UGLY UGLY HACK to get around defiency in Bufs library
module NodeElementOperations
  Ops = ExampleDataStructure::Ops
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
                            :glue_name => "ExampleCouchEnv",
                            :class_env =>
                            Hash[ :example_env =>
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

module BufsCouchRestViews

  def self.set_view(db, design_doc, view_name, opts={})
    #raise view_name if view_name == :parent_categories
    #TODO: Add options for custom maps, etc
    #creating view in design_doc
    #puts "setting design_doc #{design_doc['_id']} with view: #{view_name.inspect} with map:\n #{opts.inspect}"
    design_doc.view_by view_name.to_sym, opts
    db_view_name = "by_#{view_name}"
    views = design_doc['views'] || {}
    view_keys = views.keys || []
    unless view_keys.include? db_view_name
      design_doc['_rev'] = nil
    end
    begin
      view_rev_in_db = db.get(design_doc['_id'])['_rev']
      #TODO: See if this can be simplified, I had forgotten the underscore for rev and added a bunch of other stuff
      #I also think I'm saving when it's not needed because I can't figure out how to detect if the saved view matches the
      #current view I want to run yet
      design_doc_uptodate = (design_doc['_rev'] == view_rev_in_db) && 
                                       (design_doc['views'].keys.include? db_view_name)
      design_doc['_rev'] = view_rev_in_db #unless design_doc_uptodate
      res = design_doc.save #unless design_doc_uptodate
      #puts "Save Design Doc Response: #{res.inspect}"
      res
    rescue RestClient::RequestFailed
      puts "Warning: Request Failed, assuming because the design doc was already saved?"
      puts "Design doc_id: #{design_doc['_id'].inspect}"
      puts "doc_rev: #{design_doc['_rev'].inspect}"
      puts "db_rev: #{view_rev_in_db}"
      puts "Code thinks doc is up to date? #{design_doc_uptodate.inspect}"
    end
  end

  def self.set_view_all(db, design_doc, db_namespace)
    view_name = "all_bufs"
    namespace_id = "bufs_namespace"
    map_str = "function(doc) {
		  if (doc['#{namespace_id}'] == '#{db_namespace}') {
		     emit(doc['_id'], doc);
		  }
	       }"
    map_fn = { :map => map_str } #returned from synced block
    self.set_view(db, design_doc, view_name, map_fn)
  end
  
  def self.tmp_my_cat_view(db, design_doc, user_datastore_id)
    map_str = "function(doc) {
                   if (doc.bufs_namespace =='#{user_datastore_id}' && doc.my_category ){
                     emit(doc.my_category, doc);
                  }
               }"
    map_fn = { :map => map_str }
    self.set_view(db, design_doc, :id, map_fn)
  end

  def self.by_my_category(moab_data, user_datastore_id, match_key)
    db = moab_data[:db]
    design_doc = moab_data[:design_doc]
    map_str = "function(doc) {
                   if (doc.bufs_namespace =='#{user_datastore_id}' && doc.my_category ){
                     emit(doc.my_category, doc);
                  }
               }"
    map_fn = { :map => map_str }
    self.set_view(db, design_doc, :id, map_fn)
    raw_res = design_doc.view :by_id, :key => match_key
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"]}
  end 


  def self.by_parent_categories(moab_data, user_datastore_id, match_keys)
    db = moab_data[:db]
    design_doc = moab_data[:design_doc]
    map_str = "function(doc) {
                if (doc.bufs_namespace == '#{user_datastore_id}' && doc.parent_categories) {
                       emit(doc.parent_categories, doc);
                    };
                };"
          #   }"
    map_fn = { :map => map_str }

    self.set_view(db, design_doc, :tags, map_fn)
    raw_res = design_doc.view :tags
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"] if r["value"]["tags"].include? match_keys}
  end

end

module ExampleCouchEnv

class GlueEnv

  attr_accessor :db_user_id,
                      :user_id, #need to add to spec and mesh with db_user_id
                               :db,
                               :user_datastore_selector,
                               :user_datastore_id,
                               :collection_namespace,
                               :design_doc,
                               :query_all,
                               :attachment_base_id,
                               :db_metadata_keys,
                               :metadata_keys,
                               :base_metadata_keys,
                               :required_instance_keys,
                               :required_save_keys,
                               :node_key,
                               :model_key,
                               :version_key,
                               :namespace_key,
                               :namespace,
                               :_files_mgr_class,
                               :views,
                               :model_save_params,
                               :moab_data,
                               :attachClass 

  def initialize(env)
    #TODO: Should camelize
    env_name = :example_env #"#{self.class.name.to_s}_env".to_sym  #<= (same thing but not needed yet)
    p env_name
    couch_db_host = env[env_name][:host]
    db_name_path = env[env_name][:path]
    #FIXME: Major BUG!! when setting multiple environments in that this may cross-contaminate across users
    #if those users share the same db.  Testing up to date has been users on different dbs, so not an issue to date
    #also, one solution might be to force users to their own db? (what about sharing though?)
    #The problem is that there is one "query_all" per database, and it gets set to the last user class
    #that sets it.  
    db_user_id = env[env_name][:user_id] #TODO Change to "data_set_id at some point
    @user_id = db_user_id
    #user_attach_class_name = "UserAttach#{db_user_id}"
    #the rescue is so that testing works
    #begin
    #  attachClass = UserNode.const_get(user_attach_class_name)
    #rescue NameError
    #  puts "Warning:: Multiuser support for attachments not enabled. Using generic Attachment Class"
    #  attachClass = CouchrestAttachment
    #end
    @db_user_id = db_user_id
    couch_db_location = CouchRestEnv.set_db_location(couch_db_host, db_name_path)
    @db = CouchRest.database!(couch_db_location)
    @model_save_params = {:db => @db}
    
    @collection_namespace = CouchRestEnv.set_collection_namespace(db_name_path, db_user_id)
    @user_datastore_selector = CouchRestEnv.set_user_datastore_selector(@db, @db_user_id)
    @user_datastore_id = CouchRestEnv.set_collection_namespace(db_name_path, db_user_id)
    @design_doc = CouchRestEnv.set_couch_design(@db, db_user_id)#, @collection_namespace)
    @moab_data = {:db => @db, :design_doc => @design_doc}
    @define_query_all = "by_all_bufs".to_sym #CouchRestEnv.query_for_all_collection_records
    @metadata_keys = CouchRestEnv.set_db_metadata_keys #(@collection_namespace)
    #Can this be improved?)
    @required_instance_keys = DataStructureModels::Example::RequiredInstanceKeys
    @required_save_keys = DataStructureModels::Example::RequiredSaveKeys
    #
    @model_key = CouchRestEnv::ModelKey
    @version_key = CouchRestEnv::VersionKey
    @namespace_key = CouchRestEnv::NamespaceKey
    @node_key = DataStructureModels::Example::NodeKey
    #TODO: namespace is identical to collection_namespace?
    @namespace = CouchRestEnv.set_namespace(db_name_path, db_user_id)
    #@views = BufsCouchRestViews
    #@views.set_view_all(@db, @design_doc, @collection_namespace)
    
    #@views.tmp_my_cat_view(@db, @design_doc, @user_datastore_id)
    
    attach_class_name = "MoabAttachmentHandler#{db_user_id}"
    @attachClass = CouchRestEnv.set_attach_class(@db.root, attach_class_name) 
    @_files_mgr_class = CouchRestEnv::FilesMgrInterface
    #@_files_mgr_class.model_params = {:attachment_actor_class => @user_attachClass}
    #@_files_mgr_class = CouchRestEnv::FilesMgr.new(:attachment_actor_class => @user_attachClass)
    #@views_mgr = DataStoreModels::CouchRest::ViewsMgr.new(:db => @db, :design_doc => @design_doc)
  end

  def query_all  #TODO move to ViewsMgr and change the confusing accessor/method clash
   #breaks everything -> self.set_view(@db, @design_doc, @collection_namespace)
   raw_res = @design_doc.view @define_query_all
   raw_data = raw_res["rows"]
   raw_data.map {|d| d['value']}
  end

  def get(id)
    #maybe put in some validations to ensure its from the proper collection namespace?
    rtn = begin
      node = @db.get(id)
      node = HashKeys.str_to_sym(node)
    rescue RestClient::ResourceNotFound => e
      nil
    end
    rtn
  end

  def save(model_data)
    CouchRestEnv.save(@model_save_params, model_data)
  end

  def destroy_node(node)
    CouchRestEnv::destroy_node(node)
    node = nil
  end

  def generate_model_key(namespace, node_key)
    CouchRestEnv.generate_model_key(namespace, node_key)
  end

  #some models have additional processing required, but not this one
  def raw_all
    query_all
  end

  #TODO: Investigate if Couchrest bulk actions or design views will assist here
  #fixed to delete orphaned attachments, but this negates much of the advantage of using this method in the first place
  #or perhaps using a close to the metal design view based on the class name?? (this may be better)
  def destroy_bulk(list_of_native_records)
    #TODO: Investigate why mutiple ids may be returned for the same record
    #Answer Database Corruption
    list_of_native_records.uniq!
    #puts "List of all records: #{list_of_native_records.map{|r| r['_id']}.inspect}"
    list_of_native_records.each do |r|
      begin
        att_doc_id = r['_id'] + CouchrestAttachment::AttachmentID
        #puts "Node ID: #{r['_id'].inspect}"
        #puts "DB: #{@db.all.inspect}"
        @db.delete_doc(r)
        begin
          att_doc = @db.get(att_doc_id)
        rescue
          att_doc = nil
        end
        @db.delete_doc(att_doc) if att_doc
      rescue RestClient::RequestFailed
        puts "Warning:: Failed to delete document?"
      end
    end
    nil #TODO ok to return nil if all docs destroyed? also, not verifying
  end
end 
end


#If you have CouchRest:
  #Lets create a couchrest instance to interface to our CouchDB
  require 'couchrest'
  #example_couchdb_location = "http://bufs.younghawk.org:5984/example/"
  example_couchdb_location = "http://bufs.couchone.com/example"
  couchrest_instance = CouchRest.database!(example_couchdb_location)

  #TODO: Verify whether db_user_id is required, or whether its derived already.
  #TODO: It might be better if the node_class_id should be defaulted to the user name (or derivative)
  node_class_id = :MyExample
  reqs = nil #we aren't using an external file to hold the modules to be included
  incls = [ExampleDataStructure]
  user_id = "Me"
  couch_env = CouchRestNodeHelpers.env_builder(node_class_id, reqs, incls, couchrest_instance, user_id)
  #p couch_env
  ExampleClass = BufsNodeFactory.make(couch_env)
  hello_world_node = ExampleClass.new({:id => "My ID", :label => "Hello World"})
  hello_world_node.__save
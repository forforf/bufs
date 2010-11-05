#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

require Bufs.midas 'bufs_data_structure'
require Bufs.moabs 'moab_couchrest_env'

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
    self.set_view(db, design_doc, :my_category, map_fn)
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
    self.set_view(db, design_doc, :my_category, map_fn)
    raw_res = design_doc.view :by_my_category, :key => match_key
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

    self.set_view(db, design_doc, :parent_categories, map_fn)
    raw_res = design_doc.view :by_parent_categories
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"] if r["value"]["parent_categories"].include? match_keys}
  end

end

module BufsCouchRestEnv

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
    env_name = :bufs_info_doc_env  #"#{self.to_s}_env".to_sym  <= (same thing but not needed yet)
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
    @required_instance_keys = DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = DataStructureModels::Bufs::RequiredSaveKeys
    @model_key = CouchRestEnv::ModelKey
    @version_key = CouchRestEnv::VersionKey
    @namespace_key = CouchRestEnv::NamespaceKey
    @node_key = DataStructureModels::Bufs::NodeKey
    #TODO: namespace is identical to collection_namespace?
    @namespace = CouchRestEnv.set_namespace(db_name_path, db_user_id)
    @views = BufsCouchRestViews
    @views.set_view_all(@db, @design_doc, @collection_namespace)
    
    @views.tmp_my_cat_view(@db, @design_doc, @user_datastore_id)
    
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

require File.dirname(__FILE__) + '/../midas/bufs_data_structure'
require File.dirname(__FILE__) + '/../moabs/moab_couchrest_env'

module BufsCouchRestViews

  def self.set_view(db, design_doc, view_name, opts={})
    #raise view_name if view_name == :parent_categories
    #TODO: Add options for custom maps, etc
    #creating view in design_doc
    design_doc.view_by view_name.to_sym, opts
    db_view_name = "by_#{view_name}"
    views = design_doc['views'] || {}
    view_keys = views.keys || []
    unless view_keys.include? db_view_name
      design_doc['_rev'] = nil
    end
    begin
      view_rev_in_db = db.get(design_doc['_id'])['_rev']
      res = design_doc.save unless design_doc['rev'] == view_rev_in_db
    rescue RestClient::RequestFailed
      puts "Warning: Request Failed, assuming because the design doc was already saved?"
      puts "doc_rev: #{design_doc['_rev'].inspect}"
      puts "db_rev: #{view_rev_in_db}"
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

class GlueEnv
  attr_accessor :db_user_id,
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
                               :files_mgr,
                               :views,
                               :model_save_params,
                               :moab_data
                               #:user_attachClass #should be overwritten?

  def initialize(env)
    env_name = :bufs_info_doc_env  #"#{self.to_s}_env".to_sym  <= (same thing but not needed yet)
    couch_db_host = env[env_name][:host]
    db_name_path = env[env_name][:path]
    db_user_id = env[env_name][:user_id] #TODO Change to "data_set_id at some point
    #user_attach_class_name = "UserAttach#{db_user_id}"
    #the rescue is so that testing works
    #begin
    #  attachClass = UserNode.const_get(user_attach_class_name)
    #rescue NameError
    #  puts "Warning:: Multiuser support for attachments not enabled. Using generic Attachment Class"
    #  attachClass = BufsInfoAttachment
    #end
    @db_user_id = db_user_id
    couch_db_location = CouchRestEnv.set_db_location(couch_db_host, db_name_path)
    @db = CouchRest.database!(couch_db_location)
    @model_save_params = {:db => @db}
    
    @collection_namespace = CouchRestEnv.set_collection_namespace(db_name_path, db_user_id)
    @user_datastore_selector = CouchRestEnv.set_user_datastore_selector(@db, @db_user_id)
    @user_datastore_id = CouchRestEnv.set_collection_namespace(db_name_path, db_user_id)
    @design_doc = CouchRestEnv.set_couch_design(@db)#, @collection_namespace)
    @moab_data = {:db => @db, :design_doc => @design_doc}
    @define_query_all = "by_all_bufs".to_sym #CouchRestEnv.query_for_all_collection_records
    @attachment_base_id = CouchRestEnv::AttachmentBaseID
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
    #@user_attachClass = attachClass  
    @files_mgr = CouchRestEnv::FilesMgr.new(:attachment_actor_class => @user_attachClass)
    #@views_mgr = DataStoreModels::CouchRest::ViewsMgr.new(:db => @db, :design_doc => @design_doc)
  end

  def query_all  #TODO move to ViewsMgr and change the confusing accessor/method clash
   raw_res = @design_doc.view @define_query_all
   raw_data = raw_res["rows"]
   raw_data.map {|d| d['value']}
  end

  def get(id)
    #maybe put in some validations to ensure its from the proper collection namespace?
    rtn = begin
      @db.get(id)
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
  end

  def generate_model_key(namespace, node_key)
    CouchRestEnv.generate_model_key(namespace, node_key)
  end

  #some models have additional processing required, but not this one
  def raw_all
    query_all
  end

  def destroy_bulk(list_of_native_records)
    list_of_native_records.each do |r|
      begin
        @db.delete_doc(r)
      rescue RestClient::RequestFailed
        puts "Warning:: Failed to delete document?"
      end
    end
    nil #TODO ok to return nil if all docs destroyed? also, not verifying
  end
end 


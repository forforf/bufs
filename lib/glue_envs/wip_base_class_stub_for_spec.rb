module MoabStub
  class FileMgr
    def initialize(env, node_key)
    end
  end
end

module NodeElementOperations
  Ops = {}
  #TODO Need to test setting node element attribute operations
end

module GlueStub
  IsLoaded = true
  class GlueEnv
    attr_accessor :metadata_keys, :required_instance_keys,
                  :node_key, :_files_mgr_class, :model_key, :version_key,
                  :namespace_key, :user_datastore_id
    def initialize(env)
      @metadata_keys = [:model_metadata]
      @required_instance_keys = [:node_id, :model_content]
      @node_key = :node_id 
      @_files_mgr_class = MoabStub::FileMgr
      @model_key = :model_id_for_referencing_node_content
      @version_key = :model_key_for_accessing_content_revision_info
      @namespace_key = :user_partition_id_for_model 
      @user_datastore_id = :user_id_in_model
    end

    def query_all
      "returns all records in native form"
    end

    def raw_all
      [{:node_id => 'node1', 
        :model_content => 'native data 1', 
        :model_metadata => 'n/a to base node',
        :content_to_remove => 'bye, bye1'},
       {:node_id => 'node2',
        :model_content => 'native data 2',
        :model_metadata => 'n/a to base node',
        :content_to_remove => ['bye, bye']}]
      end
      
      def generate_model_key(namespace, node_key)
        "Using #{namespace} and #{node_key} to make model id"
      end
  end
end

#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require Bufs.lib 'bufs_base_node'
require Bufs.helpers 'log_helper'

class BufsNodeFactory 
  #Set Logger
  @@log = BufsLog.set(self.name, :debug)

  def self.make(node_env)
    BufsLog.log_raise "No Node Environment provided" unless node_env
    BufsLog.log_raise "Empty Node Environment provided" if node_env.empty?
    BufsLog.log_raise "Malformed Node Environment" unless node_env.respond_to?(:keys)
    BufsLog.log_raise "Malformed Node Environment" unless node_env.keys.include? :persist_model

    
    neo_env = node_env[:data_model] || {}
    
    neo = NodeElementOperations.new(neo_env)
    data_model_bindings = {:key_fields => neo.key_fields,
                                      #:data_ops_set => neo.field_op_set_sym,
                                      :views => neo.views}

    #TODO: Make setting the environment thread safe
    class_environment = node_env[:persist_model]
    user_doc_class_name = node_env[:node_class_id]

    #Security TODO: remove spaces and other 

    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{user_doc_class_name} < BufsBaseNode
      
      class << self; attr_accessor :user_attachClass, end

      end"

    BufsNodeFactory.class_eval(dyn_user_class_def)
    docClass = BufsNodeFactory.const_get(user_doc_class_name)

    docClass.data_struc = neo
    
    #TODO: Streamline the paramaters (maybe one env paramater?)
    docClass.set_environment(class_environment, data_model_bindings)
    docClass
  end
end 

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
    #BufsLog.log_raise "Malformed Node Environment" unless node_env.keys.include? :data_model
    #node_class_name = node_env.keys.first
    #reqs = node_env[node_class_name][:requires]
    #reqs.each {|r| require r} if reqs
    #incs = node_env[node_class_name][:includes]
    #@@log.debug {"User Provided Field Operations: #{incs.inspect}"} if @@log.debug?
    
    neo_env = node_env[:data_model] || {}
    
    #neo_defs = incs[:field_ops_def_mod]
    neo = NodeElementOperations.new(neo_env)
    data_model_bindings = {:key_fields => neo.key_fields,
                                      #:data_ops_set => neo.field_op_set_sym,
                                      :views => neo.views}
    
    #
    #incs_strs = incs.map{|i| "include #{i}"}
    #incs_str = incs_strs.join("\n")
    #user_id = node_env[node_class_name][:user_id] #TODO Remove when not needed for testing
    #TODO: Make setting the environment thread safe
    class_environment = node_env[:persist_model]
    user_doc_class_name = node_env[:node_class_id]
    #@user_attach_class_name = "UserAttach#{user_id}"  TODO Figure out attachments

    #Security TODO: remove spaces and other 

    #---- Dynamic Class Definitions ----
    incs_str = ""  #staged for deletion, this is here so it doesn't break below
    dyn_user_class_def = "class #{user_doc_class_name} < BufsBaseNode
      
      class << self; attr_accessor :user_attachClass, end

      end"

    BufsNodeFactory.class_eval(dyn_user_class_def)
    docClass = BufsNodeFactory.const_get(user_doc_class_name)
    #
    docClass.data_struc = neo
    #
    #glue_name = node_env[node_class_name][:glue_name]

    docClass.set_environment(class_environment, data_model_bindings)
    docClass
  end
end 

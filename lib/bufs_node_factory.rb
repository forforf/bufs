#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require Bufs.lib 'bufs_base_node'
require Bufs.midas 'node_element_operations'
require Bufs.helpers 'log_helper'




class BufsNodeFactory 
  #this_file = File.basename(__FILE__)
  #Set Logger
  @@log = BufsLog.set(self.name, :warn)  
  
  def self.make(node_env)
    BufsLog.log_raise "No Node Environment provided" unless node_env
    BufsLog.log_raise "Empty Node Environment provided" if node_env.empty?
    BufsLog.log_raise "Malformed Node Environment" unless node_env.respond_to?(:keys)
    BufsLog.log_raise "Malformed Node Environment" unless node_env.keys.size == 1
    node_class_name = node_env.keys.first
    reqs = node_env[node_class_name][:requires]
    reqs.each {|r| require r} if reqs
    incs = node_env[node_class_name][:includes]
    #
    neo_data = incs[:field_op_set]
    #neo_defs = incs[:field_ops_def_mod]
    neo = NodeElementOperations.new(:field_op_set => neo_data)
    #
    #incs_strs = incs.map{|i| "include #{i}"}
    #incs_str = incs_strs.join("\n")
    user_id = node_env[node_class_name][:user_id] #TODO Remove when not needed for testing
    #TODO: Make setting the environment thread safe
    class_environment = node_env[node_class_name][:class_env]
    user_doc_class_name = node_class_name #"UserNode#{user_id}"
    #@user_attach_class_name = "UserAttach#{user_id}"  TODO Figure out attachments

    #Security TODO: remove spaces and other 

    #---- Dynamic Class Definitions ----
    incs_str = ""  #staged for deletion, this is here so it doesn't break below
    dyn_user_class_def = "class #{user_doc_class_name} < BufsBaseNode
      # #{incs_str}
      
      class << self; attr_accessor :user_attachClass, :data_struc end

      end"

    BufsNodeFactory.class_eval(dyn_user_class_def)
    docClass = BufsNodeFactory.const_get(user_doc_class_name)
    #
    docClass.data_struc = neo
    #
    glue_name = node_env[node_class_name][:glue_name]
    docClass.set_environment(class_environment, glue_name)
    docClass
  end
end 

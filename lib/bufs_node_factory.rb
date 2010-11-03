#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require Bufs.lib 'bufs_base_node'

class BufsNodeFactory 
  def self.make(node_env)
    raise "No Node Environment provided" unless node_env
    raise "Empty Node Environment provided" if node_env.empty?
    raise "Malformed Node Environment" unless node_env.keys.size == 1
    node_class_name = node_env.keys.first
    reqs = node_env[node_class_name][:requires]
    reqs.each {|r| require r} if reqs
    incs = node_env[node_class_name][:includes]
    incs_strs = incs.map{|i| "include #{i}"}
    incs_str = incs_strs.join("\n")
    user_id = node_env[node_class_name][:user_id] #TODO Remove when not needed for testing
    #TODO: Make setting the environment thread safe
    class_environment = node_env[node_class_name][:class_env]
    user_doc_class_name = node_class_name #"UserNode#{user_id}"
    #@user_attach_class_name = "UserAttach#{user_id}"  TODO Figure out attachments

    #Security TODO: remove spaces and other 

    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{user_doc_class_name} < BufsBaseNode
      #{incs_str}
      
      class << self; attr_accessor :user_attachClass end

      end"

    BufsNodeFactory.class_eval(dyn_user_class_def)
    docClass = BufsNodeFactory.const_get(user_doc_class_name)
    glue_name = node_env[node_class_name][:glue_name]
    docClass.set_environment(class_environment, glue_name)
    docClass
  end
end 
  

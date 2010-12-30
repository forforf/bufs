#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

require Bufs.helpers 'log_helper'


#TODO This should be a class and instance assigned to a node class
#     otherwise different node classes will clobber each other

#rename module to DefaultOpSets
module DefaultOpSets
  
  class << self; attr_accessor :op_sets_to_def_table  end
  #definitions WIP
  #op_name => type of operations (add, subtract, get, etc)
  #op_def => anonymous function that defines a particular operations behavior in a particular context
  #             addition in the context of lists for example
  #op_set => the set of all operations that belong with a certain context
  #             the set of operations that can work with lists for example
  #op_behav => types of context, for example static (unchanging), replacing, appending, merging, etc
  #fields => the key portion of a key-value persisted record
  #field value => the value portion of key-value persisted record
  #key field => the primary identifier for a key-value record (akin to a primary key)
  #field_op_set => the assignment of context to a field, and associated op_behav's belonging
  #              to that context
  #record_op_set => the collection fo field operation assignments for an entire record
  
  #Building Field Operation Definitions
  #General:
  #A Proc that accepts two input parameters, the first (this) is the current value assigned to the field,
  #the second (other) is the value to be used by the operation.
  #A Hash is returned with the folowing parameters
  #  :update_this => <Update the current field to this value> (mandatory)
  #  :return_val => <return this value from the operation> (optional, if not included the value of "update_this" is returned
  
  #Static Operations are for fixed values (i.e., any attempts at changes are ignored)
  StaticAddOpDef = lambda{|this, other| Hash[:update_this => this] }
  StaticSubtractOpDef = lambda{|this, other| Hash[:update_this => this]}

  StaticOpSet = {:add => StaticAddOpDef, :subtract => StaticSubtractOpDef}
  
  
  #We define a field where adding will replace the existing value for that field, and subtracting a matching value will set the value to nil
  ReplaceAddOpDef = lambda { |this, other|   Hash[:update_this => other]  }
  ReplaceSubtractOpDef = lambda do |this, other|
    if (this == other)
      Hash[:update_this => nil] 
    else
      Hash[:update_this => this]
    end
  end
                                  
  ReplaceOpSet = {:add => ReplaceAddOpDef, :subtract => ReplaceSubtractOpDef}
  
  #We define a field where adding will add the value to the existing list, and subtracting will remove matching values from the list
  ListAddOpDef = lambda  do |this,other|
    this = [this].flatten
    other = [other].flatten
    this = this + other
    this.uniq!; this.compact!
    Hash[:update_this => this]
  end
                         
  ListSubtractOpDef = lambda do |this,other| 
    this = [this].flatten
    other = [other].flatten
    this -= other
    this.uniq!
    this.compact!
    Hash[:update_this => this]
  end
  
  ListOpSet = {:add => ListAddOpDef, :subtract => ListSubtractOpDef}
  
  #A bit more complicated is if we have a field that holds key-value pairs, but we want our operations
  #to operate on the underlying values of the key-value pair, and not on the actual key value sets.
  #Here the values are a list type.  What happens is if an existing key is passed, the value is added to the 
  #set of values for the existing key.  If a new key is passed, the new key and its value are added to the list
  KListAddOpDef = lambda do |this, other|
    this = this || {}  
    other = other || {}
    all_keys = this.keys + other.keys
    combined = {}
    all_keys.each do |k|
      this_list = [this[k]].flatten
      other_list = [other[k]].flatten
      combined[k] = (this_list + other_list).flatten
      #if this[k]
      #  this[k] = [this[k] ].flatten + [ other[k] ].flatten
      #else
      #  this[k] = [ other[k] ].flatten
      #end 
      combined[k].uniq!
      combined[k].compact!
    end
    Hash[:update_this => combined] 
  end
                                                  
  KListSubtractOpDef = lambda do |this, other|
    this = this || {}
    other = other || {}
    subtracted_list = {}
    this.keys.each do |k|
      this_list = [this[k]].flatten
      other_list = [other[k]].flatten
      #other[s].each {|olnk| this[k].delete(olnk) if this[k]}
      #this[k].delete(other[k]) if this[k]
      subtracted_list[k] = (this_list - other_list).flatten
      subtracted_list[k].compact!
      subtracted_list[k].uniq!
      #this.delete(k) if (this[k].nil? || this[k].empty?)
    end
    Hash[:update_this => subtracted_list]
  end
  
  # With the KVP, we might want the keys that contain a given value
  #note that in this case, the return value is not the same as the value stored in the field, hence the explicit return_value parameter
  #Something to think about is whether this should be some type of recursive operation since the record is key-value, and the field is key-value
  KListGetKeyforValueOpDef = lambda do |this, values|
    values = [values].flatten
    this = this|| {}
    keys = []
    this.each do |k,v|
      values.each do |value|
        keys << k if v.include? value 
      end
    end
    rtn_val = if keys.size > 0
      {:return_value => keys, :update_this => this}
    else
      {:return_value => nil, :update_this => this}
    end
    rtn_val
  end
  
  KListOpSet = {:add => KListAddOpDef, 
                     :subtract => KListSubtractOpDef,
                     :getkeys => KListGetKeyforValueOpDef} 
                     

  self.op_sets_to_def_table = { :static_ops => StaticOpSet,
                        :replace_ops => ReplaceOpSet,
                        :list_ops => ListOpSet,
                        :key_list_ops => KListOpSet
                      }

  #default_config = {:id => StaticFieldOps, :label => ReplaceFieldOps, :tags => ListFieldOps, :kvps=> KVListOps}
  
  #default_config = {:id => StaticFieldOps}
  #self.configuration = default_config

  #the keys represent the data type, the values represent the operations to perform on those datatypes  
  #Ops = {:id => StaticFieldOps, :label => ReplaceFieldOps, :tags => ListFieldOps, :kvps=> KVListOps}
  #Ops = NodeElementOperations.configuration
  
  #attr_accessor :ops
  #def self.ops
  #  NodeElementOperations.configuration
  #end
    
end

module DataModelViews

  OpIdToViewType = {
      :static_ops => :value_match,
      :replace_ops => :value_match,
      :list_ops => :included_match,
      :key_list_ops => :key_of_included_match
  }
  #note: currently "get" is defined as part of the node, and returns the unique record for a given key
  #keep there or move here?
  
  #views return a list of matches (which may be empty)
  
  def default_views(field_op_set)
    views = {}
    field_op_set.each do |field, op_id|
      view_name = "by_#{field.to_s}"
      type_of_view = OpIdToViewType[op_id] || :value_match
      views[view_name] = {:field => field.to_sym, :type_of_view => type_of_view}
    end
    views
  end
end

class NodeElementOperations
  include DataModelViews
  #Set Logger
  @@log = BufsLog.set(self.name, :warn) 
  
  DefaultFieldOpSet = {:id => :static_ops,
                                :data => :replace_ops,
                                :name => :replace_ops,   #convenience field for a node name
                                :tags => :list_ops}         #convenience field for a list of tags
                                #:kvlist => :key_list_ops}   #convenience field for a list of lists
  
  #Default works for node element operations, but not glue operations  
  DefaultKeyFields = { :required_keys => [:id], :primary_key => :id}
    
  attr_accessor :field_op_defs, 
                     :field_op_set_sym,  #used in model for views
                     :required_instance_keys ,
                     :required_save_keys,
                     :node_key,
                     :key_fields,
                     :views
  
  #With no parameters - Defaults are used
  #:op_sets_mod => The module with the data operations that apply to the data fields
  #:field_op_set => The assignment of data fields to the data operations
  def initialize(op_data = {})
    @@log.debug {"Node Element Initialized with: #{op_data.inspect}"} if @@log.debug?
    
    #set the module with the operation definition and include them
    @ops_set_module = op_data[:op_sets_mod] ||DefaultOpSets
    self.class.__send__(:include, @ops_set_module)  #why is this private? am I doing something wrong?
    
    #set the mapping between fields and the type of operations supported by those fields
    @field_op_set_sym = DefaultFieldOpSet.merge(op_data[:field_op_set] || {})
    @@log.info {"Field Operations Set: #{@field_op_set_sym.inspect}"} if @@log.info?
    @field_op_defs = get_field_op_procs(@field_op_set_sym)
    
    #set the key fields that will work as node/record identifiers or other key fields
    @key_fields = op_data[:key_fields]||DefaultKeyFields
    raise "key_fields are required" unless @key_fields

    #we are no longer differentiating between keys required for insantiation and persistence
    #this can be added in the future easily though.
    @required_instance_keys = @key_fields[:required_keys]
    @required_save_keys = @key_fields[:required_keys]
    @node_key = @key_fields[:primary_key]
    @views = default_views(@field_op_set_sym)  #TODO: Allow custom views in the future
  end
  
  def set_op(ops)
    ops.each do |field, ops_sym|
      op_proc = self.lookup_op_proc(ops_sym)
      ops[field] = op_proc
    end
    @field_op_defs = @field_op_defs.merge(ops)
  end
  
  def lookup_op_proc(ops_sym)
     proc = @ops_set_module.op_sets_to_def_table[ops_sym]
  end
  
  def get_field_op_procs(field_op_set_sym)
    field_op_defs = {}
    #convert from symbol to actual Proc.  Using symbol allows the type of op to be passed around
    #needed because the Proc is anonymous so self-referential data is hard to get
    @field_op_set_sym.each do |field, ops_sym|
      if ops_sym.class == Symbol
        ops_proc = lookup_op_proc(ops_sym)
        field_op_defs[field] = ops_proc
      else
        raise "Unrecognized operation definition label #{ops_orig.inspect}"
      end 
    end
    field_op_defs
  end
  
end


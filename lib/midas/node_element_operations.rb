
#TODO This should be a class and instance assigned to a node class
#     otherwise different node classes will clobber each other
module NodeElementOperations

  class << self; attr_accessor :configuration  end
   
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


  default_config = {:id => StaticFieldOps, :label => ReplaceFieldOps, :tags => ListFieldOps, :kvps=> KVListOps}
  NodeElementOperations.configuration = default_config

  #the keys represent the data type, the values represent the operations to perform on those datatypes  
  #Ops = {:id => StaticFieldOps, :label => ReplaceFieldOps, :tags => ListFieldOps, :kvps=> KVListOps}
  Ops = NodeElementOperations.configuration
end


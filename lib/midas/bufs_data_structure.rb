module DataStructureModels
  module Bufs
    #Required Keys on instantiation
    RequiredInstanceKeys = [:my_category]
    RequiredSaveKeys = [:my_category]  #duplicative?
    NodeKey = :my_category #TODO look at supporting multiple node keys
  end
end

=begin
module NodeElementOperations
  #TODO the hash inside the proc is confusing (the curly braces) update to better readability
  MyCategoryAddOp = lambda {|this,other|   Hash[:update_this => this]  } #my cat is not allowed to change
  MyCategorySubtractOp = lambda{ |this, other| Hash[:update_this => this] } #TODO use this to delete a node?
  MyCategoryOps = {:add => MyCategoryAddOp, :subtract => MyCategorySubtractOp}
  ParentCategoryAddOp = lambda {|this,other|
                           this = this || []
                           other = other || []
                           this = this + [other].flatten
                           this.uniq!; this.compact!
                           Hash[:update_this => this]
                         }
  ParentCategorySubtractOp = lambda {|this,other| 
                                this = [this] || []
                                other = [other] || []
                                this.flatten!
                                other.flatten!
                                this -= other
                                this.uniq!
                                this.compact!
                                Hash[:update_this => this]
                               }
  ParentCategoryOps = {:add => ParentCategoryAddOp, :subtract => ParentCategorySubtractOp}
  LinkAddOp = lambda {|this, other|
                                 this = this || {}  #investigate why its passed as nil (probably hasn't been built yet
                                 other = other || {}
                                 srcs = other.keys
                                 srcs.each {|s| if this[s]
                                            #this[s] = [ other[s] ].flatten
                                            this[s] = other[s]
                                           else
                                            #this[s] = [ other[s] ].flatten
                                            this[s] = other[s]
                                           end }
                                           #this[s].uniq!
                                           #this[s].compact! }
                           Hash[:update_this => this] }
  #if link_name is used besides other, then all link_names would need to be unique, so we use other
  LinkSubtractOp = lambda {|this, other| this = this || {}
                                          #Hacked together needs thought out (and TESTED!!)
                                         other = other || {}
                                         puts "This / Other: #{this.inspect} / #{other.inspect}"
                                         #srcs = [other].flatten
                                         other.keys.each { |s|
                                                      #other[s].each {|olnk| this[s].delete(olnk) if this[s]}
                                                      puts "delete #{other[s].inspect} from #{this[s].inspect}"
                                                      #this[s].delete(other[s]) if this[s]
                                                      this.delete(s) 
                                                      #this.delete(s) if (this[s].nil? || this[s].empty?)
                                              }
                                         Hash[:update_this => this]
                           }
  #think if this is what you want, returning a single uri if only one exists, while an array if more than one?
  #I think so since it's *almost* an error case if more than one url exists for a name, but I'm not sure this is the best approach
  LinkGetOp = lambda {|this, link_name|
                                       this_ary = this.to_a
                                       rtn_val = nil
                                       rtn_val = if this_ary.flatten.include? link_name
                                         srcs = []
                                         this_ary.each { |s, ls| srcs << s if ls.include? link_name }
                                         rtn_val =  {:return_value => srcs, :update_this => this } if srcs.size > 1
                                         rtn_val = {:return_value => srcs.first, :update_this => this } if srcs.size == 1
                                         rtn_val
                                        else
                                          rtn_val = {:return_value => nil, :update_this => this} 
                                        end
                                        rtn_val
                     }

  LinkOps = {:add => LinkAddOp, :subtract => LinkSubtractOp, :get => LinkGetOp}

  Ops = {:my_category => MyCategoryOps, :parent_categories => ParentCategoryOps, :links => LinkOps}
end
=end

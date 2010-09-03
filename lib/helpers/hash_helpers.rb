require 'ostruct'

module HashKeys
  def self.str_to_sym(a_hash)
    a_hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end
 
  def self.sym_to_str(a_hash) #inverse of above
    a_hash.inject({}){|memo,(k,v)| memo["#{k}"] = v; memo}
  end
end

class MoreOpenStruct < OpenStruct
  def _to_hash
    h = @table
    #handles nested structures
    h.each do |k,v|
      if v.class == MoreOpenStruct
        h[k] = v._to_hash
      end
    end
    return h
  end
  
  def _table
    @table   #table is the hash structure used in OpenStruct
  end
  
  def _manual_set(hash)
    if hash && (hash.class == Hash)
      for k,v in hash
        @table[k.to_sym] = v
        new_ostruct_member(k)
      end
    end
  end
end

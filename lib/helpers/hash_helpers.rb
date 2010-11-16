require 'ostruct'

   #from Facets via Hashery
class Hash
  


  def rekey!(*args, &block)
    # for backward comptability (TODO: DEPRECATE).
    block = args.pop.to_sym.to_proc if args.size == 1
    if args.empty?
      block = lambda{|k| k.to_sym} unless block
      keys.each do |k|
        nk = block[k]
        self[nk]=delete(k) if nk
      end
    else
      raise ArgumentError, "3 for 2" if block
      to, from = *args
      self[to] = self.delete(from) if self.has_key?(from)
    end
    self
  end
  
  def rekey(*args, &block)
     dup.rekey!(*args, &block)
   end
   
  public :rekey, :rekey!
end

module HashKeys
  def self.str_to_sym(a_hash)
    raise "#{a_hash.class.name} must respond to inject" unless a_hash.respond_to? :inject
    a_hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end
 
  def self.sym_to_str(a_hash) #inverse of above
    raise "#{a_hash.class.name} must respond to inject" unless a_hash.respond_to? :inject
    a_hash.inject({}){|memo,(k,v)| memo["#{k}"] = v; memo}
  end
end

module HashOps
  def self.remove_hash(other_hash)
    delete_if { |k,v| other_hash[k] == v }
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

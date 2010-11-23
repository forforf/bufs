
class DirFilter
  def initialize(ignore_list)
    @ignore_list = [ignore_list].flatten
    @ignore_list << /^\./    #ignore dot files
  end
  
  
  def filter_entries(path)
    wkg_entries = Dir.entries(path)
    #remove dot files
    wkg_entires = wkg_entries.delete_if{|entry| in_ignore_list?(entry)  }
  end
  
  private
  def in_ignore_list?(entry)
    in_ignore = @ignore_list.map{|list| true if entry =~ list}
    in_ignore.compact.first  #nil if nothing in ignore
  end
end
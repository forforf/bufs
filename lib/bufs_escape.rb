class BufsEscape
  def self.escape(str)
    esc_str = str.gsub(/([^a-zA-Z0-9_.-]+)/n, '_')
    #str.gsub!('+', ' ')
    #str = CGI.escape(str)
    #str.gsub!('%2B', '+')
    return esc_str
  end
end


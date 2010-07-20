require 'cgi'  #Can replace with url_escape if performance is an issue

class BufsEscape
  def self.escape(str)
    esc_str = str.gsub(/([^a-zA-Z0-9_.-]+)/n, '_')
    #str.gsub!('+', ' ')
    #str = CGI.escape(str)
    #str.gsub!('%2B', '+')
    return esc_str
  end

  #TODO: Continue using cgi or create unescape specific to Bufs?
  def self.unescape(str)
    return CGI.unescape(str)
  end
end


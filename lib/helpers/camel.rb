#copy of Rails camelize and underscore (almost)

module Camel
  def self.ize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
    if first_letter_in_uppercase
      lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
    else
      lower_case_and_underscored_word.first + camelize(lower_case_and_underscored_word)[1..-1]
    end
  end
  
  def self.score(camel_cased_word)
     word = camel_cased_word.to_s.dup
     word.gsub!(/::/, '_')  #except I changed '/' to '_'
     word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
     word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
     word.tr!("-", "_")
     word.downcase!
     word
  end
end

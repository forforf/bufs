
#contains behavior that is consistent across all models
module BufsBaseModel
  #list of supported data structures and any generic  management methods needed
  #  :my_category  (immutable)
  #  :parent_categories (array)
  #  :description (string)
  #  :files       (discrete block of application data)
  #  :links       (uri with label)
  #  other? [ :comments, :posts, :tags ???

  #component for managing collections, though the management method will vary by model
  #  examples: all records in model, records where a data structure value(s) match a key
  #  method for collecting records will vary by model

  #setting the environment that binds the ruby class to the underlying persistent model
  
  #Binding the base model object to the user data and user data operations
end

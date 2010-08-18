require 'json'

  DefaultDataModel = {
      :a  => {
         :node_data => {
            "my_category" => "a",
            "parent_categories" => ["root","aa"],
            "description" => "a description"
         }
      },
      :b => {
         :node_data => {
            "my_category" => "b",
            "parent_categories" => ["root","ab", "bb"],
            "description" => "b description"
         }
      },
      :aa=> {
         :node_data => {
            "my_category" => "aa",
            "parent_categories" => ["a"],
            "description" => "aa description"
         }
      },
      :ab => {
         :node_data => {
            "my_category" => "ab",
            "parent_categories" => ["a","bb"],
            "description" => "ab description"
         },
         :attachments => [
            {:filename => "ab1.txt",
            :data => "data from ab1.txt"},
            {:filename => "ab2.txt",
            :data => "data from ab2.txt"}
         ]
      },
      :ac => {
         :node_data => {
            "my_category" => "ac",
            "parent_categories" => ["a"],
            "description" => "ac description"
         },
         :attachments => [
            {:filename => "ac.txt",
            :data => "data from ac.txt"
            }
         ]
      },
      "ba"=> {
         :node_data => {
            "my_category" => "ba",
            "parent_categories" => ["b"],
            "description" => "ba description"
         }
      },
      "bb"=> {
         :node_data => {
            "my_category" => "bb",
            "parent_categories" => ["b"],
            "description" => "bb description"
         }
      },
       "bc"=> {
         :node_data => {
            "my_category" => "bc",
            "parent_categories" => ["b"],
            "description" => "bc description"
         },
          :attachments => [
            {:filename => "bc.txt",
            :data => "data from bc.txt"}
         ]
         }
  }

model_json = DefaultDataModel.to_json
File.open('default_data_model.json','w'){|f| f.write(model_json)}

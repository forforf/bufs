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
            "parent_categories" => ["root"],
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
      :aaa=> {
         :node_data => {
            "my_category" => "aaa",
            "parent_categories" => ["aa"],
            "description" => "aaa description"
         }
      },
      :ab => {
         :node_data => {
            "my_category" => "ab",
            "parent_categories" => ["a","bb","aaa"],
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
            "parent_categories" => ["b","ab"],
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
      "bbb"=> {
         :node_data => {
            "my_category" => "bbb",
            "parent_categories" => ["bb","aaa"],
            "description" => "bbb description"
         }
      },
       "bc"=> {
         :node_data => {
            "my_category" => "bc",
            "parent_categories" => ["b","bbb"],
            "description" => "bc description"
         },
          :attachments => [
            {:filename => "bc.txt",
            :data => "data from bc.txt"}
         ]
         },
       "bcc"=> {
         :node_data => {
            "my_category" => "bcc",
            "parent_categories" => ["bc"],
            "description" => "bcc description"
         },
          :attachments => [
            {:filename => "bcc.txt",
            :data => "data from bcc.txt"}
         ]
         }

  }

model_json = DefaultDataModel.to_json
File.open('default_data_model.json','w'){|f| f.write(model_json)}

require 'json'
require File.dirname(__FILE__) + '/bufs_info_doc'

class DefaultNode < Hash
  attr_accessor :parent_categories, :my_category, :description
  def initialize(my_cat)
    self['_id'] = 'dummy_' + my_cat
    @parent_categories = nil
    @my_category = my_cat
    @description = 'This node is organizational only'
  end
end

class BufsJsvisData
  def initialize(node_list)
    @all_nodes = node_list
    #This is duplicating some of the database functionality but
    #this may be better for responsiveness?
    @nodes_by_cat = {}
    @all_nodes.each do |node|
      @nodes_by_cat[node.my_category] = node
    end
    @nodes_by_parent_cat = []
    @all_nodes.each do |node|
      node.parent_categories.each do |node_parent_cat|
	@nodes_by_parent_cat << [node_parent_cat, node]
      end
    end
  end

  def json_vis(top_node_parent_cat, depth)
    json_vis_nodes = nil
    top_node = @nodes_by_cat[top_node_parent_cat]||DefaultNode.new(top_node_parent_cat)
    jsm = make_json_vis_from_node(top_node, depth) 
    jsm.to_json
  end

  def make_json_vis_from_node(node, depth, current_model = nil)
    jsvis_model = {} #JsvisModel.new
    return nil if depth < 0
    jsvis_model['id'] = node['_id']
    jsvis_model['name'] = node.my_category
    jsvis_model['data'] = {}#node.description
    jsvis_model['children'] = get_node_children(node).map {|cn| make_json_vis_from_node(cn, depth-1)}
    jsvis_model['children'].compact!
    return jsvis_model
  end

  def get_category_children_nodes(parent_cat)
    @nodes_by_parent_cat.select{|n| n[0] == parent_cat}.map{|i| i.last}
  end

  def get_node_children(node)
    childrens_parent_category = node.my_category  #I am my childrens' parent
    @nodes_by_parent_cat.select {|n| n[0] == childrens_parent_category}.map{|i| i.last}
  end
end

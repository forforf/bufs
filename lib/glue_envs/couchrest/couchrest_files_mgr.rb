#require helper for cleaner require statements
#require File.join(File.dirname(__FILE__), '../../helpers/require_helper')

#Bufs directory organization defined in lib/helpers/require_helper
require Bufs.glue 'couchrest/couchrest_attachment_handler'

module CouchrestInterface
  class FilesMgr

      attr_accessor :attachment_doc_class

      #not tested in factory tests, tested in couchrest though
      def self.get_att_doc(node)
        node_id = node._model_metadata[:_id]
        attachment_doc_id = node.my_GlueEnv.moab_data[:attachClass].uniq_att_doc_id(node_id)
        att_doc = node.my_GlueEnv.moab_data[:db].get(attachment_doc_id)
        if att_doc
          return att_doc
        else
          return nil 
        end
      end

      def initialize(node_env, node_key)
        #for bufs node_key is the value of :my_category
        #although it is not used in this class, it is required to 
        #maintain consitency with bufs_base_node
        #TODO: Actually the goal is for moab's to have no dependency on bufs_base_node
        #so maybe the glue environment should have a files interface to bufs_base_node??
        #@attachment_doc_class = node_env.attachClass  #old
        #TODO: just pass moab_data??
        @attachment_doc_class = node_env.moab_data[:attachClass]
      end

      def add_files(node, file_datas)
        bia_class = @attachment_doc_class
        attachment_package = {}
        file_datas = [file_datas].flatten
        file_datas.each do |file_data|
          #get file data
          src_filename = file_data[:src_filename]
          src_basename = BufsEscape.escape(File.basename(src_filename))
          raise "File data must include the source filename when adding a file to the model" unless src_filename
          model_basename = file_data[:model_basename] || src_basename
          model_basename.gsub!('+', ' ')  #plus signs are problematic
          #TODO: Consider creating BufsEscape.unescape method
          model_basename = CGI.unescape(model_basename)
          content_type = file_data[:content_type] || MimeNew.for_ofc_x(model_basename)
          modified_time = file_data[:modified_time] || File.mtime(src_filename).to_s
          #create attachment class data structure
          file_metadata = {}
          file_metadata['content_type'] = content_type
          file_metadata['file_modified'] = modified_time
          #read in file
          #TODO: reading the file in this way is memory intensive for large files, chunking it up would be better
          file_data = File.open(src_filename, "rb") {|f| f.read}
          attachment_package[model_basename] = {'data' => file_data, 'md' => file_metadata}
        end
        #attachment package has now been created
        #create the attachment record
        #The attachment handler (bia_class) will deal with creating vs updating
        user_id = node.my_GlueEnv.user_id
        node_id = node._model_metadata[:_id]
        #TODO: There is probably a cleaner way to do add attachments, but low on the priority list
        record = bia_class.add_attachment_package(node_id, bia_class, attachment_package)
        #get the basenames we just stored
        stored_basenames = record['_attachments'].keys
        if node.respond_to? :attachment_doc_id
          #make sure the objects attachment id matches the persistence layer's record id
          if node.attachment_doc_id && (node.attachment_doc_id != record['_id'] )
            raise "Attachment ID mismatch, current id: #{node.attachment_doc_id} new id: #{record['_id']}"
          #if the attachment id doesn't exist, create it
          elsif node.attachment_doc_id.nil?
            node.attachment_doc_id = record['_id']  #TODO How is it nil?
          else
            #we will reach here when everything is fine but we don't need to do anything
          end
        else #it's a new attachment and the attachment id has not been set, so we create and set it
          node.__set_userdata_key(:attachment_doc_id,  record['_id'] )
        end
        stored_basenames
      end

      def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
        bia_class = node.my_GlueEnv.moab_data[:attachClass]
        file_metadata = {}
        if file_modified_at
          file_metadata['file_modified'] = file_modified_at
        else
          file_metadata['file_modified'] = Time.now.to_s
        end
        file_metadata['content_type'] = content_type 
        attachment_package = {}
        unesc_attach_name = BufsEscape.unescape(attach_name)
        attachment_package[unesc_attach_name] = {'data' => raw_data, 'md' => file_metadata}
        node_id = node._model_metadata[:_id]
        record = bia_class.add_attachment_package(node_id, bia_class, attachment_package)
        if node.respond_to? :attachment_doc_id
          if node.attachment_doc_id && (node.attachment_doc_id != record['_id'] )
            raise "Attachment ID mismatch, current id: #{node.attachment_doc_id} new id: #{record['_id']}"
          elsif node.attachment_doc_id.nil?
            node.attachment_doc_id = record['_id']  #TODO How is it nil?
          end
        else
          node.__set_userdata_key(:attachment_doc_id,  record['_id'] )
        end
        [attach_name]
      end

      #TODO  Document the :all shortcut somewhere
      def subtract_files(node, model_basenames)
        bia_class = node.my_GlueEnv.moab_data[:attachClass]
        if model_basenames == :all
          subtract_all(node, bia_class)
        else
          subtract_some(node, model_basenames, bia_class)
        end
      end

      def get_raw_data(node, model_basename)
        bia_class = node.my_GlueEnv.moab_data[:attachClass]
        node_id = node._model_metadata[:_id]
        bia_doc_id = bia_class.uniq_att_doc_id(node_id)
        bia_doc = bia_class.get(bia_doc_id)
        bia_doc.fetch_attachment(model_basename)
      end

      def get_attachments_metadata(node)
        bia_class = node.my_GlueEnv.moab_data[:attachClass]
        node_id = node._model_metadata[:_id]
        bia_doc_id = bia_class.uniq_att_doc_id(node_id)
        bia_doc = bia_class.get(bia_doc_id)
        bia_doc.get_attachments
      end 


      #TODO: make private
      def subtract_some(node, model_basenames, bia_class)
        if node.attachment_doc_id
          bia_doc = bia_class.get(node.attachment_doc_id)
          raise "BiaClass_Attach: #{node.class.user_attachClass} Node: #{node.class.name} AttID: #{node.attachment_doc_id}" unless bia_doc
          bia_doc.remove_attachment(model_basenames)
          rem_atts = bia_doc.get_attachments
          subtract_all(node, bia_class) if rem_atts.empty?
        end
      end
      #TODO: make private
      def subtract_all(node, bia_class)
        #delete the attachment record
        doc_db = node.my_GlueEnv.moab_data[:db]
        if node.attachment_doc_id
          attach_doc = doc_db.get(node.attachment_doc_id)
          doc_db.delete_doc(attach_doc)
          node.__unset_userdata_key(:attachment_doc_id)
          node.__save
        else
          puts "Warning: Attempted to delete attachments when none existed"
        end
        node
      end
    end
  end
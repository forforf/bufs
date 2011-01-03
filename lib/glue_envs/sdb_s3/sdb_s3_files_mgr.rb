require 'aws/s3'

module AWS::S3
    class NoSuchBucket < ResponseError
    end
end

module SdbS3Interface

  class NilBucketError < StandardError
  end
  
  class FilesMgr
    include AWS
    AccessKey = ENV["AMAZON_ACCESS_KEY_ID"]
    SecretKey = ENV["AMAZON_SECRET_ACCESS_KEY"]

    BucketNamespacePrefix = 'forforf'
    
    @@s3_connection = S3::Base.establish_connection!(:access_key_id => AccessKey,
                                                                          :secret_access_key => SecretKey,
                                                                          :persistent => false)
    
    attr_accessor :attachment_bucket

    def initialize(glue_env, node_key_value)
      #@s3_connection = S3::Base.establish_connection!(:access_key_id => AccessKey,
      #                                                                    :secret_access_key => SecretKey)
      @bucket_name = "#{BucketNamespacePrefix}_#{glue_env.user_datastore_location}"
      @attachment_bucket = use_bucket(@bucket_name)
      #verify bucket is ready
      #puts "Previous Response: #{S3::Service.response}"
      #puts "#{__LINE__} - #{ S3::Service.buckets(true).map{|b| b.name} }"
      #puts "This Bucket: #{@attachment_bucket.name}"
      #puts "Last Response: #{S3::Service.response}"
      #size = @attachment_bucket.size
    end

    #TODO: Move common file management functions from base node to here
    def add_files(node, file_datas)
      filenames = []
      file_datas.each do |file_data|
        filenames << file_data[:src_filename]
      end

      filenames.each do |filename|
        basename = File.basename(filename)
        begin
          S3::S3Object.store(basename, open(filename), @bucket_name)
        rescue AWS::S3::NoSuchBucket
          puts "Rescued while adding files, retrying"
          retry_request { S3::S3Object.store(basename, open(filename), @bucket_name) }
        end
      end
      #verify files are there
      files = self.list_attachments
    
      filenames.each do |f|
        puts "Filename: #{f.inspect}"
        bname = File.basename(f)
        retry_request { S3::S3Object.store(bname, open(f), @bucket_name) } unless files.include?(bname)
      end
    end

    def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
      @moab_interface.add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
    end

    def subtract_files(node, file_basenames)
      if file_basenames == :all
        subtract_all
      else
        subtract_some(file_basenames)
      end
    end

    def get_raw_data(node, basename)
      rtn = nil

      begin
        rtn = S3::S3Object.value(basename, @bucket_name)
      rescue AWS::S3::NoSuchBucket
        puts "Rescued while getting raw data, bucket name: #{@bucket_name}"
        rtn = retry_request(basename, @bucket_name){|obj, buck| puts "sdbs3: #{obj.inspect} - #{buck.inspect}"; S3::S3Object.value(obj, buck)}
      end
      rtn
    end

    #todo change name to get_files_metadata
    def get_attachments_metadata(node)
      files_md = {}
      begin
        objects = @attachment_bucket.objects
      rescue  AWS::S3::NoSuchBucket
        puts "rescued while getting objects from bucket to check metadata"
        objects = retry_request{ @attachment_bucket.objects }
      end
      objects.each do |object|
        begin
          obj_md = object.about
        rescue AWS::S3::NoSuchBucket 
          puts "Rescued while getting metadata from object"
          obj_md = retry_request{object.about}
        end
        obj_md_file_modified = obj_md["last_modified"]
        obj_md_content_type = obj_md["content-type"]
        new_md = {:content_type => obj_md_content_type, :file_modified => obj_md_file_modified}
        new_md.merge(obj_md)  #where does the original metadata go?
        #p new_md.keys
        files_md[object.key] = new_md
        #puts "Obj METADATA: #{new_md.inspect}"
      end
      files_md
    end#def
    
    def list_objects
      list = nil
      begin
        list = @attachment_bucket.objects
      rescue AWS::S3::NoSuchBucket
        puts "Rescued while listing attachments"
        list = retry_request{@attachment_bucket.objects}
      end
      list
    end
    
    def list_attachments
      objs = list_objects
      atts = objs.map{|o| o.key} if objs
      atts || []
    end
    
    def destroy_file_container
      begin
        @attachment_bucket.delete(:force => true)
      rescue AWS::S3::NoSuchBucket
        puts "Running sanity check"
        buckets = S3::Service.buckets(true).map{|b| b.name}
        if buckets.include?(@bucket_name)
          puts "AWS temporarily lost bucket before finding it so it can be deleted"
          retry_request { @attachment_bucket.delete(:force => true) }
        end
      end
    end
    
    def subtract_some(file_basenames)
      file_basenames.each do |basename|
        p basename
        S3::S3Object.delete(basename, @attachment_bucket.name)
      end
    end
    
    def subtract_all
      #Changed behavior to leave bucket (this is different than other FileMgrs) 
      begin  
        aws_names = @attachment_bucket.objects
      rescue AWS::S3::NoSuchBucket
        aws_names = nil
        #aws_names = retry_request{@attachment_bucket.objects}
      end
      file_basenames = aws_names.map{|o| o.key} if aws_names
      self.subtract_some(file_basenames) if file_basenames
    end
  
    def retry_request(*args, &block)
      puts "RETRYING Request with block: #{block.inspect}"
      wait_time = 0.1
      backoff_delay = 1
      max_retries = 10
      
      resp = nil

      1.upto(max_retries) do |i|
        puts "Wating #{wait_time} secs to try again"
        sleep wait_time
        begin
          resp = yield *args
          raise TypeError, "Response was Nil, retrying" unless resp
          break
        rescue AWS::S3::NoSuchKey => e
          raise e  #we want to raise this one"
        rescue AWS::S3::ResponseError => e 
          puts "rescued #{e.inspect}"
          backoff_delay += backoff_delay# * i
          wait_time += backoff_delay
          if (wait_time > 3) && (e.class == AWS::S3::NoSuchBucket)
            puts "Attempting to reset bucket"
            @attachment_bucket = use_bucket(@bucket_name)
          end
          next
        end#begin-rescue
      end#upto
      
      
    end#def
    
    private
    
    def use_bucket(bucket_name)
      begin
        bucket = S3::Bucket.find(bucket_name)
      rescue (AWS::S3::NoSuchBucket||NilBucketError) => e
        begin
          puts "Rescued error in use_bucket: #{e.inspect}"
          S3::Bucket.create(bucket_name)
          bucket = S3::Bucket.find(bucket_name)
        rescue AWS::S3::NoSuchBucket #we just made it!!
          bucket = retry_request(bucket_name){|buck_name| S3::Bucket.find(buck_name)}
        end#inner begin-rescue
      end#outer begin-rescue
      
      #verify bucket exists
      found_buckets = S3::Service.buckets(true).map{|b| b.name}
      unless found_buckets.include?(bucket_name)
        #bucket = retry(:retry_block, bucket_name){|buck_name| S3::Bucket.find(buck_name)}
      end#unless
      unless bucket
        puts "NIL Bucket cannot be returned"
        retry_request(bucket_name){|buck_name| S3::Bucket.find(buck_name)}
      end
      raise(NilBucketError, "NIL Bucket cannot be returned",nil) unless bucket
      return bucket
    end#def
    
  end#class
end#module
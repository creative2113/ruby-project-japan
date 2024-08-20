class S3Handler
  def initialize
    region = 'ap-northeast-1'
    @client = Aws::S3::Client.new(region: region)
  end

  def upload(s3_path:, file_path:)
    object_uploaded?(s3_path, file_path)
  end

  def download(s3_path:, output_path: nil)
    bucket, key = make_bucket_and_key(s3_path)
    if output_path.present?
      output_path = output_path + key.split('/')[-1] if output_path[-1] == '/'
      @client.get_object(response_target: output_path, bucket: bucket, key: key)
    else
      @client.get_object(bucket: bucket, key: key)
    end
  end

  def exist_object?(s3_path:)
    bucket, key = make_bucket_and_key(s3_path)
    res = @client.list_objects_v2({
      bucket: bucket,
      max_keys: 1,
      prefix: key
    })
    res.contents[0].present? && res.contents[0].key == key
  end

  def get_list(s3_path:)
    bucket, key = make_bucket_and_key(s3_path)
    res = @client.list_objects_v2({
      bucket: bucket,
      prefix: key
    })
    res.contents
  end

  def get_list_keys(s3_path:)
    res = get_list(s3_path: s3_path)
    res.map { |con| con.key }
  end

  def delete(s3_path: nil, bucket: nil, key: nil)
    bucket, key = make_bucket_and_key(s3_path) if s3_path.present?
    resp = @client.delete_object({
      bucket: bucket,
      key: key
    })
  end

  private

  def make_bucket_and_key(s3_path)
    bucket = s3_path.split('/')[0]
    key    = s3_path.cut_front("#{bucket}/")
    [bucket, key]
  end

  def object_uploaded?(s3_path, file_path)
    bucket, key = make_bucket_and_key(s3_path)

    response = @client.put_object(
      bucket: bucket,
      key: key,
      body: File.open(file_path))

    if response.etag
      return true
    else
      raise response.etag.to_s
    end
  rescue StandardError => e
    puts "Error uploading object: #{e.message}"
    Lograge.logging('error', { class: self.class.to_s, method: 'object_uploaded?', issue: 'S3 File Upload Error', err_msg: e.message, backtrace: e.backtrace })
    return false
  end
end

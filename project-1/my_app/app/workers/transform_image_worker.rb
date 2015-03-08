class TransformImageWorker
  include Sidekiq::Worker

  def perform(image_id, key)
    image = Image.find image_id
    return if image.key_uploaded?(key)

    width, height = Image.transform_params_for_key(key)
    Rails.logger.debug "[TransformImageWorker] Transforming image #{image_id} to #{width} x #{height}"

    # If the original is not present on-disk then download it from S3
    path = image.tempfile_path
    unless File.exists?(path)
      tempfile = Tempfile.new("#{image_id}-#{key.to_s}-")

      s3_object = Image.s3_object_for_key(image.s3_key_for_original)
      raise "Image #{image_id} has not uploaded its original!" unless s3_object.exists?

      tempfile.write(s3_object.read)
      tempfile.close

      thumb = MiniMagick::Image.open(tempfile.path)  # open creates a copy of the image
      tempfile.unlink
    else
      thumb = MiniMagick::Image.open(path)  # open creates a copy of the image
    end

    thumb.resize "#{width}x#{height}"
    # thumb.format "png" # force to PNG?
    # thumb.path #prints the path of the copied image

    # Upload to S3
    thumb_key = image.s3_key_for_thumb(key)
    object = Image.s3_object_for_key(thumb_key)
    object.write(:file => thumb.path)

    # FIXME: if the Image was destroyed prior to this finishing then we need to delete the S3 object

    image.update_attribute(key, object.key)
  end
end
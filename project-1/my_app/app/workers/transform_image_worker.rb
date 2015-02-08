class TransformImageWorker
  include Sidekiq::Worker

  def perform(image_id, key, width, height)
    logger.debug "[TransformImageWorker] Transforming image #{image_id} to #{width} x #{height}"

    image = Image.find image_id
    return if image.send(key).present?

    raise "Image #{image_id} tempfile does not exist: #{image.tempfile_path}" unless File.exists?(image.tempfile_path)

    if Image::FAKE_UPLOADS
      image.update_attribute(key, image.key1)
      return
    end

    logger.debug "[TransformImageWorker] Transforming image #{image_id} to #{width} x #{height}"
    thumb = MiniMagick::Image.open(image.tempfile_path)  # open creates a copy of the image
    thumb.resize "#{width}x#{height}"
    # thumb.format "png" # force to PNG?
    # thumb.path #prints the path of the copied image

    # Upload to S3
    object = Image.s3_object_for_key(key)
    obj.write(:file => tmpfile)

    # FIXME: if the Image was destroyed prior to this finishing then we need to delete the S3 object

    image.update_attribute(key, object.key)
  end
end
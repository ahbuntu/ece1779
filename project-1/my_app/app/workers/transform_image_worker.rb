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

    file = File.open(image.tempfile_path)
    object = Image.s3_object_for_key(key)

    # TODO: image transforms
    logger.debug "[TransformImageWorker] Transforming image #{image_id} to #{width} x #{height}"

    # FIXME: if the Image was destroyed prior to this finishing then we need to delete the S3 object

    image.update_attribute(key, object.key)
  end
end
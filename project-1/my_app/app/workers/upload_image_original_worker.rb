class UploadImageOriginalWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :critical

  def perform(image_id)
    image = Image.find image_id
    Rails.logger.debug "[UploadImageOriginalWorker] Uploading Image #{image_id} from #{image.tempfile_path} to S3..."

    # hack for testing
    if Image::FAKE_UPLOADS
      image.update_attribute(:key1, image.uuid)
      image.dispatch_image_transformations!
      return
    end

    object = Image.s3_object_for_key(image.s3_key_for_original)

    # FIXME: if the Image is destroyed before this job is dispatched then the following will raise an exception

    file = File.open(image.tempfile_path, "r")
    object.write(:file => file)
    # TODO: needs error handling
    file.close

    image.key1 = object.key
    image.save!
    image.dispatch_image_transformations!
  end
end

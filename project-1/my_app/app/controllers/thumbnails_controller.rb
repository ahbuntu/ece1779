class ThumbnailsController < ApplicationController

  def show
    image = Image.find params[:image_id]
    key = params[:id]

    unless image.key_uploaded?(key)
      # force the image processing, synchronously
      Rails.logger.info "Forcing thumbnail generation for Image #{image.id} (key: :#{key})"
      TransformImageWorker.new.perform(image.id, key)
      image.reload
    end

    url_expiry = 10.minutes.to_i
    object = Image.s3_object_for_key(image.send(key))
    url = object.url_for(:read, :expires => url_expiry)
    redirect_to url.to_s
  end

end

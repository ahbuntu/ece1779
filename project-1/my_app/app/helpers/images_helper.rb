module ImagesHelper
  def thumbnail_for_image(i)
    Image.s3_object_for_key(i.key2).url_for(:read)
  end
end

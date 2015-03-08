module ImagesHelper
  def thumbnail_preview_url_for_image(i)
    user_image_thumbnail_path(current_user, i, "key2")
  end
end

class TransformImageWorker
  include Sidekiq::Worker

  def perform(image_id, width, height)
    image = Image.find image_id
    puts "Transforming image #{image_id} to #{width} x #{height}"
    # AWS::S3::S3Object.store(file, open(file), bucket)
    # write the URL back to image.keyX
  end
end
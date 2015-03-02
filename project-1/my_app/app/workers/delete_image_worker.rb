class DeleteImageWorker
  include Sidekiq::Worker

  def perform(key)
    return if key.nil?
    Rails.logger.debug "[DeleteImageWorker] Deleting asset located at #{key}"
    Image.s3_object_for_key(key).destroy
  end
end

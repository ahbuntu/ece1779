class ClearS3BucketWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :critical

  def perform
    count = Image.s3_bucket.objects.count
    if count > 0
      Rails.logger.info "[ClearS3BucketWorker] #{count} S3 objects remaining..."
      versions = Image.s3_bucket.versions.take(1000) # delete in batches of 1000
      if version.any?
        Image.s3_bucket.objects.delete(versions)
        ClearS3BucketWorker.perform_async
        return
      end
    end
    Rails.logger.info "[ClearS3BucketWorker] DONE"
  end
end

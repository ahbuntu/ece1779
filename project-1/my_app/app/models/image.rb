class Image < ActiveRecord::Base

  FAKE_UPLOADS = false # for testing

  belongs_to :user, foreign_key: "userId"

  validates :user, presence: true

  validates :uuid, presence: true, uniqueness: true # , allow_nil: true

  after_commit   :dispatch_upload_job, on: :create
  after_save     :check_and_delete_tmpfile_after_transformations
  before_destroy :delete_assets
  before_destroy :delete_tempfile

  cattr_reader   :uuid_generator

  ### Accessors

  # Save the upload to a file that the various upload/transform jobs use
  def file=(value)
    if value == nil
      delete_tempfile
    else
      tempfile = File.new(tempfile_path, "wb+")
      tempfile.write(value.read)
      tempfile.close
    end
  end

  def uuid
    unless u = read_attribute(:uuid)
      self.uuid = u = Image.uuid_generator.generate
    end
    u
  end

  ### Helpers

  def s3_base_key
    File.join("images", user.id.to_s, self.id.to_s)
  end

  def s3_key(filename)
    File.join(s3_base_key, filename)
  end

  def s3_key_for_thumb(key)
    s3_key("#{key.to_s}#{extension}")
  end

  def s3_key_for_original
    s3_key("original#{extension}")
  end

  def self.s3_bucket_name
    YAML.load(File.read('config/aws.yml'))[Rails.env.to_s]["bucket"]
  end

  def self.s3_bucket
    @bucket ||= AWS::S3.new.buckets[Image.s3_bucket_name]
  end

  def self.s3_object_for_key(key)
    Image.s3_bucket.objects[key] 
  end

  def tempfile_path
    uuid.present? ? File.join(Dir.tmpdir, uuid) : nil
  end

  def dispatch_image_transformations!
    Rails.logger.info "[Image] Dispatching TransformImageWorker jobs"
    self.key2.nil? && TransformImageWorker.perform_async(id, :key2, 100, 100)
    self.key3.nil? && TransformImageWorker.perform_async(id, :key3, 200, 200)
    self.key4.nil? && TransformImageWorker.perform_async(id, :key4, 300, 300)
  end

  private

  def image_keys
    [:key1, :key2, :key3, :key4]
  end

  def original_uploaded_to_s3?
    self.key1.present?
  end

  def dispatch_upload_job
    Rails.logger.info "[Image] Dispatching UploadImageOriginalWorker job"
    UploadImageOriginalWorker.perform_async(self.id)
  end

  def delete_assets
    Rails.logger.debug "Deleting Image #{id} assets"
    image_keys.each do |k|
      v = self.send(k) && DeleteImageWorker.perform_async(v)
    end
    true
  end

  def delete_tempfile
    Rails.logger.debug "KEYS: " + image_keys.map{|k| send(k)}.join(", ")
    Rails.logger.debug "Deleting tempfile? #{tempfile_path} for Image #{id}"
    unless !File.exists?(tempfile_path)
      Rails.logger.info "Deleting Image #{id} tempfile: #{tempfile_path}"
      File.unlink(tempfile_path)
    end
  end

  def check_and_delete_tmpfile_after_transformations
    if image_keys.all?{|k| send(k).present?}
      delete_tempfile
    end
    true
  end

  def self.uuid_generator
    @@uuid_generator ||= UUID.new
  end

end

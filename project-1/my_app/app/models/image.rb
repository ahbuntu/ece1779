class Image < ActiveRecord::Base
  belongs_to :user, foreign_key: "userId"

  validates :user, presence: true

  after_commit :dispatch_image_transforms, on: :create

  private

  def dispatch_image_transforms
    # just some sample transforms
    TransformImageWorker.perform_async(id, 100, 100)
    TransformImageWorker.perform_async(id, 200, 200)
    TransformImageWorker.perform_async(id, 300, 300)
  end
end

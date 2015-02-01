class User < ActiveRecord::Base
  has_many :images, foreign_key: "userID"
  validates :login, presence: true, uniqueness: true
  validates :password, presence: true
end

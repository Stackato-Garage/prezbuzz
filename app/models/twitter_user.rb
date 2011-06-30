class TwitterUser < ActiveRecord::Base
  has_many :tweets
  validates_presence_of :userName
  validates_presence_of :userId
  validates_uniqueness_of :userId
end

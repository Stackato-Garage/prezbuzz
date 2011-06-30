class Tweet < ActiveRecord::Base
  belongs_to :twitter_users, :class_name => :TwitterUser
  has_and_belongs_to_many :hashtags
  has_and_belongs_to_many :candidates
  validates_uniqueness_of :tweetId
end

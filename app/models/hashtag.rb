class Hashtag < ActiveRecord::Base
  has_and_belongs_to_many :tweets
  validates_presence_of :hashtag
  validates_uniqueness_of :hashtag
end

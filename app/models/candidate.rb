class Candidate < ActiveRecord::Base
  has_and_belongs_to_many :tweets
  validates_presence_of :firstName
  validates_presence_of :lastName
end

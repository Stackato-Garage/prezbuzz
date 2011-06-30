class HashtagsTweets < ActiveRecord::Migration
  def self.up
    create_table :hashtags_tweets, :id => false do |t|
      t.integer :hashtag_id
      t.integer :tweet_id
    end 
  end

  def self.down
    drop_table :hashtags_tweets
  end
end

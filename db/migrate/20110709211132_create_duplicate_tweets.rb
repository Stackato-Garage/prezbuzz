class CreateDuplicateTweets < ActiveRecord::Migration
  def self.up
    create_table :duplicate_tweets do |t|
      t.integer :orig_tweet_id
      t.integer :tweetId
    end
    add_index :duplicate_tweets, :tweetId
    add_index :duplicate_tweets, :orig_tweet_id
  end

  def self.down
    drop_table :duplicate_tweets
  end
end

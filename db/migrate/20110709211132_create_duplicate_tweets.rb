class CreateDuplicateTweets < ActiveRecord::Migration
  def self.up
    create_table :duplicate_tweets do |t|
      t.integer :orig_tweet_id # ID for the tweet in the tweets table
      t.string  :tweetId       # twitter long ID for the tweet, not used yet.
      t.datetime :publishedAt
    end
    add_index :duplicate_tweets, :tweetId
    add_index :duplicate_tweets, :orig_tweet_id
    add_index :tweets, :publishedAt
  end

  def self.down
    drop_table :duplicate_tweets
  end
end

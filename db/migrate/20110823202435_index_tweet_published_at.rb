class IndexTweetPublishedAt < ActiveRecord::Migration
  def self.up
    add_index :tweets, :publishedAt
    add_index :duplicate_tweets, :orig_tweet_id
  end

  def self.down
    remove_index :duplicate_tweets, :orig_tweet_id
    remove_index :tweets, :publishedAt
  end
end

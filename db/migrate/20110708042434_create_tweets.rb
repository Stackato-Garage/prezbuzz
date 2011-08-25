class CreateTweets < ActiveRecord::Migration
  def self.up
    create_table :tweets do |t|
      t.string :text
      t.string :textKernel
      t.string :tweetId
      t.integer :twitter_user_id
      t.integer :sentimentScore
      t.integer :positiveWordCount
      t.integer :negativeWordCount
      t.datetime :publishedAt
    end
    add_index :tweets, :textKernel
    add_index :tweets, :tweetId
    add_index :tweets, :twitter_user_id
    add_index :tweets, :publishedAt
  end

  def self.down
    drop_table :tweets
  end
end

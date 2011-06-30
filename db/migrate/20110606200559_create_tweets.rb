class CreateTweets < ActiveRecord::Migration
  def self.up
    create_table :tweets do |t|
      t.string :text
      t.string :tweetId
      t.integer :twitter_user_id
      t.datetime :publishedAt

      t.timestamps
    end
    add_index :tweets, :publishedAt
  end

  def self.down
    drop_table :tweets
  end
end

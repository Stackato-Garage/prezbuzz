class CandidatesTweets < ActiveRecord::Migration
  def self.up
    create_table :candidates_tweets, :id => false do |t|
      t.integer :candidate_id
      t.integer :tweet_id
    end 
    add_index :candidates_tweets, :candidate_id
    add_index :candidates_tweets, :tweet_id
  end

  def self.down
    drop_table :candidates_tweets
  end
end

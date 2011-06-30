class CreateTwitterUsers < ActiveRecord::Migration
  def self.up
    create_table :twitter_users do |t|
      t.string :userName
      t.string :userId
      t.string :profileImageUrl
      t.timestamps
    end
  end

  def self.down
    drop_table :twitter_users
  end
end

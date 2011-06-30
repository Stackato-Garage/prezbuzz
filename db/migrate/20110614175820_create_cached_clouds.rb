class CreateCachedClouds < ActiveRecord::Migration
  def self.up
    create_table :cached_clouds do |t| 
      t.datetime :startTime
      t.datetime :endTime
      t.integer       :candidateId
      t.text     :json_word_cloud
    end
    add_index(:cached_clouds, [:startTime, :endTime, :candidateId])
  end

  def self.down
    drop_table :cached_clouds
  end
end

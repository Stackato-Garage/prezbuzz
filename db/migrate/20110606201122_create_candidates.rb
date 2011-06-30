class CreateCandidates < ActiveRecord::Migration
  def self.up
    create_table :candidates do |t|
      t.string :firstName
      t.string :lastName
      t.string :color, :limit => 6, :default => "ffffff"
      t.timestamps
    end
  end

  def self.down
    drop_table :candidates
  end
end

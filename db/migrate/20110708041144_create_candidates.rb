class CreateCandidates < ActiveRecord::Migration
  def self.up
    create_table :candidates do |t|
      t.string :firstName
      t.string :lastName
      t.string :color, :limit => 6, :default => "ffffff"
    end
  end

  def self.down
    drop_table :candidates
  end
end

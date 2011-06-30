class CreateStopWords < ActiveRecord::Migration
  def self.up
    create_table :stop_words do |t|
      t.string :word
      t.timestamps
    end
    add_index(:stop_words, :word)
  end

  def self.down
    drop_table :stop_words
  end
end

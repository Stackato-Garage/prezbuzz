class CreatePositiveWords < ActiveRecord::Migration
  def self.up
    create_table :positive_words do |t|
      t.string :word
    end
    add_index(:positive_words, :word)
  end

  def self.down
    drop_table :positive_words
  end
end

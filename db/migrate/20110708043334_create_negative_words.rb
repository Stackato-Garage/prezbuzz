class CreateNegativeWords < ActiveRecord::Migration
  def self.up
    create_table :negative_words do |t|
      t.string :word
    end
    add_index(:negative_words, :word)
  end

  def self.down
    drop_table :negative_words
  end
end

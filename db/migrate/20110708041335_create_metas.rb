class CreateMetas < ActiveRecord::Migration
  def self.up
    create_table :metas do |t|
      t.datetime :processTime
    end
  end

  def self.down
    drop_table :metas
  end
end

class CreateFileCounters < ActiveRecord::Migration[5.2]
  def change
    create_table :file_counters do |t|
      t.string  :directory_path,               unique: true
      t.integer :count,            default: 0
      t.integer :one_before_count, default: 0

      t.timestamps
    end
  end
end

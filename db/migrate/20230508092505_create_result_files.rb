class CreateResultFiles < ActiveRecord::Migration[6.1]
  def change
    create_table :result_files do |t|
      t.string :path
      t.integer :status, null: false, default: 0
      t.date :expiration_date
      t.text :fail_files
      t.boolean :deletable, null: false, default: false, index: true
      t.bigint :start_row
      t.bigint :end_row
      t.bigint :request_id, null: false, index: true

      t.timestamps
    end

    add_index :result_files, [:created_at]
  end
end

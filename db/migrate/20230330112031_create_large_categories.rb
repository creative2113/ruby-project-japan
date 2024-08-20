class CreateLargeCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :large_categories do |t|
      t.string :name, null: false, index: { unique: true }
      t.integer :sort, null: false, default: 0, index: true

      t.timestamps
    end
  end
end

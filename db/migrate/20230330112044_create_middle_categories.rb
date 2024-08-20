class CreateMiddleCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :middle_categories do |t|
      t.string :name, null: false, index: { unique: true }

      t.timestamps
    end
  end
end

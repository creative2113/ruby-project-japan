class CreateDetailCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :detail_categories do |t|
      t.string :name, null: false, index: { unique: true }

      t.timestamps
    end
  end
end

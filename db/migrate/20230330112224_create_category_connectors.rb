class CreateCategoryConnectors < ActiveRecord::Migration[6.1]
  def change
    create_table :category_connectors do |t|
      t.bigint  :large_category_id, null: false
      t.bigint  :middle_category_id
      t.bigint  :small_category_id
      t.bigint  :detail_category_id
      t.integer :count,             default: 0

      t.timestamps
    end

    add_index :category_connectors, [:large_category_id, :middle_category_id, :small_category_id, :detail_category_id], unique: true, name: 'index_category_connectors'
  end
end

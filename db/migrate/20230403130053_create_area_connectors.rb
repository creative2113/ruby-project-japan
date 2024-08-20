class CreateAreaConnectors < ActiveRecord::Migration[6.1]
  def change
    create_table :area_connectors do |t|
      t.bigint  :region_id,       null: false
      t.bigint  :prefecture_id
      t.bigint  :city_id
      t.integer :count,           default: 0

      t.timestamps
    end

    add_index :area_connectors, [:region_id, :prefecture_id, :city_id], unique: true, name: 'index_area_connectors'
  end
end

class CreateBillingHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :billing_histories do |t|
      t.string :item_name, null: false
      t.bigint :price, null: false
      t.text :memo
      t.date :billing_date, null: false
      t.bigint :unit_price, null: false
      t.integer :number, null: false
      t.integer :payment_method, null: false
      t.references :billing, null: false, index: true

      t.timestamps
    end

    add_index :billing_histories, [:billing_id, :billing_date]
    add_index :billing_histories, [:payment_method, :billing_date]
  end
end

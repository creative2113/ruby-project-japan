class CreateBillingPlans < ActiveRecord::Migration[6.1]
  def change
    create_table :billing_plans do |t|
      t.string :name
      t.text :memo
      t.bigint :price, null: false
      t.integer :type, null: false
      t.string :charge_date, null: false
      t.integer :status, null: false
      t.datetime :start_at, null: false
      t.datetime :end_at
      t.boolean :tax_included
      t.integer :tax_rate
      t.boolean :trial, null: false, default: false
      t.date :next_charge_date, index: true
      t.date :last_charge_date
      t.references :billing, null: false, index: true

      t.timestamps
    end

    add_index :billing_plans, [:billing_id, :start_at, :end_at]
  end
end

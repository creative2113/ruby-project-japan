class CreateMasterBillingPlans < ActiveRecord::Migration[6.1]
  def change
    create_table :master_billing_plans do |t|
      t.string :name, null: false
      t.text :memo
      t.bigint :price, null: false
      t.integer :type, null: false
      t.datetime :start_at
      t.datetime :end_at
      t.datetime :application_start_at
      t.datetime :application_end_at
      t.boolean :enable
      t.boolean :application_available
      t.boolean :tax_included
      t.integer :tax_rate

      t.timestamps
    end
  end
end

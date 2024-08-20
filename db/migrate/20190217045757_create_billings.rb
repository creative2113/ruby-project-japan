class CreateBillings < ActiveRecord::Migration[5.2]
  def change
    create_table :billings do |t|
      t.integer    :plan
      t.integer    :last_plan
      t.integer    :next_plan
      t.integer    :status
      t.integer    :payment_method
      t.datetime   :first_paid_at
      t.datetime   :last_paid_at
      t.datetime   :expiration_date
      t.string     :customer_id
      t.string     :subscription_id
      t.boolean    :strange
      t.references :user,            index: true, foreign_key: true

      t.timestamps
    end
  end
end

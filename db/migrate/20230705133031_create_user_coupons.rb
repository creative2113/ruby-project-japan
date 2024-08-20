class CreateUserCoupons < ActiveRecord::Migration[6.1]
  def change
    create_table :user_coupons do |t|
      t.bigint  :user_id
      t.bigint  :coupon_id
      t.integer :count

      t.timestamps
    end

    add_index :user_coupons, [:user_id, :coupon_id] 
  end
end

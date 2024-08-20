class CreateCoupons < ActiveRecord::Migration[6.1]
  def change
    create_table :coupons do |t|
      t.string  :title, null: false, index: true, unique: true
      t.text    :description
      t.integer :limit, default: 0
      t.string  :code, index: true
      t.integer :category

      t.timestamps
    end
  end
end

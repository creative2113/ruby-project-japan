class CreateReferrers < ActiveRecord::Migration[6.1]
  def change
    create_table :referrers do |t|
      t.string :name, null: false
      t.string :email
      t.string :code, null: false

      t.timestamps
    end

    add_index :referrers, :code, unique: true
    add_index :referrers, :email
  end
end

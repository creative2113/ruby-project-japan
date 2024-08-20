class CreateBanConditions < ActiveRecord::Migration[6.1]
  def change
    create_table :ban_conditions do |t|
      t.string  :memo
      t.string  :ip
      t.string  :mail
      t.integer :ban_action, null: false, default: 0

      t.timestamps
    end

    add_index :ban_conditions, [:ip, :mail, :ban_action]
  end
end

class CreateAllowIps < ActiveRecord::Migration[6.1]
  def change
    create_table :allow_ips do |t|
      t.string :name,    null: false
      t.text   :ips
      t.bigint :user_id,              index: true

      t.timestamps
    end
  end
end

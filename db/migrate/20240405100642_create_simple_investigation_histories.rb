class CreateSimpleInvestigationHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :simple_investigation_histories do |t|
      t.text :url, null: false
      t.string :domain, index: true
      t.text :memo
      t.boolean :resolved, default: false
      t.bigint :new_request_id
      t.bigint :request_id, null: false
      t.bigint :user_id, null: false

      t.timestamps
    end

    add_index :simple_investigation_histories, [:user_id, :request_id]
  end
end

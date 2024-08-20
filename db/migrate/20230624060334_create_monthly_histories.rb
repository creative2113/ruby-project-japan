class CreateMonthlyHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :monthly_histories do |t|
      t.integer  :plan, null: false
      t.text     :memo
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.integer  :search_count, default: 0
      t.integer  :request_count, default: 0
      t.integer  :acquisition_count, default: 0
      t.bigint   :user_id, null: false, index: true

      t.timestamps
    end
  end
end

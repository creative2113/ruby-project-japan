class AddColumnsToRequest < ActiveRecord::Migration[6.1]
  def change
    add_column :requests, :plan, :integer, null: false, default: 0, after: :test
  end
end

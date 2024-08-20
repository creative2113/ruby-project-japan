class AddColumnToBanConditions < ActiveRecord::Migration[6.1]
  def change
    add_column :ban_conditions, :count, :integer, default: 0, null: false, after: :ban_action
    add_column :ban_conditions, :last_acted_at, :datetime, after: :count
  end
end

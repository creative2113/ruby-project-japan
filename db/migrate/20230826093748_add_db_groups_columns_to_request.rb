class AddDbGroupsColumnsToRequest < ActiveRecord::Migration[6.1]
  def change
    add_column :requests, :db_groups, :text, default: nil, after: :db_areas
    add_column :company_company_groups, :source, :string, default: nil, after: :company_group_id
    add_column :company_company_groups, :expired_at, :datetime, default: nil, after: :source

    change_column :company_groups, :grouping_number, :integer, null: false
  end
end

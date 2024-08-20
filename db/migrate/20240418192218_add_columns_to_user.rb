class AddColumnsToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :family_name, :string, after: :company_name
    add_column :users, :given_name, :string, after: :family_name
    add_column :users, :department, :string, after: :given_name
    add_column :users, :position, :integer, after: :department
    add_column :users, :tel, :string, after: :position
  end
end

class AddColumnsToResultFile < ActiveRecord::Migration[6.1]
  def change
    add_column :result_files, :parameters, :longtext, after: :end_row
    add_column :result_files, :phase, :string, after: :parameters
    add_column :result_files, :final, :boolean, default: false, null: false, after: :phase
    add_column :result_files, :started_at, :datetime, after: :final
  end
end

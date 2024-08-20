class AddFileTypeToResultFile < ActiveRecord::Migration[6.1]
  def change
    add_column :result_files, :file_type, :integer, default: 0, after: :path
  end
end

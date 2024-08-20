class AddColumnOnlyPagingToRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :requests, :paging_mode, :integer, default: 0, after: :multi_path_analysis
    remove_column :requests, :only_this_page, :boolean, default: false, after: :multi_path_analysis
  end
end

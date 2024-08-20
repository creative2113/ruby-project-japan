class ChangeDataTypeOfUrlsOfTables < ActiveRecord::Migration[6.1]
  def up
    change_column :requests, :corporate_list_site_start_url, :text
  end

  def down
    change_column :requests, :corporate_list_site_start_url, :string
  end
end

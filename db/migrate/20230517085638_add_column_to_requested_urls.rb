class AddColumnToRequestedUrls < ActiveRecord::Migration[6.1]
  def change
    add_column :requested_urls, :arrange_status, :integer, default: 0, after: :status
    add_column :requested_urls, :corporate_list_url_id, :bigint, after: :request_id
    add_index :requested_urls, [:request_id, :corporate_list_url_id]
    add_column :requests, :only_list_crawl, :boolean, default: false, after: :paging_mode
  end
end

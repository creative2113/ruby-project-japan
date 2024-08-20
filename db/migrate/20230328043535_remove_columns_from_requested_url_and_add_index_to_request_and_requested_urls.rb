class RemoveColumnsFromRequestedUrlAndAddIndexToRequestAndRequestedUrls < ActiveRecord::Migration[6.1]
  def change
    remove_column :requested_urls, :free_search_result, :text, after: :retry_count
    remove_column :requested_urls, :candidate_crawl_urls, :longtext, after: :retry_count
    remove_column :requested_urls, :single_url_ids, :text, after: :retry_count
    remove_column :requested_urls, :result, :longtext, after: :retry_count
    remove_column :requested_urls, :corporate_list_result, :longtext, after: :retry_count

    add_index :requested_urls, [:type, :status, :test]
    add_index :requested_urls, :finish_status

    add_index :requests, :status
    add_index :requests, [:expiration_date, :updated_at]
  end
end

class CreateRequestedUrls < ActiveRecord::Migration[5.2]
  def change
    create_table :requested_urls do |t|
      t.text       :url
      t.text       :domain
      t.boolean    :test
      t.text       :organization_name
      t.string     :type
      t.integer    :status
      t.integer    :finish_status
      t.integer    :retry_count, default: 0
      t.text       :free_search_result
      t.longtext   :candidate_crawl_urls
      t.text       :single_url_ids
      t.longtext   :result
      t.longtext   :corporate_list_result
      t.references :request, index: true, foreign_key: true

      t.timestamps
    end

    add_index :requested_urls, :url, length: 255
  end
end

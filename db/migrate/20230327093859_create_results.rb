class CreateResults < ActiveRecord::Migration[6.1]
  def change
    create_table :results do |t|
      t.text       :free_search
      t.longtext   :candidate_crawl_urls
      t.text       :single_url_ids
      t.longtext   :main
      t.longtext   :corporate_list
      t.references :requested_url, index: true

      t.timestamps
    end
  end
end

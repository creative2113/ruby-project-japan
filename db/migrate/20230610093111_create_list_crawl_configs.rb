class CreateListCrawlConfigs < ActiveRecord::Migration[6.1]
  def change
    create_table :list_crawl_configs do |t|
      t.string     :domain, null: false, index: true
      t.string     :domain_path
      t.text       :corporate_list_config
      t.text       :corporate_individual_config
      t.mediumtext :analysis_result

      t.timestamps
    end
  end
end

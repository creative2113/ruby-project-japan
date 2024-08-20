class AddColumnsToListCrawlConfig < ActiveRecord::Migration[6.1]
  def change
    add_column :list_crawl_configs, :class_name, :string, after: :analysis_result
    add_column :list_crawl_configs, :process_result, :boolean, default: false, after: :class_name
  end
end

class ChangeSettingsToPreferences < ActiveRecord::Migration[6.1]
  def change
    rename_table :settings, :preferences

    remove_column :users, :setting_id, :bigint
    add_column :preferences, :advanced_setting_for_crawl, :boolean, default: false, null: false, after: :search_words
    add_column :preferences, :user_id, :bigint, null: false, after: :advanced_setting_for_crawl
  end
end

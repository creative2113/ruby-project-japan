class AddRequestedUrlsCountToRequests < ActiveRecord::Migration[6.1]
  def self.up
    add_column :requests, :requested_urls_count, :integer, null: false, default: 0, after: :user_id
  end

  def self.down
    remove_column :requests, :requested_urls_count
  end
end

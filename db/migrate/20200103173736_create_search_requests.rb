class CreateSearchRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :search_requests do |t|
      t.text       :url
      t.text       :domain
      t.string     :accept_id,          index: true, unique: true
      t.integer    :status
      t.integer    :finish_status
      t.boolean    :use_storage
      t.integer    :using_storage_days
      t.boolean    :free_search
      t.string     :link_words
      t.string     :target_words
      t.text       :free_search_result
      t.references :user,               index: true, foreign_key: true

      t.timestamps
    end
  end
end

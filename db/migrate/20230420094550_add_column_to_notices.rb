class AddColumnToNotices < ActiveRecord::Migration[6.1]
  def change
    add_column :notices, :top_page, :boolean, default: false, after: :opened_at
    add_index :notices, [:display, :opened_at, :top_page]
  end
end

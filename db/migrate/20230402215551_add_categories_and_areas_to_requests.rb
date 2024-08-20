class AddCategoriesAndAreasToRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :requests, :db_areas, :text, after: :using_storage_days
    add_column :requests, :db_categories, :text, after: :using_storage_days
  end
end

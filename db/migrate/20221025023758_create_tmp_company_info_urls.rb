class CreateTmpCompanyInfoUrls < ActiveRecord::Migration[6.1]
  def change
    create_table :tmp_company_info_urls do |t|
      t.integer    :bunch_id, null: false
      t.text       :url
      t.text       :domain
      t.text       :organization_name
      t.longtext   :result
      t.longtext   :corporate_list_result
      t.references :request, index: true, foreign_key: true

      t.timestamps
    end

     add_index :tmp_company_info_urls, [:request_id, :bunch_id]
  end
end

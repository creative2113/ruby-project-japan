class AddResultFileIdColumnToTmpCompanyInfo < ActiveRecord::Migration[6.1]
  def change
    add_column :tmp_company_info_urls, :result_file_id, :bigint, after: :request_id
    remove_index :tmp_company_info_urls, [:request_id, :bunch_id]
    add_index :tmp_company_info_urls, [:request_id, :bunch_id, :result_file_id], name: 'index_tmp_company_info_urls'
  end
end

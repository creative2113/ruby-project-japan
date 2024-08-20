class CreateRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :requests do |t|
      t.string     :title
      t.string     :file_name
      t.integer    :status
      t.string     :accept_id,      index: true, unique: true
      t.date       :expiration_date
      t.integer    :type
      t.string     :excel
      t.string     :mail_address
      t.boolean    :use_storage
      t.integer    :using_storage_days
      t.boolean    :test,                     default: false
      t.boolean    :unnecessary_company_info, default: false
      t.text       :company_info_result_headers                  # 企業サーチ結果のヘッダー
      t.string     :corporate_list_site_start_url                # 企業一覧サイトのURL
      t.text       :corporate_list_config
      t.text       :corporate_individual_config
      t.text       :list_site_result_headers                     # 企業一覧サイト結果のヘッダー
      t.mediumtext :list_site_analysis_result                    # 企業一覧サイト解析結果
      t.longtext   :accessed_urls                                # 企業一覧サイトクロールのアクセスページ
      t.boolean    :complete_multi_path_analysis, default: false # 企業一覧サイトクロールでマルチパス解析が終わったかどうか
      t.text       :multi_path_candidates                        # 企業一覧サイトクロールでマルチパスの候補URL
      t.mediumtext :multi_path_analysis                          # 企業一覧サイトクロールでマルチパス解析結果
      t.boolean    :only_this_page, default: false
      t.boolean    :free_search, default: false
      t.string     :link_words
      t.string     :target_words
      t.string     :result_file_path
      t.string     :ip,             index: true
      t.string     :token,          index: true
      t.references :user,           index: true, foreign_key: true

      t.timestamps
    end
  end
end

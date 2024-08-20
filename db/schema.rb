# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2024_06_23_042622) do

  create_table "allow_ips", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.text "ips"
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_allow_ips_on_user_id"
  end

  create_table "area_connectors", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "region_id", null: false
    t.bigint "prefecture_id"
    t.bigint "city_id"
    t.integer "count", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["region_id", "prefecture_id", "city_id"], name: "index_area_connectors", unique: true
  end

  create_table "ban_conditions", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "memo"
    t.string "ip"
    t.string "mail"
    t.integer "ban_action", default: 0, null: false
    t.integer "count", default: 0, null: false
    t.datetime "last_acted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["ip", "mail", "ban_action"], name: "index_ban_conditions_on_ip_and_mail_and_ban_action"
  end

  create_table "ban_inquiries", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "mail"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["mail"], name: "index_ban_inquiries_on_mail"
  end

  create_table "billing_histories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "item_name", null: false
    t.bigint "price", null: false
    t.text "memo"
    t.date "billing_date", null: false
    t.bigint "unit_price", null: false
    t.integer "number", null: false
    t.integer "payment_method", null: false
    t.bigint "billing_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["billing_id", "billing_date"], name: "index_billing_histories_on_billing_id_and_billing_date"
    t.index ["billing_id"], name: "index_billing_histories_on_billing_id"
    t.index ["payment_method", "billing_date"], name: "index_billing_histories_on_payment_method_and_billing_date"
  end

  create_table "billing_plans", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name"
    t.text "memo"
    t.bigint "price", null: false
    t.integer "type", null: false
    t.string "charge_date", null: false
    t.integer "status", null: false
    t.datetime "start_at", null: false
    t.datetime "end_at"
    t.boolean "tax_included"
    t.integer "tax_rate"
    t.boolean "trial", default: false, null: false
    t.date "next_charge_date"
    t.date "last_charge_date"
    t.bigint "billing_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["billing_id", "start_at", "end_at"], name: "index_billing_plans_on_billing_id_and_start_at_and_end_at"
    t.index ["billing_id"], name: "index_billing_plans_on_billing_id"
    t.index ["next_charge_date"], name: "index_billing_plans_on_next_charge_date"
  end

  create_table "billings", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "plan"
    t.integer "last_plan"
    t.integer "next_plan"
    t.integer "status"
    t.integer "payment_method"
    t.datetime "first_paid_at"
    t.datetime "last_paid_at"
    t.datetime "expiration_date"
    t.string "customer_id"
    t.string "subscription_id"
    t.boolean "strange"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_billings_on_user_id"
  end

  create_table "category_connectors", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "large_category_id", null: false
    t.bigint "middle_category_id"
    t.bigint "small_category_id"
    t.bigint "detail_category_id"
    t.integer "count", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["large_category_id", "middle_category_id", "small_category_id", "detail_category_id"], name: "index_category_connectors", unique: true
  end

  create_table "cities", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_cities_on_name", unique: true
  end

  create_table "companies", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "domain", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["domain"], name: "index_companies_on_domain", unique: true
  end

  create_table "company_area_connectors", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "company_id"
    t.bigint "area_connector_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "area_connector_id"], name: "index_company_and_area_connector", unique: true
  end

  create_table "company_category_connectors", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "company_id"
    t.bigint "category_connector_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "category_connector_id"], name: "index_company_and_category_connector", unique: true
  end

  create_table "company_company_groups", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "company_group_id", null: false
    t.string "source"
    t.datetime "expired_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["company_id", "company_group_id"], name: "index_company_and_company_group", unique: true
  end

  create_table "company_groups", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "type", null: false
    t.integer "grouping_number", null: false
    t.string "title", null: false
    t.string "subtitle"
    t.string "contents"
    t.bigint "upper"
    t.bigint "lower"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["type", "grouping_number", "title"], name: "index_company_groups_on_type_and_grouping_number_and_title"
  end

  create_table "country_data", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name"
    t.string "japanese_name"
    t.string "language"
    t.text "areas"
    t.integer "country_code"
    t.integer "tel_number_max_size"
    t.integer "tel_number_min_size"
    t.integer "post_code_max_size"
    t.integer "post_code_min_size"
    t.string "post_code_regexps"
    t.string "search_words"
    t.string "company_names"
    t.text "organization_words"
    t.string "address_words"
    t.string "post_code_words"
    t.string "tel_words"
    t.string "fax_words"
    t.string "contact_words"
    t.string "requested_url"
    t.text "indicate_words"
    t.text "indicators"
    t.text "extraction_item_words"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["japanese_name"], name: "index_country_data_on_japanese_name"
    t.index ["name"], name: "index_country_data_on_name"
  end

  create_table "coupons", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "limit", default: 0
    t.string "code"
    t.integer "category"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_coupons_on_code"
    t.index ["title"], name: "index_coupons_on_title"
  end

  create_table "detail_categories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_detail_categories_on_name", unique: true
  end

  create_table "file_counters", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "directory_path"
    t.integer "count", default: 0
    t.integer "one_before_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "inquiries", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name"
    t.string "mail"
    t.string "title"
    t.text "body"
    t.string "genre"
    t.boolean "close"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "large_categories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.integer "sort", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_large_categories_on_name", unique: true
    t.index ["sort"], name: "index_large_categories_on_sort"
  end

  create_table "list_crawl_configs", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "domain", null: false
    t.string "domain_path"
    t.text "corporate_list_config"
    t.text "corporate_individual_config"
    t.text "analysis_result", size: :medium
    t.string "class_name"
    t.boolean "process_result", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["domain"], name: "index_list_crawl_configs_on_domain"
  end

  create_table "master_billing_plans", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.text "memo"
    t.bigint "price", null: false
    t.integer "type", null: false
    t.datetime "start_at"
    t.datetime "end_at"
    t.datetime "application_start_at"
    t.datetime "application_end_at"
    t.boolean "enable"
    t.boolean "application_available"
    t.boolean "tax_included"
    t.integer "tax_rate"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "middle_categories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_middle_categories_on_name", unique: true
  end

  create_table "monthly_histories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "plan", null: false
    t.text "memo"
    t.datetime "start_at", null: false
    t.datetime "end_at", null: false
    t.integer "search_count", default: 0
    t.integer "request_count", default: 0
    t.integer "acquisition_count", default: 0
    t.integer "simple_investigation_count", default: 0
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_monthly_histories_on_user_id"
  end

  create_table "notices", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "subject"
    t.text "body"
    t.boolean "display"
    t.datetime "opened_at"
    t.boolean "top_page", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display", "opened_at", "top_page"], name: "index_notices_on_display_and_opened_at_and_top_page"
  end

  create_table "prefectures", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.integer "sort", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_prefectures_on_name", unique: true
    t.index ["sort"], name: "index_prefectures_on_sort"
  end

  create_table "preferences", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "output_formats"
    t.text "search_words"
    t.boolean "advanced_setting_for_crawl", default: false, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "referrers", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "code", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_referrers_on_code", unique: true
    t.index ["email"], name: "index_referrers_on_email"
  end

  create_table "regions", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.integer "sort", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_regions_on_name", unique: true
    t.index ["sort"], name: "index_regions_on_sort"
  end

  create_table "requested_urls", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "url"
    t.text "domain"
    t.boolean "test"
    t.text "organization_name"
    t.string "type"
    t.integer "status"
    t.integer "arrange_status", default: 0
    t.integer "finish_status"
    t.integer "retry_count", default: 0
    t.bigint "request_id"
    t.bigint "corporate_list_url_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["finish_status"], name: "index_requested_urls_on_finish_status"
    t.index ["request_id", "corporate_list_url_id"], name: "index_requested_urls_on_request_id_and_corporate_list_url_id"
    t.index ["request_id"], name: "index_requested_urls_on_request_id"
    t.index ["type", "status", "test"], name: "index_requested_urls_on_type_and_status_and_test"
    t.index ["url"], name: "index_requested_urls_on_url", length: 255
  end

  create_table "requests", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "title"
    t.string "file_name"
    t.integer "status"
    t.string "accept_id"
    t.date "expiration_date"
    t.integer "type"
    t.string "excel"
    t.string "mail_address"
    t.boolean "use_storage"
    t.integer "using_storage_days"
    t.text "db_categories"
    t.text "db_areas"
    t.text "db_groups"
    t.boolean "test", default: false
    t.integer "plan", default: 0, null: false
    t.boolean "unnecessary_company_info", default: false
    t.text "company_info_result_headers"
    t.text "corporate_list_site_start_url"
    t.text "corporate_list_config"
    t.text "corporate_individual_config"
    t.text "list_site_result_headers"
    t.text "list_site_analysis_result", size: :medium
    t.text "accessed_urls", size: :long
    t.boolean "complete_multi_path_analysis", default: false
    t.text "multi_path_candidates"
    t.text "multi_path_analysis", size: :medium
    t.integer "paging_mode", default: 0
    t.boolean "only_list_crawl", default: false
    t.boolean "free_search", default: false
    t.string "link_words"
    t.string "target_words"
    t.string "result_file_path"
    t.string "ip"
    t.string "token"
    t.bigint "user_id"
    t.integer "requested_urls_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accept_id"], name: "index_requests_on_accept_id"
    t.index ["expiration_date", "updated_at"], name: "index_requests_on_expiration_date_and_updated_at"
    t.index ["ip"], name: "index_requests_on_ip"
    t.index ["status"], name: "index_requests_on_status"
    t.index ["token"], name: "index_requests_on_token"
    t.index ["user_id"], name: "index_requests_on_user_id"
  end

  create_table "result_files", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "path"
    t.integer "file_type", default: 0
    t.integer "status", default: 0, null: false
    t.date "expiration_date"
    t.text "fail_files"
    t.boolean "deletable", default: false, null: false
    t.bigint "start_row"
    t.bigint "end_row"
    t.text "parameters", size: :long
    t.string "phase"
    t.boolean "final", default: false, null: false
    t.datetime "started_at"
    t.bigint "request_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_result_files_on_created_at"
    t.index ["deletable"], name: "index_result_files_on_deletable"
    t.index ["request_id"], name: "index_result_files_on_request_id"
  end

  create_table "results", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "free_search"
    t.text "candidate_crawl_urls", size: :long
    t.text "single_url_ids"
    t.text "main", size: :long
    t.text "corporate_list", size: :long
    t.bigint "requested_url_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["requested_url_id"], name: "index_results_on_requested_url_id"
  end

  create_table "search_requests", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "url"
    t.text "domain"
    t.string "accept_id"
    t.integer "status"
    t.integer "finish_status"
    t.boolean "use_storage"
    t.integer "using_storage_days"
    t.boolean "free_search"
    t.string "link_words"
    t.string "target_words"
    t.text "free_search_result"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accept_id"], name: "index_search_requests_on_accept_id"
    t.index ["user_id"], name: "index_search_requests_on_user_id"
  end

  create_table "simple_investigation_histories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "url", null: false
    t.string "domain"
    t.text "memo"
    t.boolean "resolved", default: false
    t.bigint "new_request_id"
    t.bigint "request_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["domain"], name: "index_simple_investigation_histories_on_domain"
    t.index ["user_id", "request_id"], name: "index_simple_investigation_histories_on_user_id_and_request_id"
  end

  create_table "small_categories", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_small_categories_on_name", unique: true
  end

  create_table "tmp_company_info_urls", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "bunch_id", null: false
    t.text "url"
    t.text "domain"
    t.text "organization_name"
    t.text "result", size: :long
    t.text "corporate_list_result", size: :long
    t.bigint "request_id"
    t.bigint "result_file_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["request_id", "bunch_id", "result_file_id"], name: "index_tmp_company_info_urls"
    t.index ["request_id"], name: "index_tmp_company_info_urls_on_request_id"
  end

  create_table "user_coupons", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "coupon_id"
    t.integer "count"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id", "coupon_id"], name: "index_user_coupons_on_user_id_and_coupon_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_general_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "company_name"
    t.string "family_name"
    t.string "given_name"
    t.string "department"
    t.integer "position"
    t.string "tel"
    t.string "language"
    t.boolean "terms_of_service"
    t.integer "search_count", default: 0
    t.integer "last_search_count", default: 0
    t.date "latest_access_date"
    t.integer "monthly_search_count", default: 0
    t.integer "last_monthly_search_count", default: 0
    t.integer "request_count", default: 0
    t.integer "last_request_count", default: 0
    t.date "last_request_date"
    t.integer "monthly_request_count", default: 0
    t.integer "last_monthly_request_count", default: 0
    t.bigint "referrer_id"
    t.integer "referral_reason"
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "billings", "users"
  add_foreign_key "requested_urls", "requests"
  add_foreign_key "requests", "users"
  add_foreign_key "search_requests", "users"
  add_foreign_key "tmp_company_info_urls", "requests"
end

require 'sidekiq/web'

Rails.application.routes.draw do
  namespace :admin do
      resources :users
      resources :billings
      resources :billing_histories
      resources :monthly_histories
      resources :search_requests
      resources :requests do
        put :list_site_analysis_result, on: :member, to: 'requests#update_list_site_analysis_result'
        post :copy, on: :member
      end
      resources :requested_urls
      namespace :search_request do
        resources :corporate_lists
        resources :corporate_singles
        resources :company_infos
      end
      resources :results
      resources :category_connectors
      resources :cities
      resources :area_connectors
      resources :companies do
        post :import_company_file, on: :collection
      end
      resources :company_category_connectors
      resources :company_area_connectors
      resources :company_groups
      resources :company_company_groups
      resources :country_data
      resources :coupons
      resources :detail_categories
      resources :file_counters
      resources :inquiries
      resources :large_categories
      resources :middle_categories
      resources :notices
      resources :prefectures
      resources :referrers
      resources :regions
      resources :simple_investigation_histories
      resources :preferences
      resources :small_categories
      resources :ban_inquiries
      resources :ban_conditions
      resources :allow_ips
      resources :result_files
      resources :tmp_company_info_urls
      resources :user_coupons
      resources :billing_plans
      resources :master_billing_plans

      root to: "search_requests#index"
    end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  root to: 'requests#index'

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions:      'users/sessions'
  }

  get  'search',         to: 'searchers#index'
  post 'search',         to: 'searchers#search'
  post 'search_request', to: 'searchers#search_request'
  get  'confirm_search', to: 'searchers#confirm_search'
  get  'candidate_urls', to: 'searchers#fetch_candidate_urls'

  get  'request/corporate',             to: 'requests#index'
  get  'request/corporate/reconfigure', to: 'requests#reconfigure'
  get  'request/multiple',              to: 'requests#index_multiple'
  post 'request',                       to: 'requests#create'
  put  'request/stop',                  to: 'requests#stop'
  put  'request/main_corporate',        to: 'requests#recreate'
  get  'confirm',                       to: 'requests#confirm'
  get  'download',                      to: 'requests#download'
  get  'result_file',                   to: 'requests#get_result_file'
  post 'result_file',                   to: 'requests#make_result_file'
  put  'simple_investigation',          to: 'requests#request_simple_investigation'
  get  'areas_categories',              to: 'company#find_areas_categories'
  get  'company_count',                 to: 'company#count_companies'

  get    'payment/edit',                      to: 'payments#edit'
  post   'payment',                           to: 'payments#create_credit_subscription'
  put    'payment/update',                    to: 'payments#update'
  delete 'payment/stop',                      to: 'payments#stop_credit_subscription'
  get    'payment_info',                      to: 'payments#get_payment_info'
  put    'payment/card/update',               to: 'payments#update_card'
  get    'admin_page/payments',               to: 'payments#index'
  put    'admin_page/payment',                to: 'payments#modify'
  put    'admin_page/create_bank_transfer',   to: 'payments#create_bank_transfer'
  put    'admin_page/continue_bank_transfer', to: 'payments#continue_bank_transfer'
  put    'admin_page/create_invoice',         to: 'payments#create_invoice'

  get    'payment_histories', to: 'payment_histories#index'
  get    'payment_histories/:month', to: 'payment_histories#show', as: 'payment_histories_by_month'
  get    'payment_histories/:month/download', to: 'payment_histories#download', as: 'payment_histories_by_month_download'

  put  'coupon',       to: 'coupons#add'
  get  'coupon/trial', to: 'coupons#new_trial'
  post 'coupon/trial', to: 'coupons#create_trial'

  get  'inquiry', to: 'inquiries#new'
  post 'inquiry', to: 'inquiries#create'

  get 'information', to: 'information#index'
  get 'information/specified_commercial_transaction_act', to: 'information#specified_commercial_transaction_act'

  resources :batches, only: [] do
    get :search_request, to: 'batches#request_search', on: :collection
    get :result_file_request, to: 'batches#request_result_file', on: :collection
    get :test_search_request, to: 'batches#request_test_search', on: :collection
  end

  require "admin_constraint"
  authenticate :user, lambda { |u| u.administrator? } do
    mount Sidekiq::Web => '/sidekiq', :constraints => AdminConstraint.new
  end

  get  '*not_found' => 'application#routing_error'
  post '*not_found' => 'application#routing_error'
end

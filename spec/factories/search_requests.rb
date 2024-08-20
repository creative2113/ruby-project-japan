FactoryBot.define do
  factory :search_request do
    url { 'http://www.example.com' }
    domain { nil }
    accept_id { 'abcdefg' }
    status { 0 }
    finish_status { 0 }
    use_storage { false }
    using_storage_days { 0 }
    free_search { nil }
    link_words { nil }
    target_words { nil }
    free_search_result { nil }
    user_id { nil }

    factory :complete_search_request do
      status { EasySettings.status[:completed] }
    end

    factory :complete_and_success_search_request do
      status { EasySettings.status[:completed] }
      finish_status { EasySettings.finish_status[:successful] }
    end

    factory :complete_but_error_search_request do
      status { EasySettings.status[:completed] }
      finish_status { EasySettings.finish_status[:error] }
    end
  end
end

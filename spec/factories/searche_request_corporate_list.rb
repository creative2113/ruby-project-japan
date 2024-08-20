FactoryBot.define do
  factory :search_request_corporate_list, class: SearchRequest::CorporateList do
    url { 'http://www.example.com' }
    status { 0 }
    finish_status { 0 }
    domain { nil }

    association :request

    transient do
      result_attrs { {} }
    end

    factory :search_request_corporate_list_finished do
      status { EasySettings.status[:completed] }
      finish_status { EasySettings.finish_status[:successful] }
    end

    after(:create) do |req_url, evaluater|
      req_url.result.update!(evaluater.result_attrs)
    end
  end
end

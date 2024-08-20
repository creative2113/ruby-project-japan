FactoryBot.define do
  factory :requested_url do
    url { "http://www.example.com/#{Random.alphanumeric}" }
    type { 'SearchRequest::CompanyInfo' }
    status { 0 }
    finish_status { 0 }
    test { false }
    request_id { 1 }
    domain { nil }

    association :request

    transient do
      result_attrs { {} }
    end

    after(:create) do |req_url, evaluater|
      req_url.result.update!(evaluater.result_attrs)
    end

    factory :requested_url_finished do
      status { EasySettings.status[:completed] }
      finish_status { EasySettings.finish_status[:successful] }
    end

    trait :corporate_list do
      type { 'SearchRequest::CorporateList' }
    end

    trait :company_info do
      type { 'SearchRequest::CompanyInfo' }
    end
  end
end

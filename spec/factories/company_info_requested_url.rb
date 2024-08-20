FactoryBot.define do
  factory :company_info_requested_url, class: SearchRequest::CompanyInfo do
    url { "http://www.example.com/#{Random.alphanumeric}" }
    type { 'SearchRequest::CompanyInfo' }
    status { 0 }
    finish_status { 0 }
    test { false }
    request_id { 1 }
    domain { nil }
    corporate_list_url_id { nil }

    association :request, type: Request.types[:file]

    transient do
      result_attrs { {} }
    end

    after(:create) do |req_url, evaluater|
      req_url.result.update!(evaluater.result_attrs)
    end

    factory :company_info_requested_url_finished do
      status { EasySettings.status[:completed] }
      finish_status { EasySettings.finish_status[:successful] }
    end
  end
end
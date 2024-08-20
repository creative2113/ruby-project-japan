FactoryBot.define do
  factory :tmp_company_info_url do
    url { '' }
    domain { nil }
    bunch_id { 1 }
    corporate_list_result { nil }

    association :request
  end
end

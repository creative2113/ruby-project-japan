FactoryBot.define do
  factory :company_company_group do
    source { 'corporate_site' }
    expired_at { 3.months.from_now }

    association :company_group
    association :company
  end
end

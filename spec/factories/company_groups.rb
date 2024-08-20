FactoryBot.define do
  factory :company_group do

    type { CompanyGroup.types[:source] }
    sequence(:grouping_number)
    sequence(:title, 'title_1')
    subtitle { 'MyText' }
    contents { 'MyText' }
    upper { nil }
    lower { nil }

    trait :range do
      type { CompanyGroup.types[:range] }
      title { CompanyGroup::CAPITAL }
      subtitle { nil }
      contents { nil }
      upper { 1_000 }
      lower { 0 }
    end
  end
end

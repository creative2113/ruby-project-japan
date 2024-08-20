FactoryBot.define do
  factory :billing_plan do
    name { 'テストプラン' }
    price { 10_000 }
    type { :monthly }
    status { :ongoing }
    charge_date { '1' }
    start_at { Time.zone.now.beginning_of_day }
    end_at { Time.zone.now.next_month.end_of_month }
    tax_included { true }
    tax_rate { 10 }
    next_charge_date { nil }
    last_charge_date { nil }

    association :billing
  end
end

FactoryBot.define do
  factory :master_billing_plan do
    name { "#{('a'..'z').to_a.shuffle[0..3].join.upcase}プラン" }
    price { Faker::Number.between(from: 1, to: 100) * 100 }
    type { :monthly }
    start_at { Time.zone.now - 3.years }
    end_at { nil }
    enable { true }
    application_start_at { Time.zone.now - 3.years }
    application_end_at { nil }
    application_available { true }
    tax_included { true }
    tax_rate { 10 }

    trait :test_light do
      name { 'Rspecテスト ライトプラン' }
      price { 1_000 }
      type { :monthly }
    end

    trait :test_standard do
      name { 'Rspecテスト スタンダードプラン' }
      price { 3_000 }
      type { :monthly }
    end

    trait :test_annually_light do
      name { 'Rspecテスト 年間契約ライトプラン' }
      price { 12_000 }
      type { :annually }
    end

    trait :test_annually_standard do
      name { 'Rspecテスト 年間契約スタンダードプラン' }
      price { 36_000 }
      type { :annually }
    end

    trait :test_testerA do
      name { 'Test TesterA プラン' }
      price { 1_500 }
      type { :monthly }
    end

    trait :test_testerB do
      name { 'Test TesterB プラン' }
      price { 1_600 }
      type { :monthly }
    end

    trait :test_testerC do
      name { 'Test TesterC プラン' }
      price { 1_700 }
      type { :monthly }
    end

    trait :test_testerC do
      name { 'Test TesterD プラン' }
      price { 1_800 }
      type { :monthly }
    end

    trait :beta_standard do
      name { 'β版スタンダードプラン' }
      price { 4_000 }
      type { :monthly }
    end

    trait :standard do
      name { 'スタンダードプラン' }
      price { 4_000 }
      type { :monthly }
      start_at { Time.zone.now - 3.years }
      end_at { nil }
      enable { true }
      application_start_at { Time.zone.now - 3.years }
      application_end_at { nil }
      application_available { true }
      tax_included { true }
      tax_rate { 10 }
    end

    trait :gold do
      name { 'ゴールドプラン' }
      price { 8_000 }
      type { :monthly }
      start_at { Time.zone.now - 3.years }
      end_at { nil }
      enable { true }
      application_start_at { Time.zone.now - 3.years }
      application_end_at { nil }
      application_available { true }
      tax_included { true }
      tax_rate { 10 }
    end

    trait :platinum do
      name { 'プラチナムプラン' }
      price { 10_000 }
      type { :monthly }
      start_at { Time.zone.now - 3.years }
      end_at { nil }
      enable { true }
      application_start_at { Time.zone.now - 3.years }
      application_end_at { nil }
      application_available { true }
      tax_included { true }
      tax_rate { 10 }
    end
  end
end

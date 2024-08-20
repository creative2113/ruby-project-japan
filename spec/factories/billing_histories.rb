FactoryBot.define do
  factory :billing_history do

    item_name { Faker::Commerce.product_name }
    memo { nil }
    payment_method { :credit }
    billing_date { Time.zone.now }
    unit_price { Faker::Number.between(from: 100, to: 1_000_000) }
    number { Faker::Number.between(from: 1, to: 10) }
    price { number * unit_price }

    trait :credit do
      payment_method { :credit }
    end

    trait :invoice do
      payment_method { :invoice }
    end

    trait :bank_transfer do
      payment_method { :bank_transfer }
    end
  end
end

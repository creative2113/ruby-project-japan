FactoryBot.define do
  factory :referrer do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    code { SecureRandom.random_number(7) }
  end
end

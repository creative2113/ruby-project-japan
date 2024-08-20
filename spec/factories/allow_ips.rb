FactoryBot.define do
  factory :allow_ip do
    name { 'sample' }

    trait :admin do
      name { 'Admin IP' }
      ips { "{\"localhost\":null,\"::1\":\"2023-06-01T11:47:37.120+09:00\",\"0.0.0.0\":null,\"127.0.0.1\":null}" }
      user_id { User.find_by(email: Rails.application.credentials.user[:admin][:email]).id }
    end
  end
end

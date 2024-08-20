FactoryBot.define do
  factory :request do
    title { 'sample title' }
    file_name { 'file_name' }
    status { EasySettings.status[:new] }
    accept_id { SecureRandom.alphanumeric(5) }
    corporate_list_site_start_url { "http://test_#{SecureRandom.alphanumeric(3)}.com" }
    expiration_date { Time.zone.today }
    mail_address { 'to@example.org' }
    type { Request.types[:file] }
    test { false }
    plan { EasySettings.plan[:free] }
    use_storage { false }
    using_storage_days { 0 }
    ip { "#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(256)}" }
    token { SecureRandom.alphanumeric(20) }

    association :user

    factory :request_completed do
      status { EasySettings.status[:completed] }
    end

    factory :request_of_public_user do
      user { User.get_public }
      plan { EasySettings.plan[:public] }
    end

    trait :corporate_site_list do
      type { Request.types[:corporate_list_site] }
    end
  end
end

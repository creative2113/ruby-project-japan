FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password1234' }
    company_name { Faker::Company.name }
    family_name { Faker::Name.middle_name }
    given_name { Faker::Name.first_name }
    department { Faker::Company.department }
    position { 'general_employee' }
    tel { Faker::PhoneNumber.cell_phone }
    confirmed_at { Time.zone.now }
    confirmation_sent_at { Time.zone.now - 30.seconds }
    language { '日本語' }
    role { :general_user }

    transient do
      billing { :billing }
      billing_plan { :billing_plan }
      billing_attrs { nil }
      plan { nil }
    end

    factory :user_exceed_access do
      search_count { EasySettings.access_limit[:standard] + 1 }
    end

    factory :user_yesterday do
      latest_access_date { Time.zone.today - 1 }
    end

    factory :user_exceed_access_yesterday do
      search_count { EasySettings.access_limit[:standard] + 1 }
      latest_access_date { Time.zone.today - 1 }
    end

    factory :user_exceed_request_access do
      request_count { EasySettings.request_limit[:standard] + 1 }
    end

    factory :user_exceed_request_access_yesterday do
      request_count { EasySettings.request_limit[:standard] + 1 }
      last_request_date { Time.zone.today - 1 }
    end

    factory :user_public do
      email { Rails.application.credentials.user[:public][:email] }
      family_name { 'パブリック' }
      given_name { 'ユーザ' }
      company_name { 'public_test_company' }
      role { :public_user }
    end

    factory :admin_user do
      email { Rails.application.credentials.user[:admin][:email] || Faker::Internet.email }
      role { :administrator }
    end

    after(:create) do |user, evaluater|
      attributes = evaluater.billing_attrs.nil? ? {user: user} : {user: user}.merge(evaluater.billing_attrs)

      FactoryBot.create(evaluater.billing, attributes)
    end
  end
end

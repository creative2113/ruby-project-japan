FactoryBot.define do
  factory :coupon do
    title { 'sample' }
    description { 'sample' }
    limit { 1 }
    code { nil }
    category { 0 }

    factory :referrer_trial do
      code { nil }
      title { Coupon::TRIAL_REFERRER_TITLE }
      category { Coupon.categories[:trial_plan] }
    end
  end
end

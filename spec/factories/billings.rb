FactoryBot.define do
  factory :billing do
    plan            { nil }
    last_plan       { nil }
    next_plan       { nil }
    status          { nil }
    payment_method  { Billing.payment_methods[:credit] }
    first_paid_at   { nil }
    last_paid_at    { nil }
    expiration_date { nil }
    customer_id     { nil }
    subscription_id { nil }
    strange         { false }

    association :user

    factory :free do
      plan            { nil }
      last_plan       { nil }
      next_plan       { nil }
      status          { nil }
      payment_method  { nil }
      first_paid_at   { nil }
      last_paid_at    { nil }
      expiration_date { nil }
      customer_id     { nil }
      subscription_id { nil }
      strange         { false }
    end

    factory :credit do
      payment_method  { Billing.payment_methods[:credit] }
    end
  end
end

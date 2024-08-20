FactoryBot.define do
  factory :monthly_history do
    plan { EasySettings.plan[:free] }
    start_at { Time.zone.now.beginning_of_month }
    end_at { Time.zone.now.end_of_month }

    association :user
  end
end

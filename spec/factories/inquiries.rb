FactoryBot.define do
  factory :inquiry do
    name { 'Tanaka Taro' }
    mail { 'sample@example.com' }
    body { 'abcde' }
    user_id { User.public_id }
  end
end

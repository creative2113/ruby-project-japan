FactoryBot.define do
  factory :notice do
    subject { 'My Title' }
    body { 'main body' }
    display { true }
    opened_at { Time.zone.now - 1.day }
    top_page { false }
    
  end
end

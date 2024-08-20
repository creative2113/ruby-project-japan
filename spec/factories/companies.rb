FactoryBot.define do
  factory :company do
    domain { "#{['www.',''].sample}#{Random.alphanumeric(Random.rand(5..20)).downcase}.#{['co.jp','com','biz','net','jp','inc'].sample}" }
  end
end

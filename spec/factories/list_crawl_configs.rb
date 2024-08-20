FactoryBot.define do
  factory :list_crawl_config do
    domain { 'example.com' }
    domain_path { nil }
    corporate_list_config { nil }
    corporate_individual_config { nil }
    analysis_result { 'aaa' }
  end
end

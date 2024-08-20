FactoryBot.define do
  factory :corporate_single_requested_url, class: SearchRequest::CorporateSingle  do
    url { "http://www.example.com/#{Random.alphanumeric}" }
    type { SearchRequest::CorporateSingle::TYPE }
    status { 0 }
    finish_status { 0 }
    test { false }
    request_id { 1 }
    domain { nil }

    association :request, type: Request.types[:corporate_list_site]

    factory :corporate_single_requested_url_finished do
      status { EasySettings.status[:completed] }
      finish_status { EasySettings.finish_status[:successful] }
    end

    transient do
      result_attrs { {} }
      defined_result_attrs { {} }
    end

    after(:create) do |req_url, evaluater|
      attrs = evaluater.defined_result_attrs.present? ? evaluater.result_attrs.merge(evaluater.defined_result_attrs) : evaluater.result_attrs
      req_url.result.update!(attrs)
    end

    trait :a do
      url { 'http://www.example.com/companies/aaa.html' }
      defined_result_attrs {
        { corporate_list:
          {"AAA織物工業 http://www.example.com/companies/aaa.html"=>
            {"組織名"=>"AAA織物工業",
             "掲載ページタイトル"=>"AAA織物工業のページ",
             "掲載ページ"=>"http://www.example.com/companies/aaa.html",
             "$$content_urls$$"=>[],
             "new_domain_urls"=>[],
             "郵便番号"=>"100-0001",
             "所在地"=>"〒100-0001 東京都大和市南町1-1-1",
             "住所"=>"東京都大和市南町1-1-1",
             "電話番号"=>"000-000-0001",
             "URL"=>"http://www.aaa.jp/",
             "ホームページ"=>"http://www.aaa.jp/",
             "資本金"=>"100万円",
             "従業員数"=>"40人"
            }
          }.to_json
        }
      }
    end

    trait :b do
      url { 'http://www.example.com/companies/bbb.html' }
      defined_result_attrs {
        { corporate_list:
          {"BBB株式会社 http://www.example.com/companies/bbb.html"=>
            {"組織名"=>"BBB株式会社",
             "掲載ページタイトル"=>"BBB株式会社のページ",
             "掲載ページ"=>"http://www.example.com/companies/bbb.html",
             "$$content_urls$$"=>[],
             "new_domain_urls"=>[],
             "郵便番号"=>"200-0002",
             "所在地"=>"〒200-0002 東京都北区南町2-2-2",
             "住所"=>"東京都北区南町2-2-2",
             "電話番号"=>"000-000-0002",
             "URL"=>"http://www.bbb.jp/",
             "ホームページ"=>"http://bbb.co.jp",
             "業務分類"=>"鉄鋼業",
             "資本金"=>"500万円"
            }
          }.to_json
        }
      }
    end

    trait :c do
      url { 'http://www.example.com/companies/ccc.html' }
      defined_result_attrs {
        { corporate_list:
          {"CCC捺染工場 http://www.example.com/companies/ccc.html"=>
            {"組織名"=>"CCC捺染工場",
             "掲載ページタイトル"=>"CCC捺染工場のページ",
             "掲載ページ"=>"http://www.example.com/companies/ccc.html",
             "$$content_urls$$"=>[],
             "new_domain_urls"=>[],
             "郵便番号"=>"300-0003",
             "所在地"=>"〒300-0003 東京都西区南町3-3-3",
             "住所"=>"東京都西区南町3-3-3",
             "電話番号"=>"000-000-0003",
             "ホームページ"=>"http://ccc.co.jp",
             "業務分類"=>"染色業",
             "従業員数"=>"100人"
            }
          }.to_json
        }
      }
    end

    trait :d do
      url { 'http://www.example.com/companies/ddd.html' }
      defined_result_attrs {
        { corporate_list:
          {"DDD株式会社 http://www.example.com/companies/ddd.html"=>
            {"組織名"=>"DDD株式会社",
             "掲載ページタイトル"=>"DDD株式会社のページ",
             "掲載ページ"=>"http://www.example.com/companies/ddd.html",
             "$$content_urls$$"=>[],
             "new_domain_urls"=>[],
             "郵便番号"=>"400-0004",
             "所在地"=>"〒400-0004 東京都西市南町4-4-4",
             "住所"=>"東京都西市南町4-4-4",
             "電話番号"=>"000-000-0004",
             "URL"=>"https://ddd.jp/",
             "ホームページ"=>"https://ddd.jp/",
             "資本金"=>"1000万円",
             "従業員数"=>"500人",
             "業務分類"=>"食品加工業"
            }
          }.to_json
        }
      }
    end

    trait :e do
      url { 'http://www.example.com/companies/eee.html' }
      defined_result_attrs {
        { corporate_list:
          {"EEE株式会社 http://www.example.com/companies/eee.html"=>
            {"組織名"=>"EEE株式会社",
             "掲載ページタイトル"=>"EEE株式会社のページ",
             "掲載ページ"=>"http://www.example.com/companies/eee.html",
             "$$content_urls$$"=>[],
             "new_domain_urls"=>[],
             "郵便番号"=>"500-0005",
             "所在地"=>"〒500-0005 東京都八幡市南町5-5-5",
             "住所"=>"東京都八幡市南町5-5-5",
             "電話番号"=>"000-000-0005",
             "URL"=>"http://eee.co.jp",
             "ホームページ"=>"http://eee.co.jp",
             "業務分類"=>"製紙業",
             "資本金"=>"700万円",
             "従業員数"=>"340人"
            }
          }.to_json
        }
      }
    end
  end
end

FactoryBot.define do
  factory :corporate_list_requested_url, class: SearchRequest::CorporateList  do
    url { "http://www.example.com/#{Random.alphanumeric}" }
    type { SearchRequest::CorporateList::TYPE }
    status { 0 }
    finish_status { 0 }
    test { false }
    request_id { 1 }
    domain { nil }

    association :request, type: Request.types[:corporate_list_site]

    factory :corporate_list_requested_url_finished do
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

    trait :result_1 do |a|
      url { 'http://www.example.com/index.html' }
      defined_result_attrs {
        { corporate_list:
          {"result"=>
            {"AAA織物工業 http://www.example.com/index.html"=>
              {"組織名"=>"AAA織物工業",
               "掲載ページタイトル"=>"一覧ページ",
               "掲載ページ"=>"http://www.example.com/index.html",
               "$$content_urls$$"=>["http://www.example.com/companies/aaa.html"],
               "new_domain_urls"=>["http://www.aaa.jp/"],
               "仕切り情報"=>"工業製品1",
               "電話番号"=>"000-000-0001",
               "URL"=>"http://www.aaa.jp/"},
             "BBB株式会社 http://www.example.com/index.html"=>
              {"組織名"=>"BBB株式会社",
               "掲載ページタイトル"=>"一覧ページ",
               "掲載ページ"=>"http://www.example.com/index.html",
               "$$content_urls$$"=>["http://www.example.com/companies/bbb.html"],
               "new_domain_urls"=>["http://bbb.co.jp"],
               "仕切り情報"=>"工業製品1",
               "電話番号"=>"000-000-0002",
               "URL"=>"http://bbb.co.jp"},
             "CCC捺染工場 http://www.example.com/index.html"=>
              {"組織名"=>"CCC捺染工場",
               "掲載ページタイトル"=>"一覧ページ",
               "掲載ページ"=>"http://www.example.com/index.html",
               "$$content_urls$$"=>["http://www.example.com/companies/ccc.html"],
               "new_domain_urls"=>[],
               "仕切り情報"=>"工業製品2",
               "電話番号"=>"000-000-0003"}
            },
           "table_result"=>{}
          }.to_json
        }
      }
    end

    trait :table_result_1 do
      url { 'http://www.example.com/index.html' }
      defined_result_attrs {
        { corporate_list:
          {"result"=>{},
           "table_result"=>
            {"AAA織物工業 http://www.example.com/index.html"=>
              {"組織名"=>"AAA織物工業",
               "掲載ページタイトル"=>"一覧ページ",
               "掲載ページ"=>"http://www.example.com/index.html",
               "$$content_urls$$"=>["http://www.example.com/companies/aaa.html"],
               "new_domain_urls"=>["http://www.aaa.jp/"],
               "仕切り情報"=>"工業製品1",
               "電話番号"=>"000-000-0001",
               "URL"=>"http://www.aaa.jp/"},
             "BBB株式会社 http://www.example.com/index.html"=>
              {"組織名"=>"BBB株式会社",
               "掲載ページタイトル"=>"一覧ページ",
               "掲載ページ"=>"http://www.example.com/index.html",
               "$$content_urls$$"=>["http://www.example.com/companies/bbb.html"],
               "new_domain_urls"=>["http://bbb.co.jp"],
               "仕切り情報"=>"工業製品1",
               "電話番号"=>"000-000-0002",
               "URL"=>"http://bbb.co.jp"},
             "CCC捺染工場 http://www.example.com/index.html"=>
              {"組織名"=>"CCC捺染工場",
               "掲載ページタイトル"=>"一覧ページ",
               "掲載ページ"=>"http://www.example.com/index.html",
               "$$content_urls$$"=>["http://www.example.com/companies/ccc.html"],
               "new_domain_urls"=>[],
               "仕切り情報"=>"工業製品2",
               "電話番号"=>"000-000-0003"}
            }
          }.to_json
        }
      }
    end

    trait :result_2 do
      url { 'http://www.example.com/index2.html' }
      defined_result_attrs {
        { corporate_list:
          {"result"=>
            {"DDD株式会社 http://www.example.com/index2.html"=>
              {"組織名"=>"DDD株式会社",
               "掲載ページタイトル"=>"一覧ページ2",
               "掲載ページ"=>"http://www.example.com/index2.html",
               "$$content_urls$$"=>["http://www.example.com/companies/ddd.html"],
               "new_domain_urls"=>[],
               "仕切り情報"=>"製造業1",
               "電話番号"=>"000-000-0004",
               "URL"=>"https://ddd.jp/"},
             "EEE株式会社 http://www.example.com/index2.html"=>
              {"組織名"=>"EEE株式会社",
               "掲載ページタイトル"=>"一覧ページ2",
               "掲載ページ"=>"http://www.example.com/index2.html",
               "$$content_urls$$"=>["http://www.example.com/companies/eee.html"],
               "new_domain_urls"=>["http://eee.co.jp"],
               "仕切り情報"=>"製造業2",
               "電話番号"=>"000-000-0005",
               "URL"=>"http://eee.co.jp"}
            },
           "table_result"=>{}
          }.to_json
        }
      }
    end

    trait :table_result_2 do
      url { 'http://www.example.com/index.html' }
      defined_result_attrs {
        { corporate_list:
          {"result"=>{},
           "table_result"=>
            {"DDD株式会社 http://www.example.com/index2.html"=>
              {"組織名"=>"DDD株式会社",
               "掲載ページタイトル"=>"一覧ページ2",
               "掲載ページ"=>"http://www.example.com/index2.html",
               "$$content_urls$$"=>["http://www.example.com/companies/ddd.html"],
               "new_domain_urls"=>[],
               "仕切り情報"=>"製造業1",
               "電話番号"=>"000-000-0004",
               "URL"=>"https://ddd.jp/"},
             "EEE株式会社 http://www.example.com/index2.html"=>
              {"組織名"=>"EEE株式会社",
               "掲載ページタイトル"=>"一覧ページ2",
               "掲載ページ"=>"http://www.example.com/index2.html",
               "$$content_urls$$"=>["http://www.example.com/companies/eee.html"],
               "new_domain_urls"=>["http://eee.co.jp"],
               "仕切り情報"=>"製造業2",
               "電話番号"=>"000-000-0005",
               "URL"=>"http://eee.co.jp"}
            }
          }.to_json
        }
      }
    end
  end
end

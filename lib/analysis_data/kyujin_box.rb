class AnalysisData::KyujinBox < AnalysisData::Base
  class << self

    def domain
      'xn--pckua2a7gp15o89zb.com'
    end

    def enable_process_result; false; end

    def path; nil; end

    def ban_pathes
      pathes = ["#{domain}"]
      pathes.map { |path| [path, "#{path}/"] }.flatten
    end

    # def ban_pathes_alert_message
    #   '取得不可能なURLです。お手数ですが、URLの注意事項とイーキャリアの注意事項をよくご確認して、やり直してください。'
    # end

    def original
      tmp = '{"multi":{"org_name_pathes":{"/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]/a/h2":10},"contents_pathes":{"/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]/a/em":4},"common_item_words":["東京都渋谷区"],"common_item_pathes":["/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]/a/em"],"uncommon_item_pathes":{},"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"corporate_area_pathes":["/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]"],"corporate_area_start_pathes":{"/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]":10},"end_pathes":{"/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]/a/text()[$LOOP$]":9},"separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],"filter_path_of_content_urls":{"/html/body/div[1]/div[3]/main/article[2]/nav/ul/li[$LOOP$]/a":10}},"single":{"org_name_pathes":{"/html/body/div[1]/div[3]/article/section/section[2]/article/h3":10},"contents_pathes":{"/html/body/div[1]/div[3]/article/section/section[2]/article/div/div/section[$LOOP$]/div/div[1]/dl[$LOOP$]/dtdd[$LOOP$]":65,"/html/body/div[1]/div[3]/article/section/section[2]/article/div/div/section[$LOOP$]/div/div[1]/dl/dtdd/ul/li[$LOOP$]":54,"/html/body/div[1]/span[4]":20},"footer_pathes":{"/html/body/div[1]/footer/div/div[2]/ul/li[$LOOP$]/a/text()":7,"/html/body/div[3]/div/div[2]/div[1]/div/div[2]/ul/li[$LOOP$]/text()":4,"/html/body/noscript[$LOOP$]/div/img":2,"/html/body/noscript[5]/img[$LOOP$]":2},"common_item_words":[],"common_item_pathes":[],"uncommon_item_pathes":{"/html/body/div[1]/div[3]/article/section/section[2]/article/div/div/section[$LOOP$]/div/div[1]/dl/dd/ul/li[$LOOP$]/text()":362,"/html/body/div[1]/div[3]/article/section/section[2]/article/div/div/section[$LOOP$]/div/div[1]/dl/dt/text()":61,"/html/body/div[1]/div[3]/article/section/div/dl[$LOOP$]/dd[$LOOP$]/ul/li[$LOOP$]/a/text()":39},"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[]},"multi_available_urls":["https://www.ecareer.ne.jp/q/jobCategory/1010400?window=5"],"js_functions":{},"accessed_count":1,"high_priority_accessed_count":10,"accessed_urls":["https://www.ecareer.ne.jp/q/jobCategory/1010400?window=5"],"high_priority_accessed_urls":["https://www.ecareer.ne.jp/positions/00055000001/2?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00051905001/1?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00054085001/8?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00054204001/1?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00051844001/4?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00051844001/6?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00051658001/1?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00021421004/217?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00000619002/14?cref=1803364441\u0026spec=pc0211","https://www.ecareer.ne.jp/positions/00033732006/10?cref=1803364441\u0026spec=pc0211"],"analisys_page_count":1,"post_pagenation":null}'
      Json2.parse(tmp, symbolize: false)
    end

    def customize
      tmp = '{"multi":{
          "org_name_pathes":{"/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]/p[1]":25},
          "contents_pathes":{"/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]/ul[$LOOP$]":25,
                             "/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]":25},
          "common_item_words":[],
          "common_item_pathes":[],
          "uncommon_item_pathes":{},
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
          "corporate_area_pathes":["/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]"],
          "corporate_area_start_pathes":{"/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]":10},
          "end_pathes":{"/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]/div[2]/a/p":9},
          "separation_data":null,
          "relative":{},
          "absolute":[],"same_column":[],
          "filter_path_of_content_urls":{"/html/body/form/div/div/div[$LOOP$]/article/main/section[$LOOP$]/h2/a":10}},
        "single":{
          "org_name_pathes":{"/html/body/div[1]/div[1]/article/section/div/p[1]":11},
          "contents_pathes":{"/html/body/div[1]/div[2]/div/div[4]/div/div/div[1]/div[1]/div[$LOOP$(5-6)]/div[3]":55},
          "footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,
          "relative":{"title":["/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div/div[1]/dl[$LOOP$]/dt",
                               "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div[1]/dl[$LOOP$]/dt",
                               "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div/section[$LOOP$]/div/h2",
                               "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/section[$LOOP$]/div/h2"],
                       "text":["/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div/div[1]/dl[$LOOP$]/dd",
                               "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div[1]/dl[$LOOP$]/dd",
                               "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div/section[$LOOP$]/div/p",
                               "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/section[$LOOP$]/div/p"]},
          "absolute":{"雇用形態":["/html/body/div[1]/div[1]/article/section/div/ul[1]/li[1]"],
                      "特徴":["/html/body/div[1]/div[1]/article/section/div/ul[1]/li[$LOOP$(2-100)]"],
                      "掲載元":["/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div/div[2]/p[$LOOP$]", "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/div[2]/p[$LOOP$]"]},
          "same_column":[],
          "operations":[],
          "getting_text_operations":{ "operations":[["click", "xpath", {"path": "/html/body/div[1]/div[1]/article/div/div[$LOOP$]/section[$LOOP$]/div[$LOOP$]/a", "text": "この企業の求人を見る"} ]],
                                      "target_texts":{ "title":"求人掲載数", "pathes":["/html/body/div[1]/div/article/div/div/section[$LOOP$(1-3)]/p"] }
                                    }},
          "multi_available_urls":[]}'
      Json2.parse(tmp, symbolize: false)
    end

    private

  end
end

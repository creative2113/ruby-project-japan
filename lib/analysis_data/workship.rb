class AnalysisData::Workship < AnalysisData::Base
  class << self

    def domain
      'goworkship.com'
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
          "org_name_pathes":{"/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]/div/a/span":25},
          "contents_pathes":{"/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]/a/div/span":25,
                             "/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]/a/h3":25},
          "common_item_words":[],
          "common_item_pathes":[],
          "uncommon_item_pathes":{},
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,
          "corporate_area_pathes":["/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]"],
          "corporate_area_start_pathes":{"/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]":10},
          "end_pathes":{"/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]/div/a/span":9},
          "separation_data":null,
          "relative":{"title":[],"text":[]},
          "absolute":{
            "タイトル":[{"count":0, "up":3, "direction":"down", "down":[{"a":1}, {"h3":1}] }],
            "職種":   [{"count":0, "up":3, "direction":"down", "down":[{"a":1}, {"div":1}, {"span":1}] }]},
          "same_column":[],
          "filter_path_of_content_urls":{"/html/body/div[1]/main/div/div[2]/ul/li[$LOOP$]/div":10}},
        "single":{
          "org_name_pathes":{"/html/body/div[1]/div/section/div/div/div[1]/div/a[1]/h2":11},
          "contents_pathes":{"/html/body/div[1]/div/main/div[2]/table/tbody/tr[$LOOP$]":55,
                             "/html/body/div[1]/div/section/div/div/div[1]/div/a[2]":44},
          "footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
          "relative":{},
          "absolute":{},
          "same_column":[],
          "operations":[]},
          "multi_available_urls":[]}'
      Json2.parse(tmp, symbolize: false)
    end

    private

  end
end

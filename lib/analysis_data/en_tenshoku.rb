class AnalysisData::EnTenshoku < AnalysisData::Base
  class << self

    def domain
      'employment.en-japan.com'
    end

    def enable_process_result; true; end

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
          "org_name_pathes":{"/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[2]/div/div[1]/a/div/div[$LOOP$]/span":10},
          "contents_pathes":{"/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[2]/div/div[2]/div[3]":4},
          "common_item_words":[],
          "common_item_pathes":[],
          "uncommon_item_pathes":{},
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,
          "corporate_area_pathes":["/html/body/div[2]/div[3]/div[2]/div[$LOOP$]"],
          "corporate_area_start_pathes":{"/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[1]":10},
          "end_pathes":{"/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[2]/div/div[6]":9},
          "separation_data":null,
          "relative":{"title":["/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[2]/div/div[$LOOP$]/div[$LOOP$]/ul/li[$LOOP$]/span[1]/span"],
                      "text":["/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[2]/div/div[$LOOP$]/div[$LOOP$]/ul/li[$LOOP$]/span[2]"]},
          "absolute":[],"same_column":[],
          "filter_path_of_content_urls":{"/html/body/div[2]/div[3]/div[2]/div[$LOOP$]/div[2]/div/div[1]/a":10}},
        "single":{
          "org_name_pathes":{"/html/body/div[4]/div[$LOOP$]/div[1]/div[$LOOP$]/div[2]/span":11},
          "contents_pathes":{"/html/body/div[4]/div[$LOOP$]/div/div[$LOOP$]/table/tbody/tr[$LOOP$]":55},
          "footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
          "relative":{"title":[],"text":[]},"absolute":[],"same_column":[],
          "operations":[]},
          "multi_available_urls":[]}'
      Json2.parse(tmp, symbolize: false)
    end

    def process_result(result, type)
      return if type == SearchRequest::CorporateSingle::TYPE
      delete_row(result)
    end

    private

    def delete_row(result)
      result[:result]&.delete_if { |key, values| ['プロ取材', 'インタビュー記事掲載中！'].include?(values['組織名']) }

      pre_key = nil
      result[:result]&.each_with_index do |(key, values), i|
        if ['正社員', 'アルバイト・パート', '契約社員'].include?(values['組織名'])
          values.each do |k, v|
            next if ['組織名', '掲載ページタイトル', '掲載ページ'].include?(k)
            result[:result][pre_key][k] = v
          end
        end
        pre_key = key
      end

      result[:result]&.delete_if { |key, values| ['正社員', 'アルバイト・パート' , '契約社員'].include?(values['組織名']) }
    end
  end
end

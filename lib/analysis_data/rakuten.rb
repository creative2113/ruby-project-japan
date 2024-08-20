class AnalysisData::Rakuten < AnalysisData::Base
  class << self

    def domain
      'www.rakuten.co.jp'
    end

    def enable_process_result; true; end

    def path; nil; end

    def original
    end

    def customize
      tmp = '{"multi":{"org_name_pathes":{"/html/body/div[1]/div[3]/div[2]/div[8]/div/div/div/div[$LOOP$]/div[6]":1079},"contents_pathes":{"/html/body/div[1]/div[3]/div[2]/div[8]/div/div/div/div[$LOOP$]/div[6]":474},"common_item_words":[],
        "common_item_pathes":null,
        "uncommon_item_pathes":null,
        "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"corporate_area_pathes":{},"corporate_area_start_pathes":{},"end_pathes":{},"separation_data":[],"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],"filter_path_of_content_urls":{}},"single":{"org_name_pathes":{},"contents_pathes":{},"footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[]},"multi_available_urls":[],"js_functions":{},"accessed_count":1,"high_priority_accessed_count":0,"accessed_urls":["https://www.rakuten.co.jp/category/110662/?l-id=top_normal_gmenu_d_sake_001"],"high_priority_accessed_urls":[],"analisys_page_count":1}'
      Json2.parse(tmp, symbolize: false)
    end
  end
end

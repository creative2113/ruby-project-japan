class AnalysisData::Townpage < AnalysisData::Base
  class << self
    def domain
      'itp.ne.jp'
    end

    def enable_process_result; true; end

    def path; nil; end

    def ban_pathes
      pathes = ["#{domain}"]
      pathes.map { |path| [path, "#{path}/"] }.flatten
    end

    def original
      tmp = '{"multi":{"org_name_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/p/a":1079},"contents_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]/table/tbody/tr[3]/td":474,"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]/table/tbody/tr[$LOOP$]":474},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"corporate_area_pathes":["/html/body/div[1]/div[3]/form/div/div[$LOOP$]","/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]","/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]","/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/div/span[$LOOP$]"],"corporate_area_start_pathes":"/html/body/div[1]/div[3]/form/div/div[$LOOP$]","end_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/p[2]/span/text()":1008},"separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],"filter_path_of_content_urls":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/a":9}},"single":{"org_name_pathes":{"/html/body/div[1]/form/div[1]/div[2]/div/div[2]/div[2]/div[$LOOP$]/h1/span[2]":11,"/html/body/div[1]/div[5]/div[2]/div/div[2]/div[$LOOP$]/div[$LOOP$]/h1/span[2]":9},"contents_pathes":{"/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[$LOOP$]/tbody/tr[$LOOP$]":55,"/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[2]/tbody/tr[$LOOP$]/th":26},"footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[]},"multi_available_urls":["https://tenshoku.mynavi.jp/list/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg372/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg2/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg3/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg4/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg5/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg6/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg8/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg7/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg9/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg10/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg364/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg365/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg363/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg366/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg367/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg368/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg371/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg11/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg369/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg370/?jobsearchType=4\u0026searchType=8"],"js_functions":{},"accessed_count":21,"high_priority_accessed_count":20,"accessed_urls":["https://tenshoku.mynavi.jp/list/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg2/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg4/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg3/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg372/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg5/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg6/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg7/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg8/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg9/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg10/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg363/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg364/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg365/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg366/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg367/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg368/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg369/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg370/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg371/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg11/?jobsearchType=4\u0026searchType=8"],"high_priority_accessed_urls":["https://tenshoku.mynavi.jp/jobinfo-305644-5-7-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-224262-1-38-1/msg/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-257635-1-115-1/msg/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-304486-1-14-1/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-222030-1-2-1/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-289753-5-14-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-161913-1-2-1/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-302928-1-6-1/msg/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-222030-1-2-1/msg/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-304486-1-14-1/msg/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-161913-1-2-1/msg/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-328961-5-10-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-182119-1-67-1/msg/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-234944-1-1-1/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-26767-1-78-1/msg/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-333313-5-7-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=4","https://tenshoku.mynavi.jp/jobinfo-111025-1-126-1/msg/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-332448-1-2-1/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-234944-1-1-1/msg/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-158503-1-9-1/msg/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=3"],"analisys_page_count":21}'
      Json2.parse(tmp, symbolize: false)
    end

    def customize
      tmp = '{"multi":{
        "org_name_pathes":{"/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]/div[3]/div[2]/div[2]/div[4]/p/a":1079},

        "contents_pathes":{"/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]":474,
                           "/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]":474},
        "common_item_words":[],
        "common_item_pathes":null,"uncommon_item_pathes":null,
        "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,
        "corporate_area_pathes":["/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]"],
        "corporate_area_start_pathes":{"/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]":1079},
        "end_pathes":{"/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]/div[5]/a":1008},
        "separation_data":null,"relative":{"title":[],"text":[]},
        "absolute":{
          "業種":  [{"count":6, "up":7, "direction":"down", "down":[{"div":4}, {"div":2}, {"div":1}, {"div":1}, {"div":1}, {"p":1}, {"span":1}] }],
          "説明":  [{"count":6, "up":5, "direction":"down", "down":[{"div":1}, {"div":1}, {"div":1}, {"p":1}, {"span":1}] }],
          "最寄駅":[{"count":6, "up":5, "direction":"down", "down":[{"div":1}, {"div":1}, {"div":3}, {"div":1}, {"p":1}, {"span":1}] }] },
        "same_column":[],
        "filter_path_of_content_urls":{"/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]/div[5]/a":9,
                                       "/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[2]/div[2]/div[2]/div[$LOOP$]/div/div[$LOOP$]/div[3]/div[2]/div[2]/div[4]/p/a":9}},
        "single":{"org_name_pathes":{"/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[6]/div[2]/h1":11,
                                     "/html/body/div[3]/div/header/div/div[$LOOP$]/h1":9},
          "contents_pathes":{"/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[$LOOP$]/tbody/tr[$LOOP$]":55,
                             "/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[2]/tbody/tr[$LOOP$]/th":26},
          "footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,
          "relative":{"title":["/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[3]/div[2]/div[$LOOP$]/div[3]/h2",
                               "/html/body/div[3]/div/div/div/div[1]/div/article[1]/div/section[1]/dl[$LOOP$]/dt",
                               "/html/body/div[3]/div/div/div/div[1]/div/div[2]/article[1]/div/section[1]/dl[$LOOP$]/dt"],
                      "text":["/html/body/div/div/div[2]/div/div/div/div[2]/div/main/section[1]/div[3]/div[2]/div[$LOOP$]/div[4]",
                              "/html/body/div[3]/div/div/div/div[1]/div/article[1]/div/section[1]/dl[$LOOP$]/dd",
                              "/html/body/div[3]/div/div/div/div[1]/div/div[2]/article[1]/div/section[1]/dl[$LOOP$]/dd"]},
          "absolute":[],
          "same_column":[],
          "operations":[["click_and_find", ["/html/body/div[3]/div/nav/div/ul/li[$LOOP$]/a"], {"href":"/shop"}, {"path":"/html/body/div[3]/div/div/div/div[1]/div/article[$LOOP$]/div[$LOOP$]/section[$LOOP$]/dl[$LOOP$]/dt", "text":"掲載名"} ]]},
          "multi_available_urls":[],
          "js_functions":{},"post_pagenation":false,"accessed_count":21,"high_priority_accessed_count":20,"accessed_urls":[],"high_priority_accessed_urls":[],"analisys_page_count":21}'
      Json2.parse(tmp, symbolize: false)
    end

    def process_result(result, type)
      if type == SearchRequest::CorporateList::TYPE
        process_tel_fax(result)
      end

      if type == SearchRequest::CorporateSingle::TYPE
        process_strange_fields(result)
      end
    end

    private

    def process_tel_fax(result)
      result[:result]&.each do |key, values|
        values = values.store_after('抽出電話番号', '', '電話番号')
        values = values.store_after('抽出FAX', '', '抽出電話番号')

        next result[:result][key] = values if values['電話番号'].blank?

        if values['電話番号'].include?('(F専)')
          values['抽出FAX'] = values['電話番号'].gsub('(F専)', '').strip
        elsif values['電話番号'].include?('(F兼)')
          val = values['電話番号'].gsub('(F兼)', '').strip
          values['抽出電話番号'] = val
          values['抽出FAX'] = val
        else
          values['抽出電話番号'] = values['電話番号'].gsub('(代)', '').strip
        end

        result[:result][key] = values
      end
    end

    def process_strange_fields(result)
      result.each do |key, values|
        next if values['掲載名'].present? || values['フリガナ'].present?

        if values['組織名'] == 'Business Name'
          val = { '組織名' => '', '掲載ページタイトル' => values['掲載ページタイトル'], '掲載ページ' => values['掲載ページ'] }
          result[key] = val
          next
        end

        values.delete('店舗・施設詳細情報') if values['店舗・施設詳細情報'] == '土曜日、日曜日、祝日'
        values.delete('時間') if values['時間'] == '平日（月曜～金曜） 09:00～17:00'
        values.delete('チェックイン') if values['チェックイン'] == '16:00～'
        values.delete('チェックアウト') if values['チェックアウト'] == '～10:00'
        values.delete('医療') if values['医療'] == '取扱い商品：白馬紫米受付方法：インターネット、TEL、FAX、e-mail支払方法：クレジットカード、代金引換通販種類：インターネット通販サイト：yahoo'
        values.delete('EC') if values['EC'] == '院長：黒瀬 満郎医師人数：5人専門医：一般社団法人日本循環器学会 循環器専門医 黒瀬満郎専門医：一般社団法人日本内科学会 総合内科専門医 黒瀬満郎専門医：一般社団法人日本糖尿病学会 糖尿病専門医 守田靖子女性医師による診療：有有資格者：理学療法士、作業療法士、言語聴覚士、診療放射線技師、臨床検査技師、管理栄養士、看護士、準看護師、介護福祉士、社会福祉士、薬剤師予防接種対応：予防接種有'
        values.delete('Wi-Fi') if values['Wi-Fi'] == 'Wifi環境（公衆無線LAN） 無料Wifi'
        values.delete('休業日') if values['休業日'] == '土曜日、日曜日、祝日'
        values.delete('道の駅') if values['道の駅'] == '土曜日、日曜日、祝日'
        values.delete('休診日') if values['休診日'] == ''

        result[key] = values
      end
    end
  end
end

class AnalysisData::Rikunabi
  class Next < AnalysisData::Base
    class << self

      def domain
        'next.rikunabi.com'
      end

      def enable_process_result; false; end

      def path; nil; end

      def ban_pathes
        pathes = ["#{domain}", "#{domain}/", "https://#{domain}/docs/cp_s00700.jsp",
                  "#{domain}/rnc/docs/cp_s00700.jsp?leadtc=top_jbmodal_submit",
                  "#{domain}/rnc/docs/cp_s00700.jsp?leadtc=n_ichiran_panel_submit_btn"]
      end

      def ban_pathes_alert_message
      '取得不可能なURLです。お手数ですが、URLの注意事項とリクナビNEXTの注意事項をよくご確認して、やり直してください。'
    end

      def original
        tmp = '{"multi":{"org_name_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/p/a":1079},"contents_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]/table/tbody/tr[3]/td":474,"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]/table/tbody/tr[$LOOP$]":474},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"corporate_area_pathes":["/html/body/div[1]/div[3]/form/div/div[$LOOP$]","/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]","/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]","/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/div/span[$LOOP$]"],"corporate_area_start_pathes":"/html/body/div[1]/div[3]/form/div/div[$LOOP$]","end_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/p[2]/span/text()":1008},"separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],"filter_path_of_content_urls":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/a":9}},"single":{"org_name_pathes":{"/html/body/div[1]/form/div[1]/div[2]/div/div[2]/div[2]/div[$LOOP$]/h1/span[2]":11,"/html/body/div[1]/div[5]/div[2]/div/div[2]/div[$LOOP$]/div[$LOOP$]/h1/span[2]":9},"contents_pathes":{"/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[$LOOP$]/tbody/tr[$LOOP$]":55,"/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[2]/tbody/tr[$LOOP$]/th":26},"footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[]},"multi_available_urls":["https://tenshoku.mynavi.jp/list/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg372/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg2/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg3/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg4/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg5/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg6/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg8/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg7/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg9/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg10/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg364/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg365/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg363/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg366/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg367/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg368/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg371/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg11/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg369/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg370/?jobsearchType=4\u0026searchType=8"],"js_functions":{},"accessed_count":21,"high_priority_accessed_count":20,"accessed_urls":["https://tenshoku.mynavi.jp/list/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg2/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg4/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg3/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg372/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg5/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg6/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg7/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg8/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg9/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg10/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg363/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg364/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg365/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg366/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg367/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg368/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg369/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg370/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg371/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg11/?jobsearchType=4\u0026searchType=8"],"high_priority_accessed_urls":["https://tenshoku.mynavi.jp/jobinfo-305644-5-7-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-224262-1-38-1/msg/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-257635-1-115-1/msg/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-304486-1-14-1/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-222030-1-2-1/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-289753-5-14-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-161913-1-2-1/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-302928-1-6-1/msg/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-222030-1-2-1/msg/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-304486-1-14-1/msg/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=1","https://tenshoku.mynavi.jp/jobinfo-161913-1-2-1/msg/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-328961-5-10-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-182119-1-67-1/msg/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-234944-1-1-1/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-26767-1-78-1/msg/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=2","https://tenshoku.mynavi.jp/jobinfo-333313-5-7-1/?ty=fnc_sr\u0026searchId=1382987171\u0026pageNum=372\u0026showNo=4","https://tenshoku.mynavi.jp/jobinfo-111025-1-126-1/msg/?ty=rzs\u0026searchId=1382987146\u0026pageNum=1\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-332448-1-2-1/?ty=fnc_sr\u0026searchId=1382987170\u0026pageNum=3\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-234944-1-1-1/msg/?ty=fnc_sr\u0026searchId=1382987169\u0026pageNum=4\u0026showNo=3","https://tenshoku.mynavi.jp/jobinfo-158503-1-9-1/msg/?ty=fnc_sr\u0026searchId=1382987167\u0026pageNum=2\u0026showNo=3"],"analisys_page_count":21}'
        Json2.parse(tmp, symbolize: false)
      end

      def customize
        tmp = '{"multi":{
          "org_name_pathes":{"/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]/div[1]/p":1079},

          "contents_pathes":{"/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]/a/div[2]/table/tbody":474},
          "common_item_words":[],
          "common_item_pathes":null,"uncommon_item_pathes":null,
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
          "corporate_area_pathes":["/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]"],
          "corporate_area_start_pathes":{"/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]/div":1079},
          "end_pathes":{"/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]/div[2]/div/div[2]/div/div[2]":1008},
          "separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],
          "filter_path_of_content_urls":{"/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]/div[1]/h2/a":9,
                                         "/html/body/div[3]/div[2]/div/div[1]/div[2]/div[1]/ul[1]/li[$LOOP$]/div[1]/p/a":9}},
          "single":{"org_name_pathes":{"/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[3]/div/div[1]/p":11,
                                       "/html/body/ul/li[4]":9},
            "contents_pathes":{"/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[3]/div":55,
                               "/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[4]/div[1]/div[3]/div":55,
                               "/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[3]/div/div[7]":26,
                               "/html/body/div[3]/div[1]/div/div/table/tbody[$LOOP$]":26},
            "footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,
            "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,
            "relative":{"title":{"/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[3]/div/div[$LOOP$]/h3":6,
                                 "/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[4]/div[1]/div[3]/h3":6,
                                 "/html/body/div[3]/div[1]/div/div/table/tbody[$LOOP$]/tr[$LOOP$]/th":6},
                         "text":{"/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[3]/div/div[$LOOP$]/p":6,
                                 "/html/body/div[3]/div[1]/div[1]/div[6]/div[1]/div[4]/div[1]/div[3]/div":6,
                                 "/html/body/div[3]/div[1]/div/div/table/tbody[$LOOP$]/tr[$LOOP$]/td":6}},
            "absolute":[],"same_column":[],
            "operations":[["click", "xpath","/html/body/div[3]/div[1]/div[1]/div[4]/div/div[2]/div[3]/div/ul/li[2]/a/span"]]},
            "multi_available_urls":[],"js_functions":{},"accessed_count":0,"high_priority_accessed_count":0,"accessed_urls":[],
            "high_priority_accessed_urls":[],"analisys_page_count":0}'
        Json2.parse(tmp, symbolize: false)
      end
    end
  end
end

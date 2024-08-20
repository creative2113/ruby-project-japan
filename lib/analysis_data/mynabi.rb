class AnalysisData::Mynabi
  class Tenshyoku < AnalysisData::Base
    class << self

      def domain
        'tenshoku.mynavi.jp'
      end

      def enable_process_result; false; end

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
          "org_name_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/h3":1079,
                             "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]/div[1]/div[4]/h2/p[1]":1079,
                             "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]/div[1]/div[4]/p[1]":1079},
          "contents_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/p/a":474,
                             "/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]/table/tbody/tr[3]/td":474,
                             "/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]/table/tbody/tr[$LOOP$]":474,
                             "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]/div[1]/div[4]/h2/p[2]/a":474,
                             "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]/div[1]/div[5]/div[$LOOP$]/div[1]/table/tbody/tr[$LOOP$]":474},
          "common_item_words":[],
          "common_item_pathes":null,"uncommon_item_pathes":null,
          "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
          "corporate_area_pathes":["/html/body/div[1]/div[3]/form/div/div[$LOOP$]",
                                   "/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]",
                                   "/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/div[$LOOP$]",
                                   "/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/section/div/span[$LOOP$]",
                                   "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]"],
          "corporate_area_start_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]":1079,
                                         "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]":1079},
          "end_pathes":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/p[2]/span/text()":1008,
                        "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]/div[1]/div[6]/div[2]/p[2]":1008},
          "separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],
          "filter_path_of_content_urls":{"/html/body/div[1]/div[3]/form/div/div[$LOOP$]/div/div[$LOOP$]/a":9,
                                         "/html/body/div[1]/div/div[2]/div[$LOOP$]/section[$LOOP$]/div[1]/div[6]/div[1]/a":9}},
          "single":{"org_name_pathes":{"/html/body/div[1]/form/div[1]/div[2]/div/div[2]/div[2]/div[$LOOP$]/h1/span[2]":11,
                                       "/html/body/div[1]/div[5]/div[2]/div/div[2]/div[$LOOP$]/div[$LOOP$]/h1/span[2]":9},
            "contents_pathes":{"/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[$LOOP$]/tbody/tr[$LOOP$]":55,
                               "/html/body/div[1]/div[5]/div[4]/div/div[2]/div[1]/table[2]/tbody/tr[$LOOP$]/th":26},
            "footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,
            "reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
            "relative":{"title":[],"text":[]},"absolute":[],"same_column":[],
            "operations":[["click", "xpath","/html/body/div[1]/form/div[1]/nav[1]/ul/li[1]"]]},
            "multi_available_urls":["https://tenshoku.mynavi.jp/list/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg372/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg2/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg3/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg4/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg5/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg6/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg8/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg7/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg9/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg10/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg364/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg365/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg363/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg366/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg367/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg368/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg371/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg11/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg369/?jobsearchType=4\u0026searchType=8","https://tenshoku.mynavi.jp/list/pg370/?jobsearchType=4\u0026searchType=8"],"js_functions":{},"accessed_count":21,"high_priority_accessed_count":20,"accessed_urls":[],"high_priority_accessed_urls":[],"analisys_page_count":21}'
        Json2.parse(tmp, symbolize: false)
      end
    end
  end

  class Gakusei < AnalysisData::Base
    class << self

      def domain
        'job.mynavi.jp'
      end

      def path
        'job.mynavi.jp/24'
      end

      def original
      end

      def customize
      end
    end
  end
end

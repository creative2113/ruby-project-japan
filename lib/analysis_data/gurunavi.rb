class AnalysisData::Gurunavi < AnalysisData::Base
  class << self

    def domain
      'r.gnavi.co.jp'
    end

    def enable_process_result; true; end

    def path; nil; end

    def original
      tmp = '{"multi":{"org_name_pathes":{"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[1]/a/h2":40},"contents_pathes":{"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/img":149,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/span/img":149,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/noscript/img":137,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/figcaption/p[$LOOP$]":173},"common_item_words":["店貸切","1,980円(税込)","テーブル席 2名様～4名様","かなわ  こだわりの画像 かなわ  コースの画像","てんぷら 天朝  店内の画像 てんぷら 天朝  こだわりの画像","天ぷら 阿部 銀座8丁目店 店内の画像 天ぷら 阿部 銀座8丁目店 こだわりの画像","銀座 天國  メニューの画像 銀座 天國  店内の画像 銀座 天國  コースの画像","博多水炊きと焼き鳥 鳥善銀座店 店内の画像 博多水炊きと焼き鳥 鳥善銀座店 コースの画像","てんぷら近藤  店内の画像 てんぷら近藤  こだわりの画像 てんぷら近藤  コースの画像","小松庵総本家 銀座  メニューの画像 小松庵総本家 銀座  店内の画像 小松庵総本家 銀座  こだわりの画像","天ぷら 阿部 銀座本店 メニューの画像 天ぷら 阿部 銀座本店 店内の画像 天ぷら 阿部 銀座本店 こだわりの画像","バードランド  メニューの画像 バードランド  店内の画像 バードランド  こだわりの画像 バードランド  コースの画像","焼鳥 くふ楽 銀座総本店  店内の画像 焼鳥 くふ楽 銀座総本店  こだわりの画像 焼鳥 くふ楽 銀座総本店  コースの画像","銀座ハゲ天 本店 メニューの画像 銀座ハゲ天 本店 店内の画像 銀座ハゲ天 本店 こだわりの画像 銀座ハゲ天 本店 コースの画像","焼とり 鳥ぼんち  メニューの画像 焼とり 鳥ぼんち  店内の画像 焼とり 鳥ぼんち  こだわりの画像 焼とり 鳥ぼんち  コースの画像","銀座くらはし‐hanare‐  店内の画像 銀座くらはし‐hanare‐  こだわりの画像 銀座くらはし‐hanare‐  コースの画像","日本橋やぶ久 銀座店 メニューの画像 日本橋やぶ久 銀座店 店内の画像 日本橋やぶ久 銀座店 こだわりの画像 日本橋やぶ久 銀座店 コースの画像","【銀座】焼き鳥・釜飯ニュー鳥ぎん  メニューの画像 【銀座】焼き鳥・釜飯ニュー鳥ぎん  こだわりの画像 【銀座】焼き鳥・釜飯ニュー鳥ぎん  コースの画像","串焼BISTRO 福みみコリドー店  店内の画像 串焼BISTRO 福みみコリドー店  こだわりの画像 串焼BISTRO 福みみコリドー店  コースの画像","銀座じゃのめ 銀座三丁目店 メニューの画像 銀座じゃのめ 銀座三丁目店 店内の画像 銀座じゃのめ 銀座三丁目店 こだわりの画像 銀座じゃのめ 銀座三丁目店 コースの画像","銀座 神籬 ＜ひもろぎ＞  メニューの画像 銀座 神籬 ＜ひもろぎ＞  店内の画像 銀座 神籬 ＜ひもろぎ＞  こだわりの画像 銀座 神籬 ＜ひもろぎ＞  コースの画像","完全個室 和食 入母屋 ～別邸～ 銀座七丁目店 店内の画像 完全個室 和食 入母屋 ～別邸～ 銀座七丁目店 こだわりの画像 完全個室 和食 入母屋 ～別邸～ 銀座七丁目店 コースの画像","焼き鶏喰って蕎麦で〆る一 hajime  メニューの画像 焼き鶏喰って蕎麦で〆る一 hajime  店内の画像 焼き鶏喰って蕎麦で〆る一 hajime  こだわりの画像 焼き鶏喰って蕎麦で〆る一 hajime  コースの画像","鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 メニューの画像 鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 店内の画像 鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 こだわりの画像 鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 コースの画像","Up Town 銀座 生牡蠣とカリフォルニアワインのお店 メニューの画像 Up Town 銀座 生牡蠣とカリフォルニアワインのお店 店内の画像 Up Town 銀座 生牡蠣とカリフォルニアワインのお店 こだわりの画像 Up Town 銀座 生牡蠣とカリフォルニアワインのお店 コースの画像"],"common_item_pathes":["/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/span/img","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/img","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/noscript/img","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/figcaption/p[$LOOP$]"],"uncommon_item_pathes":{},"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"corporate_area_pathes":["/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[4]/ul/li[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[3]/div[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[5]/div/a/div/div/span[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]/span/span[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[13]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]"],"corporate_area_start_pathes":"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]","end_pathes":{"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[2]/span[3]/text()":20,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[4]/ul/li[$LOOP$]/text()":3},"separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],"filter_path_of_content_urls":{}},"single":{"org_name_pathes":{},"contents_pathes":{},"footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,"relative":{"title":{"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/table/tbody/tr[$LOOP$]/th":2,"/html/body/div[2]/div[2]/header/div/div/div[1]/dl/dt[$LOOP$]":2,"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/section[2]/div/table/tbody/tr[2]/th":1},"text":{"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/table/tbody/tr[1]/td/p[1]":1,"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/table/tbody/tr[4]/td/ul/li[1]":1,"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/section[2]/div/table/tbody/tr[2]/td/ul/li":1,"/html/body/div[2]/div[2]/header/div/div/div[1]/dl/dd[1]":1,"/html/body/div[2]/div[2]/header/div/div/div[1]/dl/dd[2]/ul/li[1]/a":1}},"absolute":{},"same_column":{}},"multi_available_urls":["https://r.gnavi.co.jp/area/aream2105/rs/?cuisine=OYSTER,TEMPURA,TONKATSU,UDONSOBA,YAKITORI"],"js_functions":{},"accessed_count":1,"high_priority_accessed_count":1,"accessed_urls":["https://r.gnavi.co.jp/area/aream2105/rs/?cuisine=OYSTER,TEMPURA,TONKATSU,UDONSOBA,YAKITORI"],"high_priority_accessed_urls":["https://r.gnavi.co.jp/b4pxc3xr0000/"],"analisys_page_count":1}'

      '{"multi":{"org_name_pathes":{"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[1]/a/h2":40},"contents_pathes":{"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/img":149,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/span/img":149,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/noscript/img":137,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/figcaption/p[$LOOP$]":173},"common_item_words":["店貸切","1,980円(税込)","テーブル席 2名様～4名様","かなわ  こだわりの画像 かなわ  コースの画像","てんぷら 天朝  店内の画像 てんぷら 天朝  こだわりの画像","天ぷら 阿部 銀座8丁目店 店内の画像 天ぷら 阿部 銀座8丁目店 こだわりの画像","銀座 天國  メニューの画像 銀座 天國  店内の画像 銀座 天國  コースの画像","博多水炊きと焼き鳥 鳥善銀座店 店内の画像 博多水炊きと焼き鳥 鳥善銀座店 コースの画像","てんぷら近藤  店内の画像 てんぷら近藤  こだわりの画像 てんぷら近藤  コースの画像","小松庵総本家 銀座  メニューの画像 小松庵総本家 銀座  店内の画像 小松庵総本家 銀座  こだわりの画像","天ぷら 阿部 銀座本店 メニューの画像 天ぷら 阿部 銀座本店 店内の画像 天ぷら 阿部 銀座本店 こだわりの画像","バードランド  メニューの画像 バードランド  店内の画像 バードランド  こだわりの画像 バードランド  コースの画像","焼鳥 くふ楽 銀座総本店  店内の画像 焼鳥 くふ楽 銀座総本店  こだわりの画像 焼鳥 くふ楽 銀座総本店  コースの画像","銀座ハゲ天 本店 メニューの画像 銀座ハゲ天 本店 店内の画像 銀座ハゲ天 本店 こだわりの画像 銀座ハゲ天 本店 コースの画像","焼とり 鳥ぼんち  メニューの画像 焼とり 鳥ぼんち  店内の画像 焼とり 鳥ぼんち  こだわりの画像 焼とり 鳥ぼんち  コースの画像","銀座くらはし‐hanare‐  店内の画像 銀座くらはし‐hanare‐  こだわりの画像 銀座くらはし‐hanare‐  コースの画像","日本橋やぶ久 銀座店 メニューの画像 日本橋やぶ久 銀座店 店内の画像 日本橋やぶ久 銀座店 こだわりの画像 日本橋やぶ久 銀座店 コースの画像","【銀座】焼き鳥・釜飯ニュー鳥ぎん  メニューの画像 【銀座】焼き鳥・釜飯ニュー鳥ぎん  こだわりの画像 【銀座】焼き鳥・釜飯ニュー鳥ぎん  コースの画像","串焼BISTRO 福みみコリドー店  店内の画像 串焼BISTRO 福みみコリドー店  こだわりの画像 串焼BISTRO 福みみコリドー店  コースの画像","銀座じゃのめ 銀座三丁目店 メニューの画像 銀座じゃのめ 銀座三丁目店 店内の画像 銀座じゃのめ 銀座三丁目店 こだわりの画像 銀座じゃのめ 銀座三丁目店 コースの画像","銀座 神籬 ＜ひもろぎ＞  メニューの画像 銀座 神籬 ＜ひもろぎ＞  店内の画像 銀座 神籬 ＜ひもろぎ＞  こだわりの画像 銀座 神籬 ＜ひもろぎ＞  コースの画像","完全個室 和食 入母屋 ～別邸～ 銀座七丁目店 店内の画像 完全個室 和食 入母屋 ～別邸～ 銀座七丁目店 こだわりの画像 完全個室 和食 入母屋 ～別邸～ 銀座七丁目店 コースの画像","焼き鶏喰って蕎麦で〆る一 hajime  メニューの画像 焼き鶏喰って蕎麦で〆る一 hajime  店内の画像 焼き鶏喰って蕎麦で〆る一 hajime  こだわりの画像 焼き鶏喰って蕎麦で〆る一 hajime  コースの画像","鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 メニューの画像 鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 店内の画像 鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 こだわりの画像 鳥と手打ち蕎麦 とり数寄 東急プラザ銀座店 コースの画像","Up Town 銀座 生牡蠣とカリフォルニアワインのお店 メニューの画像 Up Town 銀座 生牡蠣とカリフォルニアワインのお店 店内の画像 Up Town 銀座 生牡蠣とカリフォルニアワインのお店 こだわりの画像 Up Town 銀座 生牡蠣とカリフォルニアワインのお店 コースの画像"],"common_item_pathes":["/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/span/img","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/img","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/noscript/img","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/figcaption/p[$LOOP$]"],"uncommon_item_pathes":{},"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,"corporate_area_pathes":["/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[4]/ul/li[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[3]/div[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[5]/div/a/div/div/span[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]/span/span[$LOOP$]","/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[13]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]"],"corporate_area_start_pathes":"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]","end_pathes":{"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[2]/span[3]/text()":20,"/html/body/div[1]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[4]/ul/li[$LOOP$]/text()":3},"separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],"filter_path_of_content_urls":{}},"single":{"org_name_pathes":{},"contents_pathes":{},"footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":true,"relative":{"title":{"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/table/tbody/tr[$LOOP$]/th":2,"/html/body/div[2]/div[2]/header/div/div/div[1]/dl/dt[$LOOP$]":2,"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/section[2]/div/table/tbody/tr[2]/th":1},"text":{"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/table/tbody/tr[1]/td/p[1]":1,"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/table/tbody/tr[4]/td/ul/li[1]":1,"/html/body/div[2]/div[2]/div[3]/div[1]/section[5]/div[2]/div[1]/div/section[2]/div/table/tbody/tr[2]/td/ul/li":1,"/html/body/div[2]/div[2]/header/div/div/div[1]/dl/dd[1]":1,"/html/body/div[2]/div[2]/header/div/div/div[1]/dl/dd[2]/ul/li[1]/a":1}},"absolute":{},"same_column":{}},"multi_available_urls":["https://r.gnavi.co.jp/area/aream2105/rs/?cuisine=OYSTER,TEMPURA,TONKATSU,UDONSOBA,YAKITORI"],"js_functions":{},"accessed_count":1,"high_priority_accessed_count":1,"accessed_urls":["https://r.gnavi.co.jp/area/aream2105/rs/?cuisine=OYSTER,TEMPURA,TONKATSU,UDONSOBA,YAKITORI"],"high_priority_accessed_urls":["https://r.gnavi.co.jp/b4pxc3xr0000/"],"analisys_page_count":1}'

      Json2.parse(tmp, symbolize: false)
    end

    def customize
      tmp = '{"multi":{"org_name_pathes":{"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[1]/a/h2":40},
      "contents_pathes":{"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/img":149,"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/span/img":149,"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/noscript/img":137,"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/figcaption/p[$LOOP$]":173},
      "common_item_words":[],"common_item_pathes":["/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/span/img","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/img","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/span[2]/noscript/img","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]/figure/figcaption/p[$LOOP$]"],
      "uncommon_item_pathes":{},"reserved_common_item_words":[],"delimiter":[],"contents_config_mode":false,
      "corporate_area_pathes":["/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[4]/ul/li[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[3]/div[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[5]/div/a/div/div/span[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a/ul/li[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]/span/span[$LOOP$]","/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[13]/article/div[7]/div/div[1]/table/tbody/tr/td[$LOOP$]"],
      "corporate_area_start_pathes":{"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]":40},
      "end_pathes":{"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[7]/div/div[2]/span[3]/text()":20,"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[4]/ul/li[$LOOP$]/text()":3},
      "separation_data":null,"relative":{"title":[],"text":[]},"absolute":[],"same_column":[],
      "filter_path_of_content_urls":{"/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[1]/a":20,
                                     "/html/body/div[$LOOP$]/div/div[2]/main/div[$LOOP$]/div[2]/div[$LOOP$]/article/div[2]/div/a":20}},
      "single":{"org_name_pathes":{"/html/body/div[$LOOP$]/div[$LOOP$]/header/div/div/div[2]/div/div[1]/div/div[$LOOP$]/h1":2,"/html/body/div[$LOOP$]/div[$LOOP$]/header/div/div/div[2]/div[1]/div[1]/h1":2},
      "contents_pathes":{},"footer_pathes":{},"common_item_words":[],"common_item_pathes":null,"uncommon_item_pathes":null,"reserved_common_item_words":[],
      "delimiter":[],"contents_config_mode":true,
      "relative":{"title":{"/html/body/div[$LOOP$]/div[$LOOP$]/div[3]/div[1]/section[$LOOP$]/div[$LOOP$]/div[1]/div/table/tbody/tr[$LOOP$]/th":2,"/html/body/div[$LOOP$]/div[$LOOP$]/div[3]/div[1]/section[$LOOP$]/div[$LOOP$]/div[1]/div/section[$LOOP$]/div/table/tbody/tr[$LOOP$]/th":2,"/html/body/div[$LOOP$]/div[$LOOP$]/header/div/div/div[1]/dl/dt[$LOOP$]":2},
                  "text":{"/html/body/div[$LOOP$]/div[$LOOP$]/div[3]/div[1]/section[$LOOP$]/div[$LOOP$]/div[1]/div/table/tbody/tr[$LOOP$]/td":2,"/html/body/div[$LOOP$]/div[$LOOP$]/div[3]/div[1]/section[$LOOP$]/div[$LOOP$]/div[1]/div/section[$LOOP$]/div/table/tbody/tr[$LOOP$]/td":2,"/html/body/div[$LOOP$]/div[$LOOP$]/header/div/div/div[1]/dl/dd[$LOOP$]":1}},
      "absolute":{},"same_column":{}},"multi_available_urls":["https://r.gnavi.co.jp/area/aream2105/rs/?cuisine=OYSTER,TEMPURA,TONKATSU,UDONSOBA,YAKITORI"],
      "js_functions":{},"accessed_count":1,"high_priority_accessed_count":1,
      "accessed_urls":["https://r.gnavi.co.jp/area/aream2105/rs/?cuisine=OYSTER,TEMPURA,TONKATSU,UDONSOBA,YAKITORI"],
      "high_priority_accessed_urls":["https://r.gnavi.co.jp/b4pxc3xr0000/"],"analisys_page_count":1}'

      Json2.parse(tmp, symbolize: false)
    end

    def process_result(result, type)
      if type == SearchRequest::CorporateList::TYPE
        process_pr_name(result)
      end

      if type == SearchRequest::CorporateSingle::TYPE
        process_name(result)
        process_address(result)
        process_tel_fax(result)
      end
    end

    private

    def process_pr_name(result)
      result[:result]&.each do |key, values|
        next if values['組織名'].blank? || values['組織名情報'].blank?
        next unless values['組織名'] == 'PR'

        values['組織名'] = values['組織名情報'].hyper_strip
        result[:result][key] = values
      end
    end

    def process_name(result)
      result.each do |key, values|
        next if values['組織名情報'].blank?

        values['組織名'] = values['組織名'] + ' ' + values['組織名情報'].hyper_strip
        result[key] = values
      end
    end

    def process_address(result)
      result.each do |key, values|
        next if values['住所'].blank? || values['郵便番号、住所'].blank?

        values['住所'] = values['郵便番号、住所'].split(values['郵便番号'])[1].hyper_strip
        result[key] = values
      end
    end

    def process_tel_fax(result)
      data = Crawler::Country.find(Crawler::Country.japan[:english]).new

      result.each do |key, values|
        next if values['電話番号'].blank? && values['電話番号・FAX'].blank?

        if values['電話番号'].present?
          tel_map = values['電話番号'].split(':')
          tel_map.delete_if { |str| !data.include_phone_number?(str) }
          tel_map.join(':').hyper_strip

          v = tel_map.join(':').hyper_strip
          values = values.store_after('電話番号', v, '掲載ページ')
          result[key] = values
          next
        end

        if values['電話番号・FAX'].present?
          tmp_tel = values['電話番号・FAX'].dup
          v_tel = tmp_tel.split(':')[0].hyper_strip
          values = values.store_after('電話番号', v_tel, '掲載ページ')
          v_fax = tmp_tel.split('FAX')[-1].split(':')[-1].hyper_strip if tmp_tel.include?('FAX')
          values = values.store_after('FAX', v_fax, '電話番号')
          values['電話番号・FAX'] = tmp_tel.gsub(': お問合わせの際はぐるなびを見たというとスムーズです。', '').gsub(': ご予約の際ぐるなびを見たというとスムーズです。', '').gsub(': ネット予約はこちらから', '').hyper_strip
          result[key] = values
          next
        end
      end
    end
  end
end

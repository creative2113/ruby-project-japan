require 'rails_helper'

RSpec.describe DataCombiner, type: :model do
  let(:user) { create(:user) }
  let(:r1) { create(:request, :corporate_site_list, user: user) }

  let(:s1) { create(:corporate_single_requested_url_finished, :a, request: r1) }
  let(:s2) { create(:corporate_single_requested_url_finished, :b, request: r1) }
  let(:s3) { create(:corporate_single_requested_url_finished, :c, request: r1) }

  let(:combined_header) { {"組織名" => 1, "掲載ページタイトル" => 1, "掲載ページ" => 1, "仕切り情報" => 1, "電話番号" => 1, "URL" => 1, "組織名(個別ページ)" => 1, "掲載ページタイトル(個別ページ)" => 1, "掲載ページ(個別ページ)" => 1, "郵便番号(個別ページ)" => 1, "所在地(個別ページ)" => 1, "住所(個別ページ)" => 1, "電話番号(個別ページ)" => 1, "URL(個別ページ)" => 1, "ホームページ(個別ページ)" => 1, "業務分類(個別ページ)" => 1, "資本金(個別ページ)" => 1, "従業員数(個別ページ)" => 1} }

  let(:combined_result) do
    {"AAA織物工業 http://www.example.com/index.html"=>combined_result1,
     "BBB株式会社 http://www.example.com/index.html"=>combined_result2,
     "CCC捺染工場 http://www.example.com/index.html"=>combined_result3
    }
  end

  let(:combined_result1) do
    {"組織名"=>"AAA織物工業",
     "掲載ページタイトル"=>"一覧ページ",
     "掲載ページ"=>"http://www.example.com/index.html",
     "仕切り情報"=>"工業製品1",
     "電話番号"=>"000-000-0001",
     "URL"=>"http://www.aaa.jp/",
     "組織名(個別ページ)"=>"AAA織物工業",
     "掲載ページタイトル(個別ページ)"=>"AAA織物工業のページ",
     "掲載ページ(個別ページ)"=>"http://www.example.com/companies/aaa.html",
     "郵便番号(個別ページ)"=>"100-0001",
     "所在地(個別ページ)"=>"〒100-0001 東京都大和市南町1-1-1",
     "住所(個別ページ)"=>"東京都大和市南町1-1-1",
     "電話番号(個別ページ)"=>"000-000-0001",
     "URL(個別ページ)"=>"http://www.aaa.jp/",
     "ホームページ(個別ページ)"=>"http://www.aaa.jp/",
     "資本金(個別ページ)"=>"100万円",
     "従業員数(個別ページ)"=>"40人"
    }
  end

  let(:combined_result2) do
    {"組織名"=>"BBB株式会社",
     "掲載ページタイトル"=>"一覧ページ",
     "掲載ページ"=>"http://www.example.com/index.html",
     "仕切り情報"=>"工業製品1",
     "電話番号"=>"000-000-0002",
     "URL"=>"http://bbb.co.jp",
     "組織名(個別ページ)"=>"BBB株式会社",
     "掲載ページタイトル(個別ページ)"=>"BBB株式会社のページ",
     "掲載ページ(個別ページ)"=>"http://www.example.com/companies/bbb.html",
     "郵便番号(個別ページ)"=>"200-0002",
     "所在地(個別ページ)"=>"〒200-0002 東京都北区南町2-2-2",
     "住所(個別ページ)"=>"東京都北区南町2-2-2",
     "電話番号(個別ページ)"=>"000-000-0002",
     "URL(個別ページ)"=>"http://www.bbb.jp/",
     "ホームページ(個別ページ)"=>"http://bbb.co.jp",
     "業務分類(個別ページ)"=>"鉄鋼業",
     "資本金(個別ページ)"=>"500万円"
    }
  end

  let(:combined_result3) do
    {"組織名"=>"CCC捺染工場",
     "掲載ページタイトル"=>"一覧ページ",
     "掲載ページ"=>"http://www.example.com/index.html",
     "仕切り情報"=>"工業製品2",
     "電話番号"=>"000-000-0003",
     "組織名(個別ページ)"=>"CCC捺染工場",
     "掲載ページタイトル(個別ページ)"=>"CCC捺染工場のページ",
     "掲載ページ(個別ページ)"=>"http://www.example.com/companies/ccc.html",
     "郵便番号(個別ページ)"=>"300-0003",
     "所在地(個別ページ)"=>"〒300-0003 東京都西区南町3-3-3",
     "住所(個別ページ)"=>"東京都西区南町3-3-3",
     "電話番号(個別ページ)"=>"000-000-0003",
     "ホームページ(個別ページ)"=>"http://ccc.co.jp",
     "業務分類(個別ページ)"=>"染色業",
     "従業員数(個別ページ)"=>"100人"
    }
  end

  describe '#combine_results' do
    shared_examples '結合結果が正しいこと' do
      it 'ヘッダが正しいこと' do
        seeker = described_class.new(request: r1).combine_results(corp_list_url1)
        expect(seeker.headers).to eq combined_header.keys
      end

      it '結果が結合されていること' do
        seeker = described_class.new(request: r1).combine_results(corp_list_url1)
        expect(seeker.combined_result).to eq combined_result
      end
    end

    before do
      corp_list_url1
      s1
      s2
      s3
    end

    context 'resultの場合' do
      let(:corp_list_url1) { create(:corporate_list_requested_url_finished, :result_1, request: r1, result_attrs: { single_url_ids: single_url_ids } ) }

      context 'single_url_idsがnilのとき' do
        let(:single_url_ids) { nil }

        it_behaves_like '結合結果が正しいこと'
      end

      context 'single_url_idsが全てあるとき' do
        let(:single_url_ids) { [s1.id, s2.id, s3.id].to_json }

        it_behaves_like '結合結果が正しいこと'
      end

      context 'single_url_idsが全てあるとき' do
        let(:single_url_ids) { [s1.id, s3.id].to_json }

        it_behaves_like '結合結果が正しいこと'
      end

      context 'single_url_idsが1万以上あるとき' do
        let(:single_url_ids) {
          ids = []
          1_050.times do |i|
            ids << i + 1
          end
          (ids + [s1.id, s2.id, s3.id]).uniq.to_json
        }

        it_behaves_like '結合結果が正しいこと'
      end
    end

    context 'table_resultの場合' do
      let(:corp_list_url1) { create(:corporate_list_requested_url_finished, :table_result_1, request: r1, result_attrs: { single_url_ids: single_url_ids } ) }

      context 'single_url_idsがnilのとき' do
        let(:single_url_ids) { nil }

        it_behaves_like '結合結果が正しいこと'
      end

      context 'single_url_idsが全てあるとき' do
        let(:single_url_ids) { [s1.id, s2.id, s3.id].to_json }

        it_behaves_like '結合結果が正しいこと'
      end

      context 'single_url_idsが一部あるとき' do
        let(:single_url_ids) { [s1.id, s3.id].to_json }

        it_behaves_like '結合結果が正しいこと'
      end

      context 'single_url_idsが1千以上あるとき' do
        let(:single_url_ids) {
          ids = []
          1_050.times do |i|
            ids << i + 1
          end
          (ids + [s1.id, s2.id, s3.id]).uniq.to_json
        }

        it_behaves_like '結合結果が正しいこと'
      end
    end
  end

  describe '#combine_results_and_save_tmp_company_info_urls' do
    subject { described_class.new(request: r1).combine_results_and_save_tmp_company_info_urls(result_file_id) }

    let(:corp_list_url1) { create(:corporate_list_requested_url_finished, :result_1, request: r1, result_attrs: { single_url_ids: single_url_ids } ) }
    let(:single_url_ids) { nil }
    let(:result_file_id) { nil }

    before do
      corp_list_url1
      s1
      s2
      s3
    end

    shared_examples '結合結果が正しいこと' do
      it '結合されていること' do
        subject

        expect(r1.tmp_company_info_urls[0].corporate_list_result).to eq combined_result1.to_json
        expect(r1.tmp_company_info_urls[1].corporate_list_result).to eq combined_result2.to_json
        expect(r1.tmp_company_info_urls[2].corporate_list_result).to eq combined_result3.to_json
      end
    end

    it_behaves_like '結合結果が正しいこと'

    it 'TmpCompanyInfoUrlが３つ増えること' do
      expect{subject}.to change(TmpCompanyInfoUrl, :count).by(3)
    end

    describe 'bunch_id' do
      context 'TmpCompanyInfoUrlがない時' do
        it 'bunch_idが1である' do
          subject

          expect(r1.tmp_company_info_urls[0].bunch_id).to eq 1
          expect(r1.tmp_company_info_urls[1].bunch_id).to eq 1
          expect(r1.tmp_company_info_urls[2].bunch_id).to eq 1
        end
      end

      context 'TmpCompanyInfoUrlがある時' do
        before { create(:tmp_company_info_url, request: r1, bunch_id: 3) }

        it 'bunch_idが4である' do
          subject

          expect(r1.tmp_company_info_urls[1].bunch_id).to eq 4
          expect(r1.tmp_company_info_urls[2].bunch_id).to eq 4
          expect(r1.tmp_company_info_urls[3].bunch_id).to eq 4
        end
      end
    end

    context 'result_file_idがある時' do
      let(:result_file_id) { 7 }

      it_behaves_like '結合結果が正しいこと'

      context 'TmpCompanyInfoUrlがない時' do
        it 'result_file_idが7である' do
          subject

          expect(r1.tmp_company_info_urls[0].result_file_id).to eq 7
          expect(r1.tmp_company_info_urls[1].result_file_id).to eq 7
          expect(r1.tmp_company_info_urls[2].result_file_id).to eq 7
        end
      end

      context 'TmpCompanyInfoUrlがある時' do
        let(:result_file_id) { 28 }

        before do
          create(:tmp_company_info_url, request: r1, bunch_id: 3, result_file_id: 15)
          create(:tmp_company_info_url, request: r1, bunch_id: 3, result_file_id: 16)
          create(:tmp_company_info_url, request: r1, bunch_id: 3, result_file_id: 17)
          create(:tmp_company_info_url, request: r1, bunch_id: 3, result_file_id: 18)
        end

        it 'result_file_idが28である' do
          subject

          expect(r1.tmp_company_info_urls[0].result_file_id).to eq 15
          expect(r1.tmp_company_info_urls[1].result_file_id).to eq 16
          expect(r1.tmp_company_info_urls[2].result_file_id).to eq 17
          expect(r1.tmp_company_info_urls[3].result_file_id).to eq 18
          expect(r1.tmp_company_info_urls[4].result_file_id).to eq 28
          expect(r1.tmp_company_info_urls[5].result_file_id).to eq 28
          expect(r1.tmp_company_info_urls[6].result_file_id).to eq 28
        end
      end
    end

    it 'ヘッダが正しいこと' do
      dc = described_class.new(request: r1)
      dc.combine_results_and_save_tmp_company_info_urls

      expect(dc.headers).to eq combined_header
    end

    context 'single_url_idsが全てあるとき' do
      let(:single_url_ids) { [s1.id, s2.id, s3.id].to_json }
      it_behaves_like '結合結果が正しいこと'
    end

    context 'single_url_idsが一部あるとき' do
      let(:single_url_ids) { [s1.id, s3.id].to_json }
      it_behaves_like '結合結果が正しいこと'
    end

    context 'single_url_idsが1千以上あるとき' do
      let(:single_url_ids) {
        ids = []
        1_050.times do |i|
          ids << i + 1
        end
        (ids + [s1.id, s2.id, s3.id]).uniq.to_json
      }

      it_behaves_like '結合結果が正しいこと'
    end

    describe 'excel_row_limitに関して' do
      subject { described_class.new(request: r1).combine_results_and_save_tmp_company_info_urls }
      let(:limit) { 5 }

      let(:corp_list_url2) { create(:corporate_list_requested_url_finished, :result_2, url: 'http://www.example.com/index2.html', request: r1, result_attrs: { single_url_ids: single_url_ids } ) }
      let(:corp_list_url3) { create(:corporate_list_requested_url_finished, :result_1, url: 'http://www.example.com/index3.html', request: r1, result_attrs: { single_url_ids: single_url_ids } ) }


      let(:s4) { create(:corporate_single_requested_url_finished, :d, url: 'http://www.example.com/com4.html', request: r1) }
      let(:s5) { create(:corporate_single_requested_url_finished, :e, url: 'http://www.example.com/com5.html', request: r1) }
      let(:s6) { create(:corporate_single_requested_url_finished, :a, url: 'http://www.example.com/com6.html', request: r1) }
      let(:s7) { create(:corporate_single_requested_url_finished, :b, url: 'http://www.example.com/com7.html', request: r1) }
      let(:s8) { create(:corporate_single_requested_url_finished, :c, url: 'http://www.example.com/com8.html', request: r1) }

      before do
        corp_list_url2
        corp_list_url3
        s4
        s5
        s6
        s7
        s8
        allow(EasySettings.excel_row_limit).to receive('[]').and_return(limit)
      end

      context 'limitが5の時' do
        let(:limit) { 4 }
        it { expect{subject}.to change(TmpCompanyInfoUrl, :count).by(4) }
        it do
          subject
          expect(r1.tmp_company_info_urls.pluck(:organization_name)).to eq ["AAA織物工業", "BBB株式会社", "CCC捺染工場", "DDD株式会社"]
        end
      end

      context 'limitが5の時' do
        let(:limit) { 5 }
        it { expect{subject}.to change(TmpCompanyInfoUrl, :count).by(5) }
        it do
          subject
          expect(r1.tmp_company_info_urls.pluck(:organization_name)).to eq ["AAA織物工業", "BBB株式会社", "CCC捺染工場", "DDD株式会社", "EEE株式会社"]
        end
      end

      context 'limitが2の時' do
        let(:limit) { 2 }
        it { expect{subject}.to change(TmpCompanyInfoUrl, :count).by(2) }
        it do
          subject
          expect(r1.tmp_company_info_urls.pluck(:organization_name)).to eq ["AAA織物工業", "BBB株式会社"]
        end
      end

      context 'limitが6の時' do
        let(:limit) { 6 }
        it { expect{subject}.to change(TmpCompanyInfoUrl, :count).by(6) }
        it do
          subject
          expect(r1.tmp_company_info_urls.pluck(:organization_name)).to eq ["AAA織物工業", "BBB株式会社", "CCC捺染工場", "DDD株式会社", "EEE株式会社", "AAA織物工業"]
        end
      end

      context 'limitが10の時' do
        let(:limit) { 10 }
        it { expect{subject}.to change(TmpCompanyInfoUrl, :count).by(8) }
        it do
          subject
          expect(r1.tmp_company_info_urls.pluck(:organization_name)).to eq ["AAA織物工業", "BBB株式会社", "CCC捺染工場", "DDD株式会社", "EEE株式会社", "AAA織物工業", "BBB株式会社", "CCC捺染工場"]
        end
      end
    end
  end

  describe '#count_headers' do
    subject { dc.count_headers(headers) }

    let(:dc) { described_class.new(request: req) }
    let(:req) { create(:request) }

    context 'マルチとシングルの区別がないとき' do
      context '1回目' do
        let(:headers) { ['h1', 'h2', 'h3'] }
        it do
          subject
          expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1})
        end
      end

      context '複数回実行' do
        it do
          dc.count_headers(['h1', 'h2', 'h3'])
          expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1})
          expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1}.to_a)

          dc.count_headers(['h4', 'h2', 'h3'])
          expect(dc.headers).to eq({'h2' => 2, 'h3' => 2, 'h1' => 1, 'h4' => 1})
          expect(dc.headers.to_a).to eq({'h2' => 2, 'h3' => 2, 'h1' => 1, 'h4' => 1}.to_a)

          dc.count_headers(['h4', 'h3'])
          expect(dc.headers).to eq({'h3' => 3, 'h2' => 2, 'h4' => 2, 'h1' => 1})
          expect(dc.headers.to_a).to eq({'h3' => 3, 'h2' => 2, 'h4' => 2, 'h1' => 1}.to_a)

          dc.count_headers(['h4', 'h3'])
          expect(dc.headers).to eq({'h3' => 4, 'h4' => 3, 'h2' => 2, 'h1' => 1})
          expect(dc.headers.to_a).to eq({'h3' => 4, 'h4' => 3, 'h2' => 2, 'h1' => 1}.to_a)
        end
      end

      context '3000を超えるとき' do
        it do
          headers = []
          3050.times do |i|
            headers << "h#{i}"
          end

          dc.count_headers(headers)
          expect(dc.headers.size).to eq 3050

          dc.count_headers(['h3010', 'h3020', 'h3030'])
          expect(dc.headers.size).to eq 3000
          expect(dc.headers.keys[0..2]).to eq ['h3010', 'h3020', 'h3030']
        end
      end
    end

    context 'マルチとシングルの区別がある時' do
      let(:s_mark) { "(#{Crawler::Seeker::SINGLE_PAGE})" }
      let(:headers) { ['h1', 'h2', 'h3', "h1#{s_mark}", "h2#{s_mark}", "h3#{s_mark}"] }

      context '1回目' do
        it do
          subject
          expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
          expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
          expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
        end
      end

      context '複数回実行' do
        context 'マルチの場合' do
          it do
            subject
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a) # 並び順を検証するために配列にしている
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(['h1', 'h2', 'h4', 'h6'])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h6' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h6' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h4', 'h6', 'h3'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(['h2', 'h3', 'h5'])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h6' => 1, 'h3' => 1, 'h5' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h6' => 1, 'h3' => 1, 'h5' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h4', 'h6', 'h3', 'h5',])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(['h1', 'h2', 'h3', 'h6'])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h3' => 1, 'h6' => 1, 'h5' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h3' => 1, 'h6' => 1, 'h5' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h4', 'h3', 'h6', 'h5'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(['h1', 'h2', 'h3', 'h4', 'h5'])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h6' => 1, 'h5' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h6' => 1, 'h5' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3', 'h4', 'h6', 'h5'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(['h1', 'h2', 'h4', 'h5', 'h6'])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
          end
        end

        context 'シングルの場合' do
          it do
            subject
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a) # 並び順を検証するために配列にしている
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(["h4#{s_mark}", "h2#{s_mark}", "h3#{s_mark}"])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
            expect(dc.single_headers).to eq({"h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1})
            expect(dc.single_headers.to_a).to eq({"h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1}.to_a)

            dc.count_headers(["h4#{s_mark}", "h3#{s_mark}"])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h3#{s_mark}" => 3, "h2#{s_mark}" => 2, "h4#{s_mark}" => 2, "h1#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h3#{s_mark}" => 3, "h2#{s_mark}" => 2, "h4#{s_mark}" => 2, "h1#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
            expect(dc.single_headers).to eq({"h3#{s_mark}" => 3, "h2#{s_mark}" => 2, "h4#{s_mark}" => 2, "h1#{s_mark}" => 1})

            dc.count_headers(["h4#{s_mark}", "h3#{s_mark}"])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h3#{s_mark}" => 4, "h4#{s_mark}" => 3, "h2#{s_mark}" => 2, "h1#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h3#{s_mark}" => 4, "h4#{s_mark}" => 3, "h2#{s_mark}" => 2, "h1#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
            expect(dc.single_headers).to eq({"h3#{s_mark}" => 4, "h4#{s_mark}" => 3, "h2#{s_mark}" => 2, "h1#{s_mark}" => 1})
          end
        end

        context 'マルチとシングル両方の場合' do
          it do
            subject
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, "h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1}.to_a) # 並び順を検証するために配列にしている
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3'])
            expect(dc.single_headers).to eq({"h1#{s_mark}" => 1, "h2#{s_mark}" => 1, "h3#{s_mark}" => 1})

            dc.count_headers(['h1', 'h2', 'h4', 'h5', "h4#{s_mark}", "h2#{s_mark}", "h3#{s_mark}"])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h5' => 1, 'h3' => 1, "h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h5' => 1, 'h3' => 1, "h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h4', 'h5', 'h3'])
            expect(dc.single_headers).to eq({"h2#{s_mark}" => 2, "h3#{s_mark}" => 2, "h1#{s_mark}" => 1, "h4#{s_mark}" => 1})

            dc.count_headers(['h2', 'h3', 'h5', "h4#{s_mark}", "h3#{s_mark}"])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h3' => 1, 'h5' => 1, "h3#{s_mark}" => 3, "h2#{s_mark}" => 2, "h4#{s_mark}" => 2, "h1#{s_mark}" => 1})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h4' => 1, 'h3' => 1, 'h5' => 1, "h3#{s_mark}" => 3, "h2#{s_mark}" => 2, "h4#{s_mark}" => 2, "h1#{s_mark}" => 1}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h4', 'h3', 'h5',])
            expect(dc.single_headers).to eq({"h3#{s_mark}" => 3, "h2#{s_mark}" => 2, "h4#{s_mark}" => 2, "h1#{s_mark}" => 1})

            dc.count_headers(['h1', 'h3', 'h4', "h1#{s_mark}", "h2#{s_mark}", "h4#{s_mark}"])
            expect(dc.headers).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, "h3#{s_mark}" => 3, "h2#{s_mark}" => 3, "h4#{s_mark}" => 3, "h1#{s_mark}" => 2})
            expect(dc.headers.to_a).to eq({'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, "h3#{s_mark}" => 3, "h2#{s_mark}" => 3, "h4#{s_mark}" => 3, "h1#{s_mark}" => 2}.to_a)
            expect(dc.multi_headers).to eq(['h1', 'h2', 'h3', 'h4', 'h5'])
            expect(dc.single_headers).to eq({"h3#{s_mark}" => 3, "h2#{s_mark}" => 3, "h4#{s_mark}" => 3, "h1#{s_mark}" => 2})
          end
        end
      end

      context '3000を超えるとき' do
        it do
          headers = []
          3.times { |i| headers << "h#{i}" }
          3050.times { |i| headers << "h#{i}#{s_mark}" }

          dc.count_headers(headers)
          expect(dc.headers.size).to eq 3053

          dc.count_headers(["h3010#{s_mark}", "h3020#{s_mark}", "h3030#{s_mark}"])
          expect(dc.headers.size).to eq 3003
          expect(dc.headers.keys[0..5]).to eq ['h0', 'h1', 'h2', "h3010#{s_mark}", "h3020#{s_mark}", "h3030#{s_mark}"]
        end
      end
    end
  end
end

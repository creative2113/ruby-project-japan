require 'rails_helper'
require 'corporate_results'

RSpec.describe SearchersController, type: :controller do
  before do
    create_public_user
    AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'example.com'])
    prepare_safe_stub
  end

  before_res = [{:name=>"商号", :value=>"株式会社AAA", :priority=>3},
                {:name=>"title", :value=>"株式会社AAAのサイト", :priority=>3},
                {:name=>"住所", :value=>"東京都港区北町5-6-200", :priority=>3},
                {:name=>"電話番号", :value=>"0120-111-000", :priority=>3}]

  after_res  = [{:name=>"URL", :value=>"http://www.hokkaido.ccbc.co.jp", :category=>"URL"},
                {:name=>"ドメイン", :value=>"www.hokkaido.ccbc.co.jp", :category=>"ドメイン"},
                {:name=>"商号", :value=>"株式会社AAA", :category=>"名称"},
                {:name=>"サイトタイトル", :value=>"株式会社AAAのサイト", :category=>"サイトタイトル"},
                {:name=>"住所", :value=>"東京都港区北町5-6-200", :category=>"抽出住所"},
                {:name=>"電話番号", :value=>"0120-111-000", :category=>"抽出電話番号"},
                {:name=>"住所", :value=>"東京都港区北町5-6-200", :category=>"連絡先"},
                {:name=>"電話番号", :value=>"0120-111-000", :category=>"連絡先"}]

  json_res   = "{\n  \"URL\": \"http://www.hokkaido.ccbc.co.jp\",\n  \"ドメイン\": \"www.hokkaido.ccbc.co.jp\",\n  \"名称\": \"株式会社AAA\",\n  \"サイトタイトル\": \"株式会社AAAのサイト\",\n  \"抽出住所\": \"東京都港区北町5-6-200\",\n  \"抽出電話番号\": \"0120-111-000\",\n  \"連絡先\": {\n    \"住所\": \"東京都港区北町5-6-200\",\n    \"電話番号\": \"0120-111-000\"\n  }\n}"


  describe "GET index" do

    context 'normal display' do
      before { get :index }

      # 正常に動作しているか (http status)
      it { expect(response.status).to eq(200) }

      it { expect(assigns(:result_flg)).to be_falsey }

      # 正常にHTTPメソッドを呼び出せているか (render template)
      it { expect(response).to render_template :index }
    end

    context 'Give params_id but SearchRequest does not exist' do

      it '通常画面が表示されること' do
        get :index, params: { id: 'aaa' }

        expect(response.status).to eq(200)
        expect(response).to render_template :index

        expect(assigns(:result_flg)).to be_falsey
        expect(assigns(:result)).to be_nil
        expect(assigns(:json)).to be_nil
      end
    end

    context 'まだ未完了の場合' do
      domain = 'www.hokkaido.ccbc.co.jp'
      let(:sq) { create(:search_request, domain: domain, user: User.get_public, status: EasySettings.status[:working]) }

      it '通常画面が表示されること' do
        get :index, params: { id: sq.accept_id }

        expect(response.status).to eq(200)
        expect(response).to render_template :index

        expect(assigns(:result_flg)).to be_falsey
        expect(assigns(:result)).to be_nil
        expect(assigns(:json)).to be_nil
      end
    end

    context 'アクセスレコードがない場合' do
      domain = 'www.hokkaido.ccbc.co.jp'
      let(:sq) { create(:complete_and_success_search_request, domain: domain, user: User.get_public) }

      it '通常画面が表示されること' do
        get :index, params: { id: sq.accept_id }

        expect(response.status).to eq(200)
        expect(response).to render_template :index

        expect(assigns(:result_flg)).to be_falsey
        expect(assigns(:result)).to be_nil
        expect(assigns(:json)).to be_nil
      end
    end

    context '取得ずみの正しいaccept_idを渡した時' do
      domain = 'www.hokkaido.ccbc.co.jp'
      let(:sq) { create(:complete_and_success_search_request, domain: domain, user: User.get_public) }

      it '通常画面が表示されること' do
        AccessRecord.create(domain: domain, result: before_res)
        get :index, params: { id: sq.accept_id }

        expect(response.status).to eq(200)
        expect(response).to render_template :index

        expect(assigns(:result_flg)).to be_truthy
        expect(assigns(:result)).to eq after_res
        expect(assigns(:json)).to eq json_res

        expect(flash[:notice]).to eq Message.const[:get_info]
      end
    end
  end

  describe "POST search_request" do
    let(:domain)    { 'www.hokkaido.ccbc.co.jp' }
    let(:dummy_url) { 'http://' + domain + '/' }
    let(:url)       { dummy_url }
    let(:params)    { { url: url } }

    before do
      allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200}))
    end

    def fail_result(finish_status:, message:)
      expect(SearchRequest.count).to eq 0

      post :search_request, params: params

      body = JSON.parse(response.body).symbolize_keys
      expect(response.status).to eq(200)
      expect(body[:status]).to eq 400
      expect(body[:message]).to eq message
      expect(assigns(:finish_status)).to eq finish_status
      expect(assigns(:url)).to eq url
      expect(assigns(:result)).to eq nil
      expect(assigns(:result_flg)).to be_falsey

      expect(SearchRequest.count).to eq 0
    end

    describe 'NGケース' do

      describe 'About storage date validation' do
        let(:params) { { url: url, use_storage: '1', using_storaged_date: 'a5' } }

        it 'Error status code is 400' do
          fail_result(finish_status: :using_strage_setting_invalid, message: Message.const[:confirm_storage_date])

          expect(assigns(:use_storage)).to be_truthy
        end
      end

      describe 'About url validation' do
        context 'In case url is empty' do
          let(:url) { '' }

          it 'Error status code is 400' do
            fail_result(finish_status: :invalid_url_form, message: Message.const[:confirm_url])
          end
        end

        context 'In case url is wrong form' do
          let(:url) { 'http/aaa.com' }

          it 'Error status code is 400' do
            fail_result(finish_status: :invalid_url_form, message: Message.const[:confirm_url])
          end
        end

        context 'In case url is wrong' do
          let(:url) { 'http://a.com' }

          it 'Error status code is 400' do
            fail_result(finish_status: :invalid_url, message: Message.const[:confirm_url])
          end
        end
      end

      describe 'Banned Domain' do
        let(:url) { 'http://aaa.cn' }

        it do
          fail_result(finish_status: :ban_domain, message: Message.const[:ban_domain])
        end
      end

      describe 'Banned Domain Final' do
        let(:url) { dummy_url }

        before do
          allow(Url).to receive(:get_final_domain).and_return( 'example.aa.cn' )
        end

        it do
          fail_result(finish_status: :ban_domain_final, message: Message.const[:ban_domain])
        end
      end
    end

    context 'In case user have not accessed yet today' do
      before { allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200})) }

      describe 'モデルの増減について' do

        # モデルの増減 (change by)
        it { expect{ post :search_request, params: params }.to change(AccessRecord, :get_count).by(0) }
        it { expect{ post :search_request, params: params }.to change(SealedPage, :get_count).by(0) }

        # たまにパラレルで落ちる
        it { expect{ post :search_request, params: params }.to change(SearchRequest, :count).by(1) }
      end

      describe 'About Using storage data' do

        let(:five_days_ago) { (Time.zone.today - 5.day).to_time }
        let(:params) { { url: url, use_storage: use_storage, using_storaged_date: using_storaged_date } }


        context '日付を指定して、過去に取得したデータを取得して来る場合' do
          let(:use_storage)         { '1' }
          let(:using_storaged_date) { '5' }

          before do
            AccessRecord.create(domain: domain, result: before_res, last_fetch_date: five_days_ago)
            post :search_request, params: params
          end

          it '既に取得済みのデータが返ってくること' do
            body = JSON.parse(response.body).symbolize_keys
            expect(response.status).to eq(200)
            expect(body[:status]).to eq 200
            expect(body[:complete]).to be_truthy
            expect(assigns(:finish_status)).to eq :using_storaged_date
            expect(assigns(:url)).to eq dummy_url

            sq = SearchRequest.find_by_accept_id(body[:accept_id])
            expect(sq.url).to eq dummy_url
            expect(sq.finish_status).to eq EasySettings.finish_status[:using_storaged_date]
            expect(sq.status).to eq EasySettings.status[:completed]
            expect(sq.domain).to eq domain
            expect(sq.use_storage).to be_truthy
            expect(sq.using_storage_days).to eq 5
            expect(sq.user).to eq User.get_public

            access_record = AccessRecord.new(domain).get

            # last_fetch_dateは更新されない
            expect(access_record.last_fetch_date).to eq five_days_ago
            # AccessRecordも通常通りカウントアップされる
            expect(access_record.count).to eq 2
          end

          it { expect{ post :search_request, params: params }.to change(SearchRequest, :count).by(1) }
        end

        context '日付を指定せずに、過去に取得したデータを取得して来る場合' do
          let(:use_storage)         { '1' }
          let(:using_storaged_date) { '' }

          it '既に取得済みのデータが返ってくること' do

            expect(SearchRequest.count).to eq 0

            AccessRecord.create(domain: domain, result: before_res, last_fetch_date: five_days_ago)
            post :search_request, params: params

            body = JSON.parse(response.body).symbolize_keys
            expect(response.status).to eq(200)
            expect(body[:status]).to eq 200
            expect(body[:complete]).to be_truthy
            expect(assigns(:finish_status)).to eq :using_storaged_date
            expect(assigns(:url)).to eq dummy_url

            sq = SearchRequest.find_by_accept_id(body[:accept_id])
            expect(sq.url).to eq dummy_url
            expect(sq.finish_status).to eq EasySettings.finish_status[:using_storaged_date]
            expect(sq.status).to eq EasySettings.status[:completed]
            expect(sq.domain).to eq domain
            expect(sq.use_storage).to be_truthy
            expect(sq.using_storage_days).to be_nil
            expect(sq.user).to eq User.get_public

            access_record = AccessRecord.new(domain).get

            # last_fetch_dateは更新されない
            expect(access_record.last_fetch_date).to eq five_days_ago
            # AccessRecordも通常通りカウントアップされる
            expect(access_record.count).to eq 2
          end
        end

        context '指定した日付より取得日が古く、再度取得して来る場合' do
          let(:use_storage)         { '1' }
          let(:using_storaged_date) { '4' }

          it '再度データを取得してくること' do

            expect(SearchRequest.count).to eq 0

            AccessRecord.create(domain: domain, count: 1, result: before_res, last_fetch_date: five_days_ago)
            post :search_request, params: params

            body = JSON.parse(response.body).symbolize_keys
            expect(response.status).to eq(200)
            expect(body[:status]).to eq 200
            expect(body[:complete]).to be_falsey
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:url)).to eq dummy_url

            sq = SearchRequest.find_by_accept_id(body[:accept_id])
            expect(sq.url).to eq dummy_url
            expect(sq.finish_status).to eq nil
            expect(sq.status).to eq EasySettings.status[:new]
            expect(sq.domain).to eq domain
            expect(sq.use_storage).to be_truthy
            expect(sq.using_storage_days).to eq 4
            expect(sq.user).to eq User.get_public

            expect(SearchRequest.count).to eq 1

            access_record = AccessRecord.new(domain).get
            expect(access_record.last_fetch_date).to eq five_days_ago

            # AccessRecordも通常通りカウントアップされる
            expect(access_record.count).to eq 2
          end
        end
      end
    end

    describe 'About current activate limit' do
      context 'Over current activate limit' do

        before do
          create_list(:search_request, EasySettings.access_current_limit[:public], user: User.get_public)
        end

        it '適切な適切なレスポンスが返ってくること' do
          sr_count = SearchRequest.count

          post :search_request, params: params

          expect(assigns(:finish_status)).to eq :current_access_limit
          expect(assigns(:url)).to eq dummy_url
          expect(assigns(:sq)).to be_nil

          body = JSON.parse(response.body).symbolize_keys
          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:access_concentration]

          expect(SearchRequest.count).to eq sr_count
        end
      end
    end
  end

  describe "GET fetch_candidate_urls" do
    let(:word)   { 'h' }
    let(:params) { { word: word } }

    context 'url候補のワードの場合' do
      before { get :fetch_candidate_urls, params: params }

      context 'ワードがhの場合' do
        let(:word) { 'h' }

        it 'JSONで空の結果を返すこと' do
          expect(response.status).to eq(200)
          expect(response.body).to eq '{"status":200,"urls":""}'
        end
      end

      context 'ワードがhtの場合' do
        let(:word) { 'ht' }

        it 'JSONで空の結果を返すこと' do
          expect(response.status).to eq(200)
          expect(response.body).to eq '{"status":200,"urls":""}'
        end
      end

      context 'ワードがhttの場合' do
        let(:word) { 'htt' }

        it 'JSONで空の結果を返すこと' do
          expect(response.status).to eq(200)
          expect(response.body).to eq '{"status":200,"urls":""}'
        end
      end

      context 'ワードがhttp~の場合' do
        let(:word) { 'http4r' }

        it 'JSONで空の結果を返すこと' do
          expect(response.status).to eq(200)
          expect(response.body).to eq '{"status":200,"urls":""}'
        end
      end
    end

    context '正常に取得できる場合' do
      let(:word) { 'abcdefgh' }

      it 'JSONでステータス200とメッセージを返すこと' do

        result = [{title: 'aaa', url: 'aaa.com'},
                  {title: 'bbb', url: 'bbb.com'},
                  {title: 'ccc', url: 'http://ccc.com'},
                  {title: 'ddd', url: 'https://ddd.com'},
                  {title: 'eee', url: 'eee.com'},
                  {title: 'fff', url: 'fff.com'},
                  {title: 'ggg', url: 'ggg.com'},
                  {title: 'hhh', url: 'hhh.com'},
                  {title: 'iii', url: 'iii.com'},
                  {title: 'jjj', url: 'jjj.com'}
                  # {title: 'kkk', url: 'kkk.com'},
                  # {title: 'lll', url: 'lll.com'},
                  # {title: 'mmm', url: 'mmm.com'},
                  # {title: 'nnn', url: 'nnn.com'},
                  # {title: 'ooo', url: 'ooo.com'},
                  # {title: 'ppp', url: 'ppp.com'},
                  # {title: 'qqq', url: 'qqq.com'},
                  # {title: 'rrr', url: 'rrr.com'},
                  # {title: 'sss', url: 'sss.com'},
                  # {title: 'ttt', url: 'ttt.com'},
                  # {title: 'uuu', url: 'uuu.com'}
                ]

        allow_any_instance_of(Crawler::UrlSearcher).to receive(:fetch_results).and_return(result)
        get :fetch_candidate_urls, params: params

        expected_response  = '{"title":"aaa","url":"http://aaa.com"},'
        expected_response += '{"title":"bbb","url":"http://bbb.com"},'
        expected_response += '{"title":"ccc","url":"http://ccc.com"},'
        expected_response += '{"title":"ddd","url":"https://ddd.com"},'
        expected_response += '{"title":"eee","url":"http://eee.com"},'
        expected_response += '{"title":"fff","url":"http://fff.com"},'
        expected_response += '{"title":"ggg","url":"http://ggg.com"},'
        expected_response += '{"title":"hhh","url":"http://hhh.com"},'
        expected_response += '{"title":"iii","url":"http://iii.com"},'
        expected_response += '{"title":"jjj","url":"http://jjj.com"}'
        # expected_response += '{"title":"kkk","url":"http://kkk.com"},'
        # expected_response += '{"title":"lll","url":"http://lll.com"},'
        # expected_response += '{"title":"mmm","url":"http://mmm.com"},'
        # expected_response += '{"title":"nnn","url":"http://nnn.com"},'
        # expected_response += '{"title":"ooo","url":"http://ooo.com"},'
        # expected_response += '{"title":"ppp","url":"http://ppp.com"},'
        # expected_response += '{"title":"qqq","url":"http://qqq.com"},'
        # expected_response += '{"title":"rrr","url":"http://rrr.com"},'
        # expected_response += '{"title":"sss","url":"http://sss.com"},'
        # expected_response += '{"title":"ttt","url":"http://ttt.com"}'

        expect(response.status).to eq(200)
        expect(response.body).to eq '{"status":200,"urls":[' + expected_response + ']}'
      end

      it 'JSONでステータス200であり、かつ、取得カウントが10個であること' do

        get :fetch_candidate_urls, params: { word: '東京' }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['urls'].size).to eq 10
      end
    end

    context '途中でエラーが起きた場合' do
      let(:word) { 'abcdefgh' }

      it 'JSONでステータス500とメッセージを返すこと' do
        allow(Crawler::UrlSearcher).to receive(:new).and_raise('Dummy Error')
        get :fetch_candidate_urls, params: params

        expect(response.status).to eq(200)
        expect(response.body).to eq '{"status":500,"urls":"","message":"エラーが発生し、URLを検索することができませんでした。"}'
      end
    end
  end
end

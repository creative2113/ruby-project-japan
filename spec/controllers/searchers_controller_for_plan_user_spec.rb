require 'rails_helper'
require 'corporate_results'

RSpec.describe SearchersController, type: :controller do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  ip = '0.0.0.0'
  today = Date.today

  before do
    create_public_user
    AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'example.com'])
    SealedPage.delete_items(['www.hokkaido.ccbc.co.jp', 'example.com', 'a.com'])
    prepare_safe_stub

    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
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
    # email = 'a' + SecureRandom.alphanumeric(4) + '@get_test.com'
    let(:email) { 'a' + SecureRandom.alphanumeric(4) + '@get_test.com' }
    let(:user)    { create(:user, email: email, billing: :credit) }
    let(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[:standard]) }
    let!(:plan)   { create(:billing_plan, name: master_standard_plan.name, status: :ongoing, billing: user.billing) }

    context 'normal display' do
      before do
        sign_in user
        get :index
      end

      # 正常に動作しているか (http status)
      it { expect(response.status).to eq(200) }

      it { expect(assigns(:result_flg)).to be_falsey }

      # 正常にHTTPメソッドを呼び出せているか (render template)
      it { expect(response).to render_template :index }
    end

    context 'Give params_id but SearchRequest does not exist' do

      it '通常画面が表示されること' do
        sign_in user
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
      let!(:sq) { create(:search_request, domain: domain, user: user, status: EasySettings.status[:working]) }

      it '通常画面が表示されること' do
        sign_in user
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
      let!(:sq) { create(:complete_and_success_search_request, domain: domain, user: user) }

      it '通常画面が表示されること' do
        sign_in user
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
      let!(:sq) { create(:complete_and_success_search_request, domain: domain, user: user) }

      it '通常画面が表示されること' do
        AccessRecord.create(domain: domain, result: before_res)

        sign_in user
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
    subject { post :search_request, params: params }

    let(:domain) { 'www.hokkaido.ccbc.co.jp' }
    let(:url) { 'http://' + domain + '/' }
    let(:use_storage) { 1 }
    let(:using_storaged_date) { nil }
    let(:params) { { url: url, use_storage: use_storage, using_storaged_date: using_storaged_date} }
    let(:body) { JSON.parse(response.body).symbolize_keys }
    let(:search_request) { SearchRequest.where(url: url, user: user).last }
    let(:access_record) { AccessRecord.new(domain).get }
    let(:email) { 'a' + SecureRandom.alphanumeric(4) + '@test2.com' }
    let(:user)  { create(:user, email: email, billing: :credit) }
    let!(:history) { create(:monthly_history, plan: EasySettings.plan[:standard], user: user, search_count: search_count) }
    let!(:plan)   { create(:billing_plan, name: master_standard_plan.name, status: :ongoing, billing: user.billing) }
    let(:search_count) { 0 }

    before do
      sign_in user
    end

    context 'NGケース' do
      let(:email) { 'a' + SecureRandom.alphanumeric(4) + '@ng_test.com' }

      def fail_result(finish_status:, message:, count:)
        expect(SearchRequest.count).to eq 0

        subject

        expect(response.status).to eq(200)
        expect(body[:status]).to eq 400
        expect(body[:message]).to eq message
        expect(assigns(:finish_status)).to eq finish_status
        expect(assigns(:use_storage)).to be_truthy
        expect(assigns(:result_flg)).to be_falsey

        # カウントアップされない
        expect(MonthlyHistory.find_around(user).search_count).to eq count

        expect(SearchRequest.count).to eq 0
      end

      describe 'About storage date validation' do
        let(:using_storaged_date) { 'a5' }

        it 'Error status code is 400' do
          fail_result(finish_status: :using_strage_setting_invalid, message: Message.const[:confirm_storage_date], count: 0)
        end
      end

      describe 'About url validation' do
        context 'In case url is empty' do
          let(:url) { '' }

          it 'Error status code is 400' do
            fail_result(finish_status: :invalid_url_form, message: Message.const[:confirm_url], count: 1)
          end
        end

        context 'In case url is wrong' do
          let(:url) { 'http://a.com' }

          it 'Error status code is 400' do
            fail_result(finish_status: :invalid_url, message: Message.const[:confirm_url], count: 1)
          end
        end
      end

      describe 'Banned Domain' do
        context 'first domain check' do
          let(:url) { 'http://example.a.cn' }

          it 'Error status code is 400' do
            fail_result(finish_status: :ban_domain, message: Message.const[:ban_domain], count: 1)
          end
        end

        context 'Final domain check' do
          let(:url) { 'http://' + domain + '/' }

          before do
            allow(Url).to receive(:get_final_domain).and_return( 'example.aa.cn' )
          end

          it 'Error status code is 400' do
            fail_result(finish_status: :ban_domain_final, message: Message.const[:ban_domain], count: 1)
          end
        end
      end
    end

    context '今日はまだアクセスしていないユーザ' do
      let(:email) { 'a' + SecureRandom.alphanumeric(4) + '@test.com' }

      describe 'About Using storage data for paid user' do

        let(:res) { [{:name=>"商号", :value=>"株式会社AAA"},
                     {:name=>"title", :value=>"株式会社AAAのサイト"},
                     {:name=>"住所", :value=>"東京都港区北町5-6-200"},
                     {:name=>"電話番号", :value=>"0120-111-000"}]
                  }

        let(:last_fetch_date) { (Time.zone.today - 5.day).to_time }

        before do
          AccessRecord.create(domain: domain, result: res, last_fetch_date: last_fetch_date)
        end

        context '日付を指定して、過去に取得したデータを取得して来る場合' do
          let(:using_storaged_date) { 5 }

          it 'アクセスレコードは増えないこと' do
            expect{ subject }.to change(AccessRecord, :get_count).by(0)
          end

          it 'シールドページは増えないこと' do
            expect{ subject }.to change(SealedPage, :get_count).by(0)
          end

          it 'サーチリクエストを完了で作成すること' do
            expect(SearchRequest.count).to eq 0

            subject
            expect(response.status).to eq(200)
            expect(body[:status]).to eq 200
            expect(body[:complete]).to be_truthy
            expect(body[:accept_id]).to eq search_request.accept_id
            expect(assigns(:finish_status)).to eq :using_storaged_date
            expect(assigns(:url)).to eq url

            expect(search_request.status).to eq EasySettings.status.completed
            expect(search_request.finish_status).to eq EasySettings.finish_status[:using_storaged_date]
            expect(search_request.use_storage).to be_truthy
            expect(search_request.using_storage_days).to eq 5
            expect(search_request.free_search).to be_falsey
            expect(search_request.link_words).to be_nil
            expect(search_request.target_words).to be_nil

            # last_fetch_dateは更新されない
            expect(access_record.last_fetch_date).to eq last_fetch_date
            # AccessRecordは通常通りカウントアップされる
            expect(access_record.count).to eq 2

            # カウントアップされる
            expect(MonthlyHistory.find_around(user).search_count).to eq 1

            expect(SearchRequest.count).to eq 1
          end
        end

        context '日付を指定せずに、過去に取得したデータを取得して来る場合' do
          let(:using_storaged_date) { '' }

          it 'アクセスレコードは増えないこと' do
            expect{ subject }.to change(AccessRecord, :get_count).by(0)
          end

          it 'シールドページは増えないこと' do
            expect{ subject }.to change(SealedPage, :get_count).by(0)
          end

          it 'サーチリクエストを完了で作成すること' do
            expect(SearchRequest.count).to eq 0

            subject
            expect(response.status).to eq 200
            expect(body[:status]).to eq 200
            expect(body[:complete]).to be_truthy
            expect(body[:accept_id]).to eq search_request.accept_id
            expect(assigns(:finish_status)).to eq :using_storaged_date
            expect(assigns(:url)).to eq url

            expect(search_request.status).to eq EasySettings.status.completed
            expect(search_request.finish_status).to eq EasySettings.finish_status[:using_storaged_date]
            expect(search_request.use_storage).to be_truthy
            expect(search_request.using_storage_days).to be_nil
            expect(search_request.free_search).to be_falsey
            expect(search_request.link_words).to be_nil
            expect(search_request.target_words).to be_nil

            # last_fetch_dateは更新されない
            expect(access_record.last_fetch_date).to eq last_fetch_date
            # AccessRecordは通常通りカウントアップされる
            expect(access_record.count).to eq 2

            # カウントアップされる
            expect(MonthlyHistory.find_around(user).search_count).to eq 1

            expect(SearchRequest.count).to eq 1
          end
        end

        context '指定した日付より取得日が古く、再度取得して来る場合' do
          let(:using_storaged_date) { 4 }

          before { allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200})) }

          it 'アクセスレコードは増えないこと' do
            expect{ subject }.to change(AccessRecord, :get_count).by(0)
          end

          it 'シールドページは増えないこと' do
            expect{ subject }.to change(SealedPage, :get_count).by(0)
          end

          it 'サーチリクエストを未完了で作成すること' do
            expect(SearchRequest.count).to eq 0

            subject
            expect(response.status).to eq(200)
            expect(body[:status]).to eq 200
            expect(body[:complete]).to be_falsey
            expect(body[:accept_id]).to eq search_request.accept_id
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:url)).to eq url

            expect(search_request.status).to eq EasySettings.status[:new]
            expect(search_request.finish_status).to be_nil
            expect(search_request.use_storage).to be_truthy
            expect(search_request.using_storage_days).to eq 4
            expect(search_request.free_search).to be_falsey
            expect(search_request.link_words).to be_nil
            expect(search_request.target_words).to be_nil

            # AccessRecordは通常通りカウントアップされる
            expect(access_record.count).to eq 2

            # カウントアップされる
            expect(MonthlyHistory.find_around(user).search_count).to eq 1

            expect(SearchRequest.count).to eq 1
          end
        end
      end
    end

    xcontext 'In case user exceeded daily access limit' do
      describe 'Confirm response, render, instance variable' do
        it 'アクセスレコードは増えないこと' do
          expect{ subject }.to change(AccessRecord, :get_count).by(0)
        end

        it 'シールドページは増えないこと' do
          expect{ subject }.to change(SealedPage, :get_count).by(0)
        end

        it do
          expect(SearchRequest.count).to eq 0

          subject
          expect(response.status).to eq 200
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:over_access]
          expect(assigns(:finish_status)).to eq :user_over_access
          expect(assigns(:result_flg)).to be_falsey
          expect(assigns(:url)).to be_empty

          expect(MonthlyHistory.find_around(user).search_count).to eq 1

          expect(SearchRequest.count).to eq 0
        end
      end
    end

    context 'In case user exceeded monthly access limit' do
      let(:search_count) { EasySettings.monthly_access_limit[:standard] + 1 }

      describe 'Confirm response, render, instance variable' do
        it do
          expect(SearchRequest.count).to eq 0

          subject
          expect(response.status).to eq 200
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:over_monthly_limit]
          expect(assigns(:finish_status)).to eq :over_monthly_limit
          expect(assigns(:result_flg)).to be_falsey
          expect(assigns(:url)).to be_empty

          expect(MonthlyHistory.find_around(user).search_count).to eq EasySettings.monthly_access_limit[:standard] + 2

          expect(SearchRequest.count).to eq 0
        end
      end
    end

    context 'In case user already accessed today' do
      let(:use_storage) { 0 }

      context 'まだ誰もサーチしたことのないページ' do
        before { allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200})) }

        it 'アクセスレコードは増えないこと' do
          expect{ subject }.to change(AccessRecord, :get_count).by(0)
        end

        it 'シールドページは増えないこと' do
          expect{ subject }.to change(SealedPage, :get_count).by(0)
        end

        it '適切なレスポンスが返ってくること' do
          expect(SearchRequest.count).to eq 0

          subject

          expect(response.status).to eq 200
          expect(body[:status]).to eq 200
          expect(body[:complete]).to be_falsey
          expect(body[:accept_id]).to eq search_request.accept_id
          expect(assigns(:finish_status)).to eq :normal_finish
          expect(assigns(:url)).to eq url

          expect(search_request.status).to eq EasySettings.status[:new]
          expect(search_request.finish_status).to be_nil
          expect(search_request.use_storage).to be_falsey
          expect(search_request.using_storage_days).to be_nil
          expect(search_request.free_search).to be_falsey
          expect(search_request.link_words).to be_nil
          expect(search_request.target_words).to be_nil

          # AccessRecordはまだカウントを持っていない
          expect(access_record.count).to be_nil

          expect(MonthlyHistory.find_around(user).search_count).to eq 1

          expect(SearchRequest.count).to eq 1
        end
      end
    end

    describe 'About current activate limit' do
      context 'Over current activate limit' do
        before do
          create_list(:search_request, EasySettings.access_current_limit[:standard], user: user)
        end

        it '適切な適切なレスポンスが返ってくること' do
          sr_count = SearchRequest.count

          subject

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:over_current_access]
          expect(assigns(:finish_status)).to eq :current_access_limit

          expect(MonthlyHistory.find_around(user).search_count).to eq 1

          expect(SearchRequest.count).to eq sr_count
        end
      end
    end
  end
end

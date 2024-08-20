require 'rails_helper'

RSpec.describe RequestsController, type: :controller do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  let_it_be(:public_user) { create(:user_public) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end

  def check_normal_finish(add_url_count:)
    request_count = Request.count
    req_url_count = RequestedUrl.count

    subject

    expect(assigns(:finish_status)).to eq :normal_finish
    expect(assigns(:accepted)).to be_truthy
    expect(assigns(:file_name)).to eq file_name
    expect(assigns(:invalid_urls)).to eq invalid_urls
    expect(assigns(:requests)).to eq requests

    expect(response.status).to eq 302
    expect(response.location).to redirect_to request_multiple_path(r: request.id)

    # モデルチェック
    expect(request.user).to eq user
    expect(request.title).to eq file_name
    expect(request.type).to eq type.to_s
    expect(request.corporate_list_site_start_url).to be_nil
    expect(request.company_info_result_headers).to be_nil
    expect(request.status).to eq EasySettings.status.new
    expect(request.test).to be_falsey
    expect(request.plan).to eq user.my_plan_number
    expect(request.expiration_date).to be_nil
    expect(request.mail_address).to eq address
    expect(request.ip).to eq '0.0.0.0'
    expect(request.requested_urls.count).to eq add_url_count
    expect(request.requested_urls[0].status).to eq EasySettings.status.new
    expect(request.requested_urls[0].finish_status).to eq EasySettings.finish_status.new

    # 増減チェック
    expect(Request.count).to eq request_count + 1
    expect(RequestedUrl.count).to eq req_url_count + add_url_count

    # メールのチェック
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(ActionMailer::Base.deliveries.first.to).to include address
    expect(ActionMailer::Base.deliveries.first.subject).to match(/リクエストを受け付けました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{file_name}/)

    # redisにsetされていることをチェック
    expect(Redis.new.get("#{request.id}_request")).to be_present
    Redis.new.del("#{request.id}_request")
  end

  let(:ip)        { '0.0.0.0' }
  let(:today)     { Time.zone.today }
  let(:yesterday) { today - 1.day }

  let(:file_name)              { 'normal_urlcol1_1.xlsx' }
  let(:excel_path)             { File.join(Rails.root, "spec/fixtures/#{file_name}") }
  let(:excel)                  { Rack::Test::UploadedFile.new(excel_path) }
  let(:address)                { 'to@example.org' }
  let(:use_storage)            { 1 }
  let(:using_storage_days)     { '' }
  let(:header)                 { 0 }
  let(:sheet_select)           { 'シート1' }
  let(:col_select)             { 1 }
  let(:free_search)            { 0 }
  let(:link_words)             { '' }
  let(:target_words)           { '' }
  let(:type)                   { :file }
  let(:mode)                   { RequestsController::MODE_MULTIPLE }
  let(:requests)               { nil }
  let(:invalid_urls)           { [{ index: 3, url: '', reason: 'URLが空'},
                                  { index: 4, url: 'https://sample.cn/aa/bb', reason: 'クロールが禁止されたドメイン'},
                                  { index: 6, url: 'http//aaaa.com', reason: 'URLの形式でない'},
                                  { index: 8, url: 'htp://ccc', reason: 'URLの形式でない'}] }

  let(:params) { { request: { excel: excel, mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days,
                              free_search: free_search, link_words: link_words, target_words: target_words
                            },
                   header: header, sheet_select: sheet_select, col_select: col_select, request_type: type, mode: mode
                 }
               }

  let(:request) { Request.find_by_file_name(file_name) }

  after { ActionMailer::Base.deliveries.clear }

  context 'Public User' do
    let(:user)         { User.get_public }
    let(:unlogin_user) { create(:user) }
    let!(:r1)          { create(:request, user: unlogin_user) }
    let!(:r2)          { create(:request, :corporate_site_list, user: unlogin_user) }

    describe "GET index_multiple" do
      subject { get :index_multiple, params: params }

      context 'リクエストIDがない場合' do
        let(:params) { {} }

        it do
          subject

          # 正常に動作しているか (http status)
          expect(response.status).to eq(200)

          expect(assigns(:requests)).to be_nil

          # 正常にHTTPメソッドを呼び出せているか (render template)
          expect(response).to render_template :index_multiple
        end
      end

      context 'リクエストIDがある場合' do
        let(:r3) { create(:request, user: user) }
        let(:params) { { r: r3.id } }

        context 'redisに情報がない場合' do
          it do
            subject

            # 正常に動作しているか (http status)
            expect(response.status).to eq(200)

            expect(assigns(:requests)).to be_nil
            expect(assigns(:accepted)).to be_nil
            expect(assigns(:finish_status)).to be_nil
            expect(assigns(:accept_id)).to be_nil
            expect(assigns(:type)).to be_nil
            expect(assigns(:test)).to be_nil
            expect(assigns(:title)).to be_nil
            expect(assigns(:file_name)).to be_nil
            expect(assigns(:mail_address)).to be_nil
            expect(assigns(:free_search)).to be_nil
            expect(assigns(:link_words)).to be_nil
            expect(assigns(:target_words)).to be_nil
            expect(assigns(:accept_count)).to be_nil
            expect(assigns(:invalid_urls)).to be_nil
            expect(assigns(:notice_create_msg)).to be_nil

            # 正常にHTTPメソッドを呼び出せているか (render template)
            expect(response).to render_template :index_multiple
          end
        end

        context 'redisに情報がある場合' do
          let(:redis_info) { {
              title: 'Test Title',
              accepted: true,
              finish_status: 'aa',
              accept_id: 'bb',
              type: 'cc',
              test: false,
              file_name: 'dd',
              mail_address: 'ee',
              free_search: false,
              link_words: 'gg',
              target_words: 'hh',
              accept_count: 5,
              invalid_urls: 'ii',
              notice_create_msg: 'jj'
            }.to_json }

          before do
            Redis.new.set("#{r3.id}_request", redis_info)
          end

          after do
            Redis.new.del("#{r3.id}_request")
          end

          it do
            subject

            # 正常に動作しているか (http status)
            expect(response.status).to eq(200)

            expect(assigns(:requests)).to be_nil
            expect(assigns(:accepted)).to eq true
            expect(assigns(:finish_status)).to eq 'aa'
            expect(assigns(:accept_id)).to eq 'bb'
            expect(assigns(:type)).to eq 'cc'
            expect(assigns(:test)).to eq false
            expect(assigns(:title)).to eq 'Test Title'
            expect(assigns(:file_name)).to eq 'dd'
            expect(assigns(:mail_address)).to eq 'ee'
            expect(assigns(:free_search)).to eq false
            expect(assigns(:link_words)).to eq 'gg'
            expect(assigns(:target_words)).to eq 'hh'
            expect(assigns(:accept_count)).to eq 5
            expect(assigns(:invalid_urls)).to eq 'ii'
            expect(assigns(:notice_create_msg)).to eq 'jj'

            # 正常にHTTPメソッドを呼び出せているか (render template)
            expect(response).to render_template :index_multiple
          end
        end
      end
    end

    describe "POST create" do
      subject { post :create, params: params }

      context 'EXCEL 正常終了の場合' do
        it '正しい結果が返ってくること' do
          check_normal_finish(add_url_count: 4)

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:free_search)).to be_falsey


          # モデルチェック
          expect(request.use_storage).to be_truthy
          expect(request.using_storage_days).to be_nil
          expect(request.free_search).to be_falsey
          expect(request.link_words).to be_nil
          expect(request.target_words).to be_nil
          expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
          expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
          expect(request.requested_urls[2].url).to eq 'https://www.honda.co.jp/'
          expect(request.requested_urls[3].url).to eq 'https://www.starbucks.co.jp/'
        end

        context 'フリーサーチがtureの場合' do
          let(:free_search)  { 1 }
          let(:link_words)   { 'aa,bb' }
          let(:target_words) { 'cc,dd' }

          it '正しい結果が返ってくること、free_searchはOFFであること' do
            check_normal_finish(add_url_count: 4)

            # インスタンス変数のチェック
            expect(assigns(:free_search)).to be_falsey

            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
          end
        end
      end

      context 'CSV 正常終了の場合' do
        let(:file_name)    { 'normal.csv' }
        let(:invalid_urls) { [{ index: 1, url: 'ttps://aaa', reason: 'URLの形式でない'},
                              { index: 3, url: '', reason: 'URLが空'},
                              { index: 5, url: 'http:/bbb', reason: 'URLの形式でない'},
                              { index: 7, url: 'https://sample.co.cn', reason: 'クロールが禁止されたドメイン'}] }
        let(:free_search)  { 1 }
        let(:link_words)   { 'aa,bb' }
        let(:target_words) { 'cc,dd' }

        it '正しい結果が返ってくること、フリーサーチはOFFであること' do
          check_normal_finish(add_url_count: 3)

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:free_search)).to be_falsey

          # モデルチェック
          expect(request.use_storage).to be_truthy
          expect(request.using_storage_days).to be_nil
          expect(request.free_search).to be_falsey
          expect(request.link_words).to be_nil
          expect(request.target_words).to be_nil
          expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
          expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
          expect(request.requested_urls[2].url).to eq 'https://www.starbucks.co.jp/'
        end
      end

      # planかpublicかには依存しない
      xcontext 'ウィルスファイルがアップロードされた場合' do
        let(:file_name)  { 'dummy_virus.csv' }

        context 'ウィルスファイルが正常に削除された場合' do
          it 'ファイルが削除されること、メールが飛ばないこと' do
            post :create, params: params

            # インスタンス変数のチェック
            expect(assigns(:finish_status)).to eq :virus_file_uploaded
            expect(assigns(:using_storaged_date)).to eq using_storage_days
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to be_nil
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            # ファイルが削除されること
            expect(File.exist?(assigns(:virus_file_path))).to be_falsey

            expect(response.status).to eq 400
            expect(response).to render_template :index

            expect(Request.find_by_file_name(file_name)).to be_nil
            expect(PublicUser.find_by_ip(ip)).to be_nil

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end

        context 'ウィルスファイルの削除に失敗した場合' do
          it 'ファイルが削除されないこと、メールが飛ぶこと' do
            allow(File).to receive(:delete).and_raise('Dummy Error')
            post :create, params: params

            # インスタンス変数のチェック
            expect(assigns(:finish_status)).to eq :virus_file_uploaded
            expect(assigns(:using_storaged_date)).to eq using_storage_days
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to be_nil
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            # ファイルが削除されないこと
            expect(File.exist?(assigns(:virus_file_path))).to be_truthy

            expect(response.status).to eq 400
            expect(response).to render_template :index

            expect(Request.find_by_file_name(file_name)).to be_nil
            expect(PublicUser.find_by_ip(ip)).to be_nil

            expect(ActionMailer::Base.deliveries.size).to eq(3)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要緊急対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ISSUE\[Must Delete Virus File: PATH:/)
          end
        end

        it { expect{ post :create, params: params }.to change(Request, :count).by(0) }
        it { expect{ post :create, params: params }.to change(RequestedUrl, :count).by(0) }
      end

      # planかpublicかには依存しない
      context 'using_storage_daysが間違っている場合' do
        let(:using_storage_days) { '2d' }

        it '正しい結果が返ってくること' do
          request_count = Request.count
          req_url_count = RequestedUrl.count

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to eq using_storage_days
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:accepted)).to be_falsey
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:invalid_urls)).to eq([])
          expect(assigns(:finish_status)).to eq :using_strage_setting_invalid
          expect(assigns(:requests)).to be_nil
          expect(assigns(:free_search)).to be_falsey

          expect(request).to be_nil

          expect(ActionMailer::Base.deliveries.size).to eq(0)

          # 増減チェック
          expect(Request.count).to eq request_count
          expect(RequestedUrl.count).to eq req_url_count
        end
      end

      # planかpublicかには依存しない
      context 'ファイルの拡張子がxlsx、csv以外の場合' do
        let(:file_name)  { 'normal.xls' }
        let(:using_storage_days) { '5' }

        it '正しい結果が返ってくること' do
          request_count = Request.count
          req_url_count = RequestedUrl.count

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to eq using_storage_days.to_i
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:accepted)).to be_falsey
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:invalid_urls)).to eq([])
          expect(assigns(:finish_status)).to eq :invalid_extension
          expect(assigns(:requests)).to be_nil
          expect(assigns(:free_search)).to be_falsey

          expect(request).to be_nil

          expect(ActionMailer::Base.deliveries.size).to eq(0)

          # 増減チェック
          expect(Request.count).to eq request_count
          expect(RequestedUrl.count).to eq req_url_count
        end
      end

      # パブリックユーザはアクセス制限がない
      xcontext 'ユーザのアクセスが過去にある場合' do

        context 'アクセス制限を超えている場合' do
          before { update_public_user(request_count: EasySettings.request_limit[:public] + 1) }

          it '正しい結果が返ってくること' do
            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq({})
            expect(assigns(:finish_status)).to eq :request_limit
            expect(assigns(:requests)).to be_nil

            expect(request).to be_nil

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end

          # モデルの増減が正しいこと
          it { expect{ post :create, params: params }.to change(Request, :count).by(0) }
          it { expect{ post :create, params: params }.to change(RequestedUrl, :count).by(0) }
        end

        context 'アクセス制限を超えていない場合' do

          before { create(:public_user, request_count: 1) }

          it '正しい結果が返ってくること' do
            post :create, params: params

            expect(response.status).to eq 302
            expect(response.location).to redirect_to request_path(r: Request.find_by_file_name(file_name).id)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_truthy
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq invalid_urls
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(Request.find_by_file_name(file_name).status).to eq EasySettings.status.new
            expect(Request.find_by_file_name(file_name).expiration_date).to be_nil
            expect(Request.find_by_file_name(file_name).mail_address).to eq address
            expect(Request.find_by_file_name(file_name).user).to eq User.get_public
            expect(Request.find_by_file_name(file_name).title).to eq file_name
            expect(Request.find_by_file_name(file_name).plan).to eq EasySettings.plan[:public]

            expect(Request.find_by_file_name(file_name).requested_urls.count).to eq 4
            expect(Request.find_by_file_name(file_name).requested_urls[0].url).to eq 'https://www.nexway.co.jp'
            expect(Request.find_by_file_name(file_name).requested_urls[0].status).to eq EasySettings.status.new
            expect(Request.find_by_file_name(file_name).requested_urls[0].finish_status).to eq EasySettings.finish_status.new
            expect(Request.find_by_file_name(file_name).requested_urls[0].use_storage).to be_truthy
            expect(Request.find_by_file_name(file_name).requested_urls[0].using_storage_days).to be_nil
            expect(Request.find_by_file_name(file_name).requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
            expect(Request.find_by_file_name(file_name).requested_urls[2].url).to eq 'https://www.honda.co.jp/'
            expect(Request.find_by_file_name(file_name).requested_urls[3].url).to eq 'https://www.starbucks.co.jp/'

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries.last.to).to eq([address])
            expect(ActionMailer::Base.deliveries.last.subject).to match(/リクエストを受け付けました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/#{file_name}/)
          end

          # モデルの増減が正しいこと
          it { expect{ post :create, params: params }.to change(Request, :count).by(1) }
          it { expect{ post :create, params: params }.to change(RequestedUrl, :count).by(4) }
        end

        context '最後のアクセスが昨日だった場合' do

          before { create(:public_user_exceed_access_yesterday) }

          it '正しい結果が返ってくること' do
            post :create, params: params

            expect(response.status).to eq 302
            expect(response.location).to redirect_to request_path(r: Request.find_by_file_name(file_name).id)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_truthy
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq invalid_urls
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(Request.find_by_file_name(file_name).status).to eq EasySettings.status.new
            expect(Request.find_by_file_name(file_name).expiration_date).to be_nil
            expect(Request.find_by_file_name(file_name).mail_address).to eq address
            expect(Request.find_by_file_name(file_name).user).to eq User.get_public
            expect(Request.find_by_file_name(file_name).title).to eq file_name
            expect(Request.find_by_file_name(file_name).plan).to eq EasySettings.plan[:public]

            expect(Request.find_by_file_name(file_name).requested_urls.count).to eq 4
            expect(Request.find_by_file_name(file_name).requested_urls[0].url).to eq 'https://www.nexway.co.jp'
            expect(Request.find_by_file_name(file_name).requested_urls[0].status).to eq EasySettings.status.new
            expect(Request.find_by_file_name(file_name).requested_urls[0].finish_status).to eq EasySettings.finish_status.new
            expect(Request.find_by_file_name(file_name).requested_urls[0].use_storage).to be_truthy
            expect(Request.find_by_file_name(file_name).requested_urls[0].using_storage_days).to be_nil
            expect(Request.find_by_file_name(file_name).requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
            expect(Request.find_by_file_name(file_name).requested_urls[2].url).to eq 'https://www.honda.co.jp/'
            expect(Request.find_by_file_name(file_name).requested_urls[3].url).to eq 'https://www.starbucks.co.jp/'

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries.last.to).to eq([address])
            expect(ActionMailer::Base.deliveries.last.subject).to match(/リクエストを受け付けました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/#{file_name}/)
          end

          # モデルの増減が正しいこと
          it { expect{ post :create, params: params }.to change(Request, :count).by(1) }
          it { expect{ post :create, params: params }.to change(RequestedUrl, :count).by(4) }
        end
      end

      describe 'パブリックユーザのアクセス制限' do
        context '同じIPの待機数が制限を超えている時' do
          let(:file_name) { 'normal.csv' }

          before { create_list(:request, EasySettings.public_access_limit.ip, user: user, ip: '0.0.0.0') }

          it 'IPアクセス制限に引っかかること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            # インスタンス変数のチェック
            expect(assigns(:finish_status)).to eq :public_ip_access_request_limit
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey
            expect(flash[:alert]).to eq Message.const[:over_public_ip_limit]

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            expect(request).to be_nil

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'パブリックユーザの待機数が制限を超えている時' do
          let(:file_name) { 'normal.csv' }
          # let(:user) { User.get_public }
          before { create_list(:request, EasySettings.waiting_requests_limit.public, user: user) }

          it '待機リクエストのアクセス制限に引っかかること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            # インスタンス変数のチェック
            expect(assigns(:finish_status)).to eq :public_waiting_requests_limit
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey
            expect(flash[:alert]).to eq Message.const[:over_public_waiting_limit]

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            expect(request).to be_nil

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end
      end

      context 'アップロードファイルのURLが空の場合' do

        context 'EXCELでヘッダーなしの場合' do
          let(:file_name) { 'empty.xlsx' }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :no_valid_url
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(request).to be_nil
                    
            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'EXCELでヘッダーありの場合' do
          let(:file_name) { 'url_empty_with_header.xlsx' }
          let(:header)    { 1 }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :no_valid_url
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(request).to be_nil

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'CSVでヘッダーありの場合' do
          let(:file_name) { 'url_empty_with_header.csv' }
          let(:header)    { 1 }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :no_valid_url
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(request).to be_nil

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end
      end

      context 'アップロードファイルのURLが全て無効の場合' do

        context 'EXCELでヘッダーありの場合' do
          let(:file_name)    { 'no_acceptable_url_with_header.xlsx' }
          let(:header)       { 1 }
          let(:invalid_urls) { [{ index: 2, url: 'fffff', reason: 'URLの形式でない'},
                                { index: 3, url: 'http:/aaaa.com', reason: 'URLの形式でない'},
                                { index: 4, url: '', reason: 'URLが空'},
                                { index: 5, url: 'http://sample.cn/aa', reason: 'クロールが禁止されたドメイン'},
                                { index: 6, url: 'htp://ccc', reason: 'URLの形式でない'}] }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 302
            expect(response.location).to redirect_to request_multiple_path(r: request.id)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq invalid_urls
            expect(assigns(:finish_status)).to eq :no_acceptable_url
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(request.status).to eq EasySettings.status.completed
            expect(request.expiration_date).to be_nil
            expect(request.mail_address).to eq address
            expect(request.user).to eq user
            expect(request.ip).to eq '0.0.0.0'
            expect(request.requested_urls.count).to eq 0

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count + 1
            expect(RequestedUrl.count).to eq req_url_count
          end
        end
      end

      describe "想定されていない操作に関して" do
        context 'EXCELでヘッダーがあるファイルでヘッダーなしと選択された場合' do
          let(:file_name)    { 'url_empty_with_header.xlsx' }
          let(:header)       { 0 }
          let(:invalid_urls) { [{ index: 1, url: 'Url', reason: 'URLの形式でない'}] }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 302
            expect(response.location).to redirect_to request_multiple_path(r: request.id)

            # インスタンス変数のチェック
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq invalid_urls
            expect(assigns(:accept_count)).to eq 0
            expect(assigns(:finish_status)).to eq :no_acceptable_url
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            # モデルの存在確認
            expect(request.status).to eq EasySettings.status.completed
            expect(request.user).to eq user
            expect(request.ip).to eq '0.0.0.0'
            expect(request.requested_urls.count).to eq 0

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count + 1
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'typeが想定外の値の場合' do
          let(:type)  { 'abc' }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to eq ''
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to be_nil
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :invalid_type
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            expect(request).to be_nil

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq 0

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'CSV リスト作成のケース 正常終了の場合' do
          let(:file_name)    { 'making_list.csv' }
          let(:csv_str)      { "URL,タイトル\r\nhttps:/aaa,aaa\r\nhttps://www.nexway.co.jp,ネクスウェイ\r\nhttp://www.hokkaido.ccbc.co.jp/,北海道コカコーラ\r\nhtp://bbb,bbb\r\nhttps://www.starbucks.co.jp/,スタバ\r\nhttps://www.sample.ct.cn/,中国"}
          let(:invalid_urls) { [{:index=>2, :reason=>"URLの形式でない", :url=>"https:/aaa"}, {:index=>5, :reason=>"URLの形式でない", :url=>"htp://bbb"}, {:index=>7, :reason=>"クロールが禁止されたドメイン", :url=>"https://www.sample.ct.cn/"}] }
          let(:header)       { 1 }
          let(:col_select)   { 1 }
          let(:type)         { :csv_string }

          let(:params) {
            {
              request: { mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days,
                         free_search: free_search, link_words: link_words, target_words: target_words
                       },
              header: header, col_select: col_select, file_name: file_name,
              csv_str: csv_str, request_type: type, mode: mode
            }
          }

          it '正しい結果が返ってくること' do
            check_normal_finish(add_url_count: 3)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
            expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
            expect(request.requested_urls[2].url).to eq 'https://www.starbucks.co.jp/'
          end
        end

        describe 'キーワード検索に関して' do
          before { prepare_url_searcher_stub(EasySettings.excel_row_limit.public + 10) }

          let(:type)                    { :word_search }
          let(:keyword_for_word_search) { 'Tokyo' }
          let(:file_name) { keyword_for_word_search + '検索' }
          let(:invalid_urls) { [] }

          let(:params) {
            {
              request: { mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days },
              keyword_for_word_search: keyword_for_word_search, request_type: type, mode: mode
            }
          }

          context '正常終了の場合' do

            it '正しい結果が返ってくること' do
              check_normal_finish(add_url_count: EasySettings.excel_row_limit.public)

              # インスタンス変数のチェック
              expect(assigns(:using_storaged_date)).to be_nil
              expect(assigns(:use_storage)).to be_truthy
              # expect(assigns(:invalid_urls)).to eq invalid_urls
              expect(assigns(:free_search)).to be_falsey

              # モデルチェック
              expect(request.use_storage).to be_truthy
              expect(request.using_storage_days).to be_nil
              expect(request.free_search).to be_falsey
              expect(request.link_words).to be_nil
              expect(request.target_words).to be_nil
              expect(request.requested_urls[0].status).to eq EasySettings.status.new
              expect(request.requested_urls[0].finish_status).to eq EasySettings.finish_status.new
            end
          end

          context 'キーワードが入力されていない場合' do
            let(:keyword_for_word_search) { '' }

            it '正しい結果が返ってくること' do
              request_count = Request.count
              req_url_count = RequestedUrl.count

              subject

              # インスタンス変数のチェック
              expect(assigns(:finish_status)).to eq :keyword_blank
              expect(assigns(:using_storaged_date)).to be_nil
              expect(assigns(:use_storage)).to be_truthy
              expect(assigns(:accepted)).to be_falsey
              expect(assigns(:file_name)).to eq '検索'
              expect(assigns(:invalid_urls)).to eq []
              expect(assigns(:free_search)).to be_falsey

              expect(response.status).to eq 400
              expect(response).to render_template :index_multiple

              # モデルチェック
              expect(request).to be_nil

              # メールのチェック
              expect(ActionMailer::Base.deliveries.size).to eq(0)

              # 増減チェック
              expect(Request.count).to eq request_count
              expect(RequestedUrl.count).to eq req_url_count
            end
          end
        end
      end
    end
  end

  context 'Plan User' do
    email = 'login_test_user@aaa.com'
    let(:user)         { create(:user, email: email, billing: :credit) }
    let!(:history)     { create(:monthly_history, plan: EasySettings.plan[:standard], user: user, request_count: request_count) }
    let!(:plan)        { create(:billing_plan, name: master_standard_plan.name, status: :ongoing, billing: user.billing) }
    let(:request_count) { 0 }

    let(:logined_user) { user }
    let(:unlogin_user) { create(:user) }
    let(:public_user)  { User.get_public }
    let(:r1)           { create(:request, user: logined_user) }
    let(:r2)           { create(:request, user: logined_user) }

    before do
      sign_in logined_user
      create(:request, user: unlogin_user)
      create(:request, :corporate_site_list, user: unlogin_user)
      create(:request, user: public_user)
      create(:request, :corporate_site_list, user: public_user)

      create(:request, :corporate_site_list, user: logined_user)
      r1
      r2
    end

    describe "GET index_multiple" do
      subject { get :index_multiple, params: params }

      context 'リクエストIDがない場合' do
        let(:params) { {} }

        it do
          subject

          # 正常に動作しているか (http status)
          expect(response.status).to eq(200)

          expect(assigns(:requests)).to eq [r2, r1]

          # 正常にHTTPメソッドを呼び出せているか (render template)
          expect(response).to render_template :index_multiple
        end
      end

      context 'リクエストIDがある場合' do
        let(:r3) { create(:request, user: logined_user) }
        let(:params) { { r: r3.id } }

        context 'redisに情報がない場合' do
          it do
            subject

            # 正常に動作しているか (http status)
            expect(response.status).to eq(200)

            expect(assigns(:requests)).to eq [r3, r2, r1]
            expect(assigns(:accepted)).to be_nil
            expect(assigns(:finish_status)).to be_nil
            expect(assigns(:accept_id)).to be_nil
            expect(assigns(:type)).to be_nil
            expect(assigns(:test)).to be_nil
            expect(assigns(:title)).to be_nil
            expect(assigns(:file_name)).to be_nil
            expect(assigns(:mail_address)).to be_nil
            expect(assigns(:free_search)).to be_nil
            expect(assigns(:link_words)).to be_nil
            expect(assigns(:target_words)).to be_nil
            expect(assigns(:accept_count)).to be_nil
            expect(assigns(:invalid_urls)).to be_nil
            expect(assigns(:notice_create_msg)).to be_nil

            # 正常にHTTPメソッドを呼び出せているか (render template)
            expect(response).to render_template :index_multiple
          end
        end

        context 'redisに情報がある場合' do
          let(:redis_info) { {
              title: 'Test Title',
              accepted: true,
              finish_status: 'aa',
              accept_id: 'bb',
              type: 'cc',
              test: false,
              file_name: 'dd',
              mail_address: 'ee',
              free_search: false,
              link_words: 'gg',
              target_words: 'hh',
              accept_count: 3,
              invalid_urls: 'ii',
              notice_create_msg: 'jj'
            }.to_json }

          before do
            Redis.new.set("#{r3.id}_request", redis_info)
          end

          after do
            Redis.new.del("#{r3.id}_request")
          end

          it do
            subject

            # 正常に動作しているか (http status)
            expect(response.status).to eq(200)

            expect(assigns(:requests)).to eq [r3, r2, r1]
            expect(assigns(:accepted)).to eq true
            expect(assigns(:finish_status)).to eq 'aa'
            expect(assigns(:accept_id)).to eq 'bb'
            expect(assigns(:type)).to eq 'cc'
            expect(assigns(:test)).to eq false
            expect(assigns(:title)).to eq 'Test Title'
            expect(assigns(:file_name)).to eq 'dd'
            expect(assigns(:mail_address)).to eq 'ee'
            expect(assigns(:free_search)).to eq false
            expect(assigns(:link_words)).to eq 'gg'
            expect(assigns(:target_words)).to eq 'hh'
            expect(assigns(:accept_count)).to eq 3
            expect(assigns(:invalid_urls)).to eq 'ii'
            expect(assigns(:notice_create_msg)).to eq 'jj'

            # 正常にHTTPメソッドを呼び出せているか (render template)
            expect(response).to render_template :index_multiple
          end
        end
      end
    end

    describe "POST create" do
      subject { post :create, params: params }

      let(:sheet_select) { 'シート1' }
      let(:col_select)   { 1 }
      let(:requests)     { [request, r2, r1] }

      let(:params) {
        { request: { excel: excel, mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days,
                     free_search: free_search, link_words: link_words, target_words: target_words
                   },
          header: header, sheet_select: sheet_select, col_select: col_select, request_type: type, mode: mode
        }
      }

      context 'EXCEL 正常終了の場合' do
        it '正しい結果が返ってくること' do
          check_normal_finish(add_url_count: 4)

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:free_search)).to be_falsey

          # モデルチェック
          expect(request.use_storage).to be_truthy
          expect(request.using_storage_days).to be_nil
          expect(request.free_search).to be_falsey
          expect(request.link_words).to be_nil
          expect(request.target_words).to be_nil
          expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
          expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
          expect(request.requested_urls[2].url).to eq 'https://www.honda.co.jp/'
          expect(request.requested_urls[3].url).to eq 'https://www.starbucks.co.jp/'

          # リクエストカウントチェック
          expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
        end

        xcontext 'オリジナルクロールを設定した場合' do
          let(:free_search)  { 1 }
          let(:link_words)   { 'aa, bb ' }
          let(:target_words) { 'cc, dd ' }

          context '正常の場合' do
            it 'オリジナルクロールが設定されること、保存データの設定はOFFになること' do
              check_normal_finish(add_url_count: 4)

              # インスタンス変数のチェック
              expect(assigns(:using_storaged_date)).to be_nil
              expect(assigns(:use_storage)).to be_falsey
              expect(assigns(:free_search)).to be_truthy

              # モデルチェック
              expect(request.use_storage).to be_falsey
              expect(request.using_storage_days).to be_nil
              expect(request.free_search).to be_truthy
              expect(request.link_words).to eq 'aa,bb'
              expect(request.target_words).to eq 'cc,dd'
              expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
              expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
              expect(request.requested_urls[2].url).to eq 'https://www.honda.co.jp/'
              expect(request.requested_urls[3].url).to eq 'https://www.starbucks.co.jp/'

              # リクエストカウントチェック
              expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
            end

            context '企業概要などの言葉が含まれている場合、単語が6つ以上並べられている場合' do
                        
              let(:link_words)   { '企業概要, aa, bb , 会社概要, dd, ff, gg,ee,fff ' }
              let(:target_words) { 'aa, bb ,cc,企業概要 , ff,gg' }
              let(:requests)     { [Request.find_by_file_name(file_name), r2, r1] }

              it '企業概要などの言葉は削除されること、単語は5つに絞られること' do
                check_normal_finish(add_url_count: 4)

                # インスタンス変数のチェック
                expect(assigns(:using_storaged_date)).to be_nil
                expect(assigns(:use_storage)).to be_falsey
                expect(assigns(:free_search)).to be_truthy

                # モデルチェック
                expect(request.use_storage).to be_falsey
                expect(request.using_storage_days).to be_nil
                expect(request.free_search).to be_truthy
                expect(request.link_words).to eq 'aa,bb,dd'
                expect(request.target_words).to eq 'aa,bb,cc,企業概要,ff'
                expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'

                # リクエストカウントチェック
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
              end
            end

            context '最終的にリンクワードもターゲットワードも空になる場合' do
                        
              let(:link_words)   { '企業概要, 会社概要 ' }
              let(:target_words) { ', ,' }

              it 'オリジナルクロールはOFFになること、保存データ設定はONになること' do
                check_normal_finish(add_url_count: 4)

                # インスタンス変数のチェック
                expect(assigns(:using_storaged_date)).to be_nil
                expect(assigns(:use_storage)).to be_truthy
                expect(assigns(:free_search)).to be_falsey

                # モデルチェック
                expect(request.use_storage).to be_truthy
                expect(request.using_storage_days).to be_nil
                expect(request.free_search).to be_falsey
                expect(request.link_words).to be_nil
                expect(request.target_words).to be_nil
                expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'

                # リクエストカウントチェック
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
              end
            end
          end
        end
      end

      context 'CSV 正常終了の場合' do
        let(:request_count) { nil }

        let(:file_name)    { 'normal.csv' }
        let(:invalid_urls) { [{ index: 1, url: 'ttps://aaa', reason: 'URLの形式でない'},
                              { index: 3, url: '', reason: 'URLが空'},
                              { index: 5, url: 'http:/bbb', reason: 'URLの形式でない'},
                              { index: 7, url: 'https://sample.co.cn', reason: 'クロールが禁止されたドメイン'}] }
        let(:requests)     { [Request.find_by_file_name(file_name), r2, r1] }

        it '正しい結果が返ってくること' do
          check_normal_finish(add_url_count: 3)

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy

          # モデルチェック
          expect(request.use_storage).to be_truthy
          expect(request.using_storage_days).to be_nil
          expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
          expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
          expect(request.requested_urls[2].url).to eq 'https://www.starbucks.co.jp/'

          # リクエストカウントチェック
          expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
        end
      end

      context 'CSV リスト作成のケース 正常終了の場合' do
        let(:request_count) { nil }
        let(:file_name)     { 'making_list.csv' }
        let(:csv_str)       { "URL,タイトル\r\nhttps:/aaa,aaa\r\nhttps://www.nexway.co.jp,ネクスウェイ\r\nhttp://www.hokkaido.ccbc.co.jp/,北海道コカコーラ\r\nhtp://bbb,bbb\r\nhttps://www.starbucks.co.jp/,スタバ\r\n"}
        let(:invalid_urls)  { [{:index=>2, :reason=>"URLの形式でない", :url=>"https:/aaa"}, {:index=>5, :reason=>"URLの形式でない", :url=>"htp://bbb"}] }
        let(:header)        { 1 }
        let(:col_select)    { 1 }
        let(:type)          { :csv_string }
        let(:requests)      { [Request.find_by_file_name(file_name), r2, r1] }

        let(:params) {
          {
            request: { mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days },
            header: header, col_select: col_select, file_name: file_name,
            csv_str: csv_str, request_type: type, mode: mode
          }
        }

        it '正しい結果が返ってくること' do
          check_normal_finish(add_url_count: 3)

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy

          # モデルチェック
          expect(request.use_storage).to be_truthy
          expect(request.using_storage_days).to be_nil
          expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
          expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
          expect(request.requested_urls[2].url).to eq 'https://www.starbucks.co.jp/'

          # リクエストカウントチェック
          expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
        end
      end

      describe 'キーワード検索に関して' do
        let(:request_count) { nil }

        before do
          prepare_url_searcher_stub(EasySettings.excel_row_limit.standard + 10)
        end

        let(:type)                    { :word_search }
        let(:keyword_for_word_search) { 'Tokyo' }
        let(:file_name) { keyword_for_word_search + '検索' }
        let(:invalid_urls) { [] }

        let(:params) {
          {
            request: { mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days },
            keyword_for_word_search: keyword_for_word_search, request_type: type, mode: mode
          }
        }

        context '正常終了の場合' do
          it '正しい結果が返ってくること' do
            check_normal_finish(add_url_count: EasySettings.excel_row_limit.standard)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1
          end
        end

        context 'キーワードが入力されていない場合' do
          let(:keyword_for_word_search) { '' }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            # インスタンス変数のチェック
            expect(assigns(:finish_status)).to eq :keyword_blank
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq '検索'
            expect(assigns(:invalid_urls)).to eq []

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq nil

            # モデルチェック
            expect(request).to be_nil

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end
      end

      describe 'リクエスト制限に関して' do

        context '待機リクエスト制限を超えている場合' do
          let(:request_count) { EasySettings.monthly_request_limit[:standard] }

          before do
            create_list(:request, EasySettings.waiting_requests_limit[user.my_plan], user: user)
          end

          it '待機リクエスト制限に引っかかること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count
            before_request_count = user.request_count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :waiting_requests_limit
            expect(assigns(:requests).size).to eq EasySettings.waiting_requests_limit[user.my_plan]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[:standard]

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context '月次アクセス制限を超えている場合' do
          let(:request_count) { EasySettings.monthly_request_limit[:standard] }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :monthly_request_limit
            expect(assigns(:requests)).to eq [r2, r1]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[:standard] + 1

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'アクセス制限を超えていない場合' do
          let(:request_count) { EasySettings.monthly_request_limit[:standard] - 1 }

          it '正しい結果が返ってくること' do
            check_normal_finish(add_url_count: 4)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy

            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.requested_urls[0].url).to eq 'https://www.nexway.co.jp'
            expect(request.requested_urls[1].url).to eq 'http://www.hokkaido.ccbc.co.jp/'
            expect(request.requested_urls[2].url).to eq 'https://www.honda.co.jp/'
            expect(request.requested_urls[3].url).to eq 'https://www.starbucks.co.jp/'

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[:standard]
          end
        end
      end

      context 'アップロードファイルのURLが空の場合' do

        context 'EXCELでヘッダーなしの場合' do
          let(:file_name) { 'empty.xlsx' }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :no_valid_url
            expect(assigns(:requests)).to eq [r2, r1]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'EXCELでヘッダーありの場合' do
          let(:file_name) { 'url_empty_with_header.xlsx' }
          let(:header)    { 1 }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :no_valid_url
            expect(assigns(:requests)).to eq [r2, r1]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'CSVでヘッダーありの場合' do
          let(:file_name) { 'url_empty_with_header.csv' }
          let(:header)    { 1 }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :no_valid_url
            expect(assigns(:requests)).to eq [r2, r1]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end
      end

      context 'アップロードファイルのURLが全て無効の場合' do

        context 'EXCELでヘッダーありの場合' do
          let(:file_name)    { 'no_acceptable_url_with_header.xlsx' }
          let(:header)       { 1 }
          let(:invalid_urls) { [{ index: 2, url: 'fffff', reason: 'URLの形式でない'},
                                { index: 3, url: 'http:/aaaa.com', reason: 'URLの形式でない'},
                                { index: 4, url: '', reason: 'URLが空'},
                                { index: 5, url: 'http://sample.cn/aa', reason: 'クロールが禁止されたドメイン'},
                                { index: 6, url: 'htp://ccc', reason: 'URLの形式でない'}] }

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 302
            expect(response.location).to redirect_to request_multiple_path(r: request.id)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq invalid_urls
            expect(assigns(:finish_status)).to eq :no_acceptable_url
            expect(assigns(:requests)).to eq [request, r2, r1]

            expect(request.title).to eq file_name
            expect(request.status).to eq EasySettings.status.completed
            expect(request.expiration_date).to be_nil
            expect(request.mail_address).to eq address
            expect(request.ip).to eq '0.0.0.0'
            expect(request.requested_urls.count).to eq 0

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).reload.request_count).to eq 1

            # メールのチェック
            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count + 1
            expect(RequestedUrl.count).to eq req_url_count
          end
        end
      end
    end
  end
end

require 'rails_helper'

RSpec.describe RequestsController, type: :controller do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  let_it_be(:public_user)  { create(:user_public) }
  let_it_be(:ecareer_data) { AnalysisData::Ecareer.create }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end


  let(:ip) { '0.0.0.0' }
  # let(:today)     { Time.zone.today }
  # let(:yesterday) { today - 1.day }

  # let(:title)              { 'Test Title' }
  # let(:start_url)          { 'http://aaaa.com'}
  # let(:file_name)          { 'normal_urlcol1_1.xlsx' }
  # let(:address)            { 'to@example.org' }
  # let(:use_storage)        { 1 }
  # let(:using_storage_days) { '' }
  # let(:free_search)        { 0 }
  # let(:link_words)         { '' }
  # let(:target_words)       { '' }
  # let(:type)               { :file }
  # let(:mode)               { :multiple }

  after { ActionMailer::Base.deliveries.clear }

  let_it_be(:unlogin_user) { create(:user) }
  let_it_be(:r1)           { create(:request, user: unlogin_user) }
  let_it_be(:r2)           { create(:request, :corporate_site_list, user: unlogin_user) }
  let_it_be(:r3)           { create(:request, user: User.get_public) }
  let_it_be(:r4)           { create(:request, :corporate_site_list, user: User.get_public) }

  describe "GET index" do
    context 'パブリックユーザ' do
      subject { get :index, params: params }

      context 'リクエストIDがない場合' do
        let(:params) { {} }

        it do
          subject

          # 正常に動作しているか (http status)
          expect(response.status).to eq(200)

          expect(assigns(:requests)).to be_nil

          # 正常にHTTPメソッドを呼び出せているか (render template)
          expect(response).to render_template :index
          expect(response.cookies['rfd']).to be_nil
        end

        context 'パラメータにrfd(紹介者ID)が含まれているとき' do
          let(:params) { { rfd: '1234567' } }

          it do
            subject

            expect(response.status).to eq(200)

            expect(assigns(:requests)).to be_nil

            expect(response).to render_template :index
            expect(response.cookies['rfd']).to be_present
          end
        end
      end

      context 'リクエストIDがある場合' do
        let(:r5) { create(:request, :corporate_site_list, user: User.get_public) }
        let(:params) { { r: r5.id } }

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
            expect(response).to render_template :index
          end
        end

        context 'redisに情報がある場合' do
          let(:title) { 'Test Title' }

          let(:redis_info) { {
              title: title,
              accepted: true,
              finish_status: 'aa',
              accept_id: 'bb',
              type: 'cc',
              test: true,
              file_name: 'dd',
              mail_address: 'ee',
              free_search: false,
              link_words: 'gg',
              target_words: 'hh',
              accept_count: 2,
              invalid_urls: 'ii',
              notice_create_msg: 'jj'
            }.to_json }

          before do
            Redis.new.set("#{r5.id}_request", redis_info)
          end

          after do
            Redis.new.del("#{r5.id}_request")
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
            expect(assigns(:test)).to eq true
            expect(assigns(:title)).to eq title
            expect(assigns(:file_name)).to eq 'dd'
            expect(assigns(:mail_address)).to eq 'ee'
            expect(assigns(:free_search)).to eq false
            expect(assigns(:link_words)).to eq 'gg'
            expect(assigns(:target_words)).to eq 'hh'
            expect(assigns(:accept_count)).to eq 2
            expect(assigns(:invalid_urls)).to eq 'ii'
            expect(assigns(:notice_create_msg)).to eq 'jj'

            # 正常にHTTPメソッドを呼び出せているか (render template)
            expect(response).to render_template :index
          end
        end
      end
    end

    context 'ログインユーザ' do
      subject { get :index, params: params }
      let(:user) { create(:user) }
      let(:r_a1) { create(:request, :corporate_site_list, user: user) }
      let(:r_a2) { create(:request, :corporate_site_list, user: user) }
      let(:r_a3) { create(:request, :corporate_site_list, user: user) }

      before do
        sign_in user
        r_a1
        4.times { |_| create(:request, user: user) }
        r_a2
        r_a3
      end

      describe 'viewableの確認' do
        let(:params) { {} }
        let!(:r_a4) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.new, updated_at: Time.zone.today - 33.days) }
        let!(:r_a5) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.waiting, updated_at: Time.zone.today - 33.days) }
        let!(:r_a6) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.working, updated_at: Time.zone.today - 33.days) }

        let!(:r_a7) { create(:request, :corporate_site_list, :corporate_site_list, user: user, status: EasySettings.status.completed, updated_at: Time.zone.today - 1.month) }
        let!(:r_a8) { create(:request, :corporate_site_list, :corporate_site_list, user: user, status: EasySettings.status.completed, updated_at: Time.zone.today - 1.month + 1.day) }
        let!(:r_a9) { create(:request, :corporate_site_list, :corporate_site_list, user: user, status: EasySettings.status.completed, updated_at: Time.zone.today - 1.month - 1.day) }
        let!(:r_a10) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.discontinued, updated_at: Time.zone.today - 1.month) }
        let!(:r_a11) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.discontinued, updated_at: Time.zone.today - 1.month + 1.day) }
        let!(:r_a12) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.discontinued, updated_at: Time.zone.today - 1.month - 1.day) }

        it '完了から1か月以内のリクエストが表示されること' do
          subject

          expect(response.status).to eq(200)

          expect(assigns(:requests)).to eq [r_a11, r_a10, r_a8, r_a7, r_a6, r_a5, r_a4, r_a3, r_a2, r_a1]

          expect(response).to render_template :index
        end
      end

      context 'リクエストIDがない場合' do
        let(:params) { {} }

        it do
          subject

          # 正常に動作しているか (http status)
          expect(response.status).to eq(200)

          expect(assigns(:requests)).to eq [r_a3, r_a2, r_a1]

          # 正常にHTTPメソッドを呼び出せているか (render template)
          expect(response).to render_template :index
        end
      end

      context 'リクエストIDがある場合' do
        let(:r5) { create(:request, :corporate_site_list, user: user) }
        let(:params) { { r: r5.id } }

        context 'redisに情報がない場合' do
          it do
            subject

            # 正常に動作しているか (http status)
            expect(response.status).to eq(200)

            expect(assigns(:requests)).to eq [r5, r_a3, r_a2, r_a1]
            expect(assigns(:accepted)).to be_nil
            expect(assigns(:finish_status)).to be_nil
            expect(assigns(:accept_id)).to be_nil
            expect(assigns(:type)).to be_nil
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
            expect(response).to render_template :index
          end
        end

        context 'redisに情報がある場合' do
          let(:title) { "Test Title #{SecureRandom.alphanumeric(10)}" }

          let(:redis_info) { {
              title: title,
              accepted: true,
              finish_status: 'aa',
              accept_id: 'bb',
              type: 'cc',
              test: true,
              file_name: 'dd',
              mail_address: 'ee',
              free_search: false,
              link_words: 'gg',
              target_words: 'hh',
              accept_count: 2,
              invalid_urls: 'ii',
              notice_create_msg: 'jj'
            }.to_json }

          before do
            Redis.new.set("#{r5.id}_request", redis_info)
          end

          after do
            Redis.new.del("#{r5.id}_request")
          end

          it do
            subject

            # 正常に動作しているか (http status)
            expect(response.status).to eq(200)

            expect(assigns(:requests)).to eq [r5, r_a3, r_a2, r_a1]
            expect(assigns(:accepted)).to eq true
            expect(assigns(:finish_status)).to eq 'aa'
            expect(assigns(:accept_id)).to eq 'bb'
            expect(assigns(:type)).to eq 'cc'
            expect(assigns(:test)).to eq true
            expect(assigns(:title)).to eq title
            expect(assigns(:file_name)).to eq 'dd'
            expect(assigns(:mail_address)).to eq 'ee'
            expect(assigns(:free_search)).to eq false
            expect(assigns(:link_words)).to eq 'gg'
            expect(assigns(:target_words)).to eq 'hh'
            expect(assigns(:accept_count)).to eq 2
            expect(assigns(:invalid_urls)).to eq 'ii'
            expect(assigns(:notice_create_msg)).to eq 'jj'

            # 正常にHTTPメソッドを呼び出せているか (render template)
            expect(response).to render_template :index
          end
        end
      end
    end
  end

  describe "POST create" do
    subject { post :create, params: params }

    let(:title)              { "Test Title req con corp list #{SecureRandom.alphanumeric(10)}" }
    let(:start_url)          { 'http://aaaa.com'}
    let(:address)            { 'to@example.org' }
    let(:use_storage)        { 1 }
    let(:using_storage_days) { '' }
    let(:free_search)        { 0 }
    let(:link_words)         { '' }
    let(:target_words)       { '' }
    let(:type)               { :corporate_list_site }
    let(:mode)               { RequestsController::MODE_CORPORATE }
    let(:execution_type)     { 'main' }
    let(:corporate_list)     { {"1"=>{"url"=>"", "details_off"=>"1", "organization_name"=>"", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"1" } }
    let(:corporate_individual) { {"1"=>{"url"=>"", "details_off"=>"1", "organization_name"=>"", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"1"} }

    let(:params) { { request: { title: title, corporate_list_site_start_url: start_url,
                                mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days,
                                corporate_list: corporate_list, corporate_individual: corporate_individual
                        },
               request_type: type, mode: mode, execution_type: execution_type
             }
           }

    let(:request) { Request.find_by_title(title) }

    before do
      allow_any_instance_of(BatchAccessor).to receive(:request_test_search).and_return(StabMaker.new({code: 200}))
    end

    def check_normal_finish
      request_count = Request.count
      req_url_count = RequestedUrl.count

      subject

      expect(assigns(:finish_status)).to eq :normal_finish
      expect(assigns(:accepted)).to be_truthy
      expect(assigns(:file_name)).to be_nil

      expect(response.status).to eq 302
      expect(response.location).to redirect_to root_path(r: request.id)

      # モデルチェック
      expect(request.title).to eq title
      expect(request.type).to eq 'corporate_list_site'
      expect(request.corporate_list_site_start_url).to eq start_url
      expect(request.company_info_result_headers).to be_nil
      expect(request.status).to eq EasySettings.status.new
      expect(request.expiration_date).to be_nil
      expect(request.mail_address).to eq address
      expect(request.ip).to eq '0.0.0.0'
      expect(request.requested_urls.count).to eq 1
      expect(request.requested_urls[0].url).to eq start_url
      expect(request.requested_urls[0].finish_status).to eq EasySettings.finish_status.new

      expect(request.requested_urls[0].status).to eq EasySettings.status.new

      # 増減チェック
      expect(Request.count).to eq request_count + 1
      expect(RequestedUrl.count).to eq req_url_count + 1

      # メールのチェック
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(ActionMailer::Base.deliveries.first.to).to include address
      expect(ActionMailer::Base.deliveries.first.subject).to match(/リクエストを受け付けました。/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{title}/)

      # redisにsetされていることをチェック
      expect(Redis.new.get("#{request.id}_request")).to be_present
      Redis.new.del("#{request.id}_request")
    end

    def check_invalid_finish(finish_status:, message:)
      request_count = Request.count
      req_url_count = RequestedUrl.count

      subject

      expect(assigns(:finish_status)).to eq finish_status
      expect(assigns(:accepted)).to be_falsey
      expect(assigns(:file_name)).to be_nil
      expect(assigns(:invalid_urls)).to eq []

      if flash[:alert].present?
        expect(flash[:alert]).to eq message
      else
        expect(assigns(:notice_create_msg)).to eq message
      end

      expect(response.status).to eq 400
      expect(response).to render_template :index

      # 増減チェック
      expect(Request.count).to eq request_count
      expect(RequestedUrl.count).to eq req_url_count

      # メールのチェック
      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    describe '正常系' do
      context 'Public User' do
        context '本リクエスト' do
          let(:execution_type) { 'main' }

          it '正しい結果が返ってくること' do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.corporate_list_config).to be_nil
            expect(request.corporate_individual_config).to be_nil
            expect(request.test).to be_falsey
            expect(request.plan).to eq EasySettings.plan[:public]
            expect(request.user).to eq User.get_public
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.requested_urls[0].test).to be_falsey
          end
        end

        context 'テスト' do
          let(:execution_type) { 'test' }

          it '正しい結果が返ってくること' do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:requests)).to be_nil
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.corporate_list_site_start_url).to eq start_url
            expect(request.corporate_list_config).to be_nil
            expect(request.corporate_individual_config).to be_nil
            expect(request.test).to be_truthy
            expect(request.plan).to eq EasySettings.plan[:public]
            expect(request.user).to eq User.get_public
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.requested_urls[0].test).to be_truthy
          end
        end
      end

      context 'Login User' do
        let(:user) { create(:user) }
        before { sign_in user }

        context '本リクエスト' do
          let(:execution_type) { 'main' }

          it '正しい結果が返ってくること' do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.corporate_list_config).to be_nil
            expect(request.corporate_individual_config).to be_nil
            expect(request.test).to be_falsey
            expect(request.plan).to eq user.my_plan_number
            expect(request.user).to eq user
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.requested_urls[0].test).to be_falsey
          end
        end

        context 'テスト' do
          let(:execution_type) { 'test' }

          it '正しい結果が返ってくること' do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.corporate_list_site_start_url).to eq start_url
            expect(request.corporate_list_config).to be_nil
            expect(request.corporate_individual_config).to be_nil
            expect(request.test).to be_truthy
            expect(request.plan).to eq user.my_plan_number
            expect(request.user).to eq user
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.requested_urls[0].test).to be_truthy
          end
        end
      end
    end

    describe 'テストの異常系' do
      let(:user) { create(:user) }
      before { sign_in user }

      context 'テスト' do
        let(:execution_type) { 'test' }

        before do
          allow_any_instance_of(BatchAccessor).to receive(:request_test_search).and_return(StabMaker.new({code: 400, body: 'aa'}))
        end

        it '正しい結果が返ってくること' do
          request_count = Request.count
          req_url_count = RequestedUrl.count

          subject

          expect(assigns(:finish_status)).to eq :normal_finish
          expect(assigns(:accepted)).to be_truthy
          expect(assigns(:file_name)).to be_nil

          expect(response.status).to eq 302
          expect(response.location).to redirect_to root_path(r: request.id)

          # モデルチェック
          expect(request.title).to eq title
          expect(request.type).to eq 'corporate_list_site'
          expect(request.corporate_list_site_start_url).to eq start_url
          expect(request.company_info_result_headers).to be_nil
          expect(request.status).to eq EasySettings.status.new
          expect(request.expiration_date).to be_nil
          expect(request.mail_address).to eq address
          expect(request.ip).to eq '0.0.0.0'
          expect(request.requested_urls.count).to eq 1
          expect(request.requested_urls[0].url).to eq start_url
          expect(request.requested_urls[0].finish_status).to eq EasySettings.finish_status.new

          expect(request.requested_urls[0].status).to eq EasySettings.status.new

          # 増減チェック
          expect(Request.count).to eq request_count + 1
          expect(RequestedUrl.count).to eq req_url_count + 1

          # メールのチェック
          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/error発生/)
          expect(ActionMailer::Base.deliveries[1].to).to include address
          expect(ActionMailer::Base.deliveries[1].subject).to match(/リクエストを受け付けました。/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/#{title}/)

          # redisにsetされていることをチェック
          expect(Redis.new.get("#{request.id}_request")).to be_present
          Redis.new.del("#{request.id}_request")

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:free_search)).to be_falsey

          # モデルチェック
          expect(request.corporate_list_site_start_url).to eq start_url
          expect(request.corporate_list_config).to be_nil
          expect(request.corporate_individual_config).to be_nil
          expect(request.test).to be_truthy
          expect(request.plan).to eq user.my_plan_number
          expect(request.user).to eq user
          expect(request.use_storage).to be_truthy
          expect(request.using_storage_days).to be_nil
          expect(request.free_search).to be_falsey
          expect(request.link_words).to be_nil
          expect(request.target_words).to be_nil
          expect(request.requested_urls[0].test).to be_truthy
        end
      end
    end

    context 'Invalid execution_type' do
      shared_examples 'execution_typeが不正であると返ってくること' do
        it do
          check_invalid_finish(finish_status: :invalid_execution_type, message: Message.const[:unaccept_request])

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_blank
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:requests)).to be_nil
          expect(assigns(:free_search)).to be_falsey
        end
      end

      context 'execution_typeが違う' do
        let(:execution_type) { 'aa' }

        it_behaves_like 'execution_typeが不正であると返ってくること'
      end

      context 'execution_typeがnil' do
        let(:execution_type) { nil }

        it_behaves_like 'execution_typeが不正であると返ってくること'
      end
    end

    context 'Invalid type' do
      shared_examples 'typeが不正であると返ってくること' do
        it do
          check_invalid_finish(finish_status: :invalid_type, message: Message.const[:unaccept_request])

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_blank
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:requests)).to be_nil
          expect(assigns(:free_search)).to be_falsey
        end
      end

      context 'typeが不正' do
        let(:type) { :aa }

        it_behaves_like 'typeが不正であると返ってくること'
      end

      context 'typeがnil' do
        let(:type) { nil }

        it_behaves_like 'typeが不正であると返ってくること'
      end
    end

    describe 'ストレージデータ' do
      context 'ストレージデータが正常' do
        context 'using_storage_daysが空' do
          let(:use_storage)        { 1 }
          let(:using_storage_days) { '' }

          it do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_blank
            expect(assigns(:use_storage)).to be_truthy

            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
          end
        end

        context 'using_storage_daysが数値' do
          let(:use_storage)        { 1 }
          let(:using_storage_days) { 5 }

          it do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to eq 5
            expect(assigns(:use_storage)).to be_truthy

            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to eq 5
          end
        end

        context 'use_storageが0' do
          let(:use_storage)        { '0' }
          let(:using_storage_days) { 5 }

          it do
            check_normal_finish

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to eq "5"
            expect(assigns(:use_storage)).to be_falsey

            expect(request.use_storage).to be_falsey
            expect(request.using_storage_days).to eq 5
          end
        end
      end

      context 'ストレージデータが異常' do
        let(:use_storage)        { '1' }
        let(:using_storage_days) { 'a' }

        it do
          check_invalid_finish(finish_status: :using_strage_setting_invalid, message: Message.const[:confirm_storage_date])

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to eq "a"
          expect(assigns(:use_storage)).to be_truthy
        end
      end
    end

    describe 'URLのバリデーション' do
      context 'URLがnil' do
        let(:start_url) { nil }

        it do
          check_invalid_finish(finish_status: :corporate_list_site_start_url_blank, message: Message.const[:url_is_blank])

          # インスタンス変数のチェック
          expect(assigns(:corporate_list_site_start_url)).to be_empty
        end
      end

      context 'URLの値が異常' do
        let(:start_url) { 'htp://vvv.com' }

        it do
          check_invalid_finish(finish_status: :invalid_url, message: Message.const[:invalid_url])

          # インスタンス変数のチェック
          expect(assigns(:corporate_list_site_start_url)).to eq start_url
        end
      end
    end

    describe '禁止されたドメイン' do
      let(:start_url) { 'https://sample.dd.cn' }

      it do
        check_invalid_finish(finish_status: :ban_domain, message: Message.const[:ban_domain])

        # インスタンス変数のチェック
        expect(assigns(:corporate_list_site_start_url)).to eq start_url
      end
    end

    describe '利用不可能なリストサイトのURL' do
      context 'ban_pathes_alert_messageがある時' do
        context do
          let(:start_url) { 'https://www.ecareer.ne.jp/positions' }

          it do
            check_invalid_finish(finish_status: :unavailable_list_site_url, message: AnalysisData::Ecareer.ban_pathes_alert_message)

            # インスタンス変数のチェック
            expect(assigns(:corporate_list_site_start_url)).to eq start_url
          end
        end

        context do
          let(:start_url) { 'https://www.ecareer.ne.jp/' }

          it do
            check_invalid_finish(finish_status: :unavailable_list_site_url, message: AnalysisData::Ecareer.ban_pathes_alert_message)

            # インスタンス変数のチェック
            expect(assigns(:corporate_list_site_start_url)).to eq start_url
          end
        end
      end

      context 'ban_pathes_alert_messageがnilの時' do
        let(:start_url) { 'https://www.ecareer.ne.jp/' }

        before { allow(AnalysisData::Ecareer).to receive(:ban_pathes_alert_message).and_return(nil) }

        it do
          check_invalid_finish(finish_status: :unavailable_list_site_url, message: Message.const[:unavailable_list_site_url])

          # インスタンス変数のチェック
          expect(assigns(:corporate_list_site_start_url)).to eq start_url
        end
      end
    end

    describe '企業一覧ページのコンフィグ' do
      context '正常' do
        let(:corporate_list) { {"1"=>{"url"=>"https://aaa.com", "details_off"=>"0", "organization_name"=>{"1" => "aaa", "2"=>"bbb"}, "contents"=>{"1"=>{"title"=>"title1", "text"=>{"1" => "a", "2" => "b"}}}}, "config_off"=>"0" } }

        it do
          check_normal_finish

          expect(request.corporate_list_config).to be_present
          expect(request.corporate_individual_config).to be_nil
        end
      end

      context '異常' do
        let(:corporate_list) { {"1"=>{"url"=>"https://aaa.com", "details_off"=>"0", "organization_name"=>{"1" => "aaa"}, "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"0" } }

        it do
          check_invalid_finish(finish_status: :invalid_corporate_list_params, message: Message.const[:invalid_parameters])
        end
      end
    end

    describe '企業個別ページのコンフィグ' do
      context '正常' do
        let(:corporate_individual) { {"1"=>{"url"=>"http://aaa.com", "details_off"=>"0", "organization_name"=>"あああ", "contents"=>{"1"=>{"title"=>"a", "text"=>"bb"}}}, "config_off"=>"0"} }

        it do
          check_normal_finish

          expect(request.corporate_list_config).to be_nil
          expect(request.corporate_individual_config).to be_present
        end
      end

      context '異常' do
        let(:corporate_individual) { {"1"=>{"url"=>"", "details_off"=>"0", "organization_name"=>"あああ", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"0"} }

        it do
          check_invalid_finish(finish_status: :invalid_corporate_individual_params, message: Message.const[:invalid_parameters])
        end
      end
    end

    describe 'アクセス制限' do
      describe 'ログインユーザ' do
        let(:user) { create(:user, billing: :credit) }
        let(:monthly_request_count) { 5 }
        let(:plan)     { :standard }
        let!(:b_plan)  { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
        let!(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[plan], request_count: monthly_request_count) }

        before do
          sign_in user
        end

        context '本番' do
          let(:execution_type) { 'main' }

          describe '待機リクエスト制限' do
            context '待機リクエスト制限数に達していない時' do
              before do
                cnt = user.requests.unfinished.count
                (EasySettings.waiting_requests_limit[user.my_plan] - 1 - cnt).times do |_|
                  create(:request, user: user)
                end
              end

              it do
                cnt = MonthlyHistory.find_around(user).request_count
                check_normal_finish
                expect(ActionMailer::Base.deliveries.first.to).to include user.email
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq cnt + 1
              end
            end

            context '待機リクエスト制限数に達している時' do
              before do
                cnt = user.requests.unfinished.count
                (EasySettings.waiting_requests_limit[user.my_plan] - cnt).times do |_|
                  create(:request, user: user)
                end
              end

              it do
                cnt = MonthlyHistory.find_around(user).request_count
                check_invalid_finish(finish_status: :waiting_requests_limit, message: Message.const[:over_waiting_requests_limit])
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq cnt
              end
            end
          end

          describe '月間リクエスト制限' do
            context '月間リクエスト制限数に達していない時' do
              let(:monthly_request_count) { EasySettings.monthly_request_limit[plan] - 1 }

              it do
                check_normal_finish
                expect(ActionMailer::Base.deliveries.first.to).to include user.email
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[user.my_plan]
              end
            end

            context '月間リクエスト制限数に達している時' do
              let(:monthly_request_count) { EasySettings.monthly_request_limit[plan] }

              it do
                check_invalid_finish(finish_status: :monthly_request_limit, message: Message.const[:over_monthly_limit])
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[user.my_plan] + 1
              end
            end
          end
        end

        context 'テスト' do
          let(:execution_type) { 'test' }

          describe '待機リクエスト制限' do
            context '待機リクエスト制限数に達していない時' do
              before do
                cnt = user.requests.unfinished.count
                (EasySettings.waiting_requests_limit[user.my_plan] - 1 - cnt).times do |_|
                  create(:request, user: user)
                end
              end

              it do
                cnt = MonthlyHistory.find_around(user).request_count
                check_normal_finish
                expect(ActionMailer::Base.deliveries.first.to).to include user.email
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq cnt
              end
            end

            context '待機リクエスト制限数に達している時' do
              before do
                cnt = user.requests.unfinished.count
                (EasySettings.waiting_requests_limit[user.my_plan] - cnt).times do |_|
                  create(:request, user: user)
                end
              end

              it do
                cnt = MonthlyHistory.find_around(user).request_count
                check_invalid_finish(finish_status: :waiting_requests_limit, message: Message.const[:over_waiting_requests_limit])
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq cnt
              end
            end
          end

          describe '月間リクエスト制限' do
            context '月間リクエスト制限数に達していない時' do
              let(:monthly_request_count) { EasySettings.monthly_request_limit[plan] - 1 }

              it do
                check_normal_finish
                expect(ActionMailer::Base.deliveries.first.to).to include user.email
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[user.my_plan] - 1
              end
            end

            context '月間リクエスト制限数に達している時' do
              let(:monthly_request_count) { EasySettings.monthly_request_limit[plan] }

              it do
                check_invalid_finish(finish_status: :monthly_request_limit, message: Message.const[:over_monthly_limit])
                expect(MonthlyHistory.find_around(user).reload.request_count).to eq EasySettings.monthly_request_limit[user.my_plan]
              end
            end
          end
        end
      end

      describe 'パブリックユーザ' do
        context '本番' do
          let(:execution_type) { 'main' }

          describe 'IPアクセス制限' do
            let(:ip) { '0.0.0.0' }

            context 'IPアクセス制限数に達していない時' do
              before do
                cnt = User.get_public.requests.unfinished_by_ip(ip).count
                (EasySettings.public_access_limit.ip - 1 - cnt).times do |_|
                  create(:request, user: User.get_public, ip: ip)
                end
              end

              it { check_normal_finish }
            end

            context 'IPアクセス制限数に達している時' do
              before do
                cnt = User.get_public.requests.unfinished_by_ip(ip).count
                (EasySettings.public_access_limit.ip - cnt).times do |_|
                  create(:request, user: User.get_public, ip: ip)
                end
              end

              it do
                check_invalid_finish(finish_status: :public_ip_access_request_limit, message: Message.const[:over_public_ip_limit])
              end
            end
          end

          describe '待機リクエスト制限' do
            context '待機リクエスト制限数に達していない時' do
              before do
                cnt = User.get_public.requests.unfinished.count
                (EasySettings.waiting_requests_limit.public - 1 - cnt).times do |_|
                  create(:request, user: User.get_public)
                end
              end

              it { check_normal_finish }
            end

            context '待機リクエスト制限数に達している時' do
              before do
                cnt = User.get_public.requests.unfinished.count
                (EasySettings.waiting_requests_limit.public - cnt).times do |_|
                  create(:request, user: User.get_public)
                end
              end

              it do
                check_invalid_finish(finish_status: :public_waiting_requests_limit, message: Message.const[:over_public_waiting_limit])
              end
            end
          end
        end

        context 'テスト' do
          let(:execution_type) { 'test' }

          describe 'IPアクセス制限' do
            let(:ip) { '0.0.0.0' }

            context 'IPアクセス制限数に達していない時' do
              before do
                cnt = User.get_public.requests.unfinished_by_ip(ip).count
                (EasySettings.public_access_limit.ip - 1 - cnt).times do |_|
                  create(:request, user: User.get_public, ip: ip)
                end
              end

              it { check_normal_finish }
            end

            context 'IPアクセス制限数に達している時' do
              before do
                cnt = User.get_public.requests.unfinished_by_ip(ip).count
                (EasySettings.public_access_limit.ip - cnt).times do |_|
                  create(:request, user: User.get_public, ip: ip)
                end
              end

              it do
                check_invalid_finish(finish_status: :public_ip_access_request_limit, message: Message.const[:over_public_ip_limit])
              end
            end
          end

          describe '待機リクエスト制限' do
            context '待機リクエスト制限数に達していない時' do
              before do
                cnt = User.get_public.requests.unfinished.count
                (EasySettings.waiting_requests_limit.public - 1 - cnt).times do |_|
                  create(:request, user: User.get_public)
                end
              end

              it { check_normal_finish }
            end

            context '待機リクエスト制限数に達している時' do
              before do
                cnt = User.get_public.requests.unfinished.count
                (EasySettings.waiting_requests_limit.public - cnt).times do |_|
                  create(:request, user: User.get_public)
                end
              end

              it do
                check_invalid_finish(finish_status: :public_waiting_requests_limit, message: Message.const[:over_public_waiting_limit])
              end
            end
          end
        end
      end
    end
  end

  describe "PUT recreate" do
    subject { put :recreate, params: params }

    let(:user)               { User.get_public }
    let(:title)              { "Test Title req con corp list #{SecureRandom.alphanumeric(10)}" }
    let(:start_url)          { 'http://aaaa.com'}
    let(:type)               { 'corporate_list_site' }
    let(:address)            { 'to@example.org' }
    let(:notice_to_address)  { [address] }
    let(:use_storage)        { 1 }
    let(:using_storage_days) { '' }
    let(:free_search)        { 0 }
    let(:link_words)         { 'a' }
    let(:target_words)       { 'b' }
    let(:execution_type)     { 'main' }
    let(:test)               { true }
    let(:init_status)        { EasySettings.status.completed }
    let(:plan)               { user.my_plan_number }
    let(:corporate_list)     { {"1"=>{"url"=>"", "details_off"=>"1", "organization_name"=>"", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"1" } }
    let(:corporate_individual) { {"1"=>{"url"=>"", "details_off"=>"1", "organization_name"=>"", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"1"} }

    let(:base_req) { create(:request, :corporate_site_list,
                        user: user, title: title, corporate_list_site_start_url: start_url,
                        test: test, mail_address: address, status: init_status, expiration_date: nil, plan: plan,
                        ) }
    let(:req_url) { create(:search_request_corporate_list, request: base_req, status: EasySettings.status.completed, test: test, url: start_url) }
    let(:accept_id) { base_req.accept_id }
    let(:params) { { accept_id: accept_id } }


    let(:request) { Request.find_by_title(title) }

    def check_normal_finish
      request_count = Request.count
      req_url_count = RequestedUrl.count
      req_url_main_count = RequestedUrl.main.count

      subject

      expect(assigns(:finish_status)).to eq :normal_finish
      expect(assigns(:accepted)).to be_truthy
      expect(assigns(:mail_address)).to eq request.mail_address
      expect(assigns(:accept_id)).to eq request.accept_id

      expect(response.status).to eq 302
      expect(response.location).to redirect_to root_path(r: request.id)

      # モデルチェック
      expect(request.user).to eq user
      expect(request.title).to eq title
      expect(request.type).to eq 'corporate_list_site'
      expect(request.corporate_list_site_start_url).to eq base_req.corporate_list_site_start_url
      expect(request.company_info_result_headers).to eq base_req.company_info_result_headers
      expect(request.status).to eq EasySettings.status.new
      expect(request.test).to be_falsey
      expect(request.plan).to eq user.my_plan_number
      expect(request.expiration_date).to eq base_req.expiration_date
      expect(request.mail_address).to eq base_req.mail_address
      expect(request.ip).to eq '0.0.0.0'
      expect(request.requested_urls.main.count).to eq 1
      expect(request.requested_urls.count).to eq 2
      expect(request.requested_urls.main[0].url).to eq start_url
      expect(request.requested_urls.main[0].status).to eq EasySettings.status.new
      expect(request.requested_urls.main[0].finish_status).to eq EasySettings.finish_status.new
      expect(request.requested_urls.main[0].test).to be_falsey

      # 増減チェック
      expect(Request.count).to eq request_count
      expect(RequestedUrl.count).to eq req_url_count + 1
      expect(RequestedUrl.main.count).to eq req_url_main_count + 1

      # メールのチェック
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(ActionMailer::Base.deliveries.first.to).to eq(notice_to_address)
      expect(ActionMailer::Base.deliveries.first.subject).to match(/リクエストを受け付けました。/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{title}/)

      # redisにsetされていることをチェック
      expect(Redis.new.get("#{request.id}_request")).to be_present
      Redis.new.del("#{request.id}_request")
    end

    def check_invalid_recreate(finish_status:, message:)
      request_count = Request.count
      req_url_count = RequestedUrl.count
      req_url_main_count = RequestedUrl.main.count

      subject

      expect(assigns(:finish_status)).to eq finish_status
      expect(assigns(:accepted)).to be_falsey

      if flash[:alert].present?
        expect(flash[:alert]).to eq message
      else
        expect(assigns(:notice_confirm)).to eq message
      end

      expect(response.status).to eq 400
      expect(response).to render_template :index

      # 増減チェック
      expect(Request.count).to eq request_count
      expect(RequestedUrl.count).to eq req_url_count
      expect(RequestedUrl.main.count).to eq req_url_main_count

      # モデルチェック
      expect(request.user).to eq user
      expect(request.title).to eq title
      expect(request.type).to eq type
      expect(request.corporate_list_site_start_url).to eq start_url
      expect(request.company_info_result_headers).to be_nil
      expect(request.status).to eq init_status
      expect(request.expiration_date).to be_nil
      expect(request.test).to eq test
      expect(request.plan).to eq user.my_plan_number
      expect(request.mail_address).to eq address
      expect(request.ip).not_to eq '0.0.0.0'
      expect(request.requested_urls.count).to eq 1
      expect(request.requested_urls[0].url).to eq start_url
      expect(request.requested_urls[0].test).to eq test

      # # メールのチェック
      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    before do
      base_req
      req_url
    end

    context '正常系' do
      it do
        check_normal_finish
      end
    end

    context '異常系' do

      context 'accept_idが間違っている' do
        let(:accept_id) { 'a' }

        it do
          check_invalid_recreate(finish_status: :invalid_accept_id, message: Message.const[:invalid_accept_id])
        end
      end

      context 'ユーザが間違っている' do
        let(:user) { create(:user) }

        it do
          check_invalid_recreate(finish_status: :wrong_user, message: Message.const[:invalid_accept_id])
        end
      end

      context 'typeが間違っている' do
        let(:type) { 'file' }
        before { base_req.update!(type: :file) }

        it do
          check_invalid_recreate(finish_status: :unacceptable_reexecute, message: Message.const[:unacceptable_reexecute])
        end
      end

      context 'typeが間違っている' do
        let(:test) { false }

        it do
          check_invalid_recreate(finish_status: :unacceptable_reexecute, message: Message.const[:unacceptable_reexecute])
        end
      end

      context '完了していない' do
        let(:init_status) { EasySettings.status.working }

        it do
          check_invalid_recreate(finish_status: :unacceptable_reexecute, message: Message.const[:unacceptable_reexecute])
        end
      end
    end

    describe 'アクセス制限' do
      describe 'IPアクセス制限' do
        let(:ip) { '0.0.0.0' }

        context 'IPアクセス制限数に達していない時' do
          before do
            cnt = User.get_public.requests.unfinished_by_ip(ip).count
            (EasySettings.public_access_limit.ip - 1 - cnt).times do |_|
              create(:request, user: User.get_public, ip: ip)
            end
          end

          it do
            check_normal_finish
          end
        end

        context 'IPアクセス制限数に達している時' do
          before do
            cnt = User.get_public.requests.unfinished_by_ip(ip).count
            (EasySettings.public_access_limit.ip - cnt).times do |_|
              create(:request, user: User.get_public, ip: ip)
            end
          end

          it do
            check_invalid_recreate(finish_status: :public_ip_access_request_limit, message: Message.const[:over_public_ip_limit])
            expect(assigns(:mail_address)).to eq request.mail_address
            expect(assigns(:accept_id)).to eq request.accept_id
          end
        end
      end

      describe '待機リクエスト制限' do
        context 'ログインユーザ' do
          let(:user) { create(:user) }
          let(:notice_to_address)  { [user.email, address] }
          before { sign_in user }

          context '待機リクエスト制限数に達していない時' do
            before do
              cnt = user.requests.unfinished.count
              (EasySettings.waiting_requests_limit[user.my_plan] - 1 - cnt).times do |_|
                create(:request, user: user)
              end
            end

            it do
              check_normal_finish
            end
          end

          context '待機リクエスト制限数に達している時' do
            before do
              cnt = user.requests.unfinished.count
              (EasySettings.waiting_requests_limit[user.my_plan] - cnt).times do |_|
                create(:request, user: user)
              end
            end

            it do
              check_invalid_recreate(finish_status: :waiting_requests_limit, message: Message.const[:over_waiting_requests_limit])
              expect(assigns(:mail_address)).to eq request.mail_address
              expect(assigns(:accept_id)).to eq request.accept_id
            end
          end
        end

        context 'パブリックユーザ' do
          context '待機リクエスト制限数に達していない時' do
            before do
              cnt = User.get_public.requests.unfinished.count
              (EasySettings.waiting_requests_limit.public - 1 - cnt).times do |_|
                create(:request, user: User.get_public)
              end
            end

            it do
              check_normal_finish
            end
          end

          context '待機リクエスト制限数に達している時' do
            before do
              cnt = User.get_public.requests.unfinished.count
              (EasySettings.waiting_requests_limit.public - cnt).times do |_|
                create(:request, user: User.get_public)
              end
            end

            it do
              check_invalid_recreate(finish_status: :public_waiting_requests_limit, message: Message.const[:over_public_waiting_limit])
              expect(assigns(:mail_address)).to eq request.mail_address
              expect(assigns(:accept_id)).to eq request.accept_id
            end
          end
        end

        describe 'ログインユーザ：月間リクエスト制限' do
          let(:user) { create(:user) }
          let(:notice_to_address) { [user.email, address] }
          let!(:history) { create(:monthly_history, user: user, plan: user.my_plan_number, request_count: monthly_count) }

          before do
            sign_in user
          end

          context '月間リクエスト制限数に達していない時' do
            let(:monthly_count) { EasySettings.monthly_request_limit[user.my_plan] - 1 }

            it do
              check_normal_finish
              expect(MonthlyHistory.find_around(user).reload.request_count).to eq monthly_count + 1
            end
          end

          context '月間リクエスト制限数に達している時' do
            let(:monthly_count) { EasySettings.monthly_request_limit[user.my_plan] }

            it do
              check_invalid_recreate(finish_status: :monthly_request_limit, message: Message.const[:over_monthly_limit])
              expect(assigns(:mail_address)).to eq request.mail_address
              expect(assigns(:accept_id)).to eq request.accept_id
              expect(MonthlyHistory.find_around(user).reload.request_count).to eq monthly_count + 1
            end
          end
        end
      end
    end
  end

  describe "GET reconfigure" do
    subject { get :reconfigure, params: params }

    let(:user)               { User.get_public }
    let(:title)              { "Test Title req con corp list #{SecureRandom.alphanumeric(10)}" }
    let(:start_url)          { 'http://aaaa.com'}
    let(:type)               { 'corporate_list_site' }
    let(:address)            { 'to@example.org' }
    let(:free_search)        { 0 }
    let(:test)               { true }
    let(:init_status)        { EasySettings.status.completed }
    let(:corporate_list_result) { {'a' => {}, 'b' => {}} }
    let(:corporate_list)     { {"1"=>{"url"=>"", "details_off"=>"1", "organization_name"=>"", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"1" } }
    let(:corporate_individual) { {"1"=>{"url"=>"", "details_off"=>"1", "organization_name"=>"", "contents"=>{"1"=>{"title"=>"", "text"=>""}}}, "config_off"=>"1"} }

    let(:base_req) { create(:request, :corporate_site_list,
                        user: user, title: title, corporate_list_site_start_url: start_url,
                        test: test, mail_address: address, status: init_status, expiration_date: nil,
                        corporate_list_config: corporate_list.to_json, corporate_individual_config: corporate_individual.to_json,
                        ) }
    let(:req_url) { create(:search_request_corporate_list, request: base_req, status: EasySettings.status.completed, test: test, url: start_url,
                                                           result_attrs: { corporate_list: corporate_list_result.to_json }) }

    let(:accept_id) { base_req.accept_id }
    let(:params) { { accept_id: accept_id } }


    let(:request) { Request.find_by_title(title) }

    before do
      create_list(:request, 3, :corporate_site_list, user: user)
    end

    def check_normal_finish
      subject

      expect(assigns(:result)).to eq true
      expect(assigns(:accept_id)).to eq accept_id
      expect(assigns(:title)).to eq title
      expect(assigns(:type)).to eq base_req.type
      expect(assigns(:status)).to eq base_req.get_status_string
      expect(assigns(:expiration_date)).to be_nil
      expect(assigns(:requested_date)).to eq base_req.requested_date
      expect(assigns(:total_count)).to eq base_req.requested_urls.main.count
      expect(assigns(:waiting_count)).to eq base_req.get_unfinished_urls.main.count
      expect(assigns(:completed_count)).to eq base_req.get_completed_urls.main.count
      expect(assigns(:error_count)).to eq base_req.get_error_urls.main.count

      expect(assigns(:corporate_list_site_start_url)).to eq start_url
      expect(assigns(:list_config)).to eq corporate_list
      expect(assigns(:indiv_config)).to eq corporate_individual

      expect(assigns(:req)).to eq base_req

      expect(response.status).to eq 200
      expect(response).to render_template :index
    end

    def check_invalid_finish(finish_status:, message:)
      subject

      expect(assigns(:finish_status)).to eq finish_status
      expect(assigns(:accepted)).to be_falsey
      expect(assigns(:result)).to eq false
      expect(assigns(:accept_id)).to eq accept_id.nil? ? '' : accept_id
      expect(assigns(:title)).to be_nil
      expect(assigns(:type)).to be_nil
      expect(assigns(:status)).to be_nil
      expect(assigns(:expiration_date)).to be_nil
      expect(assigns(:requested_date)).to be_nil

      if flash[:alert].present?
        expect(flash[:alert]).to eq message
      else
        expect(assigns(:notice_confirm)).to eq message
      end

      expect(response.status).to eq 400
      expect(response).to render_template :index
    end

    describe '正常終了' do
      context  'パブリックユーザ' do
        context  'テスト' do
          let(:test) { true }

          before { req_url }
          it do
            check_normal_finish
            expect(assigns(:test)).to eq true
            expect(assigns(:corporate_list_result)).to eq Json2.parse(base_req.test_req_url.corporate_list_result, symbolize: false)
            expect(assigns(:requests)).to be_nil
          end
        end

        context  '本送信' do
          let(:test) { false }

          before { req_url }
          it do
            check_normal_finish
            expect(assigns(:test)).to eq false
            expect(assigns(:corporate_list_result)).to be_nil
            expect(assigns(:requests)).to be_nil
          end
        end
      end

      context  'ログインユーザ' do
        let(:user) { create(:user) }
        before { sign_in user }

        context  'テスト' do
          let(:test) { true }

          before { req_url }
          it do
            check_normal_finish
            expect(assigns(:test)).to eq true
            expect(assigns(:corporate_list_result)).to eq corporate_list_result
            expect(assigns(:requests)).to be_present
          end
        end

        context  '本送信' do
          let(:test) { false }

          before { req_url }
          it do
            check_normal_finish
            expect(assigns(:test)).to eq false
            expect(assigns(:corporate_list_result)).to be_nil
            expect(assigns(:requests)).to be_present
          end
        end
      end
    end

    describe '異常終了' do
      describe '受付IDが不正' do
        context 'パブリックユーザ' do
          context '受付IDが間違っている' do
            let(:accept_id) { 'aa' }
            it do
              check_invalid_finish(finish_status: :invalid_accept_id, message: Message.const[:invalid_accept_id])
              expect(assigns(:requests)).to be_nil
            end
          end

          context '受付IDがnil' do
            let(:accept_id) { nil }
            it do
              check_invalid_finish(finish_status: :invalid_accept_id, message: Message.const[:invalid_accept_id])
              expect(assigns(:requests)).to be_nil
            end
          end
        end

        context 'ログインユーザ' do
          let(:user) { create(:user) }
          before { sign_in user }

          context '受付IDが間違っている' do
            let(:accept_id) { 'aa' }
            it do
              check_invalid_finish(finish_status: :invalid_accept_id, message: Message.const[:no_exist_request])
              expect(assigns(:requests)).to be_present
            end
          end

          context '受付IDがnil' do
            let(:accept_id) { nil }
            it do
              check_invalid_finish(finish_status: :invalid_accept_id, message: Message.const[:no_exist_request])
              expect(assigns(:requests)).to be_present
            end
          end
        end
      end

      describe 'ユーザが不正' do
        context 'パブリックユーザ' do
          context 'パブリックユーザのリクエストではない' do
            let(:user) { create(:user) }
            it do
              check_invalid_finish(finish_status: :wrong_user, message: Message.const[:invalid_accept_id])
              expect(assigns(:requests)).to be_nil
            end
          end
        end

        context 'ログインユーザ' do
          let(:user) { create(:user) }
          let(:user2) { create(:user) }
          before { sign_in user2 }

          context 'ログインユーザのリクエストではない' do
            it do
              check_invalid_finish(finish_status: :wrong_user, message: Message.const[:no_exist_request])
            end
          end
        end
      end

      describe '企業一覧サイトのリクエストではない' do
        let(:user) { create(:user) }
        before do
          sign_in user
          base_req
        end

        let(:base_req) { create(:request,
                          user: user, title: title,
                          mail_address: address, status: init_status, expiration_date: nil,
                      ) }

        context 'ログインユーザのリクエストではない' do
          it do
            check_invalid_finish(finish_status: :not_corporate_list, message: Message.const[:invalid_accept_id])
            expect(assigns(:requests)).to be_present
          end
        end
      end
    end
  end

  describe '#set_request_contents_to_params' do
    let(:subject) { RequestsController.new.send(:set_request_contents_to_params, req, params) }
    let(:params) { {} }

    context do
      let(:mail_address) { 'aaa@example.com' }
      let(:req) { create(:request, mail_address: mail_address) }
      it { expect(subject[:request][:mail_address]).to eq mail_address }
    end

    context do
      let(:use_storage) { true }
      let(:using_storage_days) { 7 }
      let(:req) { create(:request, use_storage: use_storage, using_storage_days: using_storage_days) }
      it do
        expect(subject[:request][:use_storage]).to eq '1'
        expect(subject[:request][:using_storage_days]).to eq 7
      end
    end

    context do
      let(:use_storage) { false }
      let(:using_storage_days) { nil }
      let(:req) { create(:request, use_storage: use_storage, using_storage_days: using_storage_days) }
      it do
        expect(subject[:request][:use_storage]).to eq '0'
        expect(subject[:request][:using_storage_days]).to eq nil
      end
    end

    context do
      let(:title) { 'aaa' }
      let(:corporate_list_site_start_url) { 'http://aaa.com/aaa/bb' }
      let(:req) { create(:request, title: title, corporate_list_site_start_url: corporate_list_site_start_url) }
      it do
        expect(subject[:request][:title]).to eq title
        expect(subject[:request][:corporate_list_site_start_url]).to eq corporate_list_site_start_url
      end
    end

    context do
      let(:corporate_list_config) { nil }
      let(:corporate_individual_config) { nil }
      let(:req) { create(:request, corporate_list_config: corporate_list_config, corporate_individual_config: corporate_individual_config) }
      it { expect(subject[:detail_off]).to eq '1' }
    end

    context do
      let(:corporate_list_config) do
        {"1"=>
          {"url"=>"http://sample1.co.jp",
           "organization_name"=>{"1"=>"1テスト1", "2"=>"1テスト2", "3"=>"1テスト3"},
           "contents"=>{"1"=>{"title"=>"1_1タイトル1", "text"=>{"1"=>"1_1テキスト1", "2"=>"1_2テキスト2"}}, "2"=>{"title"=>"1_2タイトル1", "text"=>{"1"=>"1_2テキスト1", "2"=>"1_2テキスト2", "3"=>"1_2テキスト3"}}}
          },
        "2"=>
          {"url"=>"http://sample2.com",
           "organization_name"=>{"1"=>"2テスト1", "2"=>"2テスト2", "3"=>"2テスト3", "4"=>"2テスト4"},
           "contents"=>{"1"=>{"title"=>"2_1タイトル1", "text"=>{"1"=>"2_1テキスト1", "2"=>"2_1テキスト2"}}}
          },
        "3"=>
          {"url"=>"http://sample3.com",
           "organization_name"=>{"1"=>"3テスト1", "2"=>"3テスト2"}
          },
        "4"=>
          {"url"=>"http://sample4.com",
           "contents"=>{"1"=>{"title"=>"4_1タイトル1", "text"=>{"1"=>"4_1テキスト1", "2"=>"4_1テキスト2"}}}
          },
        "5"=>
          {"url"=>"http://sample5.com"}
        }.to_json
      end

      let(:result) do
        {:config_off=>"0",
         "1"=>
          {:url=>"http://sample1.co.jp",
           :details_off=>"0",
           :organization_name=>{"1"=>"1テスト1", "2"=>"1テスト2", "3"=>"1テスト3"},
           :contents=>
            {"1"=>{:text=>{"1"=>"1_1テキスト1", "2"=>"1_2テキスト2", "3"=>nil}, :title=>"1_1タイトル1"},
             "2"=>{:text=>{"1"=>"1_2テキスト1", "2"=>"1_2テキスト2", "3"=>"1_2テキスト3"}, :title=>"1_2タイトル1"}}},
         "2"=>
          {:url=>"http://sample2.com",
           :details_off=>"0",
           :organization_name=>{"1"=>"2テスト1", "2"=>"2テスト2", "3"=>"2テスト3", "4"=>"2テスト4"},
           :contents=>{"1"=>{:text=>{"1"=>"2_1テキスト1", "2"=>"2_1テキスト2", "3"=>nil}, :title=>"2_1タイトル1"}}},
         "3"=>{:url=>"http://sample3.com", :details_off=>"0", :organization_name=>{"1"=>"3テスト1", "2"=>"3テスト2"}},
         "4"=>
          {:url=>"http://sample4.com",
           :details_off=>"0",
           :contents=>{"1"=>{:text=>{"1"=>"4_1テキスト1", "2"=>"4_1テキスト2", "3"=>nil}, :title=>"4_1タイトル1"}}},
         "5"=>{:url=>"http://sample5.com", :details_off=>"1"}
        }
      end
      let(:corporate_individual_config) { nil }
      let(:req) { create(:request, corporate_list_config: corporate_list_config, corporate_individual_config: corporate_individual_config) }
      it do
        expect(subject[:detail_off]).to eq '0'
        expect(subject[:request][:corporate_list]).to eq result
      end
    end

    context do
      let(:corporate_individual_config) do
        {"1"=>
          {"url"=>"http://sample1.co.jp",
           "organization_name"=>"1テスト",
           "contents"=>{"1"=>{"title"=>"1_1タイトル", "text"=>"1_1テキスト"}, "2"=>{"title"=>"1_2タイトル", "text"=>"1_2テキスト"}}
          },
        "2"=>
          {"url"=>"http://sample2.com",
           "organization_name"=>"2テスト",
           "contents"=>{"1"=>{"title"=>"2_1タイトル", "text"=>"2_1テキスト"}}
          },
        "3"=>
          {"url"=>"http://sample3.com",
           "organization_name"=>"3テスト1"
          },
        "4"=>
          {"url"=>"http://sample4.com",
           "contents"=>{"1"=>{"title"=>"4_1タイトル", "text"=>"4_1テキスト"}}
          },
        "5"=>
          {"url"=>"http://sample5.com"}
        }.to_json
      end

      let(:result) do
        {:config_off=>"0",
          "1"=>
           {:url=>"http://sample1.co.jp",
            :details_off=>"0",
            :organization_name=>"1テスト",
            :contents=>{"1"=>{:title=>"1_1タイトル", :text=>"1_1テキスト"}, "2"=>{:title=>"1_2タイトル", :text=>"1_2テキスト"}}},
          "2"=>
           {:url=>"http://sample2.com", :details_off=>"0", :organization_name=>"2テスト", :contents=>{"1"=>{:title=>"2_1タイトル", :text=>"2_1テキスト"}}},
          "3"=>{:url=>"http://sample3.com", :details_off=>"0", :organization_name=>"3テスト1"},
          "4"=>{:url=>"http://sample4.com", :details_off=>"0", :contents=>{"1"=>{:title=>"4_1タイトル", :text=>"4_1テキスト"}}},
          "5"=>{:url=>"http://sample5.com", :details_off=>"1"}
        }
      end

      let(:corporate_list_config) { nil }
      let(:req) { create(:request, corporate_list_config: corporate_list_config, corporate_individual_config: corporate_individual_config) }
      it do
        expect(subject[:detail_off]).to eq '0'
        expect(subject[:request][:corporate_individual]).to eq result
      end
    end
  end

  describe '#make_corporate_list_config_to_params' do

    let(:cntl) { RequestsController.new }

    context 'コンフィグがあるとき' do
      let(:config) do
        {"1"=>
          {"url"=>"http://sample1.co.jp",
           "organization_name"=>{"1"=>"1テスト1", "2"=>"1テスト2", "3"=>"1テスト3"},
           "contents"=>{"1"=>{"title"=>"1_1タイトル1", "text"=>{"1"=>"1_1テキスト1", "2"=>"1_2テキスト2"}}, "2"=>{"title"=>"1_2タイトル1", "text"=>{"1"=>"1_2テキスト1", "2"=>"1_2テキスト2", "3"=>"1_2テキスト3"}}}
          },
        "2"=>
          {"url"=>"http://sample2.com",
           "organization_name"=>{"1"=>"2テスト1", "2"=>"2テスト2", "3"=>"2テスト3", "4"=>"2テスト4"},
           "contents"=>{"1"=>{"title"=>"2_1タイトル1", "text"=>{"1"=>"2_1テキスト1", "2"=>"2_1テキスト2"}}}
          },
        "3"=>
          {"url"=>"http://sample3.com",
           "organization_name"=>{"1"=>"3テスト1", "2"=>"3テスト2"}
          },
        "4"=>
          {"url"=>"http://sample4.com",
           "contents"=>{"1"=>{"title"=>"4_1タイトル1", "text"=>{"1"=>"4_1テキスト1", "2"=>"4_1テキスト2"}}}
          },
        "5"=>
          {"url"=>"http://sample5.com"}
        }
      end

      let(:result) do
        {:config_off=>"0",
         "1"=>
          {:url=>"http://sample1.co.jp",
           :details_off=>"0",
           :organization_name=>{"1"=>"1テスト1", "2"=>"1テスト2", "3"=>"1テスト3"},
           :contents=>
            {"1"=>{:text=>{"1"=>"1_1テキスト1", "2"=>"1_2テキスト2", "3"=>nil}, :title=>"1_1タイトル1"},
             "2"=>{:text=>{"1"=>"1_2テキスト1", "2"=>"1_2テキスト2", "3"=>"1_2テキスト3"}, :title=>"1_2タイトル1"}}},
         "2"=>
          {:url=>"http://sample2.com",
           :details_off=>"0",
           :organization_name=>{"1"=>"2テスト1", "2"=>"2テスト2", "3"=>"2テスト3", "4"=>"2テスト4"},
           :contents=>{"1"=>{:text=>{"1"=>"2_1テキスト1", "2"=>"2_1テキスト2", "3"=>nil}, :title=>"2_1タイトル1"}}},
         "3"=>{:url=>"http://sample3.com", :details_off=>"0", :organization_name=>{"1"=>"3テスト1", "2"=>"3テスト2"}},
         "4"=>
          {:url=>"http://sample4.com",
           :details_off=>"0",
           :contents=>{"1"=>{:text=>{"1"=>"4_1テキスト1", "2"=>"4_1テキスト2", "3"=>nil}, :title=>"4_1タイトル1"}}},
         "5"=>{:url=>"http://sample5.com", :details_off=>"1"}
        }
      end

      it do
        expect(cntl.send(:make_corporate_list_config_to_params, config)).to eq result
      end
    end

    context 'コンフィグがnil' do
      let(:config) { nil }
      it do
        expect(cntl.send(:make_corporate_list_config_to_params, config)).to eq({:config_off=>"1"})
      end
    end
  end

  describe '#make_corporate_individual_config_to_params' do

    let(:cntl) { RequestsController.new }

    context 'コンフィグがあるとき' do
      let(:config) do
        {"1"=>
          {"url"=>"http://sample1.co.jp",
           "organization_name"=>"1テスト",
           "contents"=>{"1"=>{"title"=>"1_1タイトル", "text"=>"1_1テキスト"}, "2"=>{"title"=>"1_2タイトル", "text"=>"1_2テキスト"}}
          },
        "2"=>
          {"url"=>"http://sample2.com",
           "organization_name"=>"2テスト",
           "contents"=>{"1"=>{"title"=>"2_1タイトル", "text"=>"2_1テキスト"}}
          },
        "3"=>
          {"url"=>"http://sample3.com",
           "organization_name"=>"3テスト1"
          },
        "4"=>
          {"url"=>"http://sample4.com",
           "contents"=>{"1"=>{"title"=>"4_1タイトル", "text"=>"4_1テキスト"}}
          },
        "5"=>
          {"url"=>"http://sample5.com"}
        }
      end

      let(:result) do
        {:config_off=>"0",
          "1"=>
           {:url=>"http://sample1.co.jp",
            :details_off=>"0",
            :organization_name=>"1テスト",
            :contents=>{"1"=>{:title=>"1_1タイトル", :text=>"1_1テキスト"}, "2"=>{:title=>"1_2タイトル", :text=>"1_2テキスト"}}},
          "2"=>
           {:url=>"http://sample2.com", :details_off=>"0", :organization_name=>"2テスト", :contents=>{"1"=>{:title=>"2_1タイトル", :text=>"2_1テキスト"}}},
          "3"=>{:url=>"http://sample3.com", :details_off=>"0", :organization_name=>"3テスト1"},
          "4"=>{:url=>"http://sample4.com", :details_off=>"0", :contents=>{"1"=>{:title=>"4_1タイトル", :text=>"4_1テキスト"}}},
          "5"=>{:url=>"http://sample5.com", :details_off=>"1"}
        }
      end

      it do
        expect(cntl.send(:make_corporate_individual_config_to_params, config)).to eq result
      end
    end

    context 'コンフィグがnil' do
      let(:config) { nil }
      it do
        expect(cntl.send(:make_corporate_individual_config_to_params, config)).to eq({:config_off=>"1"})
      end
    end
  end
end

require 'rails_helper'

RSpec.describe RequestsController, type: :controller do
  let_it_be(:master_standard_plan) { create(:master_billing_plan, :standard) }

  let_it_be(:pu) { create(:user_public) }

  describe "PUT stop" do
    subject { put :stop, params: params }

    let(:user)              { create(:user) }
    let(:unlogin_user)      { create(:user) }
    let(:correct_accept_id) { 'abcdef' }
    let(:wrong_accept_id)   { 'abcdefghijk' }
    let(:accept_id)         { correct_accept_id }
    let(:mode)              { :multiple }
    let(:params)            { { accept_id: accept_id, mode: mode } }
    let!(:r0)               { create(:request, accept_id: correct_accept_id, status: status, user: user) }
    let!(:r1)               { create(:request, user: user) }
    let!(:r2)               { create(:request, user: user) }
    let!(:r3)               { create(:request, :corporate_site_list, status: status, user: user) }
    let!(:r4)               { create(:request, :corporate_site_list, status: status, user: user) }
    let(:request)           { Request.find_by_accept_id(correct_accept_id) }

    before do
      create(:request, user: unlogin_user)
      create(:request, :corporate_site_list, user: unlogin_user)
      create(:request, user: User.get_public)
      create(:request, :corporate_site_list, user: User.get_public)
    end

    context 'ログインユーザ、受付IDが間違っている場合' do
      let(:status)    { EasySettings.status.new }
      let(:accept_id) { wrong_accept_id }

      it '停止できず、IDが間違っているレスポンスが返ること' do
        sign_in user

        subject

        expect(response.status).to eq 400
        expect(response).to render_template :index_multiple

        # インスタンス変数のチェック
        expect(assigns(:accept_id)).to eq wrong_accept_id
        expect(assigns(:result)).to be_falsey
        expect(assigns(:finish_status)).to eq :invalid_accept_id
        expect(assigns(:requests)).to eq [r2, r1, r0]

        expect(request.status).to eq EasySettings.status.new
      end
    end

    context 'ログインユーザ、受付IDがcorporate_siteの方の場合' do
      let(:status)    { EasySettings.status.new }
      let(:accept_id) { r3.accept_id }
      let(:request)   { Request.find_by_accept_id(accept_id) }

      it '停止でき、コーポレートサイトの方に遷移すること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to redirect_to root_path

        # インスタンス変数のチェック
        expect(assigns(:accept_id)).to eq accept_id
        expect(assigns(:result)).to be_truthy
        expect(assigns(:finish_status)).to be_nil
        expect(assigns(:requests)).to eq [r4, r3]

        expect(request.status).to eq EasySettings.status.discontinued
      end
    end

    context 'リクエストがすでに完了している場合' do

      context 'ログインユーザ、ステータスが完了の場合' do
        let(:status) { EasySettings.status.completed }

        it '正しい結果が返ってくること' do
          sign_in user

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_falsey
          expect(assigns(:finish_status)).to eq :can_not_stop
          expect(assigns(:requests)).to eq [r2, r1, r0]

          expect(request.status).to eq EasySettings.status.completed
        end
      end

      context '非ログインユーザ、ステータスがエラーの場合' do
        let(:status) { EasySettings.status.error }
        let(:user)   { User.get_public }

        it '正しい結果が返ってくること' do

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_falsey
          expect(assigns(:finish_status)).to eq :can_not_stop
          expect(assigns(:requests)).to be_nil

          expect(request.status).to eq EasySettings.status.error
        end
      end

      context 'ログインユーザ、ステータスが中止の場合' do
        let(:status) { EasySettings.status.discontinued }

        it '正しい結果が返ってくること' do
          sign_in user

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_falsey
          expect(assigns(:finish_status)).to eq :can_not_stop
          expect(assigns(:requests)).to eq [r2, r1, r0]

          expect(request.status).to eq EasySettings.status.discontinued
        end
      end
    end

    context 'リクエストを正常に中止できる場合' do

      context 'ログインユーザ、ステータスが新規の場合' do
        let(:status) { EasySettings.status.new }

        it '正しい結果が返ってくること' do
          sign_in user

          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to request_multiple_path

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_truthy
          expect(assigns(:finish_status)).to be_nil
          expect(assigns(:requests)).to eq [r2, r1, r0]

          expect(request.status).to eq EasySettings.status.discontinued
        end
      end

      context '非ログインユーザ、ステータスが着手中の場合' do
        let(:status) { EasySettings.status.working }
        let(:user)   { User.get_public }

        it '正しい結果が返ってくること' do

          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to request_multiple_path

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_truthy
          expect(assigns(:finish_status)).to be_nil
          expect(assigns(:requests)).to be_nil

          expect(request.status).to eq EasySettings.status.discontinued
        end
      end

      context 'ログインユーザ、ステータスが全件着手中の場合' do
        let(:status) { EasySettings.status.all_working }

        it '正しい結果が返ってくること' do
          sign_in user

          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to request_multiple_path

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_truthy
          expect(assigns(:finish_status)).to be_nil
          expect(assigns(:requests)).to eq [r2, r1, r0]

          expect(request.status).to eq EasySettings.status.discontinued
        end
      end
    end
  end

  # 非ログインユーザで確認 (ログインユーザでも動きは同じ)
  describe "GET confirm" do
    subject { put :confirm, params: params }

    let(:user)              { create(:user) }
    let(:unlogin_user)      { create(:user) }
    let(:correct_accept_id) { 'abcdef' }
    let(:wrong_accept_id)   { 'abcdefghijk' }
    let(:accept_id)         { correct_accept_id }
    let(:title)             { 'テスト案件' }
    let(:mode)              { :multiple }
    let(:params)            { { accept_id: accept_id, mode: mode } }
    let!(:r1)               { create(:request, user: user) }
    let!(:r2)               { create(:request, user: user) }

    before do
      create(:request, user: unlogin_user)
      create(:request, :corporate_site_list, user: unlogin_user)
      create(:request, user: User.get_public)
      create(:request, :corporate_site_list, user: User.get_public)
      create(:request, :corporate_site_list, user: user)
    end

    context '受付IDが間違っている場合' do
      let(:accept_id) { wrong_accept_id }

      before { create(:request, accept_id: correct_accept_id, user: User.get_public) }

      it '正しい結果が返ってくること' do
        subject

        expect(response.status).to eq 400
        expect(response).to render_template :index_multiple

        # インスタンス変数のチェック
        expect(assigns(:accept_id)).to eq wrong_accept_id
        expect(assigns(:result)).to be_falsey
        expect(assigns(:status)).to be_nil
        expect(assigns(:expiration_date)).to be_nil
        expect(assigns(:file_name)).to be_nil
        expect(assigns(:requested_date)).to be_nil
        expect(assigns(:total_count)).to be_nil
        expect(assigns(:waiting_count)).to be_nil
        expect(assigns(:completed_count)).to be_nil
        expect(assigns(:error_count)).to be_nil
        expect(assigns(:finish_status)).to eq :invalid_accept_id
        expect(assigns(:requests)).to be_nil

        expect(Request.find_by_accept_id(correct_accept_id)).to_not be_nil
        expect(Request.find_by_accept_id(wrong_accept_id)).to be_nil
      end
    end

    context '受付IDがcorporate_siteの方の場合' do
      let(:status)    { EasySettings.status.completed }
      let(:expiration_date) { Time.zone.today + 5.days }
      let(:request)   { create(:request, :corporate_site_list, title: title, file_name: nil,
                                accept_id: accept_id, status: status, expiration_date: expiration_date, user: User.get_public) }

      before do
        create(:requested_url, :corporate_list, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.successful)
        create(:requested_url, :corporate_list, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.using_storaged_date)
        create(:requested_url, :corporate_list, request_id: request.id, status: EasySettings.status.error, finish_status: EasySettings.finish_status.error)
      end

      it '正しい結果が返ってくること' do
        subject

        expect(response.status).to eq 200
        expect(response).to render_template :index

        # インスタンス変数のチェック
        expect(assigns(:accept_id)).to eq accept_id
        expect(assigns(:result)).to be_truthy
        expect(assigns(:status)).to eq '完了'
        expect(assigns(:expiration_date)).to eq expiration_date.strftime("%Y年%m月%d日")
        expect(assigns(:file_name)).to be_nil
        expect(assigns(:requested_date)).to eq request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
        # 以下のカウントは暫定のもの、仕様が固まり次第、変更する
        expect(assigns(:total_count)).to eq 3
        expect(assigns(:waiting_count)).to eq 0
        expect(assigns(:completed_count)).to eq 2
        expect(assigns(:error_count)).to eq 1
        expect(assigns(:requests)).to be_nil

        expect(Request.find_by_accept_id(accept_id)).to_not be_nil
      end
    end

    context '受付IDが正しい場合' do
      let(:file_name) { 'file_name' }
      let(:request)   { create(:request, accept_id: accept_id, title: title, file_name: file_name,
                                         status: status, expiration_date: expiration_date, user: User.get_public) }

      context 'ステータスが完了の場合' do
        let(:status)          { EasySettings.status.completed }
        let(:expiration_date) { Time.zone.today + 5.days }

        before do
          create(:requested_url, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.successful)
          create(:requested_url, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.using_storaged_date)
          create(:requested_url, request_id: request.id, status: EasySettings.status.error, finish_status: EasySettings.finish_status.error)
        end

        it '正しい結果が返ってくること' do
          subject

          expect(response.status).to eq 200
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_truthy
          expect(assigns(:status)).to eq '完了'
          expect(assigns(:expiration_date)).to eq expiration_date.strftime("%Y年%m月%d日")
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:requested_date)).to eq request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(assigns(:total_count)).to eq 3
          expect(assigns(:waiting_count)).to eq 0
          expect(assigns(:completed_count)).to eq 2
          expect(assigns(:error_count)).to eq 1
          expect(assigns(:requests)).to be_nil

          expect(Request.find_by_accept_id(accept_id)).to_not be_nil
        end
      end

      context 'ステータスが着手中の場合' do
        let(:status)          { EasySettings.status.working }
        let(:expiration_date) { nil }

        before do
          create(:requested_url, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.successful)
          create(:requested_url, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.using_storaged_date)
          create(:requested_url, request_id: request.id, status: EasySettings.status.error, finish_status: EasySettings.finish_status.error)
          create(:requested_url, request_id: request.id, status: EasySettings.status.error, finish_status: EasySettings.finish_status.error)
          create(:requested_url, request_id: request.id, status: EasySettings.status.new, finish_status: EasySettings.finish_status.new)
          create(:requested_url, request_id: request.id, status: EasySettings.status.waiting, finish_status: EasySettings.finish_status.new)
          create(:requested_url, request_id: request.id, status: EasySettings.status.waiting, finish_status: EasySettings.finish_status.new)
          create(:requested_url, request_id: request.id, status: EasySettings.status.working, finish_status: EasySettings.finish_status.new)
        end

        it '正しい結果が返ってくること' do
          subject

          expect(response.status).to eq 200
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_truthy
          expect(assigns(:status)).to eq '未完了'
          expect(assigns(:expiration_date)).to be_nil
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:requested_date)).to eq request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(assigns(:total_count)).to eq 8
          expect(assigns(:waiting_count)).to eq 4
          expect(assigns(:completed_count)).to eq 2
          expect(assigns(:error_count)).to eq 2
          expect(assigns(:requests)).to be_nil
        end
      end

      context 'ステータスが全件着手中の場合' do
        let(:status)          { EasySettings.status.all_working }
        let(:expiration_date) { nil }

        before do
          create(:requested_url, request_id: request.id, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.successful)
          create(:requested_url, request_id: request.id, status: EasySettings.status.error, finish_status: EasySettings.finish_status.error)
          create(:requested_url, request_id: request.id, status: EasySettings.status.working, finish_status: EasySettings.finish_status.new)
          create(:requested_url, request_id: request.id, status: EasySettings.status.working, finish_status: EasySettings.finish_status.new)
        end

        it '正しい結果が返ってくること' do
          subject

          expect(response.status).to eq 200
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:accept_id)).to eq accept_id
          expect(assigns(:result)).to be_truthy
          expect(assigns(:status)).to eq '未完了'
          expect(assigns(:expiration_date)).to be_nil
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:requested_date)).to eq request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(assigns(:total_count)).to eq 4
          expect(assigns(:waiting_count)).to eq 2
          expect(assigns(:completed_count)).to eq 1
          expect(assigns(:error_count)).to eq 1
          expect(assigns(:requests)).to be_nil
        end
      end
    end
  end

  describe "GET download" do
    subject { get :download, params: params }

    let(:user)              { create(:user, billing: :credit) }
    let!(:plan)             { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
    let(:unpaid_user)       { create(:user) }
    let(:correct_accept_id) { 'abcdef' }
    let(:wrong_accept_id)   { 'abcdefghijk' }
    let(:accept_id)         { correct_accept_id }
    let(:mode)              { :multiple }
    let(:params)            { { accept_id: accept_id, mode: mode } }
    let(:expiration_date)   { Time.zone.today }
    let(:request_user)      { User.get_public }
    let(:title)             { 'テスト案件' }
    let(:file_name)         { nil }
    let(:status)            { EasySettings.status[:new] }
    let(:result_file_path)  { nil }
    let(:request)           { create(:request, status: status, accept_id: correct_accept_id, title: title, file_name: file_name,
                                               expiration_date: expiration_date, user: request_user, result_file_path: result_file_path ) }
    let!(:company_info)     { create(:company_info_requested_url_finished, request: request) }

    after do
      S3Handler.new.delete(s3_path: request.reload.result_file_path) if request.reload.result_file_path.present?
    end

    context '受付IDが間違っている場合' do
      let(:accept_id) { wrong_accept_id }

      it '正しい結果が返ってくること' do
        subject

        expect(response.status).to eq 302
        expect(response).to redirect_to(confirm_path(accept_id: wrong_accept_id, mode: mode))

        expect(flash[:alert]).to eq Message.const[:invalid_accept_id]
      end
    end

    context 'リクエストが有効期限切れの場合' do
      let(:status) { EasySettings.status[:completed] }
      before { request.update!(updated_at: Time.zone.now - 1.month - 1.day) }

      it '正しい結果が返ってくること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

        expect(flash[:alert]).to eq Message.const[:no_exist_request]

        expect(assigns(:finish_status)).to eq :expired_request
      end
    end

    context 'ユーザが間違っている場合' do
      let(:request_user) { user }

      context '非ログインユーザ' do

        it '正しい結果が返ってくること' do
          subject

          expect(response.status).to eq 302
          expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

          expect(flash[:alert]).to eq Message.const[:invalid_accept_id]
        end
      end

      context 'ログインユーザ' do
        let(:request_user) { unpaid_user }

        it '正しい結果が返ってくること' do
          sign_in user

          subject

          expect(response.status).to eq 302
          expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

          expect(flash[:alert]).to eq Message.const[:no_exist_request]

          expect(assigns(:finish_status)).to eq :wrong_user
        end
      end
    end

    context '有効期限切れの場合' do
      let(:expiration_date) { Time.zone.today - 1.days }

      it '正しい結果が返ってくること' do
        subject

        expect(response.status).to eq 302
        expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

        expect(flash[:alert]).to eq Message.const[:expired_download]
      end
    end

    context 'エクセルの作成に失敗した場合' do
      before do
        allow_any_instance_of(ResultFile).to receive(:make_file).and_return(false)
      end

      it '正しい結果が返ってくること' do
        expect { subject }.to change(ResultFile, :count).by(1)

        expect(response.status).to eq 302
        expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

        expect(flash[:alert]).to eq Message.const[:download_failure]
      end
    end

    context 'エクセルの作成に一部だけ失敗した場合' do
      let(:file_name) { 'result_dummy.zip' }
      let(:file_path) { Rails.root.join('spec', 'fixtures', file_name).to_s }
      let(:tmp_id)    { SecureRandom.uuid }
      let(:s3_path)   { "#{Rails.application.credentials.s3_bucket[:results]}/#{tmp_id}/#{file_name}" }

      before do
        allow_any_instance_of(ResultFile).to receive(:make_file) do |rf|
          rf.update!(path: s3_path, fail_files: fail_files.to_json)
        end
        S3Handler.new.upload(s3_path: s3_path, file_path: file_path)
      end

      after do
        S3Handler.new.delete(s3_path: s3_path)
      end

      context '一つだけ失敗' do
        let(:fail_files)  { ['結果2'] }

        it '正しい結果が返ってくること' do
          expect { subject }.to change(ResultFile, :count).by(1)

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{file_name}\"; filename\*=UTF-8''#{file_name}/
          expect(response.headers['Content-Type']).to eq('application/zip')

          expect(flash[:alert]).to eq "結果2のファイル作成に失敗しました。"
        end
      end

      context '複数失敗' do
        let(:fail_files)  { ['結果2','結果3'] }

        it '正しい結果が返ってくること' do
          expect { subject }.to change(ResultFile, :count).by(1)


          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{file_name}\"; filename\*=UTF-8''#{file_name}/
          expect(response.headers['Content-Type']).to eq('application/zip')

          expect(flash[:alert]).to eq "結果2, 結果3のファイル作成に失敗しました。"
        end
      end
    end

    context 'すでに結果ファイルができ上がっている場合' do
      let(:tmp_id) { SecureRandom.uuid }
      let(:result_file_path)  { "#{Rails.application.credentials.s3_bucket[:results]}/#{tmp_id}/#{file_name}" }

      before do
        S3Handler.new.upload(s3_path: result_file_path, file_path: file_path)
      end

      after do
        S3Handler.new.delete(s3_path: result_file_path)
      end

      context 'ZIP' do
        let(:file_name) { 'result_dummy.zip' }
        let(:file_path)  { Rails.root.join('spec', 'fixtures', file_name) }

        it '正しい結果が返ってくること' do
          expect { subject }.to change(ResultFile, :count).by(0)

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{file_name}\"; filename\*=UTF-8''#{file_name}/
          expect(response.headers['Content-Type']).to eq('application/zip')
        end
      end

      context 'エクセル' do
        let(:file_name) { 'result_download.xlsx' }
        let(:file_path)  { Rails.root.join('spec', 'fixtures', file_name) }

        it '正しい結果が返ってくること' do
          expect { subject }.to change(ResultFile, :count).by(0)

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{file_name}\"; filename\*=UTF-8''#{file_name}/
          expect(response.headers['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        end
      end
    end

    context '正常にエクセルファイルをダウンロードできる場合' do
      let(:request_user)    { user }
      let!(:history)        { create(:monthly_history, user: request_user, plan: EasySettings.plan[:standard]) }
      let(:title)           { 'rspec_test_excel_file' }
      let(:download_file_name_rex) { "1_.+?_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx" }
      let(:status_str)      { req.get_status_string }
      let(:ar_coca_cola)    { AccessRecord.create(:hokkaido_coca_cola) }
      let(:ar_nexway)       { AccessRecord.create(:nexway) }
      let(:ar_starbacks)    { AccessRecord.create(:starbacks) }
      let(:status)          { EasySettings.status[:completed] }

      before do
        AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'example.com', 'www.nexway.co.jp', 'www.starbucks.co.jp'])

        ru = create(:requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain)
        ru.fetch_access_record(force_fetch: true)
        ru = create(:requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain)
        ru.fetch_access_record(force_fetch: true)
        ru = create(:requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain)
        ru.fetch_access_record(force_fetch: true)

        Timecop.freeze(current_time)
      end

      after do
        Timecop.return
        S3Handler.new.delete(s3_path: request.reload.result_files.last.path)
      end

      context 'プランユーザの場合' do
        it do
          sign_in user

          expect { subject }.to change(ResultFile, :count).by(1)

          expect(request.reload.result_files.last.path).to be_present
          expect(request.reload.result_files.last.status).to eq 'completed'
          expect(request.reload.result_files.last.phase).to eq 'phase4'

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{download_file_name_rex}\"; filename\*=UTF-8''#{download_file_name_rex}/
          expect(response.headers['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

          #ファイルが作られていること
          expect(S3Handler.new.exist_object?(s3_path: request.result_files.last.path)).to eq true
        end
      end

      context 'パブリックユーザの場合' do
        let(:request_user) { User.get_public }

        it do
          expect { subject }.to change(ResultFile, :count).by(1)

          expect(request.reload.result_files.last.path).to be_present
          expect(request.reload.result_files.last.status).to eq 'completed'
          expect(request.reload.result_files.last.phase).to eq 'phase4'

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{download_file_name_rex}\"; filename\*=UTF-8''#{download_file_name_rex}/
          expect(response.headers['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

          #ファイルが作られていること
          expect(S3Handler.new.exist_object?(s3_path: request.reload.result_files.last.path)).to eq true
        end
      end

      context '無課金ユーザの場合' do
        let(:request_user) { unpaid_user }

        it '数値を隠さずにデータをダウンロードできること' do
          sign_in unpaid_user

          expect { subject }.to change(ResultFile, :count).by(1)

          expect(request.reload.result_files.last.path).to be_present
          expect(request.reload.result_files.last.status).to eq 'completed'
          expect(request.reload.result_files.last.phase).to eq 'phase4'

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{download_file_name_rex}\"; filename\*=UTF-8''#{download_file_name_rex}/
          expect(response.headers['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

          #ファイルが作られていること
          expect(S3Handler.new.exist_object?(s3_path: request.reload.result_files.last.path)).to eq true
        end
      end

      context 'Adminユーザの場合' do
        let(:admin_user) { create(:admin_user) }

        it do
          sign_in admin_user

          expect { subject }.to change(ResultFile, :count).by(1)

          expect(request.reload.result_files.last.path).to be_present
          expect(request.reload.result_files.last.status).to eq 'completed'
          expect(request.reload.result_files.last.phase).to eq 'phase4'

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq 200
          expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{download_file_name_rex}\"; filename\*=UTF-8''#{download_file_name_rex}/
          expect(response.headers['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

          #ファイルが作られていること
          expect(S3Handler.new.exist_object?(s3_path: request.reload.result_files.last.path)).to eq true
        end
      end
    end
  end
end

require 'rails_helper'

RSpec.describe RequestsController, type: :controller do
  before { create_public_user }

  describe "POST make_result_file" do
    subject { post :make_result_file, params: params }

    let(:user)              { create(:user) }
    let(:user2)             { create(:user) }
    let(:correct_accept_id) { 'abcdef' }
    let(:wrong_accept_id)   { 'abcdefghijk' }
    let(:accept_id)         { correct_accept_id }
    let(:mode)              { :multiple }
    let(:file_type)         { 'xlsx' }
    let(:params)            { { accept_id: accept_id, mode: mode, file_type: file_type } }
    let(:request)           { create(:request, accept_id: correct_accept_id, status: status, user: user) }
    let(:status)            { EasySettings.status.new }

    before do
      request
      allow_any_instance_of(BatchAccessor).to receive(:request_result_file).and_return(StabMaker.new({code: 200}))
    end

    context '非ログインユーザ' do
      it { expect{subject}.to change(ResultFile, :count).by(0) }

      it do
        subject

        expect(response.status).to eq 302
        expect(response).to redirect_to(root_path)

        expect(flash[:alert]).to be_nil

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context 'ログインユーザ' do
      before { sign_in user }

      context '異常系' do
        context '受付IDが間違っている場合' do
          let(:accept_id) { wrong_accept_id }

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: wrong_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:invalid_accept_id]

            expect(assigns(:finish_status)).to eq :invalid_accept_id
          end
        end

        context 'ファイル種別が間違っている場合' do
          let(:file_type) { 'aaa' }

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:invalid_result_file_type]

            expect(assigns(:finish_status)).to eq :invalid_result_file_type
          end
        end

        context '有効期限切れのリクエストを指定した場合' do
          let(:status) { EasySettings.status.completed }
          before { request.update!(updated_at: Time.zone.now - 1.month - 1.day) }

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:invalid_accept_id]

            expect(assigns(:finish_status)).to eq :expired_request
          end
        end

        context '違うユーザのリクエストを指定した場合' do
          let(:accept_id) { correct_accept_id }

          before { sign_in user2 }

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:invalid_accept_id]

            expect(assigns(:finish_status)).to eq :wrong_user
          end
        end

        context 'ダウンロード有効期限切れのリクエストを指定した場合' do
          let(:status) { EasySettings.status.completed }
          before { request.update!(expiration_date: Time.zone.now - 1.day) }

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:expired_download]

            expect(assigns(:finish_status)).to eq :expired_download
          end
        end

        context '結果作成リクエストの上限に達した場合' do
          let(:status) { EasySettings.status.completed }

          before do
            FactoryBot.create_list(:result_file, 5, request: request)
          end

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:result_file_making_limit]

            expect(assigns(:finish_status)).to eq :result_file_making_limit
          end
        end

        context 'バッチサーバへのレスポンスが500の時' do
          let(:status) { EasySettings.status.completed }

          before do
            allow_any_instance_of(BatchAccessor).to receive(:request_result_file).and_return(StabMaker.new({code: 500, body: 'error'}))
          end

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

            expect(assigns(:finish_status)).to eq :error_occurred
          end
        end

        context 'バッチサーバへのレスポンスが400の時' do
          let(:status) { EasySettings.status.completed }

          before do
            allow_any_instance_of(BatchAccessor).to receive(:request_result_file).and_return(StabMaker.new({code: 400, body: 'error'}))
          end

          it { expect{subject}.to change(ResultFile, :count).by(0) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

            expect(assigns(:finish_status)).to eq :error_occurred
          end
        end
      end

      context '正常系' do
        context 'ファイル種別がエクセルの場合' do
          let(:status)    { EasySettings.status.completed }
          let(:file_type) { 'xlsx' }

          it { expect{subject}.to change(ResultFile, :count).by(1) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:notice]).to eq Message.const[:accept_result_file]

            expect(assigns(:finish_status)).to eq :normal_finish

            result_file = request.result_files.last
            expect(result_file.path).to be_nil
            expect(result_file.status).to eq 'accepted'
            expect(result_file.file_type).to eq 'xlsx'
            expect(result_file.deletable).to be_falsey
            expect(result_file.expiration_date).to be_nil
            expect(result_file.fail_files).to be_nil
          end
        end

        context 'ファイル種別がCSVの場合' do
          let(:status)    { EasySettings.status.completed }
          let(:file_type) { 'csv' }

          it { expect{subject}.to change(ResultFile, :count).by(1) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:notice]).to eq Message.const[:accept_result_file]

            expect(assigns(:finish_status)).to eq :normal_finish

            result_file = request.result_files.last
            expect(result_file.path).to be_nil
            expect(result_file.status).to eq 'accepted'
            expect(result_file.file_type).to eq 'csv'
            expect(result_file.deletable).to be_falsey
            expect(result_file.expiration_date).to be_nil
            expect(result_file.fail_files).to be_nil
          end
        end

        context '削除されるファイルがない時' do
          let(:status) { EasySettings.status.completed }

          it { expect{subject}.to change(ResultFile, :count).by(1) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:notice]).to eq Message.const[:accept_result_file]

            expect(assigns(:finish_status)).to eq :normal_finish

            result_file = request.result_files.last
            expect(result_file.path).to be_nil
            expect(result_file.status).to eq 'accepted'
            expect(result_file.deletable).to be_falsey
            expect(result_file.expiration_date).to be_nil
            expect(result_file.fail_files).to be_nil
          end
        end

        context '削除されるファイルがある時' do
          let(:status) { EasySettings.status.completed }

          before do
            FactoryBot.create_list(:result_file, 9, request: request, status: ResultFile.statuses[:completed], deletable: false)
          end

          it { expect{subject}.to change(ResultFile, :count).by(1) }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: correct_accept_id, mode: mode))

            expect(flash[:notice]).to eq Message.const[:accept_result_file]

            expect(assigns(:finish_status)).to eq :normal_finish

            result_file = request.result_files.last
            expect(result_file.path).to be_nil
            expect(result_file.status).to eq 'accepted'
            expect(result_file.deletable).to be_falsey
            expect(result_file.expiration_date).to be_nil
            expect(result_file.fail_files).to be_nil

            expect(request.result_files[0].deletable).to be_truthy
            expect(request.result_files[1].deletable).to be_truthy
            expect(request.result_files[2].deletable).to be_truthy
            expect(request.result_files[3].deletable).to be_falsey
            expect(request.result_files[4].deletable).to be_falsey
            expect(request.result_files[5].deletable).to be_falsey
            expect(request.result_files[6].deletable).to be_falsey
            expect(request.result_files[7].deletable).to be_falsey
            expect(request.result_files[8].deletable).to be_falsey
          end
        end

      end
    end
  end

  describe "GET get_result_file" do
    subject { get :get_result_file, params: params }

    let(:user)             { create(:user) }
    let(:user2)            { create(:user) }
    let(:result_file_id)   { result_file.id }
    let(:mode)             { :multiple }
    let(:params)           { { id: result_file_id, mode: mode } }
    let(:request)          { create(:request, status: status, user: user) }
    let(:result_file)      { create(:result_file, path: result_file_path, request: request, status: ResultFile.statuses[:completed], expiration_date: expiration_date) }
    let(:result_file_path) { 'aaspec/controllers/requests_controller_make_download_excel_spec.rb' }
    let(:expiration_date)  { nil }
    let(:status)           { EasySettings.status.new }

    before do
      result_file
    end

    context '非ログインユーザ' do
      it { expect{subject}.to change(ResultFile, :count).by(0) }

      it do
        subject

        expect(response.status).to eq 302
        expect(response).to redirect_to(root_path)

        expect(flash[:alert]).to be_nil

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context 'ログインユーザ' do
      before { sign_in user }

      context '異常系' do
        context '結果ファイルIDが間違っている場合' do
          let(:result_file_id) { result_file.id + 1 }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(root_path)

            expect(flash[:alert]).to eq Message.const[:error_occurred]

            expect(assigns(:finish_status)).to eq :invalid_result_file_id
          end
        end

        context '違うユーザのリクエストを指定した場合' do
          before { sign_in user2 }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(root_path)

            expect(flash[:alert]).to eq Message.const[:error_occurred]

            expect(assigns(:finish_status)).to eq :wrong_user
          end
        end

        context 'ダウンロード有効期限切れのリクエストを指定した場合' do
          let(:expiration_date) { Time.zone.now - 1.day }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: request.accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:expired_download]

            expect(assigns(:finish_status)).to eq :expired_download
          end
        end

        context '結果ファイルのファイルパスが空の場合' do
          let(:result_file_path) { nil }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: request.accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:download_failure]

            expect(assigns(:finish_status)).to eq :file_path_blank
          end
        end

        context 'accept_idの手前で例外が発生した場合' do
          before { allow(ResultFile).to receive(:find_by_id).and_raise }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(root_path)

            expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

            expect(assigns(:finish_status)).to eq :error
          end
        end

        context 'accept_idの後で例外が発生した場合' do
          before { allow(S3Handler).to receive(:new).and_raise }

          it do
            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to(confirm_path(accept_id: request.accept_id, mode: mode))

            expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

            expect(assigns(:finish_status)).to eq :error
          end
        end
      end

      context '正常系' do
        let(:s3_hdl)    { S3Handler.new }
        let(:file_name) { 'result_download.xlsx' }
        let(:file_path) { Rails.root.join('spec', 'fixtures', file_name).to_s }
        let(:day_str)   { (Time.zone.today - 3.days).strftime("%Y/%-m/%-d") }
        let(:s3_path)   { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str}/#{request.id}/#{file_name}" }
        let(:result_file_path) { s3_path }

        before do
          s3_hdl.upload(s3_path: s3_path, file_path: file_path)
        end

        after do
          s3_hdl.delete(s3_path: s3_path)
        end

        context 'エクセルファイル' do
          let(:file_name) { 'result_download.xlsx' }

          it do
            subject

            expect(assigns(:finish_status)).to eq :normal_finish

            expect(response.status).to eq 200
            expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{file_name}\"; filename\*=UTF-8''#{file_name}/
            expect(response.headers['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
          end
        end

        context 'エクセルファイル' do
          let(:file_name) { 'result_dummy.zip' }

          it do
            subject

            expect(assigns(:finish_status)).to eq :normal_finish

            expect(response.status).to eq 200
            expect(response.headers['Content-Disposition']).to match /attachment; filename=\"#{file_name}\"; filename\*=UTF-8''#{file_name}/
            expect(response.headers['Content-Type']).to eq('application/zip')
          end
        end
      end
    end
  end
end

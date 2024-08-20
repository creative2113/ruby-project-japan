require 'rails_helper'

RSpec.describe Admin::RequestsController, type: :controller do
  let_it_be(:admin_user) { create(:admin_user) }
  let_it_be(:allow_ip) { create(:allow_ip, :admin) }

  describe 'POST copy' do
    subject { post :copy, params: params }

    let(:params) { { id: request_id, user_id: user_to_id } }
    let(:request_id) { request.id }
    let(:user_to_id) { user_to.id }

    let_it_be(:user_from) { create(:user, role: :administrator) }

    let_it_be(:user_to)   { create(:user, billing: :credit) }
    let(:accept_id) { Request.create_accept_id }
    let!(:request)   { create(:request, user: user_from, accept_id: accept_id, plan: EasySettings.plan[user_from.my_plan], list_site_analysis_result: list_site_analysis_result, status: EasySettings.status.working) }
    let!(:list_url1) { create(:corporate_list_requested_url_finished, :result_1, request: request, result_attrs: { single_url_ids: [single_url1.id, single_url2.id].to_json } ) }
    let!(:single_url1) { create(:corporate_single_requested_url, :a, request: request, result_attrs: { main: 'aa', candidate_crawl_urls: 'aa1', free_search: 'aa2' } ) }
    let!(:single_url2) { create(:corporate_single_requested_url, :b, request: request, result_attrs: { main: 'bb', candidate_crawl_urls: 'bb1', free_search: 'bb2' } ) }
    let!(:list_url2) { create(:corporate_list_requested_url_finished, :result_2, request: request, result_attrs: { single_url_ids: [single_url3.id, single_url4.id].to_json } ) }
    let!(:single_url3) { create(:corporate_single_requested_url, :c, request: request, result_attrs: { main: 'cc', candidate_crawl_urls: 'cc1', free_search: 'cc2' } ) }
    let!(:single_url4) { create(:corporate_single_requested_url, :d, request: request, result_attrs: { main: 'dd', candidate_crawl_urls: 'dd1', free_search: 'dd2' } ) }
    let(:list_site_analysis_result) { {'multi' => {'aa' => 'fgh', 'cc' => ['er', 'tyu']}, 'single' => {'ee' => 'qwe', 'gg' => 'vgt'} }.to_json }

    before do
      # 無限ループするので、ここでアップデートする
      single_url1.update!(corporate_list_url_id: list_url1.id)
      single_url2.update!(corporate_list_url_id: list_url1.id)
      single_url3.update!(corporate_list_url_id: list_url2.id)
      single_url4.update!(corporate_list_url_id: list_url2.id)
    end

    context '一般ユーザの場合' do
      it '失敗すること' do
        subject
        expect(response.status).to eq 404
      end
    end

    context '管理者ユーザの場合' do
      before { sign_in admin_user }

      context 'リクエストIDが存在しない' do
        let(:request_id) { request.id + 1000000 }

        it '失敗すること。コピーされないこと。' do
          req_cnt = Request.count
          req_url_cnt = RequestedUrl.count
          res_cnt = Result.count

          subject
          expect(response.location).to redirect_to admin_requests_path
          expect(flash[:alert]).to eq "ID: #{request_id}のリクエストは存在しません。"

          expect(Request.count).to eq req_cnt + 0
          expect(RequestedUrl.count).to eq req_url_cnt + 0
          expect(Result.count).to eq res_cnt + 0
        end
      end

      context 'ユーザが存在しない' do
        let(:user_to_id) { user_to.id + 100000 }

        it '失敗すること。コピーされないこと。' do
          req_cnt = Request.count
          req_url_cnt = RequestedUrl.count
          res_cnt = Result.count

          subject
          expect(response.location).to redirect_to admin_request_path(request_id)
          expect(flash[:alert]).to eq "ID: #{user_to_id}のユーザは存在しません。"

          expect(Request.count).to eq req_cnt + 0
          expect(RequestedUrl.count).to eq req_url_cnt + 0
          expect(Result.count).to eq res_cnt + 0
        end
      end

      context 'エラーが発生する' do
        before { allow_any_instance_of(Request).to receive(:copy_to).and_raise('Dummy Error') }

        it '失敗すること。コピーされないこと。' do
          req_cnt = Request.count
          req_url_cnt = RequestedUrl.count
          res_cnt = Result.count

          subject
          expect(response.location).to redirect_to admin_request_path(request_id)
          expect(flash[:alert]).to match /コピーに失敗しました。Alert: Dummy Error/

          expect(Request.count).to eq req_cnt + 0
          expect(RequestedUrl.count).to eq req_url_cnt + 0
          expect(Result.count).to eq res_cnt + 0
        end
      end

      context '正常系' do
        it '成功すること' do
          req_cnt = Request.count
          req_url_cnt = RequestedUrl.count
          res_cnt = Result.count

          expect(Request.where(user: user_to)).to be_blank

          subject

          expect(Request.where(user: user_to).reload).to be_present
          new_request = Request.where(user: user_to).reload.last

          expect(response.location).to redirect_to admin_request_path(new_request.id)
          expect(flash[:notice]).to eq 'コピーに成功しました。'

          expect(Request.count).to eq req_cnt + 1
          expect(RequestedUrl.count).to eq req_url_cnt + 6
          expect(Result.count).to eq res_cnt + 6

          expect(new_request.user_id).to eq user_to.id
          expect(new_request.corporate_list_site_start_url).to eq request.corporate_list_site_start_url
          expect(new_request.list_site_analysis_result).to eq request.list_site_analysis_result
          expect(new_request.title).to eq request.title
          expect(new_request.file_name).to eq request.file_name
        end
      end
    end
  end

  describe 'PUT update_list_site_analysis_result' do

    subject { put :update_list_site_analysis_result, params: params }
    let(:params) { { id: request_id, analysis_result: params_analysis_result_to } }
    let(:request_id) { request.id }

    let_it_be(:user) { create(:user) }
    let!(:request) { create(:request, user: user, list_site_analysis_result: analysis_result_from) }
    let!(:analysis_result_from) { {'multi' => {'aa' => 'fgh', 'cc' => ['er', 'tyu']}, 'single' => {'ee' => 'qwe', 'gg' => 'vgt'} }.to_json }
    let!(:analysis_result_to) { {'multi' => {'aa' => ['bb', 'b2'], 'cc' => 'dd'}, 'single' => {'ee' => 'ff', 'gg' => 'hh'} }.to_json }
    let!(:params_analysis_result_to) { analysis_result_to.gsub(',', ",\r\n") }

    context '一般ユーザの場合' do
      it '失敗すること' do
        subject
        expect(response.status).to eq 404
      end
    end

    context '管理者ユーザの場合' do
      before { sign_in admin_user }

      context 'リクエストIDが存在しない' do
        let(:request_id) { request.id + 1000000 }

        it '失敗すること' do
          subject
          expect(response.location).to redirect_to admin_requests_path
          expect(flash[:alert]).to eq "ID: #{request_id}のリクエストは存在しません。"
          expect(request.reload.list_site_analysis_result).to eq analysis_result_from
        end
      end

      context 'JSONとしておかしいとき' do
        let(:params_analysis_result_to) { analysis_result_to.gsub(',', "\r\n") }

        it '失敗すること' do
          subject
          expect(response.location).to redirect_to admin_request_path(request_id)
          expect(flash[:alert]).to match /更新に失敗しました。Alert: unexpected token at/
          expect(request.reload.list_site_analysis_result).to eq analysis_result_from
        end
      end

      context '正常系' do
        it '成功すること' do
          subject
          expect(response.location).to redirect_to admin_request_path(request_id)
          expect(flash[:notice]).to eq '更新に成功しました。'
          expect(request.reload.list_site_analysis_result).to eq analysis_result_to
        end
      end
    end
  end
end

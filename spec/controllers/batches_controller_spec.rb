require 'rails_helper'
require 'sidekiq/testing'
require 'sidekiq/api'

RSpec.describe BatchesController, type: :controller do
  let(:user) { create(:user) }

  before do
    Sidekiq::Worker.clear_all
  end

  describe '#request_search' do
    subject { get :request_search, params: params }
    let(:params)  { { user_id: user_id, search_request_id: search_request_id } }
    let(:user_id) { user.id }
    let(:search_request_id) { req.id }
    let(:req) { create(:search_request, user: user) }
    let(:body) { Json2.parse(response.body) }

    before { req }

    context 'IPアドレスが違う' do

      before do
        allow_any_instance_of(ActionController::TestRequest).to receive(:remote_ip).and_return('8.8.8.8')
        subject
      end

      it '400が返る' do
        expect(body[:result]).to eq 'forbidden'
        expect(response.status).to eq 403
        expect(SearchWorker.jobs.size).to eq 0
      end
    end

    context 'IPアドレスが正しい時' do
      before { subject }

      context 'user_idがnil' do
        let(:user_id) { nil }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_request'
          expect(response.status).to eq 400
          expect(SearchWorker.jobs.size).to eq 0
        end
      end

      context 'search_request_idがnil' do
        let(:search_request_id) { nil }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_request'
          expect(response.status).to eq 400
          expect(SearchWorker.jobs.size).to eq 0
        end
      end

      context 'search_request_idが間違っているとき' do
        let(:search_request_id) { req.id + 1 }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_request'
          expect(response.status).to eq 400
          expect(SearchWorker.jobs.size).to eq 0
        end
      end

      context '正常系' do
        it '200が返る' do
          expect(body[:result]).to eq 'success'
          expect(response.status).to eq 200
          expect(SearchWorker.jobs.size).to eq 1
        end
      end
    end
  end

  describe '#request_result_file' do
    subject { get :request_result_file, params: params }
    let(:params)  { { user_id: user_id, result_file_id: result_file_id } }
    let(:user_id) { user.id }
    let(:req) { create(:request, user: user) }
    let(:result_file_id) { result_file.id }
    let(:result_file) { create(:result_file, request: req) }
    let(:body) { Json2.parse(response.body) }

    before { result_file }

    context 'IPアドレスが違う' do

      before do
        allow_any_instance_of(ActionController::TestRequest).to receive(:remote_ip).and_return('8.8.8.8')
        subject
      end

      it '400が返る' do
        expect(body[:result]).to eq 'forbidden'
        expect(response.status).to eq 403
        expect(ResultFileWorker.jobs.size).to eq 0
      end
    end

    context 'IPアドレスが正しい時' do
      before { subject }

      context 'user_idがnil' do
        let(:user_id) { nil }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_result_file'
          expect(response.status).to eq 400
          expect(ResultFileWorker.jobs.size).to eq 0
        end
      end

      context 'result_file_idがnil' do
        let(:result_file_id) { nil }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_result_file'
          expect(response.status).to eq 400
          expect(ResultFileWorker.jobs.size).to eq 0
        end
      end

      context 'result_file_idが間違っているとき' do
        let(:result_file_id) { result_file.id + 1 }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_result_file'
          expect(response.status).to eq 400
          expect(ResultFileWorker.jobs.size).to eq 0
        end
      end

      context '正常系' do
        it '200が返る' do
          expect(body[:result]).to eq 'success'
          expect(response.status).to eq 200
          expect(ResultFileWorker.jobs.size).to eq 1
        end
      end
    end
  end

  describe '#request_test_search' do
    subject { get :request_test_search, params: params }
    let(:params)  { { user_id: user_id, test_request_id: test_request_id } }
    let(:user_id) { user.id }
    let(:request) { create(:request, user: user, test: true) }
    let(:requested_url) { create(:corporate_list_requested_url, request: request, test: true) }
    let(:test_request_id) { request.id }
    let(:body) { Json2.parse(response.body) }

    before { requested_url }

    context 'IPアドレスが違う' do

      before do
        allow_any_instance_of(ActionController::TestRequest).to receive(:remote_ip).and_return('8.8.8.8')
        subject
      end

      it '400が返る' do
        expect(body[:result]).to eq 'forbidden'
        expect(response.status).to eq 403
        expect(TestRequestSearchWorker.jobs.size).to eq 0
      end
    end

    context 'IPアドレスが正しい時' do
      before { subject }

      context 'user_idがnil' do
        let(:user_id) { nil }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_request'
          expect(response.status).to eq 400
          expect(TestRequestSearchWorker.jobs.size).to eq 0
        end
      end

      context 'result_file_idがnil' do
        let(:test_request_id) { nil }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_request'
          expect(response.status).to eq 400
          expect(TestRequestSearchWorker.jobs.size).to eq 0
        end
      end

      context 'result_file_idが間違っているとき' do
        let(:test_request_id) { request.id + 1 }

        it '400が返る' do
          expect(body[:result]).to eq 'not_exist_request'
          expect(response.status).to eq 400
          expect(TestRequestSearchWorker.jobs.size).to eq 0
        end
      end

      context '正常系' do
        it '200が返る' do
          expect(body[:result]).to eq 'success'
          expect(response.status).to eq 200
          expect(TestRequestSearchWorker.jobs.size).to eq 1
        end
      end
    end
  end
end

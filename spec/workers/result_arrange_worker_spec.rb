require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe ResultArrangeWorker, type: :worker do
  def perform_worker(id)
    Sidekiq::Testing.fake! do
      ResultArrangeWorker.perform_async(id)
      ResultArrangeWorker.drain
    end
  end

  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  let_it_be(:public_user) { create(:user_public) }

  before do
    Sidekiq::Worker.clear_all
    ActionMailer::Base.deliveries.clear
    allow(MyLog).to receive(:new).and_return(MyLog.new(test_log))

    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end

  after do
    FileUtils.rm_f(test_log_path)
  end

  let(:test_log)      { "test_log_#{Random.alphanumeric}" }
  let(:test_log_path) { "log/#{test_log}_#{Time.zone.now.strftime("%Y%m%d")}.log" }

  let(:user) { create(:user, billing: :credit) }
  let!(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
  let!(:request) { create(:request, status: status,
                                    user: user,
                                    type: Request.types[:corporate_list_site],
                                    plan: user_plan,
                                    corporate_list_site_start_url: start_url)}
  let(:user_plan) { plan; user.my_plan_number }
  let(:status) { EasySettings.status[:arranging] }
  let(:domain) { 'example.com' }
  let(:url)    { 'http://' + domain + '/' }
  let(:start_url) { "http://#{domain}/list" }

  let(:single_req_url) { create(:corporate_single_requested_url, url: "http://#{domain}/aa",
                                                                 request_id: request.id,
                                                                 result_attrs: { corporate_list: nil } ) }

  let(:arrange_status) { RequestedUrl.arrange_statuses[:accepted] }

  let!(:list_req_url) { create(:corporate_list_requested_url, url: "http://#{domain}/list",
                                                              request_id: request.id,
                                                              status: EasySettings.status.completed,
                                                              arrange_status: arrange_status,
                                                              finish_status: EasySettings.finish_status.successful,
                                                              result_attrs: {
                                                                single_url_ids: single_url_ids,
                                                                corporate_list: {result: list_req_url_corporate_list_result, table_result: {} }.to_json } ) }

  let!(:list_req_url2) { create(:corporate_list_requested_url, url: "http://#{domain}/list2",
                                                               request_id: request.id,
                                                               status: EasySettings.status.completed,
                                                               arrange_status: arrange_status,
                                                               finish_status: EasySettings.finish_status.successful,
                                                               result_attrs: {
                                                                 single_url_ids: single_url_ids,
                                                                 corporate_list: {result: list_req_url_corporate_list_result, table_result: {} }.to_json } ) }

  let!(:single_req_url2) { create(:corporate_single_requested_url, url: "http://#{domain}/bb",
                                                                   request_id: request.id,
                                                                   status: EasySettings.status.completed,
                                                                   finish_status: EasySettings.finish_status.successful,
                                                                   result_attrs: { corporate_list: single_req_url2_corporate_list_result } ) }

  let!(:dummy_request) { create(:request_of_public_user, status: status,
                                                         type: Request.types[:corporate_list_site]) }

  let!(:dummy_list_req_url) { create(:corporate_list_requested_url, url: "http://#{domain}/list",
                                                                    request_id: dummy_request.id,
                                                                    status: EasySettings.status.completed,
                                                                    finish_status: EasySettings.finish_status.successful,
                                                                    result_attrs: { corporate_list: {result: list_req_url_corporate_list_result, table_result: {} }.to_json } ) }

  let!(:dummy_single_req_url) { create(:corporate_single_requested_url, url: "http://#{domain}/cc",
                                                                        request_id: dummy_request.id,
                                                                        status: EasySettings.status.completed,
                                                                        finish_status: EasySettings.finish_status.successful,
                                                                        result_attrs: { corporate_list: dummy_single_req_url_corporate_list_result } ) }

  let(:list_req_url_corporate_list_result) do
    {"aa http://#{domain}/list" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'aa',
                                    Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => ["http://#{domain}/aa"],
                                    Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same1.com', 'http://aa.com'],
                                    '電話番号' => 'aaの電話番号'},
     "bb http://#{domain}/list" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'bb',
                                    Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => ["http://#{domain}/bb"],
                                    Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same1.com'],
                                    '電話番号' => 'bbの電話番号'},
     "cc http://#{domain}/list" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'cc',
                                    Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => ["http://#{domain}/cc"], # 結合されない
                                    Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same2.com', 'http://cc.com'],
                                    '電話番号' => 'ccの電話番号'},
    }
  end

  let(:single_req_url2_corporate_list_result) do
    {"bb http://#{domain}/bb" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'bb',
                                  Analyzer::BasicAnalyzer::ATTR_PAGE => "http://#{domain}/bb",
                                  Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => [],
                                  Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same2.com', 'http://bb.com'],
                                  '住所' => 'bbの住所'}
    }.to_json
  end

  let(:dummy_single_req_url_corporate_list_result) do
    {"cc http://#{domain}/cc" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'cc',
                                  Analyzer::BasicAnalyzer::ATTR_PAGE => "http://#{domain}/cc",
                                  Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => [],
                                  Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same2.com', 'http://bb.com']}
    }.to_json
  end

  let(:result) do
    {"aa http://#{domain}/aa" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'aa',
                                  Analyzer::BasicAnalyzer::ATTR_PAGE => "http://#{domain}/aa",
                                  Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => [],
                                  Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://aa.com'],
                                  '住所' => 'aaの住所'}
    }
  end

  let(:combined_result) do
    {"aa http://#{domain}/list" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'aa',
                                    '電話番号' => 'aaの電話番号'},
     "bb http://#{domain}/list" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'bb',
                                    '電話番号' => 'bbの電話番号',
                                    "#{Analyzer::BasicAnalyzer::ATTR_ORG_NAME}(個別ページ)" => 'bb',
                                    "#{Analyzer::BasicAnalyzer::ATTR_PAGE}(個別ページ)" => "http://#{domain}/bb",
                                    '住所(個別ページ)' => 'bbの住所'},
     "cc http://#{domain}/list" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'cc',
                                    '電話番号' => 'ccの電話番号'}
    }
  end

  let(:single_url_ids) do
    ids = [single_req_url.id, single_req_url2.id]
    4.times do |i|
      ids << create(:corporate_single_requested_url, url: "http://#{domain}/#{i}",
                                                     request_id: request.id,
                                                     status: EasySettings.status.completed,
                                                     finish_status: EasySettings.finish_status.successful,
                                                     result_attrs: { corporate_list: dummy_single_req_url_corporate_list_result } ).id
    end
    ids.shuffle.to_json
  end

  describe '#perform' do
    let_it_be(:user) { create(:user, billing: :credit) }
    let_it_be(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

    context '始まらない時' do
      before { MyLog.new(test_log).log 'test' }

      context 'リクエストIDがすでに実行中の時' do
        before do
          allow_any_instance_of(Sidekiqer).to receive(:get_working_arrange_ids).and_return([request.id])
        end

        it do
          perform_worker(request.id)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] START/)
        end
      end

      context 'リクエストIDが存在しないとき' do
        it do
          perform_worker(request.id + 1000)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] START/)
        end
      end

      context 'リクエストのステータスがArrangeではない時' do
        let(:status) { EasySettings.status[:working] }

        it do
          perform_worker(request.id)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] START/)
        end
      end

      context 'リクエストのステータスがArrangeではない時' do
        let(:status) { EasySettings.status[:completed] }

        it do
          perform_worker(request.id)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] START/)
        end
      end

      context 'リクエストがTestの時' do
        before { request.update!(test: true) }

        it do
          perform_worker(request.id)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] START/)
        end
      end

      context 'リクエストURLがtestしかない時' do
        before do
          list_req_url2.destroy
          list_req_url.update!(test: true)
        end

        it do
          perform_worker(request.id)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] START/)
        end
      end
    end

    context '正常系' do
      context 'テストURLが含まれている時' do
        before do
          list_req_url.update(test: true)
          list_req_url.result.update(corporate_list: list_req_url_corporate_list_result.to_json)
        end

        it do
          ci_cnt  = SearchRequest::CompanyInfo.count
          ci_cnt2 = request.company_info_urls.size
          perform_worker(request.id)
          expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 3
          expect(request.company_info_urls.size).to eq ci_cnt2 + 3
          expect(request.corporate_list_urls.size).to eq 1 # テストのみ残る
          expect(request.corporate_single_urls.size).to eq 0
          expect(request.corporate_list_urls.first.test).to be_truthy
          expect(request.corporate_list_urls.first.arrange_status).to eq 'completed'
          expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com", "http://cc.com"]
          expect(request.reload.status).to eq EasySettings.status.working
          expect(request.reload.list_site_result_headers).to eq ["組織名", "電話番号", "組織名(個別ページ)", "掲載ページ(個別ページ)", "住所(個別ページ)"].to_json

          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] START/)
          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] END/)
        end
      end

      context 'limitに達していないとき' do

        it do
          ci_cnt  = SearchRequest::CompanyInfo.count
          ci_cnt2 = request.company_info_urls.size
          perform_worker(request.id)
          expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 6
          expect(request.company_info_urls.size).to eq ci_cnt2 + 6
          expect(request.corporate_list_urls.size).to eq 0
          expect(request.corporate_single_urls.size).to eq 0
          expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com", "http://cc.com", "http://aa.com", "http://bb.com", "http://cc.com"]
          expect(request.reload.status).to eq EasySettings.status.working
          expect(request.reload.list_site_result_headers).to eq ["組織名", "電話番号", "組織名(個別ページ)", "掲載ページ(個別ページ)", "住所(個別ページ)"].to_json

          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] START/)
          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] END/)
        end
      end

      context 'limitに達したとき' do
        before do
          allow(EasySettings.excel_row_limit).to receive('[]').and_return(3)
        end

        it do
          ci_cnt  = SearchRequest::CompanyInfo.count
          ci_cnt2 = request.company_info_urls.size
          perform_worker(request.id)
          expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 3
          expect(request.company_info_urls.size).to eq ci_cnt2 + 3
          expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com", "http://cc.com"]
          expect(request.corporate_list_urls.size).to eq 0
          expect(request.corporate_single_urls.size).to eq 0
          expect(request.reload.status).to eq EasySettings.status.working
          expect(request.reload.list_site_result_headers).to eq ["組織名", "電話番号", "組織名(個別ページ)", "掲載ページ(個別ページ)", "住所(個別ページ)"].to_json

          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] START/)
          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] END/)
        end
      end

      describe 'ヘッダーに関して' do
        context 'headerの数が300以上ある時' do
          let(:single_req_url2_corporate_list_result) do
            hash = {}
            200.times { |i| hash["h#{i}"] = "item_#{i}" }
            {"bb http://#{domain}/bb" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'bb',
                                          Analyzer::BasicAnalyzer::ATTR_PAGE => "http://#{domain}/bb",
                                          Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => [],
                                          Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same2.com', 'http://bb.com']}.merge(hash)
            }.to_json
          end

          it do
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(request.company_info_urls.size).to eq ci_cnt2 + 6
            expect(JSON.parse(request.reload.list_site_result_headers).size).to eq 204
          end
        end

        context 'headerの数が300以上ある時' do
          let(:single_req_url2_corporate_list_result) do
            hash = {}
            500.times { |i| hash["h#{i}"] = "item_#{i}" }
            {"bb http://#{domain}/bb" => {Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 'bb',
                                          Analyzer::BasicAnalyzer::ATTR_PAGE => "http://#{domain}/bb",
                                          Analyzer::BasicAnalyzer::ATTR_CONTENT_URL => [],
                                          Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL => ['http://same2.com', 'http://bb.com']}.merge(hash)
            }.to_json
          end

          it do
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(request.company_info_urls.size).to eq ci_cnt2 + 6
            expect(JSON.parse(request.reload.list_site_result_headers).size).to eq 301
          end
        end
      end
    end

    context '異常系' do
      context '一つ目でエラー発生' do
        before do
          allow_any_instance_of(RequestedUrl).to receive(:find_result_or_create) do |req_url, arg|
            if req_url.id == list_req_url.id
              raise
            end
          end
        end

        it do
          perform_worker(request.id)
          expect(request.reload.status).to eq EasySettings.status.arranging
          expect(list_req_url.reload.arrange_status).to eq 'accepted'
          expect(list_req_url2.reload.arrange_status).to eq 'accepted'

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/アレンジでエラー発生/)

          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] START/)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] END/)
          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] Error/)
        end
      end

      context '二つ目でエラー発生' do
        before do
          allow_any_instance_of(RequestedUrl).to receive(:find_result_or_create) do |req_url, arg|
            if req_url.id == list_req_url2.id
              raise
            end
          end
        end

        it do
          ci_cnt2 = request.company_info_urls.size
          perform_worker(request.id)
          expect(request.company_info_urls.size).to eq ci_cnt2 + 3
          expect(request.reload.status).to eq EasySettings.status.arranging
          expect(list_req_url.reload.arrange_status).to eq 'completed'
          expect(list_req_url2.reload.arrange_status).to eq 'accepted'

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/アレンジでエラー発生/)

          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] START/)
          expect(File.read(test_log_path)).not_to match(/\[ResultArrangeWorker\]\[#perform\] END/)
          expect(File.read(test_log_path)).to match(/\[ResultArrangeWorker\]\[#perform\] Error/)
        end
      end
    end

    describe 'excel_row_limitに関して' do
      before do
        allow(EasySettings.excel_row_limit).to receive('[]').and_return(limit)
      end

      context 'all_getがfalse(first_pageじゃない)の時' do
        let(:start_url) { "http://#{domain}/list3" }

        context 'limitが1の時' do
          let(:limit) { 1 }

          it '会社情報URLが増えていること' do
            ci_cnt  = SearchRequest::CompanyInfo.count
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 1
            expect(request.company_info_urls.size).to eq ci_cnt2 + 1
            expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com"]
          end
        end

        context 'limitが2の時' do
          let(:limit) { 2 }

          it '会社情報URLが増えていること' do
            ci_cnt  = SearchRequest::CompanyInfo.count
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 2
            expect(request.company_info_urls.size).to eq ci_cnt2 + 2
            expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com"]
          end
        end

        context 'limitが4の時' do
          let(:limit) { 4 }

          it '会社情報URLが増えていること' do
            ci_cnt  = SearchRequest::CompanyInfo.count
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 4
            expect(request.company_info_urls.size).to eq ci_cnt2 + 4
            expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com", "http://cc.com", "http://aa.com"]
          end
        end

        context 'limitが5の時' do
          let(:limit) { 5 }

          it '会社情報URLが増えていること' do
            ci_cnt  = SearchRequest::CompanyInfo.count
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 5
            expect(request.company_info_urls.size).to eq ci_cnt2 + 5
            expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com", "http://cc.com", "http://aa.com", "http://bb.com"]
          end
        end

        context 'limitが10の時' do
          let(:limit) { 10 }

          it '会社情報URLが増えていること' do
            ci_cnt  = SearchRequest::CompanyInfo.count
            ci_cnt2 = request.company_info_urls.size
            perform_worker(request.id)
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 6
            expect(request.company_info_urls.size).to eq ci_cnt2 + 6
            expect(request.company_info_urls.pluck(:url)).to eq ["http://aa.com", "http://bb.com", "http://cc.com", "http://aa.com", "http://bb.com", "http://cc.com"]
          end
        end
      end
    end
  end

  describe '#arrange_corporate_list' do
    let_it_be(:user) { create(:user, billing: :credit) }
    let_it_be(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

    let(:worker) { described_class.new }
    let(:data_combiner) { DataCombiner.new(request: request) }
    before do
      worker.instance_variable_set(:@data_combiner, data_combiner)
      worker.instance_variable_set(:@corp_list_url, list_req_url)
      worker.instance_variable_set(:@request, request)
      worker.instance_variable_set(:@url_count, 0)
      worker.instance_variable_set(:@limit_count, EasySettings.excel_row_limit[request.plan_name])
    end

    context 'すでに完了しているとき' do
      let(:arrange_status) { RequestedUrl.arrange_statuses[:completed] }

      before do
        list_req_url.result.update(main: ["組織名", "電話番号", "組織名(個別ページ)", "掲載ページ(個別ページ)", "住所(個別ページ)"].to_json)
        FactoryBot.create_list(:company_info_requested_url, 3, request: request, corporate_list_url_id: list_req_url.id)
      end

      context 'header_countがある時' do
        before do
          data_combiner.count_headers(["組織名"])
          data_combiner.count_headers(["組織名", "電話番号", "組織名(個別ページ)", "電話番号(個別ページ)"])
        end

        it do
          worker.send(:arrange_corporate_list)
          expect(worker.instance_variable_get('@finish_status')).to eq :alredy_completed
          expect(worker.instance_variable_get('@url_count')).to eq 3
          expect(worker.instance_variable_get('@data_combiner').headers).to eq({"組織名"=>1, "電話番号"=>1, "組織名(個別ページ)"=>2, "掲載ページ(個別ページ)"=>1, "電話番号(個別ページ)"=>1, "住所(個別ページ)"=>1})
          expect(list_req_url.arrange_status).to eq 'completed'
        end
      end

      context '@url_countが0の時' do
        it do
          worker.send(:arrange_corporate_list)
          expect(worker.instance_variable_get('@finish_status')).to eq :alredy_completed
          expect(worker.instance_variable_get('@url_count')).to eq 3
          expect(worker.instance_variable_get('@data_combiner').headers).to eq({"組織名"=>1, "電話番号"=>1, "組織名(個別ページ)"=>1, "掲載ページ(個別ページ)"=>1, "住所(個別ページ)"=>1})
          expect(list_req_url.arrange_status).to eq 'completed'
        end
      end

      context '@url_countが2の時' do
        before do
          worker.instance_variable_set(:@url_count, 2)
        end

        it do
          worker.send(:arrange_corporate_list)
          expect(worker.instance_variable_get('@finish_status')).to eq :alredy_completed
          expect(worker.instance_variable_get('@url_count')).to eq 5
          expect(worker.instance_variable_get('@data_combiner').headers).to eq({"組織名"=>1, "電話番号"=>1, "組織名(個別ページ)"=>1, "掲載ページ(個別ページ)"=>1, "住所(個別ページ)"=>1})
          expect(list_req_url.arrange_status).to eq 'completed'
        end
      end
    end

    context 'ステータスがエラーの時' do
      let(:arrange_status) { RequestedUrl.arrange_statuses[:error] }

      before { FactoryBot.create_list(:company_info_requested_url, 3, request: request, corporate_list_url_id: list_req_url.id) }

      context 'header_countがある時' do
        before do
          data_combiner.count_headers(["組織名", "組織名(個別ページ)"])
          data_combiner.count_headers(["組織名", "電話番号", "組織名(個別ページ)", "電話番号(個別ページ)"])
        end

        it do
          expect { worker.send(:arrange_corporate_list) }.to raise_error(ResultArrangeWorker::ErrorStatusStop, "error ID: #{list_req_url.id}")
          expect(worker.instance_variable_get('@finish_status')).to eq :alredy_error
          expect(worker.instance_variable_get('@url_count')).to eq 0
          expect(worker.instance_variable_get('@data_combiner').headers).to eq({"組織名"=>1, "電話番号"=>1, "組織名(個別ページ)"=>2, "電話番号(個別ページ)"=>1})
          expect(list_req_url.arrange_status).to eq 'error'
        end
      end
    end

    context 'ステータスがacceptedの時' do
      let(:arrange_status) { RequestedUrl.arrange_statuses[:accepted] }

      context 'seekerがblankの時' do
        before do
          data_combiner.count_headers(["組織名", "組織名(個別ページ)"])
          data_combiner.count_headers(["組織名", "電話番号", "組織名(個別ページ)", "電話番号(個別ページ)"])
          allow(data_combiner).to receive(:combine_results).and_return(nil)
          FactoryBot.create_list(:company_info_requested_url, 3, request: request, corporate_list_url_id: list_req_url.id)
        end

        it do
          expect(SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id).count).to eq 3
          expect { worker.send(:arrange_corporate_list) }.to change(SearchRequest::CompanyInfo, :count).by(-3)
          expect(worker.instance_variable_get('@finish_status')).to eq :seeker_blank
          expect(worker.instance_variable_get('@url_count')).to eq 0
          expect(worker.instance_variable_get('@data_combiner').headers).to eq({"組織名"=>1, "電話番号"=>1, "組織名(個別ページ)"=>2, "電話番号(個別ページ)"=>1})
          expect(list_req_url.arrange_status).to eq 'completed'
          expect(list_req_url.result.main).to be_nil
          expect(SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id).count).to eq 0
        end
      end

      context '正常に完了する時' do
        before do
          data_combiner.count_headers(["組織名", "組織名(個別ページ)"])
          data_combiner.count_headers(["組織名", "電話番号", "組織名(個別ページ)", "電話番号(個別ページ)"])
        end

        it do
          expect(SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id).count).to eq 0
          worker.send(:arrange_corporate_list)
          expect(worker.instance_variable_get('@finish_status')).to eq :normal_finish
          expect(worker.instance_variable_get('@url_count')).to eq 3
          expect(worker.instance_variable_get('@data_combiner').headers).to eq({"組織名"=>1, "電話番号"=>1, "組織名(個別ページ)"=>3, "掲載ページ(個別ページ)"=>1, "電話番号(個別ページ)"=>1, "住所(個別ページ)"=>1})
          expect(SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id).count).to eq 3
          expect(list_req_url.arrange_status).to eq 'completed'
          expect(list_req_url.result.main).to eq ["組織名", "電話番号", "組織名(個別ページ)", "掲載ページ(個別ページ)", "住所(個別ページ)"].to_json
        end
      end
    end
  end

  describe '#make_company_info_requested_urls' do
    let_it_be(:user) { create(:user, billing: :credit) }
    let_it_be(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

    let(:worker) { described_class.new }
    let(:data_combiner) { DataCombiner.new(request: request) }
    let(:param_results) { list_req_url_corporate_list_result }
    let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com"], "bb http://example.com/list"=>["http://bb.com"], "cc http://example.com/list"=>["http://cc.com"]} }

    before do
      worker.instance_variable_set(:@data_combiner, data_combiner)
      worker.instance_variable_set(:@corp_list_url, list_req_url)
      worker.instance_variable_set(:@request, request)
      worker.instance_variable_set(:@url_count, 0)
      worker.instance_variable_set(:@limit_count, EasySettings.excel_row_limit[request.plan_name])
    end

    context 'all_getの時' do

      context 'new_urlsが一つずつの時' do
        it do
          company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
          expect(company_info_urls.reload.size).to eq 0
          worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
          expect(worker.instance_variable_get('@url_count')).to eq 3

          expect(company_info_urls.reload.size).to eq 3
          expect(company_info_urls[0].url).to eq 'http://aa.com'
          expect(company_info_urls[0].organization_name).to eq 'aa'
          expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[1].url).to eq 'http://bb.com'
          expect(company_info_urls[1].organization_name).to eq 'bb'
          expect(company_info_urls[1].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[2].url).to eq 'http://cc.com'
          expect(company_info_urls[2].organization_name).to eq 'cc'
          expect(company_info_urls[2].result.corporate_list).to eq param_results["cc http://example.com/list"].to_json
        end
      end

      context 'new_urlsが空のものがある時' do
        let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com"], "bb http://example.com/list"=>[]} }

        it do
          company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
          expect(company_info_urls.reload.size).to eq 0
          worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
          expect(worker.instance_variable_get('@url_count')).to eq 3

          expect(company_info_urls.reload.size).to eq 3
          expect(company_info_urls[0].url).to eq 'http://aa.com'
          expect(company_info_urls[0].organization_name).to eq 'aa'
          expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[1].url).to eq ''
          expect(company_info_urls[1].organization_name).to eq 'bb'
          expect(company_info_urls[1].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[2].url).to eq ''
          expect(company_info_urls[2].organization_name).to eq 'cc'
          expect(company_info_urls[2].result.corporate_list).to eq param_results["cc http://example.com/list"].to_json
        end
      end

      context 'new_urlsが複数あるものがある時' do
        let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com", "http://aa2.com"], "bb http://example.com/list"=>["http://bb.com", "http://bb2.com"], "cc http://example.com/list"=>["http://cc.com"]} }

        it do
          company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
          expect(company_info_urls.reload.size).to eq 0
          worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
          expect(worker.instance_variable_get('@url_count')).to eq 5

          expect(company_info_urls.reload.size).to eq 5
          expect(company_info_urls[0].url).to eq 'http://aa.com'
          expect(company_info_urls[0].organization_name).to eq 'aa'
          expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[1].url).to eq 'http://aa2.com'
          expect(company_info_urls[1].organization_name).to eq 'aa'
          expect(company_info_urls[1].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[2].url).to eq 'http://bb.com'
          expect(company_info_urls[2].organization_name).to eq 'bb'
          expect(company_info_urls[2].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[3].url).to eq 'http://bb2.com'
          expect(company_info_urls[3].organization_name).to eq 'bb'
          expect(company_info_urls[3].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[4].url).to eq 'http://cc.com'
          expect(company_info_urls[4].organization_name).to eq 'cc'
          expect(company_info_urls[4].result.corporate_list).to eq param_results["cc http://example.com/list"].to_json
        end
      end

      context 'url_countがlimitに達したとき' do
        let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com", "http://aa2.com"], "bb http://example.com/list"=>["http://bb.com", "http://bb2.com"], "cc http://example.com/list"=>["http://cc.com", "http://cc2.com"]} }

        before do
          worker.instance_variable_set(:@limit_count, 3)
        end

        it do
          company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
          expect(company_info_urls.reload.size).to eq 0
          worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
          expect(worker.instance_variable_get('@url_count')).to eq 6

          expect(company_info_urls.reload.size).to eq 6
          expect(company_info_urls[0].url).to eq 'http://aa.com'
          expect(company_info_urls[0].organization_name).to eq 'aa'
          expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[1].url).to eq 'http://aa2.com'
          expect(company_info_urls[1].organization_name).to eq 'aa'
          expect(company_info_urls[1].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[2].url).to eq 'http://bb.com'
          expect(company_info_urls[2].organization_name).to eq 'bb'
          expect(company_info_urls[2].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[3].url).to eq ''
          expect(company_info_urls[3].organization_name).to eq 'bb'
          expect(company_info_urls[3].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[4].url).to eq ''
          expect(company_info_urls[4].organization_name).to eq 'cc'
          expect(company_info_urls[4].result.corporate_list).to eq param_results["cc http://example.com/list"].to_json
          expect(company_info_urls[5].url).to eq ''
          expect(company_info_urls[5].organization_name).to eq 'cc'
          expect(company_info_urls[5].result.corporate_list).to eq param_results["cc http://example.com/list"].to_json
        end
      end
    end

    context 'all_getがfalse(first_pageじゃない)の時' do
      let(:start_url) { "http://#{domain}/list2" }

      context 'new_urlsが一つずつの時' do
        it do
          company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
          expect(company_info_urls.reload.size).to eq 0
          worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
          expect(worker.instance_variable_get('@url_count')).to eq 3

          expect(company_info_urls.reload.size).to eq 3
          expect(company_info_urls[0].url).to eq 'http://aa.com'
          expect(company_info_urls[0].organization_name).to eq 'aa'
          expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          expect(company_info_urls[1].url).to eq 'http://bb.com'
          expect(company_info_urls[1].organization_name).to eq 'bb'
          expect(company_info_urls[1].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          expect(company_info_urls[2].url).to eq 'http://cc.com'
          expect(company_info_urls[2].organization_name).to eq 'cc'
          expect(company_info_urls[2].result.corporate_list).to eq param_results["cc http://example.com/list"].to_json
        end
      end

      context 'limit_countがある時' do
        before do
          worker.instance_variable_set(:@limit_count, limit_count)
        end

        context 'new_urlsが空のものがある時' do
          let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com"], "bb http://example.com/list"=>[]} }
          let(:limit_count) { 2 }

          it do
            company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
            expect(company_info_urls.reload.size).to eq 0
            worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
            expect(worker.instance_variable_get('@url_count')).to eq 2

            expect(company_info_urls.reload.size).to eq 2
            expect(company_info_urls[0].url).to eq 'http://aa.com'
            expect(company_info_urls[0].organization_name).to eq 'aa'
            expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
            expect(company_info_urls[1].url).to eq ''
            expect(company_info_urls[1].organization_name).to eq 'bb'
            expect(company_info_urls[1].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          end
        end

        context 'new_urlsが複数あるものがある時' do
          let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com", "http://aa2.com"], "bb http://example.com/list"=>["http://bb.com", "http://bb2.com"], "cc http://example.com/list"=>["http://cc.com"]} }
          let(:limit_count) { 2 }

          it do
            company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
            expect(company_info_urls.reload.size).to eq 0
            worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
            expect(worker.instance_variable_get('@url_count')).to eq 2

            expect(company_info_urls.reload.size).to eq 2
            expect(company_info_urls[0].url).to eq 'http://aa.com'
            expect(company_info_urls[0].organization_name).to eq 'aa'
            expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
            expect(company_info_urls[1].url).to eq 'http://aa2.com'
            expect(company_info_urls[1].organization_name).to eq 'aa'
            expect(company_info_urls[1].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
          end
        end

        context 'new_urlsが複数あるものがある時' do
          let(:param_new_urls) { {"aa http://example.com/list"=>["http://aa.com", "http://aa2.com"], "bb http://example.com/list"=>["http://bb.com", "http://bb2.com"], "cc http://example.com/list"=>["http://cc.com"]} }
          let(:limit_count) { 3 }

          it do
            company_info_urls = SearchRequest::CompanyInfo.where(request: request, corporate_list_url_id: list_req_url.id)
            expect(company_info_urls.reload.size).to eq 0
            worker.send(:make_company_info_requested_urls, param_results, param_new_urls)
            expect(worker.instance_variable_get('@url_count')).to eq 3

            expect(company_info_urls.reload.size).to eq 3
            expect(company_info_urls[0].url).to eq 'http://aa.com'
            expect(company_info_urls[0].organization_name).to eq 'aa'
            expect(company_info_urls[0].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
            expect(company_info_urls[1].url).to eq 'http://aa2.com'
            expect(company_info_urls[1].organization_name).to eq 'aa'
            expect(company_info_urls[1].result.corporate_list).to eq param_results["aa http://example.com/list"].to_json
            expect(company_info_urls[2].url).to eq 'http://bb.com'
            expect(company_info_urls[2].organization_name).to eq 'bb'
            expect(company_info_urls[2].result.corporate_list).to eq param_results["bb http://example.com/list"].to_json
          end
        end
      end
    end
  end

  describe '#first_page_all_get' do
    let(:worker) { described_class.new }
    let(:data_combiner) { DataCombiner.new(request: request) }

    before do
      worker.instance_variable_set(:@corp_list_url, list_req_url)
      worker.instance_variable_set(:@request, request)
    end

    context 'userがfreeプランの時' do
      let_it_be(:user) { create(:user, billing: :free) }
      let!(:plan) { nil }

      context 'first_pageの時' do
        it do
          expect(worker.send(:first_page_all_get)).to be_falsey
        end
      end

      context 'first_pageじゃない時' do
        let(:start_url) { "http://#{domain}/list2" }
        it do
          expect(worker.send(:first_page_all_get)).to be_falsey
        end
      end
    end

    context 'userがスタンダードの時' do
      let_it_be(:user) { create(:user, billing: :credit) }
      let!(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

      context 'first_pageの時' do
        it do
          expect(worker.send(:first_page_all_get)).to be_truthy
        end
      end

      context 'first_pageじゃない時' do
        let(:start_url) { "http://#{domain}/list2" }
        it do
          expect(worker.send(:first_page_all_get)).to be_falsey
        end
      end
    end
  end
end

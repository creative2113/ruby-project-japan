require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe TestRequestSearchWorker, type: :worker do
  def perform_worker(id)
    Sidekiq::Testing.fake! do
      described_class.perform_async(id)
      described_class.drain
    end
  end

  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  let_it_be(:public_user) { create(:user_public) }

  before do
    Sidekiq::Worker.clear_all
    prepare_safe_stub
    allow(Url).to receive(:get_final_domain).and_return(domain)
    allow_any_instance_of(Sidekiqer).to receive(:get_test_working_job_limit).and_return(3)

    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end

  let(:user)      { create(:user, billing: :credit) }
  let!(:plan)     { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
  let!(:history)   { create(:monthly_history, user: user, plan: user_plan, acquisition_count: acquisition_count) }
  let(:user_plan) { plan; user.my_plan_number }

  let(:request) { create(:request_of_public_user, status: status,
                                                  type: Request.types[:corporate_list_site],
                                                  test: true,
                                                  plan: user_plan,
                                                  accessed_urls: before_accessed_urls,
                                                  list_site_analysis_result: before_analysis_result,
                                                  complete_multi_path_analysis: before_complete_multi_path_analysis,
                                                  multi_path_candidates: before_multi_path_candidates,
                                                  multi_path_analysis: before_multi_path_analysis,
                                                  list_site_result_headers: before_headers,
                                                  paging_mode: paging_mode,
                                                  use_storage: use_storage,
                                                  using_storage_days: using_storage_days,
                                                  user: user) }

  let(:acquisition_count)  { 0 }
  let(:status)             { EasySettings.status[:new] }
  let(:use_storage)        { false }
  let(:using_storage_days) { 0 }
  let(:domain)             { 'example.com' }
  let(:url)                { 'http://' + domain + '/' }
  let!(:requested_url)     { create(:corporate_list_requested_url, url: url,
                                                                   status: EasySettings.status[:new],
                                                                   finish_status: EasySettings.finish_status[:new],
                                                                   test: true,
                                                                   request_id: request.id ) }

  let(:before_accessed_urls) { nil }
  let(:before_analysis_result) { nil }
  let(:before_complete_multi_path_analysis) { nil }
  let(:before_multi_path_candidates) { nil }
  let(:before_multi_path_analysis) { nil }
  let(:before_headers) { nil }
  let(:paging_mode) { Request.paging_modes[:normal] }

  let(:analysis_result) { {'a' => 'b'} }
  let(:complete_multi_path_analysis) { false }
  let(:multi_path_candidates) { ['aa', 'bb'] }
  let(:multi_path_analysis) { {[domain, ['a', 'b'], {}].to_json => 4, [domain, ['f', 'g', 'h'], {}].to_json => 2} }
  let(:headers) { ['a', 'b'] }
  let(:accessed_urls) { [url] }
  let(:accessed_url1) { "#{url}c/d/e" }
  let(:accessed_url2) { "#{url}i/j" }
  let(:first_all_result) { { url => result1 } }
  let(:all_result) { { url => result1, accessed_url1 => result1 } }
  let(:result1) { { result: { result: {'aaa' => result_contents1, 'bbb' => result_contents2 }, table_result: {} }, candidate_crawl_urls: candidate_crawl_urls } }
  let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e", "#{url}f/g/h", "#{url}i/j", "#{url}k/l"] }
  let(:new_urls) { {'aaa' => ['aa1.com', 'aa2.com'], 'bbb' => ['bb1.com'] } }
  let(:result_contents1) { {'tel' => '11' } }
  let(:result_contents2) { {'tel' => '22' } }
  let(:single_url_result) { { url => single_urls } }
  let(:single_urls) { [single_url1, single_url2] }
  let(:single_url1) { "#{url}/single/1" }
  let(:single_url2) { "#{url}/single/2" }


  describe '#perform' do
    context 'ステータスが中止の時' do
      let(:status) { EasySettings.status[:discontinued] }

      it do
        perform_worker(request.id)
        expect(requested_url.reload.status).to eq EasySettings.status[:discontinued]
        expect(requested_url.finish_status).to eq EasySettings.finish_status[:discontinued]
      end
    end

    context '他のリクエストが同じドメインへのアクセスをしている時' do
      before do
        allow_any_instance_of(described_class).to receive(:execute_search).and_return({ status: :other_exec_now })
      end

      it do
        perform_worker(request.id)
        expect(requested_url.reload.status).to eq EasySettings.status[:waiting]
        expect(requested_url.finish_status).to eq EasySettings.finish_status[:new]
      end
    end
  end

  def start_wroker(requested_url, add_corp_list_urls = [])
    cpl_cnt = SearchRequest::CorporateList.count
    ci_cnt = SearchRequest::CompanyInfo.count

    perform_worker(requested_url.id)

    expect(Redis.new.get(domain)).to be_nil

    expect(requested_url.reload.result.reload.main).to be_nil
    expect(requested_url.request.list_site_result_headers).to be_nil

    expect(SearchRequest::CorporateList.count).to eq cpl_cnt + add_corp_list_urls.size
    expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 0

    expect(requested_url.request.requested_urls.corporate_list_urls.pluck(:url)).to eq [url] + add_corp_list_urls
    expect(requested_url.request.requested_urls.company_info_urls.pluck(:url)).to eq []
  end

  describe '#execute_search' do

    context '初回実行' do

      before do
        sk = Crawler::Seeker.new
        sk.set({complete_multi_path_analysis: complete_multi_path_analysis, multi_path_candidates: multi_path_candidates,
                multi_path_analysis: multi_path_analysis, headers: headers, new_urls: new_urls})
        cl = Crawler::CorporateList.new(url)
        cl.set({accessed_urls: accessed_urls,
                result: first_all_result, candidate_crawl_urls: [], single_urls: single_url_result, seeker: sk})

        allow(Crawler::CorporateList).to receive(:new).and_return(cl)
        allow_any_instance_of(Crawler::CorporateList).to receive(:start_search_and_analysis_step).and_return(analysis_result)
        allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step).and_return(true)

        requested_url
      end

      xcontext '解析ステップのリクエストが制限を超えている時' do
        before do
          allow_any_instance_of(Sidekiqer).to receive(:over_limit_working_analysis_step_requests?).and_return(true)
        end

        it '実行されないこと' do
          Sidekiq::Testing.fake! do
            cpl_cnt = SearchRequest::CorporateList.count
            cps_cnt = SearchRequest::CorporateSingle.count
            ci_cnt = SearchRequest::CompanyInfo.count

            described_class.perform_async(request.id)
            described_class.drain

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.new
            expect(ru.status).to eq EasySettings.status.waiting
            expect(ru.domain).to be_nil
            expect(ru.retry_count).to eq 0
            expect(ru.single_url_ids).to be_nil

            res = ru.result.reload
            expect(res.main).to be_nil
            expect(res.single_url_ids).to be_nil
            expect(res.corporate_list).to be_nil
            expect(res.candidate_crawl_urls).to be_nil

            expect(ru.request.status).to eq EasySettings.status.working
            expect(ru.request.list_site_analysis_result).to be_nil
            expect(ru.request.accessed_urls).to be_nil
            expect(ru.request.complete_multi_path_analysis).to be_falsey
            expect(ru.request.multi_path_candidates).to be_nil
            expect(ru.request.multi_path_analysis).to be_nil
            expect(ru.request.list_site_result_headers).to be_nil

            expect(history.reload.acquisition_count).to eq 0

            expect(SearchRequest::CorporateList.count).to eq cpl_cnt
            expect(SearchRequest::CorporateSingle.count).to eq cps_cnt
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt
          end
        end
      end

      context 'analysis_resultが得られない時' do
        let(:analysis_result) { {} }

        it 'エラー終了になること' do
          Sidekiq::Testing.fake! do
            cpl_cnt = SearchRequest::CorporateList.count
            cps_cnt = SearchRequest::CorporateSingle.count
            ci_cnt = SearchRequest::CompanyInfo.count

            described_class.perform_async(request.id)
            described_class.drain

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.error
            expect(ru.status).to eq EasySettings.status.error
            expect(ru.domain).to be_nil
            expect(ru.retry_count).to eq 0
            expect(ru.single_url_ids).to be_nil

            res = ru.result.reload
            expect(res.main).to be_nil
            expect(res.single_url_ids).to be_nil
            expect(res.corporate_list).to be_nil
            expect(res.candidate_crawl_urls).to be_nil

            expect(ru.request.status).to eq EasySettings.status.completed
            expect(ru.request.list_site_analysis_result).to be_nil
            expect(ru.request.accessed_urls).to be_nil
            expect(ru.request.complete_multi_path_analysis).to be_falsey
            expect(ru.request.multi_path_candidates).to be_nil
            expect(ru.request.multi_path_analysis).to be_nil
            expect(ru.request.list_site_result_headers).to be_nil

            expect(history.reload.acquisition_count).to eq 0

            expect(SearchRequest::CorporateList.count).to eq cpl_cnt
            expect(SearchRequest::CorporateSingle.count).to eq cps_cnt
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt
          end
        end
      end

      context 'list_configオプションがあるとき' do
        let(:analysis_result) { {} }

        let!(:config) { create(:list_crawl_config, domain: domain, analysis_result: opt_analysis_result.to_json) }
        let(:opt_analysis_result) { {'d' => 'd', 'e' => 'e'} }

        it '解析エラーが発生しない、解析をスキップして、正常終了すること' do
          Sidekiq::Testing.fake! do
            described_class.perform_async(request.id)
            expect { described_class.drain }.not_to raise_error

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.successful
            expect(ru.status).to eq EasySettings.status.completed
            expect(ru.domain).to eq domain
            expect(ru.retry_count).to eq 0

            res = ru.result.reload
            expect(res.single_url_ids).to be_blank
            expect(res.corporate_list).to be_present

            expect(ru.request.status).to eq EasySettings.status.completed
            expect(ru.request.list_site_analysis_result).to be_present
            expect(ru.request.accessed_urls).to be_present

            expect(history.reload.acquisition_count).to eq 0
          end
        end
      end

      context 'analysis_resultがあるとき（解析が完了しているとき）' do
        let(:analysis_result) { {} }

        let(:before_analysis_result) { {'d' => 'd', 'e' => 'e'}.to_json }

        it '解析エラーが発生しない、解析をスキップして、正常終了すること' do
          Sidekiq::Testing.fake! do
            described_class.perform_async(request.id)
            expect { described_class.drain }.not_to raise_error

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.successful
            expect(ru.status).to eq EasySettings.status.completed
            expect(ru.domain).to eq domain
            expect(ru.retry_count).to eq 0

            res = ru.result.reload
            expect(res.single_url_ids).to be_blank
            expect(res.corporate_list).to be_present

            expect(ru.request.status).to eq EasySettings.status.completed
            expect(ru.request.list_site_analysis_result).to eq before_analysis_result
            expect(ru.request.accessed_urls).to be_present

            expect(history.reload.acquisition_count).to eq 0
          end
        end
      end
    end
  end
end

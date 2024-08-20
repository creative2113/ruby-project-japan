require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RequestSearchWorker, type: :worker do
  def perform_worker(id)
    Sidekiq::Testing.fake! do
      RequestSearchWorker.perform_async(id)
      RequestSearchWorker.drain
    end
  end

  let_it_be(:master_tester_a_plan) { create(:master_billing_plan, :test_testerA) }
  let_it_be(:master_standard_plan) { create(:master_billing_plan, :standard) }

  before do
    ActionMailer::Base.deliveries.clear
    Sidekiq::Worker.clear_all
    prepare_safe_stub
    allow(Url).to receive(:get_final_domain).and_return(domain)
    allow_any_instance_of(Sidekiqer).to receive(:get_test_working_job_limit).and_return(3)

    allow(Billing).to receive(:plan_list).and_return(['testerA', 'standard'])
  end

  let_it_be(:public_user) { create(:user_public) }

  let(:user)      { create(:user, billing: :credit) }
  let!(:plan)     { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
  let!(:history)  { create(:monthly_history, user: user, plan: user_plan, acquisition_count: acquisition_count) }
  let(:user_plan) { plan; user.my_plan_number }

  let(:request) { create(:request_of_public_user, status: status,
                                                  type: Request.types[:corporate_list_site],
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
  let(:status)             { EasySettings.status[:working] }
  let(:use_storage)        { false }
  let(:using_storage_days) { 0 }
  let(:domain)             { 'example.com' }
  let(:url)                { 'http://' + domain + '/' }
  let(:requested_url)      { create(:corporate_list_requested_url, url: url,
                                                                   status: EasySettings.status[:waiting],
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
    # request_search_worker_spec.rbで実施
    context 'ステータスが中止の時' do
      let(:status) { EasySettings.status[:discontinued] }

      it do
        perform_worker(requested_url.id)
        expect(requested_url.reload.status).to eq EasySettings.status[:discontinued]
      end
    end

    context '他のリクエストが同じドメインへのアクセスをしている時' do
      before do
        allow_any_instance_of(RequestSearchWorker).to receive(:execute_search).and_return({ status: :other_exec_now })
      end

      it do
        perform_worker(requested_url.id)
        expect(requested_url.reload.status).to eq EasySettings.status[:new]
        expect(requested_url.reload.finish_status).to eq EasySettings.finish_status[:new]
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
      # def start_wroker(requested_url, add_corp_list_urls = [])
      #   cpl_cnt = SearchRequest::CorporateList.count
      #   ci_cnt = SearchRequest::CompanyInfo.count

      #   perform_worker(requested_url.id)

      #   expect(Redis.new.get(domain)).to be_nil

      #   expect(requested_url.reload.result.reload.main).to be_nil
      #   expect(requested_url.request.list_site_result_headers).to be_nil

      #   expect(SearchRequest::CorporateList.count).to eq cpl_cnt + add_corp_list_urls.size
      #   expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 0

      #   expect(requested_url.request.requested_urls.corporate_list_urls.pluck(:url)).to eq [url] + add_corp_list_urls
      #   expect(requested_url.request.requested_urls.company_info_urls.pluck(:url)).to eq []
      # end

      before do
        sk = Crawler::Seeker.new
        sk.set({complete_multi_path_analysis: complete_multi_path_analysis, multi_path_candidates: multi_path_candidates,
                multi_path_analysis: multi_path_analysis, headers: headers, new_urls: new_urls})
        cl = Crawler::CorporateList.new(url)
        cl.set({accessed_urls: accessed_urls,
                result: first_all_result, candidate_crawl_urls: [], single_urls: single_url_result, seeker: sk})

        allow(Crawler::CorporateList).to receive(:new).and_return(cl)
        allow_any_instance_of(Crawler::CorporateList).to receive(:start_search_and_analysis_step).and_return(analysis_result)
        allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_multi_urls).and_return(true)

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

            RequestSearchWorker.perform_async(requested_url.id)
            RequestSearchWorker.drain

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.new
            expect(ru.status).to eq EasySettings.status.new
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

        it 'エラーが発生し、異常終了すること' do
          Sidekiq::Testing.fake! do
            cpl_cnt = SearchRequest::CorporateList.count
            cps_cnt = SearchRequest::CorporateSingle.count
            ci_cnt = SearchRequest::CompanyInfo.count

            RequestSearchWorker.perform_async(requested_url.id)
            expect { RequestSearchWorker.drain }.to raise_error("サーチと解析のプロセスで失敗")

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.error
            expect(ru.status).to eq EasySettings.status.retry
            expect(ru.domain).to be_nil
            expect(ru.retry_count).to eq 1
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

      context 'list_configオプションがあるとき' do
        let(:analysis_result) { {} }

        let(:config) { create(:list_crawl_config, domain: domain, analysis_result: opt_analysis_result.to_json) }
        let(:opt_analysis_result) { {'d' => 'd', 'e' => 'e'} }

        before { config }

        it '解析エラーが発生しない、解析をスキップして、正常終了すること' do
          Sidekiq::Testing.fake! do
            RequestSearchWorker.perform_async(requested_url.id)
            expect { RequestSearchWorker.drain }.not_to raise_error # サーチと解析のプロセスで失敗にならない

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.successful
            expect(ru.status).to eq EasySettings.status.completed
            expect(ru.domain).to eq domain
            expect(ru.retry_count).to eq 0

            res = ru.result.reload
            expect(res.single_url_ids).to be_present
            expect(res.corporate_list).to be_present

            expect(ru.request.status).to eq EasySettings.status.working
            expect(ru.request.list_site_analysis_result).to eq opt_analysis_result.to_json
            expect(ru.request.list_site_analysis_result).to eq config.analysis_result
            expect(ru.request.accessed_urls).to be_present

            expect(history.reload.acquisition_count).to eq 2
          end
        end
      end

      context 'monthly_acquisition_limitを超えているとき' do
        let(:acquisition_count)  { EasySettings.monthly_acquisition_limit[request.plan_name] }

        let(:config) { create(:list_crawl_config, domain: domain, analysis_result: opt_analysis_result.to_json) }
        let(:opt_analysis_result) { {'d' => 'd', 'e' => 'e'} }

        before { history }

        it 'monthly_acquisition_limit制限に引っかかること' do
          Sidekiq::Testing.fake! do
            cpl_cnt = SearchRequest::CorporateList.count
            cps_cnt = SearchRequest::CorporateSingle.count
            ci_cnt = SearchRequest::CompanyInfo.count

            RequestSearchWorker.perform_async(requested_url.id)
            expect { RequestSearchWorker.drain }.not_to raise_error # サーチと解析のプロセスで失敗にならない

            expect(Redis.new.get(domain)).to be_nil

            ru = requested_url.reload
            expect(ru.finish_status).to eq EasySettings.finish_status.monthly_limit
            expect(ru.status).to eq EasySettings.status.completed
            expect(ru.domain).to be_nil # ドメインを取得する前に終了するので
            expect(ru.retry_count).to eq 0

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

            expect(history.reload.acquisition_count).to eq acquisition_count

            expect(SearchRequest::CorporateList.count).to eq cpl_cnt
            expect(SearchRequest::CorporateSingle.count).to eq cps_cnt
            expect(SearchRequest::CompanyInfo.count).to eq ci_cnt
          end
        end
      end
    end
  end

  describe '#record_multi_crawl_result' do
    before do
      sk = Crawler::Seeker.new
      sk.set({complete_multi_path_analysis: complete_multi_path_analysis, multi_path_candidates: multi_path_candidates,
              multi_path_analysis: multi_path_analysis, headers: headers, new_urls: new_urls})
      cl = Crawler::CorporateList.new(url)
      cl.set({accessed_urls: accessed_urls,
              result: first_all_result, candidate_crawl_urls: [], single_urls: single_url_result, seeker: sk})

      allow(Crawler::CorporateList).to receive(:new).and_return(cl)
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_search_and_analysis_step).and_return(analysis_result)
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_multi_urls).and_return(true)

      requested_url
    end

    describe 'multi_path_analysisについて' do
      context 'complete_multi_path_analysisがtrueの時' do
        let(:complete_multi_path_analysis) { true }

        it 'requestのmulti_path_analysisが更新されること & 合致するcandidate_crawl_urlsが追加されること' do
          start_wroker(requested_url,  ["#{url}a/b", "#{url}f/g/h"])

          req = requested_url.reload.request
          expect(req.complete_multi_path_analysis).to eq true
          expect(req.multi_path_candidates).to eq multi_path_candidates.to_json
          expect(req.multi_path_analysis).to eq multi_path_analysis.to_json
        end
      end

      context 'complete_multi_path_analysisがfalseの時' do
        let(:complete_multi_path_analysis) { false }
        let(:multi_path_analysis) { {} }

        it 'requestのmulti_path_analysisが更新されないこと & candidate_crawl_urlsは全て追加されること' do
          start_wroker(requested_url, candidate_crawl_urls)

          req = requested_url.reload.request
          expect(req.complete_multi_path_analysis).to eq false
          expect(req.multi_path_candidates).to eq multi_path_candidates.to_json
          expect(req.multi_path_analysis).to eq '{}'
        end
      end
    end

    describe 'accessed_urlsについて' do
      context '初回実行' do
        let(:before_accessed_urls) { nil }
        let(:accessed_urls) { [requested_url.url, "#{url}a/b", "#{url}c/d/e"] }

        it 'accessed_urlsが更新されること' do
          start_wroker(requested_url, ["#{url}f/g/h", "#{url}i/j", "#{url}k/l"])

          expect(requested_url.reload.request.accessed_urls).to eq accessed_urls.to_json
        end
      end

      context '既にaccessed_urlsがある時' do
        let(:before_accessed_urls) { ["#{url}a/b", "#{url}c/d/e"] }
        let(:accessed_urls) { [requested_url.url] }

        it 'accessed_urlsが更新されること' do
          start_wroker(requested_url, ["#{url}f/g/h", "#{url}i/j", "#{url}k/l"])

          expect(requested_url.reload.request.accessed_urls).to eq ( before_accessed_urls + accessed_urls ).to_json
        end
      end
    end

    describe 'corporate_list_resultについて' do
      let(:first_all_result) { { url => result1 } }

      it 'corporate_list_resultに結果が保存されること' do
        start_wroker(requested_url, candidate_crawl_urls)

        expect(requested_url.reload.corporate_list_result).to eq result1[:result].to_json
      end
    end

    describe 'レコードのカウントについて' do
      let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d"] }

      it 'CorporateListはcandidate_crawl_urlsの数だけ増えること' do
        cpl_cnt = SearchRequest::CorporateList.count

        start_wroker(requested_url, candidate_crawl_urls)

        expect(SearchRequest::CorporateList.count).to eq cpl_cnt + candidate_crawl_urls.size
      end

      it 'CompanyInfoは増えないこと' do
        ci_cnt = SearchRequest::CompanyInfo.count

        start_wroker(requested_url, candidate_crawl_urls)

        expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 0
      end
    end

    describe 'corporate_list_urlsの増加について' do

      def start_wroker_and_check_corporate_list_urls_count(requested_url, add_corp_list_urls = [])
        cpl_cnt = SearchRequest::CorporateList.count

        RequestSearchWorker.perform_async(requested_url.id)
        RequestSearchWorker.drain

        expect(SearchRequest::CorporateList.count).to eq cpl_cnt + add_corp_list_urls.size
        expect(requested_url.reload.request.corporate_list_urls.pluck(:url)).to eq [url] + add_corp_list_urls
      end

      describe 'filtered_candidate_crawl_urlsについて' do

        context '新しいlist_urls(candidate_crawl_urls)がない時' do
          let(:candidate_crawl_urls) { [] }

          it 'corporate_list_urlsは増えないこと' do
            start_wroker_and_check_corporate_list_urls_count(requested_url)
          end
        end

        context '新しいlist_urls(candidate_crawl_urls)に空文字列がある時' do
          let(:candidate_crawl_urls) { [''] }

          it 'corporate_list_urlsは増えないこと' do
            start_wroker_and_check_corporate_list_urls_count(requested_url)
          end
        end

        context 'requested_urlのurlがcandidate_crawl_urlsに入っている時' do
          let(:candidate_crawl_urls) { [requested_url.url, "#{url}a/b", "#{url}c/d/e"] }

          it 'requested_urlのurlは入らない' do
            start_wroker_and_check_corporate_list_urls_count(requested_url, ["#{url}a/b", "#{url}c/d/e"] )
          end
        end

        context '新しいcandidate_crawl_urlsがある時' do
          let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e"] }

          it 'corporate_list_urlsが増えること' do
            start_wroker_and_check_corporate_list_urls_count(requested_url, candidate_crawl_urls)
          end
        end

        context 'accessed_urlsがcandidate_crawl_urlsが入っている時' do
          let(:accessed_urls) { ["#{url}a/b"] }
          let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e" ] }

          it 'accessed_urlsに含まれているものは追加されない' do
            start_wroker_and_check_corporate_list_urls_count(requested_url, ["#{url}c/d/e"])
          end
        end

        context 'corporate_list_urlsがある時' do
          let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e", "#{url}f/g/h", "#{url}i/j", "#{url}k/l"] }
          before do
            create(:corporate_list_requested_url, url: "#{url}a/b", request: requested_url.request)
            create(:corporate_list_requested_url, url: "#{url}f/g/h", request: requested_url.request)
            create(:corporate_list_requested_url, url: "#{url}i/j", request: requested_url.request)
          end

          it 'corporate_list_urlsのURLは追加されない' do
            cpl_cnt = SearchRequest::CorporateList.count

            RequestSearchWorker.perform_async(requested_url.id)
            RequestSearchWorker.drain

            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + ["#{url}c/d/e", "#{url}k/l"].size
            urls = requested_url.reload.request.corporate_list_urls.pluck(:url)
            expect(urls[-2]).to eq "#{url}c/d/e"
            expect(urls[-1]).to eq "#{url}k/l"
          end
        end

        context 'complete_multi_path_analysisがtrueの時' do
          let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e", "#{url}f/g/h", "#{url}i/j", "#{url}k/l"] }
          let(:complete_multi_path_analysis) { true }

          it 'a/bとf/g/hのurlが追加される' do
            start_wroker_and_check_corporate_list_urls_count(requested_url, ["#{url}a/b", "#{url}f/g/h"])
          end
        end
      end

      context 'only_this_pageの時' do
        let(:paging_mode) { Request.paging_modes[:only_this_page] }
        let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e" ] }

        it 'corporate_list_urlsは増えないこと' do
          start_wroker_and_check_corporate_list_urls_count(requested_url)
        end
      end
    end

    describe 'single_urlsについて' do
      let(:candidate_crawl_urls) { [] }
      let(:single_url_result) { { url => single_urls } }
      let(:single_urls) { [single_url1, single_url2] }
      let(:single_url1) { "#{url}/single/1" }
      let(:single_url2) { "#{url}/single/2" }

      it 'single_urlsが増えること' do
        cps_cnt = SearchRequest::CorporateSingle.count

        start_wroker(requested_url)

        ru = requested_url.reload
        expect(SearchRequest::CorporateSingle.count).to eq cps_cnt + 2
        expect(ru.request.requested_urls.corporate_single_urls.pluck(:url)).to eq single_urls
      end

      it 'corporate_list_urlsのsingle_url_idsにsingle_urlsのidが追加されること' do
        start_wroker(requested_url)

        ru = requested_url.reload
        expect(ru.single_url_ids).to eq ru.request.requested_urls.corporate_single_urls.pluck(:id).to_json
      end
    end

    describe 'requesteのステータスについて' do
      context '最初がall_workingの時' do
        let(:status) { EasySettings.status[:all_working] }

        context 'candidate_crawl_urlsがある時、single_urlsがない時' do
          let(:candidate_crawl_urls) { ["#{url}a/b"] }
          let(:single_urls) { [] }

          it 'statusがworkingになる' do
            start_wroker(requested_url, candidate_crawl_urls)

            expect(request.reload.status).to eq EasySettings.status.working
          end
        end

        context 'candidate_crawl_urlsがない時、single_urlsがある時' do
          let(:candidate_crawl_urls) { [] }
          let(:single_urls) { [single_url1, single_url2] }

          it 'statusがworkingになる' do
            start_wroker(requested_url, candidate_crawl_urls)

            expect(request.reload.status).to eq EasySettings.status.working
          end
        end
      end
    end

    describe 'requested_urlのステータスについて' do
      context 'candidate_crawl_urlsがない時' do
        let(:candidate_crawl_urls) { [] }

        it 'statusが完了になる' do
          start_wroker(requested_url, candidate_crawl_urls)

          expect(requested_url.reload.finish_status).to eq EasySettings.finish_status.successful
          expect(requested_url.status).to eq EasySettings.status.completed
        end
      end

      context 'candidate_crawl_urlsがある時' do
        let(:candidate_crawl_urls) { ["#{url}a/b"] }

        it 'statusが完了になる' do
          start_wroker(requested_url, candidate_crawl_urls)

          expect(requested_url.reload.finish_status).to eq EasySettings.finish_status.successful
          expect(requested_url.status).to eq EasySettings.status.completed
        end
      end
    end
  end

  describe '#update_monthly_count_and_complete_for_multi' do
    def start_wroker2(requested_url, add_corp_list_urls = [], add_corp_single_urls = [])
      cpl_cnt = SearchRequest::CorporateList.count
      cps_cnt = SearchRequest::CorporateSingle.count
      ci_cnt = SearchRequest::CompanyInfo.count

      perform_worker(requested_url.id)

      expect(Redis.new.get(domain)).to be_nil

      expect(requested_url.reload.result.reload.main).to be_nil
      expect(requested_url.request.list_site_result_headers).to be_nil

      expect(SearchRequest::CorporateList.count).to eq cpl_cnt + add_corp_list_urls.size
      expect(SearchRequest::CorporateSingle.count).to eq cps_cnt + add_corp_single_urls.size
      expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 0

      expect(requested_url.request.requested_urls.corporate_list_urls.pluck(:url)).to eq [url] + add_corp_list_urls
      expect(requested_url.request.requested_urls.corporate_single_urls.pluck(:url)).to eq add_corp_single_urls
      expect(requested_url.request.requested_urls.company_info_urls.pluck(:url)).to eq []

      expect(request.reload.status).to eq EasySettings.status.working
    end

    before do
      sk = Crawler::Seeker.new
      sk.set({complete_multi_path_analysis: complete_multi_path_analysis, multi_path_candidates: multi_path_candidates,
              multi_path_analysis: multi_path_analysis, headers: headers, new_urls: new_urls})
      cl = Crawler::CorporateList.new(url)
      cl.set({accessed_urls: accessed_urls,
              result: first_all_result, candidate_crawl_urls: [], single_urls: single_url_result, seeker: sk})

      allow(Crawler::CorporateList).to receive(:new).and_return(cl)
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_search_and_analysis_step).and_return(analysis_result)
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_multi_urls).and_return(true)

      requested_url
    end

    xcontext 'パブリックユーザ' do
      let(:user)    { User.get_public }
      let!(:history) { nil }
      let!(:plan)    { nil }

      before do
        requested_url
        allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_multi_urls) do
          # set_workingが発動するかを確認するため、意図的に、all_workingに変更する
          request.update!(status: EasySettings.status.all_working)
          true
        end
      end

      context '追加のrequested_urlsが作成される時' do
        it do
          start_wroker2(requested_url, candidate_crawl_urls, single_urls)

          expect(requested_url.reload.status).to eq EasySettings.status.completed
          expect(requested_url.finish_status).to eq EasySettings.finish_status.successful
        end
      end

      context '追加のrequested_urlsが作成されない時' do
        let(:single_url_result) { {url => []} }
        let(:candidate_crawl_urls) { [] }

        it do
          start_wroker2(requested_url, [], [])

          expect(requested_url.reload.status).to eq EasySettings.status.completed
          expect(requested_url.finish_status).to eq EasySettings.finish_status.successful
        end
      end
    end

    context 'プランユーザ' do
      context 'transactionでエラーした時' do
        let(:acquisition_count) { 0 }

        before do
          allow_any_instance_of(RequestedUrl).to receive(:complete).and_raise
        end

        it do
          cpl_cnt = SearchRequest::CorporateList.count
          cps_cnt = SearchRequest::CorporateSingle.count

          expect { perform_worker(requested_url.id) }.to raise_error(RuntimeError)

          expect(requested_url.reload.result.reload.main).to be_nil
          expect(requested_url.request.list_site_result_headers).to be_nil

          expect(SearchRequest::CorporateList.count).to eq cpl_cnt + candidate_crawl_urls.size
          expect(SearchRequest::CorporateSingle.count).to eq cps_cnt + 0

          expect(request.reload.status).to eq EasySettings.status.working

          expect(requested_url.reload.status).to eq EasySettings.status.retry
          expect(requested_url.finish_status).to eq EasySettings.finish_status.error
          expect(requested_url.result.reload.corporate_list).to eq result1[:result].to_json
          expect(history.reload.acquisition_count).to eq 0
        end
      end

      context 'monthly_request_limit制限に引っかかる時' do
        let(:acquisition_count) { EasySettings.monthly_acquisition_limit[requested_url.request.plan_name] }

        before { allow_any_instance_of(RequestSearchWorker).to receive(:over_monthly_limit?).and_return(false) }

        it do
          start_wroker2(requested_url, candidate_crawl_urls, [])

          expect(requested_url.reload.status).to eq EasySettings.status.completed
          expect(requested_url.finish_status).to eq EasySettings.finish_status.monthly_limit
          expect(requested_url.result.reload.corporate_list).to be_nil
          expect(history.reload.acquisition_count).to eq acquisition_count
        end
      end

      context 'monthly_request_limit制限に引っかからない時' do
        context 'パターン1' do
          let(:acquisition_count) { 0 }

          it do
            start_wroker2(requested_url, candidate_crawl_urls, single_urls)

            expect(requested_url.reload.status).to eq EasySettings.status.completed
            expect(requested_url.finish_status).to eq EasySettings.finish_status.successful
            expect(requested_url.result.reload.corporate_list).to eq result1[:result].to_json
            expect(history.reload.acquisition_count).to eq 2
          end
        end

        context 'パターン2' do
          let(:acquisition_count) { 5 }
          let(:result1) { { result: { result: {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents2 }, table_result: {'aaa' => result_contents1, 'bbb' => result_contents2} }, candidate_crawl_urls: candidate_crawl_urls } }

          it do
            start_wroker2(requested_url, candidate_crawl_urls, single_urls)

            expect(requested_url.reload.status).to eq EasySettings.status.completed
            expect(requested_url.finish_status).to eq EasySettings.finish_status.successful
            expect(requested_url.result.reload.corporate_list).to eq result1[:result].to_json
            expect(history.reload.acquisition_count).to eq 10
          end
        end
      end
    end
  end

  describe '#cut_result_by_monthly_limit' do
    def start_wroker_for_cut_result_by_monthly_limit(requested_url, single_urls_result)
      single_urls_count = request.corporate_single_urls.size

      perform_worker(requested_url.id)

      expect(requested_url.reload.status).to eq EasySettings.status.completed
      expect(requested_url.finish_status).to eq EasySettings.finish_status.successful

      expect(request.corporate_single_urls.size).to eq single_urls_count + single_urls_result.size
      expect(request.corporate_single_urls.pluck(:url)).to eq single_urls_result
    end

    let(:result1) { { result: { result: result, table_result: table_result }, candidate_crawl_urls: candidate_crawl_urls } }
    let!(:plan)     { create(:billing_plan, name: master_tester_a_plan.name, billing: user.billing) }

    let(:count_limit) { EasySettings.monthly_acquisition_limit[request.plan_name] }
    let(:single_urls) { ['a1', 'b1', 'c1', 'd1', 'e1', 'f1'] }
    let(:new_dom_lbl) { Analyzer::BasicAnalyzer::ATTR_NEW_DOMAIN_URL }
    let(:cont_lbl)    { Analyzer::BasicAnalyzer::ATTR_CONTENT_URL }
    let(:result_contents1) { {'tel' => '11', new_dom_lbl => ['a'], cont_lbl => ['a1'] } }
    let(:result_contents2) { {'tel' => '22', new_dom_lbl => ['b'], cont_lbl => ['b1'] } }
    let(:result_contents3) { {'tel' => '33', new_dom_lbl => ['c'], cont_lbl => ['c1'] } }
    let(:result_contents4) { {'tel' => '44', new_dom_lbl => ['d'], cont_lbl => ['d1'] } }
    let(:result_contents5) { {'tel' => '55', new_dom_lbl => ['e'], cont_lbl => ['e1'] } }
    let(:result_contents6) { {'tel' => '66', new_dom_lbl => ['f'], cont_lbl => ['f1'] } }
    let(:after_contents1)  { {'tel' => '11', new_dom_lbl => [], cont_lbl => ['a1'] } }
    let(:after_contents2)  { {'tel' => '22', new_dom_lbl => [], cont_lbl => ['b1'] } }
    let(:after_contents3)  { {'tel' => '33', new_dom_lbl => [], cont_lbl => ['c1'] } }
    let(:after_contents4)  { {'tel' => '44', new_dom_lbl => [], cont_lbl => ['d1'] } }
    let(:after_contents5)  { {'tel' => '55', new_dom_lbl => [], cont_lbl => ['e1'] } }
    let(:after_contents6)  { {'tel' => '66', new_dom_lbl => [], cont_lbl => ['f1'] } }

    before do
      sk = Crawler::Seeker.new
      sk.set({complete_multi_path_analysis: complete_multi_path_analysis, multi_path_candidates: multi_path_candidates,
              multi_path_analysis: multi_path_analysis, headers: headers, new_urls: new_urls})
      cl = Crawler::CorporateList.new(url)
      cl.set({accessed_urls: accessed_urls,
              result: first_all_result, candidate_crawl_urls: [], single_urls: single_url_result, seeker: sk})

      allow(Crawler::CorporateList).to receive(:new).and_return(cl)
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_search_and_analysis_step).and_return(analysis_result)
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_multi_urls).and_return(true)

      requested_url
    end

    context '件数制限にかからない時' do
      let(:acquisition_count) { count_limit - 6 }
      let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
      let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }

      it do
        start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'b1', 'c1', 'd1', 'e1', 'f1'])

        expect(requested_url.result.reload.corporate_list).to eq({result: result, table_result: table_result}.to_json)
        expect(history.reload.acquisition_count).to eq count_limit
      end
    end

    context 'first_pageの時' do
      before { request.update!(corporate_list_site_start_url: requested_url.url) }

      describe 'table_resultに関して' do
        context 'table_resultが全て消える' do
          let(:acquisition_count) { count_limit - 3 }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }
          let(:after_table_result) { {'ddd' => after_contents4, 'eee' => after_contents5, 'fff' => after_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'b1', 'c1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: result, table_result: after_table_result}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end

        context 'table_resultが一部消える' do
          let(:acquisition_count) { count_limit - 2 }
          let(:result) { {} }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'b1', 'c1', 'd1', 'e1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: result, table_result: {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => after_contents6 }}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end

        context 'table_resultが全て消える' do
          let(:acquisition_count) { count_limit - 1 }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }
          let(:after_result) { {'aaa' => result_contents1, 'bbb' => after_contents2, 'ccc' => after_contents3 } }
          let(:after_table_result) { {'ddd' => after_contents4, 'eee' => after_contents5, 'fff' => after_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: after_result, table_result: after_table_result}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end
      end

      describe 'resultに関して' do
        let(:result1) { { result: { result: result, table_result: table_result }, candidate_crawl_urls: candidate_crawl_urls } }

        context 'resultが一部消える' do
          let(:single_urls) { ['a1', 'b1', 'c1'] }
          let(:acquisition_count) { count_limit - 2 }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
          let(:table_result) { {} }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'b1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => after_contents3}, table_result: {}}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end
      end
    end

    context 'first_pageではない時' do

      describe 'table_resultに関して' do
        context 'table_resultが全て消える' do
          let(:acquisition_count) { count_limit - 3 }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'b1', 'c1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: result, table_result: {}}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end

        context 'table_resultが一部消える' do
          let(:acquisition_count) { count_limit - 2 }
          let(:single_urls) { ['d1', 'e1', 'f1'] }
          let(:result) { {} }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['d1', 'e1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: {}, table_result: {'ddd' => result_contents4, 'eee' => result_contents5}}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end

        context 'table_resultが全て消える' do
          let(:acquisition_count) { count_limit - 1 }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: {'aaa' => result_contents1}, table_result: {}}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end
      end

      describe 'resultに関して' do
        let(:result1) { { result: { result: result, table_result: table_result }, candidate_crawl_urls: candidate_crawl_urls } }

        context 'resultが一部消える' do
          let(:acquisition_count) { count_limit - 2 }
          let(:single_urls) { ['a1', 'b1', 'c1'] }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents2, 'ccc' => result_contents3 } }
          let(:table_result) { {} }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'b1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: {'aaa' => result_contents1, 'bbb' => result_contents2}, table_result: {}}.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end
      end

      context '残すsingle_urlsと削除するsingle_urlsが被っている場合' do
        context 'パターン1' do
          let(:acquisition_count) { count_limit - 4 }
          let(:single_urls) { ['a1', 'c1', 'e1', 'f1'] }
          let(:result) { {'aaa' => result_contents1, 'bbb' => result_contents6, 'ccc' => result_contents3 } }
          let(:table_result) { {'ddd' => result_contents5, 'eee' => result_contents5, 'fff' => result_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['a1', 'c1', 'e1', 'f1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: {'aaa' => result_contents1, 'bbb' => result_contents6, 'ccc' => result_contents3}, table_result: {'ddd' => result_contents5} }.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end

        context 'パターン2' do
          let(:acquisition_count) { count_limit - 2 }
          let(:single_urls) { ['d1', 'c1', 'e1', 'f1'] }
          let(:result) { {'aaa' => result_contents4, 'bbb' => result_contents3, 'ccc' => result_contents3 } }
          let(:table_result) { {'ddd' => result_contents4, 'eee' => result_contents5, 'fff' => result_contents6 } }

          it do
            start_wroker_for_cut_result_by_monthly_limit(requested_url, ['d1', 'c1'])

            expect(requested_url.result.reload.corporate_list).to eq({result: {'aaa' => result_contents4, 'bbb' => result_contents3}, table_result: {} }.to_json)
            expect(history.reload.acquisition_count).to eq count_limit
          end
        end
      end
    end
  end

  describe '#extract_deletable_single_urls' do
    subject { worker.send(:extract_deletable_single_urls, result, delete_keys) }
    let(:worker) { described_class.new }
    let(:deletable_single_urls) { [] }
    let(:leave_single_urls) { [] }
    let(:lbl) { Analyzer::BasicAnalyzer::ATTR_CONTENT_URL }
    let(:result) { {'aaa' => {lbl => ['https://a1.com', 'https://a2.com']}, 'bbb' => {lbl => ['https://b1.com', 'https://b2.com']} } }
    let(:delete_keys) { [] }

    before do
      worker.instance_variable_set(:@deletable_single_urls, deletable_single_urls)
      worker.instance_variable_set(:@leave_single_urls, leave_single_urls)
    end

    context 'delete_keysがないとき' do
      let(:delete_keys) { [] }

      context '@deletable_single_urlsと@leave_single_urlsがない時' do
        let(:deletable_single_urls) { [] }
        let(:leave_single_urls) { [] }
        it do
          subject
          expect(worker.instance_variable_get('@deletable_single_urls')).to eq []
          expect(worker.instance_variable_get('@leave_single_urls')).to eq ['https://a1.com', 'https://a2.com', 'https://b1.com', 'https://b2.com']
        end
      end

      context '@deletable_single_urlsと@leave_single_urlsがない時' do
        let(:deletable_single_urls) { ['https://x1.com', 'https://x2.com'] }
        let(:leave_single_urls) { ['https://y1.com', 'https://a1.com', 'https://b2.com'] }
        it do
          subject
          expect(worker.instance_variable_get('@deletable_single_urls')).to eq deletable_single_urls
          expect(worker.instance_variable_get('@leave_single_urls')).to eq ['https://y1.com', 'https://a1.com', 'https://b2.com', 'https://a2.com', 'https://b1.com']
        end
      end

      context 'delete_keysがあるとき' do
        let(:delete_keys) { ['bbb'] }

        context '@deletable_single_urlsと@leave_single_urlsがない時' do
          let(:deletable_single_urls) { [] }
          let(:leave_single_urls) { [] }
          it do
            subject
            expect(worker.instance_variable_get('@deletable_single_urls')).to eq ['https://b1.com', 'https://b2.com']
            expect(worker.instance_variable_get('@leave_single_urls')).to eq ['https://a1.com', 'https://a2.com']
          end
        end

        context '@deletable_single_urlsと@leave_single_urlsがない時' do
          let(:deletable_single_urls) { ['https://x1.com', 'https://x2.com', 'https://b2.com'] }
          let(:leave_single_urls) { ['https://y1.com', 'https://a1.com'] }
          it do
            subject
            expect(worker.instance_variable_get('@deletable_single_urls')).to eq ['https://x1.com', 'https://x2.com', 'https://b2.com', 'https://b1.com']
            expect(worker.instance_variable_get('@leave_single_urls')).to eq ['https://y1.com', 'https://a1.com', 'https://a2.com']
          end
        end
      end
    end
  end

  describe '#execute_corporate_list_multi_search (2回目以降、マルチURLの実行)' do

    let(:requested_url) { create(:corporate_list_requested_url, url: url,
                                                                request_id: request.id,
                                                                result_attrs: {
                                                                  single_url_ids: before_single_url_ids,
                                                                  candidate_crawl_urls: nil,
                                                                  corporate_list: corporate_list_result } ) }

    let(:before_analysis_result) { {'a' => 'b'}.to_json }
    let(:before_accessed_urls) { ["#{url}c/d/e", "#{url}h/i"].to_json }
    let(:before_complete_multi_path_analysis) { false }
    let(:before_multi_path_candidates) { ['aa', 'bb'].to_json }
    let(:before_single_url_ids) { nil }

    let(:complete_multi_path_analysis) { true }
    let(:multi_path_candidates) { ['aa', 'cc'] }
    let(:multi_path_analysis) { {[domain, ['a', 'b'], {}].to_json => 4, [domain, ['f', 'g', 'h'], {}].to_json => 2} }
    let(:accessed_urls) { [url, accessed_url2, accessed_url3] }
    
    let(:corporate_list_result) { nil }

    let(:all_result) { { url => result1, accessed_url2 => result2, accessed_url3 => result3 } }
    let(:accessed_url2) { "#{url}i/j" }
    let(:accessed_url3) { "#{url}f/g/h" }
    let(:result1) { { result: { result: {'aaa' => result_contents1, 'bbb' => result_contents2 }, table_result: {} }, candidate_crawl_urls: candidate_crawl_urls1 } }
    let(:result2) { { result: { result: {'aaa' => result_contents1, 'bbb' => result_contents2 }, table_result: {} }, candidate_crawl_urls: candidate_crawl_urls2 } }
    let(:result3) { { result: { result: {},                                                      table_result: {} }, candidate_crawl_urls: candidate_crawl_urls3 } }
    let(:candidate_crawl_urls1) { ["#{url}a/b", "#{url}i/j", "#{url}k/l"] }
    let(:candidate_crawl_urls2) { ["#{url}c/d/e", "#{url}f/g/h", "#{url}k/l"] }
    let(:candidate_crawl_urls3) { ["#{url}a", "#{url}b", "#{url}k/l"] }

    let(:single_url_result) { { url => single_urls1, accessed_url2 => [], accessed_url3 => single_urls2 } }
    let(:single_urls1) { [single_url1, single_url2] }
    let(:single_urls2) { [single_url3, single_url4] }
    let(:single_url1) { "#{url}/single/1" }
    let(:single_url2) { "#{url}/single/2" }
    let(:single_url3) { "#{url}/single/3" }
    let(:single_url4) { "#{url}/single/4" }

    before do
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_multi_urls) do |corporate_list, args|
        corporate_list.set({accessed_urls: accessed_urls,
                            result: all_result, candidate_crawl_urls: [], single_urls: single_url_result})
        corporate_list.seeker.set({complete_multi_path_analysis: complete_multi_path_analysis, multi_path_candidates: multi_path_candidates,
                                   multi_path_analysis: multi_path_analysis})
        true
      end
    end

    describe '全体的な確認' do
      let(:complete_multi_path_analysis) { false }
      let(:candidate_crawl_urls) { ["#{url}a/b", "#{url}c/d/e", "#{url}f/g/h", "#{url}i/j", "#{url}k/l", "#{url}1", "#{url}2", "#{url}3", "#{url}4", "#{url}5", "#{url}6"] }

      it '正常に終了すること' do
        id = requested_url.id

        cpl_cnt = SearchRequest::CorporateList.count
        cps_cnt = SearchRequest::CorporateSingle.count
        ci_cnt = SearchRequest::CompanyInfo.count

        perform_worker(id)

        expect(Redis.new.get(domain)).to be_nil

        ru = RequestedUrl.find(id)
        expect(ru.finish_status).to eq EasySettings.finish_status.successful
        expect(ru.status).to eq EasySettings.status.completed
        expect(ru.domain).to eq domain
        expect(ru.result.main).to be_nil
        expect(ru.corporate_list_result).to eq result1[:result].to_json
        expect(ru.candidate_crawl_urls).to be_nil

        expect(ru.request.status).to eq EasySettings.status.working
        expect(ru.request.list_site_analysis_result).to eq analysis_result.to_json
        expect(ru.request.accessed_urls).to eq ["#{url}c/d/e", "#{url}h/i", url, "#{url}i/j", "#{url}f/g/h"].to_json
        expect(ru.request.complete_multi_path_analysis).to eq complete_multi_path_analysis
        expect(ru.request.multi_path_candidates).to eq ['aa', 'bb', 'cc'].to_json
        expect(ru.request.multi_path_analysis).to eq multi_path_analysis.to_json
        expect(ru.request.list_site_result_headers).to eq before_headers

        expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 2
        expect(SearchRequest::CorporateSingle.count).to eq cps_cnt + 2
        expect(SearchRequest::CompanyInfo.count).to eq ci_cnt + 0

        expect(ru.request.requested_urls.corporate_list_urls.pluck(:url)).to eq [url, "#{url}a/b", "#{url}k/l"]
        expect(ru.request.requested_urls.corporate_single_urls.pluck(:url)).to eq single_urls1
        expect(ru.request.requested_urls.company_info_urls.pluck(:url)).to eq []

        expect(history.reload.acquisition_count).to eq 2
      end
    end

    context 'monthly_request_limit制限に引っかかる時' do
      let(:acquisition_count)  { EasySettings.monthly_acquisition_limit[request.plan_name] }

      it do
        perform_worker(requested_url.id)
        expect(requested_url.reload.corporate_list_result).to be_nil
        expect(requested_url.status).to eq EasySettings.status[:completed]
        expect(requested_url.finish_status).to eq EasySettings.finish_status[:monthly_limit]
        expect(history.reload.acquisition_count).to eq acquisition_count
      end
    end

    context 'URLが404の時' do
      before { allow(Url).to receive(:get_final_domain).and_return('404') }

      it do
        perform_worker(requested_url.id)
        expect(requested_url.reload.corporate_list_result).to be_nil
        expect(requested_url.status).to eq EasySettings.status[:completed]
        expect(requested_url.finish_status).to eq EasySettings.finish_status[:invalid_url]
        expect(history.reload.acquisition_count).to eq 0
      end
    end

    describe 'メインrequested_urlのresultについて' do
      let(:complete_multi_path_analysis) { false }
      let(:result1) { { result: { result: {'aaa' => result_contents1, 'bbb' => result_contents2 }, table_result: {} }, candidate_crawl_urls: candidate_crawl_urls1 } }

      context 'メインrequested_urlのレコードに結果がない時' do
        let(:corporate_list_result) { nil }
        let(:candidate_crawl_urls) { ["#{url}1", "#{url}2", "#{url}3", "#{url}4", "#{url}5", "#{url}6", "#{url}7", "#{url}8", "#{url}9", "#{url}10", "#{url}11"].to_json }
        let(:all_result) { { url => result2, accessed_url2 => result2, accessed_url3 => result3 } }

        it 'corporate_list_resultは更新される' do
          perform_worker(requested_url.id)
          expect(requested_url.reload.corporate_list_result).to eq result2[:result].to_json
          expect(requested_url.status).to eq EasySettings.status[:completed]
        end
      end
    end

    describe '新しいマルチURLについて' do
      let(:complete_multi_path_analysis) { false }
      let(:before_accessed_urls) { ["#{url}c/d/e"].to_json }
      let(:accessed_urls) { [url, "#{url}k/l"] }
      let(:candidate_crawl_urls) { nil }
      let(:accessed_url2) { "#{url}i/j" }

      before { requested_url }

      context '新しいマルチの結果が得られたとき' do

        let(:all_result) { { url => result1 } }
        let(:result1) { { result: { result: {'ccc' => result_contents1, 'ddd' => result_contents2 }, table_result: {'ccc' => result_contents1} }, candidate_crawl_urls: candidate_crawl_urls1 } }
        let(:result_contents1) { ["#{url}a/b", "#{url}i/j", "#{url}k/l"] }
        let(:candidate_crawl_urls1) { [url, "#{url}a/b", "#{url}c/d/e", "#{url}f/g/h", "#{url}k/l"] }

        context 'まだマルチURLが一つもない時' do
          it 'マルチURLが増加すること' do
            cpl_cnt = SearchRequest::CorporateList.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 2

            expect(request.corporate_list_urls[0].corporate_list_result).to eq result1[:result].to_json
            expect(request.corporate_list_urls[1].url).to eq "#{url}a/b"
            expect(request.corporate_list_urls[1].corporate_list_result).to be_nil
            expect(request.corporate_list_urls[2].url).to eq "#{url}f/g/h"
            expect(request.corporate_list_urls[2].corporate_list_result).to be_nil
          end
        end

        context 'すでにマルチURLがいくつかある時' do
          before do
            create(:corporate_list_requested_url, url: "#{url}a/b", request_id: request.id)
            create(:corporate_list_requested_url, url: "#{url}f/g/h", request_id: request.id)
          end

          it 'マルチURLは増えないこと' do
            cpl_cnt = SearchRequest::CorporateList.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 0

            expect(requested_url.reload.corporate_list_result).to eq result1[:result].to_json
          end
        end

        context '最初のcandidate_crawl_urlsがない時' do
          let(:before_accessed_urls) { nil }
          let(:accessed_urls) { [] }

          it 'マルチURLが増加すること' do
            cpl_cnt = SearchRequest::CorporateList.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 4

            expect(requested_url.reload.corporate_list_result).to eq result1[:result].to_json
            expect(request.corporate_list_urls[1].url).to eq "#{url}a/b"
            expect(request.corporate_list_urls[1].corporate_list_result).to be_nil
            expect(request.corporate_list_urls[2].url).to eq "#{url}c/d/e"
            expect(request.corporate_list_urls[2].corporate_list_result).to be_nil
            expect(request.corporate_list_urls[3].url).to eq "#{url}f/g/h"
            expect(request.corporate_list_urls[3].corporate_list_result).to be_nil
            expect(request.corporate_list_urls[4].url).to eq "#{url}k/l"
            expect(request.corporate_list_urls[4].corporate_list_result).to be_nil
          end
        end

        context 'complete_multi_path_analysisがtrueの時' do
          let(:complete_multi_path_analysis) { true }
          let(:before_accessed_urls) { nil }
          let(:accessed_urls) { [] }

          it 'マルチURLが増加すること' do
            cpl_cnt = SearchRequest::CorporateList.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 2

            expect(requested_url.reload.corporate_list_result).to eq result1[:result].to_json
            expect(request.corporate_list_urls[1].url).to eq "#{url}a/b"
            expect(request.corporate_list_urls[1].corporate_list_result).to be_nil
            expect(request.corporate_list_urls[2].url).to eq "#{url}f/g/h"
            expect(request.corporate_list_urls[2].corporate_list_result).to be_nil
          end
        end
      end

      context '新しいマルチの結果が得られなかったとき' do
        let(:result1) { { result: { result: {}, table_result: {} }, candidate_crawl_urls: candidate_crawl_urls1 } }
        let(:result_contents1) { ["#{url}a/b", "#{url}i/j", "#{url}k/l"] }
        let(:candidate_crawl_urls1) { [] }

        context '結果が空だった時' do
          let(:all_result) { { url => result1 } }

          it 'マルチURLは増加しない' do
            cpl_cnt = SearchRequest::CorporateList.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 0

            expect(requested_url.reload.corporate_list_result).to eq({ result: {}, table_result: {} }.to_json)
          end
        end

        context '結果が全くない時' do
          let(:corporate_list_result) { result1[:result].to_json }
          let(:all_result) { {} }

          it 'マルチURLは増加しない' do
            cpl_cnt = SearchRequest::CorporateList.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateList.count).to eq cpl_cnt + 0

            expect(requested_url.reload.corporate_list_result).to eq({}.to_json)
          end
        end
      end
    end

    describe '新しいシングルURLについて' do
      # result3の結果を作らないとaccessed_url3のレコードが作られない
      let(:result3) { { result: { result: {'aaa' => result_contents1 }, table_result: {} }, candidate_crawl_urls: candidate_crawl_urls3 } }

      let(:single_url_result) { { url => single_urls1, accessed_url2 => [], accessed_url3 => single_urls2 } }
      let(:single_urls1) { [single_url1, single_url2] }
      let(:single_urls2) { [single_url3, single_url4] }
      let(:single_url1) { "#{url}/single/1" }
      let(:single_url2) { "#{url}/single/2" }
      let(:single_url3) { "#{url}/single/3" }
      let(:single_url4) { "#{url}/single/4" }

      context '新しいシングルURLの結果がある時' do
        it 'シングルURLが増加する' do
          cpl_cnt = SearchRequest::CorporateSingle.count
          perform_worker(requested_url.id)
          expect(SearchRequest::CorporateSingle.count).to eq cpl_cnt + 2

          expect(request.corporate_single_urls[0].url).to eq single_url1
          expect(request.corporate_single_urls[1].url).to eq single_url2
        end

        it 'single_url_idsに追加される' do
          perform_worker(requested_url.id)
          expect(requested_url.reload.single_url_ids).to eq [request.corporate_single_urls[0].id, request.corporate_single_urls[1].id].to_json
        end
      end

      context '新しいシングルURLの結果がない時' do
        let(:single_urls1) { [] }
        let(:single_urls2) { [] }

        it 'シングルURLが増加しない' do
          cpl_cnt = SearchRequest::CorporateSingle.count
          perform_worker(requested_url.id)
          expect(SearchRequest::CorporateSingle.count).to eq cpl_cnt + 0

          expect(request.corporate_single_urls[0]).to be_nil
        end

        it 'single_url_idsに追加されない' do
          perform_worker(requested_url.id)
          expect(requested_url.reload.single_url_ids).to be_nil
        end
      end

      context 'すでにシングルURLレコードがある時' do
        let(:single_urls1) { [single_url1, single_url2] }
        let(:single_urls2) { [] }
        let(:before_single_url_ids) { [request.corporate_single_urls[0].id].to_json }
        let(:single_url_rc) { create(:corporate_single_requested_url, url: single_url1, request_id: request.id) }

        before do
          single_url_rc
        end

        context '最初からsingle_url_idsに値が入っている時。' do
          let(:before_single_url_ids) { [single_url_rc.id].to_json }

          it 'シングルURL2が増加する' do
            cpl_cnt = SearchRequest::CorporateSingle.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateSingle.count).to eq cpl_cnt + 1

            expect(request.corporate_single_urls.last.url).to eq single_url2
          end

          it 'single_url_idsに追加される' do
            perform_worker(requested_url.id)
            r = request.corporate_single_urls.where(url: single_url2).first
            expect(requested_url.reload.single_url_ids).to eq [single_url_rc.id, r.id].to_json
          end
        end

        context '最初はsingle_url_idsに値が入っていない時' do
          let(:before_single_url_ids) { nil }

          it 'シングルURLが増加する' do
            cpl_cnt = SearchRequest::CorporateSingle.count
            perform_worker(requested_url.id)
            expect(SearchRequest::CorporateSingle.count).to eq cpl_cnt + 1

            expect(request.corporate_single_urls.last.url).to eq single_url2
          end

          it 'single_url_idsに追加される' do
            perform_worker(requested_url.id)
            r = request.corporate_single_urls.where(url: single_url2).first
            expect(requested_url.reload.single_url_ids).to eq [single_url_rc.id, r.id].to_json
          end
        end
      end
    end
  end

  describe '#execute_corporate_list_single_search (2回目以降、シングルURLの実行)' do

    let(:requested_url) { create(:corporate_single_requested_url, url: url,
                                                                  request_id: request.id,
                                                                  result_attrs: {
                                                                    candidate_crawl_urls: candidate_crawl_urls,
                                                                    corporate_list: corporate_list_result } ) }

    let(:corporate_list_result) { nil }
    let(:candidate_crawl_urls)  { nil }

    let(:result) { { 'title' => {'aaa' => result_contents1, 'bbb' => result_contents2 } } }

    before do
      allow_any_instance_of(Crawler::CorporateList).to receive(:start_scraping_step_to_single_urls) do |corporate_list, args|
        corporate_list.set({result: result})
        true
      end
      requested_url
    end

    context 'URLが404の時' do
      before { allow(Url).to receive(:get_final_domain).and_return('404') }

      it do
        cpl_cnt = SearchRequest::CorporateSingle.count
        perform_worker(requested_url.id)
        expect(SearchRequest::CorporateSingle.count).to eq cpl_cnt + 0

        expect(requested_url.reload.corporate_list_result).to be_nil
        expect(requested_url.status).to eq EasySettings.status[:completed]
        expect(requested_url.finish_status).to eq EasySettings.finish_status[:invalid_url]
        expect(history.reload.acquisition_count).to eq 0
      end
    end

    context '正常終了' do
      it '正常に終了する' do
        cpl_cnt = SearchRequest::CorporateSingle.count
        perform_worker(requested_url.id)
        expect(SearchRequest::CorporateSingle.count).to eq cpl_cnt + 0

        expect(requested_url.reload.url).to eq url
        expect(requested_url.reload.corporate_list_result).to eq result.to_json
        expect(requested_url.reload.status).to eq EasySettings.status.completed
        expect(requested_url.reload.finish_status).to eq EasySettings.finish_status.successful
        expect(history.reload.acquisition_count).to eq 0
      end
    end
  end
end

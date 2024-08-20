require 'rails_helper'

RSpec.describe Sidekiqer, type: :model do

  describe '#get_working_analysis_step_request_size' do
    subject { described_class.new.get_working_analysis_step_request_size(limit, self_id) }
    let(:limit) { nil }
    let(:self_id) { nil }

    let(:ru1) { create(:company_info_requested_url) }
    let(:ru2) { create(:company_info_requested_url) }
    let(:ru3) { create(:company_info_requested_url) }
    let(:ru4) { create(:corporate_list_requested_url) }
    let(:ru5) { create(:corporate_list_requested_url) }
    let(:ru6) { create(:corporate_list_requested_url) }
    let(:ru7) { create(:corporate_list_requested_url) }
    let(:ru8) { create(:corporate_list_requested_url, test: true) }
    let(:ru9) { create(:corporate_list_requested_url, test: true) }

    let(:job1) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru1.id, 'SearchRequest::CompanyInfo'] } }
    let(:job2) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru2.id, 'SearchRequest::CompanyInfo'] } }
    let(:job3) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru4.id, 'SearchRequest::CorporateList'] } }
    let(:job4) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru5.id, 'SearchRequest::CorporateList'] } }
    let(:job5) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru6.id, 'SearchRequest::CorporateList'] } }
    let(:job6) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru7.id, 'SearchRequest::CorporateList'] } }
    let(:job7) { {'queue' => 'test_request', 'class' => 'TestRequestSearchWorker', 'args' => [ru8.request.id] } }
    let(:job8) { {'queue' => 'test_request', 'class' => 'TestRequestSearchWorker', 'args' => [ru9.request.id] } }

    before do
      ru7.request.update(test: true)
      ru8.request.update(test: true)

      allow(Sidekiq::Workers).to receive(:new).and_return(
        [
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job1.to_json, 'queue' => job1['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job2.to_json, 'queue' => job2['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job3.to_json, 'queue' => job3['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job4.to_json, 'queue' => job4['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job5.to_json, 'queue' => job5['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job6.to_json, 'queue' => job6['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job7.to_json, 'queue' => job7['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i, 'payload' => job8.to_json, 'queue' => job8['queue']}],
        ]
      )
    end

    context 'limitがnil' do
      context 'self_idがnil' do

        context do
          before {
            ru4.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
            ru6.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          }
          it { expect(subject).to eq(4) }
        end

        context do
          before {
            ru5.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          }
          it { expect(subject).to eq(5) }
        end

        context do
          let(:job8) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [ru3.id, 'SearchRequest::CompanyInfo'] } }
          before {
            ru4.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
            ru6.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          }
          it { expect(subject).to eq(3) }
        end
      end

      context 'self_idがある' do
        context 'テストのself_id' do
          let(:self_id) { ru8.request.id }

          before {
            ru4.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
            ru6.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          }
          it { expect(subject).to eq(3) }
        end

        context '本リクエストのself_id' do
          let(:self_id) { ru3.request.id }
          before {
            ru4.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
            ru6.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          }
          it { expect(subject).to eq(4) }
        end
      end
    end

    context 'limitがある' do
      let(:limit) { 1 }
      context 'self_idがnil' do
        before {
          ru4.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          ru6.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
        }
        it { expect(subject).to eq(2) }
      end

      context 'self_idがある' do
        let(:self_id) { ru8.request.id }

        before {
          ru4.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
          ru6.request.update(list_site_analysis_result: {multi: 'aa'}.to_json)
        }
        it { expect(subject).to eq(1) }
      end
    end
  end

  describe '#get_timeout_jobs' do
    subject { described_class.new.get_timeout_jobs }

    let(:job1) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [1, 'SearchRequest::CompanyInfo'] } }
    let(:job2) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [2, 'SearchRequest::CompanyInfo'] } }
    let(:job3) { {'queue' => 'search', 'class' => 'SearchWorker', 'args' => [3] } }
    let(:job4) { {'queue' => 'search', 'class' => 'SearchWorker', 'args' => [4] } }
    let(:job5) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [5, 'SearchRequest::CorporateList'] } }
    let(:job6) { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [6, 'SearchRequest::CorporateList'] } }
    let(:job7) { {'queue' => 'test_request', 'class' => 'TestRequestSearchWorker', 'args' => [7] } }
    let(:job8) { {'queue' => 'test_request', 'class' => 'TestRequestSearchWorker', 'args' => [8] } }

    before do
      allow(Sidekiq::Workers).to receive(:new).and_return(
        [
          [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job1.to_json, 'queue' => job1['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i,  'payload' => job2.to_json, 'queue' => job2['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job3.to_json, 'queue' => job3['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i,  'payload' => job4.to_json, 'queue' => job4['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 31.minutes).to_i, 'payload' => job5.to_json, 'queue' => job5['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job6.to_json, 'queue' => job6['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 31.minutes).to_i, 'payload' => job7.to_json, 'queue' => job7['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job8.to_json, 'queue' => job8['queue']}],
        ]
      )
    end

    it do
      expect(subject).to eq({ company_info: [1], search_request: [3], corp_list: [5],  test_corp_list: [7] })
    end
  end


  describe '#reboot_request_sidekiq' do
    let(:user)     { create(:user) }
    let(:status)   { EasySettings.status.new }
    let(:req)      { create(:request, user: user, status: status ) }
    let(:req_url1) { create(:requested_url, request: req) }
    let(:req_url2) { create(:requested_url, request: req) }
    let(:job1)     { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [req_url1.id, 'SearchRequest::CompanyInfo'] } }
    let(:job2)     { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [req_url2.id, 'SearchRequest::CompanyInfo'] } }

    let(:file_name) { "sidekiq_reboot_for_test_#{Random.alphanumeric}" }
    let(:cntl_path) { "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}" }

    let(:deploy_file_name) { "deploying_for_test_#{Random.alphanumeric}" }
    let(:test_log) { "test_log_#{Random.alphanumeric}" }
    let(:test_log_path) { "log/#{test_log}_#{Time.zone.now.strftime("%Y%m%d")}.log" }
    let(:my_log) { MyLog.new(test_log) }

    before do
      ActionMailer::Base.deliveries.clear

      FileUtils.mkdir_p(Rails.application.credentials.control_directory[:path]) unless Dir.exist?(Rails.application.credentials.control_directory[:path])

      allow_any_instance_of(ChromeKiller).to receive(:execute).and_return(nil)
      allow(MyLog).to receive(:new).and_return(MyLog.new(test_log))

      # パラレルテストで他のrspecに影響が出るので
      allow(EasySettings.control_files).to receive('[]') do |arg|
        if arg == :sidekiq_reboot
          file_name
        elsif arg == :deploying
          deploy_file_name
        end
      end

      allow(Memory).to receive(:free_and_available).and_return('2000M')

      allow(Sidekiq::Workers).to receive(:new).and_return(
        [
          [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job1.to_json, 'queue' => job1['queue']}],
          [1, 2, {'run_at' => (Time.zone.now - 2.minutes).to_i,  'payload' => job2.to_json, 'queue' => job2['queue']}],
        ]
      )
    end

    after do
      FileUtils.rm_f(test_log_path)
      FileUtils.rm_f(cntl_path)
    end

    context '他のコントロールファイルがある場合' do
      context 'デプロイファイルがある場合' do
        let(:deploy_file) { "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}" }
        before { FileUtils.touch(deploy_file) }
        after  { FileUtils.rm_f(deploy_file) }

        it '実行しないこと' do
          expect(File.exist?(cntl_path)).to be_falsey

          kiqer = Sidekiqer.new
          expect(kiqer.reboot_request_sidekiq(timeout_min: 15)).to eq :deploying

          expect(File.exist?(cntl_path)).to be_falsey
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        end
      end

      context '再起動ファイルがある場合' do
        before { FileUtils.touch(cntl_path) }

        it '実行しないこと' do
          expect(File.exist?(cntl_path)).to be_truthy

          kiqer = Sidekiqer.new
          expect(kiqer.reboot_request_sidekiq(timeout_min: 15)).to eq :rebooting

          expect(File.exist?(cntl_path)).to be_truthy
          expect(ActionMailer::Base.deliveries.size).to eq(0)
        end
      end
    end

    describe 'ファイルが作られることの確認' do
      before { allow(FileUtils).to receive(:rm_f).and_return(nil) }

      it 'ファイルが作られること' do
        expect(File.exist?(cntl_path)).to be_falsey

        kiqer = Sidekiqer.new
        allow(kiqer).to receive(:quiet_request_process!).and_raise(RuntimeError)
        kiqer.reboot_request_sidekiq(timeout_min: 15)

        expect(File.exist?(cntl_path)).to be_truthy
      end
    end

    context 'メモリが不足してる時' do
      before do
        allow(Memory).to receive(:current).and_return(300)
        allow(Memory).to receive(:average).and_return(300)
      end
      it '15分経過したジョブはSTOPになる & サーバ再起動が走る' do
        aggregate_failures do
          kiqer = Sidekiqer.new
          allow(kiqer).to receive(:marker_key) do |arg, _|
            "dummy crawl_point_marker #{arg}"
          end
          allow(kiqer).to receive(:sleep).and_return(nil)
          kiqer.reboot_request_sidekiq(timeout_min: 15, log: my_log)

          expect(req_url1.reload.status).to eq EasySettings.status.completed
          expect(req_url1.finish_status).to eq EasySettings.finish_status.timeout

          expect(req_url2.reload.status).to eq EasySettings.status.new
          expect(req_url2.finish_status).to eq EasySettings.finish_status.new

          expect(File.exist?(cntl_path)).to be_falsey

          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/再起動 サーバ/)
          expect(ActionMailer::Base.deliveries[2].subject).to match(/再起動 Sidekiq 終了/)
          expect(ActionMailer::Base.deliveries[2].body).to match(/終了しなかったリクエストURL ID: {:requested_urls=&gt;\[#{req_url1.id}, #{req_url2.id}\], :search_requests=&gt;\[\], :test_request=&gt;\[\]}/)
          expect(ActionMailer::Base.deliveries[2].body).to match(/タイムアウトしたリクエストURL ID: {:company_info=&gt;\[#{req_url1.id}\], :search_request=&gt;\[\], :corp_list=&gt;\[\], :test_corp_list=&gt;\[\]}/)

          log = File.read(test_log_path)
          expect(log).to match(/Too Memory Shortage 平均/)
          expect(log).not_to match(/Waiting Finish Job. Exec Job IDs/)
        end
      end
    end

    context 'タイムアウトするジョブがある' do
      it 'タイムアウトのジョブはSTOPになる' do
        aggregate_failures do
          kiqer = Sidekiqer.new
          allow(kiqer).to receive(:marker_key) do |arg, _|
            "dummy crawl_point_marker #{arg}"
          end
          allow(kiqer).to receive(:sleep).and_return(nil)
          kiqer.reboot_request_sidekiq(timeout_min: 15, log: my_log)

          expect(req_url1.reload.status).to eq EasySettings.status.completed
          expect(req_url1.finish_status).to eq EasySettings.finish_status.timeout

          expect(req_url2.reload.status).to eq EasySettings.status.new
          expect(req_url2.finish_status).to eq EasySettings.finish_status.new

          expect(File.exist?(cntl_path)).to be_falsey

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/再起動 Sidekiq 終了/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/終了しなかったリクエストURL ID: {:requested_urls=&gt;\[#{req_url1.id}, #{req_url2.id}\], :search_requests=&gt;\[\], :test_request=&gt;\[\]}/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/タイムアウトしたリクエストURL ID: {:company_info=&gt;\[#{req_url1.id}\], :search_request=&gt;\[\], :corp_list=&gt;\[\], :test_corp_list=&gt;\[\]}/)

          log = File.read(test_log_path)
          expect(log).not_to match(/Too Memory Shortage 平均/)
          expect(log).to match(/Waiting Finish Job. Exec Job IDs/)
        end
      end
    end

    context '重要なマーカーがある' do
      let(:key) { "dummy crawl_point_marker #{req_url1.id}" }
      let(:marker) { 'corp_list_result_process' }
      before do
        redis = Redis.new
        res = redis.multi do |pipeline|
          pipeline.set(key, marker)
          pipeline.expire(key, 5*60)
        end
      end
      after { Redis.new.del(key) }

      it 'マーカーのメールが送られる' do
        aggregate_failures do
          expect(Redis.new.get(key)).to be_present

          kiqer = Sidekiqer.new
          allow(kiqer).to receive(:marker_key) do |arg, _|
            "dummy crawl_point_marker #{arg}"
          end
          allow(kiqer).to receive(:sleep).and_return(nil)
          kiqer.reboot_request_sidekiq(timeout_min: 15)

          expect(Redis.new.get(key)).to be_present

          expect(req_url1.reload.status).to eq EasySettings.status.completed
          expect(req_url1.finish_status).to eq EasySettings.finish_status.timeout

          expect(req_url2.reload.status).to eq EasySettings.status.new
          expect(req_url2.finish_status).to eq EasySettings.finish_status.new

          expect(File.exist?(cntl_path)).to be_falsey

          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/重要マーカー reboot_sidekiq/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/クロール重要マーカーあり/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/リクエストID: #{req.id} リクエストURL ID: #{req_url1.id}/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/マーカー #{marker}/)
          expect(ActionMailer::Base.deliveries[2].subject).to match(/再起動 Sidekiq 終了/)
          expect(ActionMailer::Base.deliveries[2].body).to match(/終了しなかったリクエストURL ID: {:requested_urls=&gt;\[#{req_url1.id}, #{req_url2.id}\], :search_requests=&gt;\[\], :test_request=&gt;\[\]}/)
          expect(ActionMailer::Base.deliveries[2].body).to match(/タイムアウトしたリクエストURL ID: {:company_info=&gt;\[#{req_url1.id}\], :search_request=&gt;\[\], :corp_list=&gt;\[\], :test_corp_list=&gt;\[\]}/)
        end
      end
    end

    context 'SearchRequestがある' do
      let(:req_url1) { create(:search_request, user: user, status: status) }
      let(:req_url2) { create(:search_request, user: user, status: status) }
      let(:job1)     { {'queue' => 'search', 'class' => 'SearchWorker', 'args' => [req_url1.id] } }
      let(:job2)     { {'queue' => 'search', 'class' => 'SearchWorker', 'args' => [req_url2.id] } }

      it do
        aggregate_failures do
          kiqer = Sidekiqer.new
          allow(kiqer).to receive(:marker_key) do |arg, _|
            "dummy crawl_point_marker #{arg}"
          end
          allow(kiqer).to receive(:sleep).and_return(nil)
          kiqer.reboot_request_sidekiq(timeout_min: 15)

          expect(req_url1.reload.status).to eq EasySettings.status.completed
          expect(req_url1.finish_status).to eq EasySettings.finish_status.timeout

          expect(req_url2.reload.status).to eq EasySettings.status.new
          expect(req_url2.finish_status).to eq EasySettings.finish_status.new

          expect(File.exist?(cntl_path)).to be_falsey

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/再起動 Sidekiq 終了/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/終了しなかったリクエストURL ID: {:requested_urls=&gt;\[\], :search_requests=&gt;\[#{req_url1.id}, #{req_url2.id}\], :test_request=&gt;\[\]}/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/タイムアウトしたリクエストURL ID: {:company_info=&gt;\[\], :search_request=&gt;\[#{req_url1.id}\], :corp_list=&gt;\[\], :test_corp_list=&gt;\[\]}/)
        end
      end
    end

    context 'CorpListUrlがある' do
      let(:req_url1) { create(:corporate_list_requested_url, request: req, status: status, test: false) }
      let(:req_url2) { create(:corporate_list_requested_url, request: req, status: status, test: false) }
      let(:job1)     { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [req_url1.id] } }
      let(:job2)     { {'queue' => 'request', 'class' => 'RequestSearchWorker', 'args' => [req_url2.id] } }

      before do
        allow(Sidekiq::Workers).to receive(:new).and_return(
          [
            [1, 2, {'run_at' => (Time.zone.now - 31.minutes).to_i, 'payload' => job1.to_json, 'queue' => job1['queue']}],
            [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job2.to_json, 'queue' => job2['queue']}],
          ]
        )
      end

      it do
        aggregate_failures do
          kiqer = Sidekiqer.new
          allow(kiqer).to receive(:marker_key) do |arg, _|
            "dummy crawl_point_marker #{arg}"
          end
          allow(kiqer).to receive(:sleep).and_return(nil)
          kiqer.reboot_request_sidekiq(timeout_min: 15)

          expect(req_url1.reload.status).to eq EasySettings.status.completed
          expect(req_url1.finish_status).to eq EasySettings.finish_status.timeout

          expect(req_url2.reload.status).to eq EasySettings.status.new
          expect(req_url2.finish_status).to eq EasySettings.finish_status.new

          expect(File.exist?(cntl_path)).to be_falsey

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/再起動 Sidekiq 終了/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/終了しなかったリクエストURL ID: {:requested_urls=&gt;\[#{req_url1.id}, #{req_url2.id}\], :search_requests=&gt;\[\], :test_request=&gt;\[\]}/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/タイムアウトしたリクエストURL ID: {:company_info=&gt;\[\], :search_request=&gt;\[\], :corp_list=&gt;\[#{req_url1.id}\], :test_corp_list=&gt;\[\]}/)
        end
      end
    end

    context 'TestRequestがある' do
      let(:req_url1) { create(:corporate_list_requested_url, request: req, status: status, test: true) }
      let(:req_url2) { create(:corporate_list_requested_url, request: req, status: status, test: true) }
      let(:job1)     { {'queue' => 'test_request', 'class' => 'TestRequestSearchWorker', 'args' => [req_url1.id] } }
      let(:job2)     { {'queue' => 'test_request', 'class' => 'TestRequestSearchWorker', 'args' => [req_url2.id] } }

      before do
        allow(Sidekiq::Workers).to receive(:new).and_return(
          [
            [1, 2, {'run_at' => (Time.zone.now - 31.minutes).to_i, 'payload' => job1.to_json, 'queue' => job1['queue']}],
            [1, 2, {'run_at' => (Time.zone.now - 16.minutes).to_i, 'payload' => job2.to_json, 'queue' => job2['queue']}],
          ]
        )
      end

      it do
        aggregate_failures do
          kiqer = Sidekiqer.new
          allow(kiqer).to receive(:marker_key) do |arg, _|
            "dummy crawl_point_marker #{arg}"
          end
          allow(kiqer).to receive(:sleep).and_return(nil)
          kiqer.reboot_request_sidekiq(timeout_min: 15)

          expect(req_url1.reload.status).to eq EasySettings.status.completed
          expect(req_url1.finish_status).to eq EasySettings.finish_status.timeout

          expect(req_url2.reload.status).to eq EasySettings.status.waiting
          expect(req_url2.finish_status).to eq EasySettings.finish_status.new

          expect(File.exist?(cntl_path)).to be_falsey

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/再起動 Sidekiq 終了/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/終了しなかったリクエストURL ID: {:requested_urls=&gt;\[\], :search_requests=&gt;\[\], :test_request=&gt;\[#{req_url1.id}, #{req_url2.id}\]}/)
          expect(ActionMailer::Base.deliveries[1].body).to match(/タイムアウトしたリクエストURL ID: {:company_info=&gt;\[\], :search_request=&gt;\[\], :corp_list=&gt;\[\], :test_corp_list=&gt;\[#{req_url1.id}\]}/)
        end
      end
    end
  end
end
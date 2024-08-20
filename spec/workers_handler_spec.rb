require 'rails_helper'
require 'sidekiq/testing'
require 'sidekiq/api'

describe '#restart_lost_test_request_jobs' do

  let(:sidekiqer) { Sidekiqer.new }
  let(:limit) { 2 }
  let(:working_size) { 0 }

  let(:ru1) { create(:corporate_list_requested_url, test: true) }
  let(:ru2) { create(:corporate_list_requested_url, test: true) }

  before do
    ru1.request.update(test: true)
    ru2.request.update(test: true)
    allow(sidekiqer).to receive(:get_test_working_job_limit).and_return(limit)
    allow(sidekiqer).to receive(:get_working_analysis_step_request_size).and_return(working_size)
  end

  context 'limitが2' do
    let(:limit) { 2 }

    context 'working_sizeが0' do
      let(:working_size) { 0 }

      it do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.send(:restart_lost_test_request_jobs, sidekiqer) }.to change { TestRequestSearchWorker.jobs.size }.by(2)
        end
      end
    end

    context 'working_sizeが1' do
      let(:working_size) { 1 }

      it do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.send(:restart_lost_test_request_jobs, sidekiqer) }.to change { TestRequestSearchWorker.jobs.size }.by(1)
        end
      end
    end

    context 'working_sizeが2' do
      let(:working_size) { 2 }

      it do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.send(:restart_lost_test_request_jobs, sidekiqer) }.to change { TestRequestSearchWorker.jobs.size }.by(0)
        end
      end
    end
  end

  context 'limitが1' do
    let(:limit) { 1 }

    context 'working_sizeが0' do
      let(:working_size) { 0 }

      it do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.send(:restart_lost_test_request_jobs, sidekiqer) }.to change { TestRequestSearchWorker.jobs.size }.by(1)
        end
      end
    end

    context 'working_sizeが1' do
      let(:working_size) { 1 }

      it do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.send(:restart_lost_test_request_jobs, sidekiqer) }.to change { TestRequestSearchWorker.jobs.size }.by(0)
        end
      end
    end
  end
end

describe '#execute' do
  before { create_public_user }

  let(:user)     { create(:user) }
  let(:status)   { EasySettings.status.new }
  let(:req)      { create(:request, user: user, status: status ) }
  let(:req_url)  { create(:company_info_requested_url, request: req, url: 'https://www.hokkaido.ccbc.co.jp/', domain: 'www.hokkaido.ccbc.co.jp') }
  let(:req_url2) { create(:company_info_requested_url, request: req, url: 'https://www.nexway.co.jp/',        domain: 'www.nexway.co.jp') }

  before { Sidekiq::Worker.clear_all }

  describe 'ResultFile' do
    before { allow(Tasks::WorkersHandler).to receive(:sleep).and_return(nil) }
    let!(:result_file) { create(:result_file, status: status) }

    context 'ステータスacceptedの結果ファイル作成リクエストがあり、キューにない場合' do

      let(:status) { ResultFile.statuses[:accepted] }

      it 'キューに投げられる' do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.execute }.to change { ResultFileWorker.jobs.size }.by(1)

          expect(result_file.reload.status).to eq 'waiting'
        end
      end
    end

    context 'ステータスcompletedの結果ファイル作成リクエストがあり、キューにない場合' do

      let(:status) { ResultFile.statuses[:completed] }

      it 'キューに投げられない' do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.execute }.to change { ResultFileWorker.jobs.size }.by(0)

          expect(result_file.reload.status).to eq 'completed'
        end
      end
    end

    context 'ステータスacceptedの結果ファイル作成リクエストがあり、キューにある場合' do

      let(:status) { ResultFile.statuses[:accepted] }

      before { allow_any_instance_of(Sidekiqer).to receive(:get_waiting_result_file_ids).and_return([result_file.id]) }

      it 'キューに投げられない' do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.execute }.to change { ResultFileWorker.jobs.size }.by(0)
          expect(result_file.reload.status).to eq 'accepted'
        end
      end
    end

    context 'ステータスacceptedの結果ファイル作成リクエストがあり、すでに動いている場合' do

      let(:status) { ResultFile.statuses[:accepted] }

      before { allow_any_instance_of(Sidekiqer).to receive(:get_working_result_file_ids).and_return([result_file.id]) }

      it 'キューに投げられない' do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.execute }.to change { ResultFileWorker.jobs.size }.by(0)
          expect(result_file.reload.status).to eq 'accepted'
        end
      end
    end
  end

  context 'all_workingのリクエストがあり、ステータスがnewのリクエストURLがある場合' do

    let(:status)   { EasySettings.status.all_working }
    let(:req_url)  { create(:company_info_requested_url, request: req, status: EasySettings.status.new) }

    before do
      req_url
    end

    it '12時間たったリクエストURLがキューに投げられる' do
      Sidekiq::Testing.fake! do
        expect { Tasks::WorkersHandler.execute }.to change { RequestSearchWorker.jobs.size }.by(1)

        expect(req_url.reload.status).to eq EasySettings.status.waiting
      end
    end
  end

  context 'ステータスがretryのリクエストURLがある場合' do
    let(:req_url)  { create(:company_info_requested_url, request: req, status: EasySettings.status.retry, updated_at: Time.zone.now - 11.minutes) }
    let(:req_url2) { create(:company_info_requested_url, request: req, status: EasySettings.status.retry, updated_at: Time.zone.now - 9.minutes) }

    before do
      req_url
      req_url2
    end

    it '10分たったリクエストURLがキューに投げられる' do

      Sidekiq::Testing.fake! do
        expect { Tasks::WorkersHandler.execute }.to change { RequestSearchWorker.jobs.size }.by(1)

        expect(req_url.reload.status).to eq EasySettings.status.waiting
        expect(req_url2.reload.status).to eq EasySettings.status.retry
      end
    end
  end

  context 'ステータスがwaitingのリクエストURLがある場合' do

    context 'キューが0でない場合' do
      let(:status)   { EasySettings.status.working }
      let(:updated_at2) { Time.zone.now - 1.hours - 57.minute }
      let(:req_url)  { create(:company_info_requested_url, request: req, status: EasySettings.status.waiting, updated_at: Time.zone.now - 2.hours - 1.minute) }
      let(:req_url2) { create(:company_info_requested_url, request: req, status: EasySettings.status.waiting, updated_at: updated_at2) }

      before do
        req_url
        req_url2

        # Sidekiq::Queue.new(:request)
        # 事前にキューに入れておかないと、全てキューに投げられる
        allow_any_instance_of(Sidekiq::Queue).to receive(:size).and_return(1)
      end

      it '2時間たったリクエストURLがキューに投げられる' do
        Sidekiq::Testing.fake! do
          expect { Tasks::WorkersHandler.execute }.to change { RequestSearchWorker.jobs.size }.by(1)

          expect(req_url.reload.status).to eq EasySettings.status.waiting
          expect(req_url2.reload.status).to eq EasySettings.status.waiting
          expect(req_url.updated_at).to be > Time.zone.now - 3.minutes
          expect(req_url2.updated_at).to eq updated_at2.iso8601
        end
      end
    end

    context 'キューが0の場合' do

      it '全てのリクエストがキューに投げられる' do
        AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'www.example.com'])

        81.times do |i|
          create(:company_info_requested_url, request: req, status: EasySettings.status.waiting, url: 'https://www.hokkaido.ccbc.co.jp/', domain: 'www.hokkaido.ccbc.co.jp')
        end

        Sidekiq::Testing.fake! do
          expect(RequestSearchWorker.jobs.size).to eq 0
          expect { Tasks::WorkersHandler.execute }.to change { RequestSearchWorker.jobs.size }.by(81)
          expect(RequestSearchWorker.jobs.size).to eq 81
        end
      end
    end
  end

  context 'ステータスがworkingのリクエストURLがある場合' do

    let(:status)   { EasySettings.status.working }
    let(:updated_at2) { Time.zone.now - 17.minute }
    let(:req_url)  { create(:company_info_requested_url, request: req, status: EasySettings.status.working, updated_at: Time.zone.now - 21.minute) }
    let(:req_url2) { create(:company_info_requested_url, request: req, status: EasySettings.status.working, updated_at: updated_at2) }

    before do
      req_url
      req_url2
    end

    it '20分たったリクエストURLがキューに投げられる' do
      Sidekiq::Testing.fake! do
        expect { Tasks::WorkersHandler.execute }.to change { RequestSearchWorker.jobs.size }.by(1)

        expect(req_url.reload.status).to eq EasySettings.status.waiting
        expect(req_url2.reload.status).to eq EasySettings.status.working
        expect(req_url2.updated_at).to eq updated_at2.iso8601
      end
    end
  end

  context '通常の場合' do

    it 'リクエストがキューに投げられる' do

      req1 = create(:request, user: user, status: EasySettings.status.new)

      10.times do |i|
        create(:company_info_requested_url, request: req1, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req2 = create(:request, user: user, status: EasySettings.status.working)

      2.times do |i|
        create(:company_info_requested_url, request: req2, status: EasySettings.status.working, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      8.times do |i|
        create(:company_info_requested_url, request: req2, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req3 = create(:request, user: user, status: EasySettings.status.all_working)

      3.times do |i|
        create(:company_info_requested_url, request: req3, status: EasySettings.status.working, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req4 = create(:request, user: user, status: EasySettings.status.new)

      3.times do |i|
        create(:company_info_requested_url, request: req4, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req5 = create(:request, user: user, status: EasySettings.status.working)

      5.times do |i|
        create(:company_info_requested_url, request: req5, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      sleep 2

      Sidekiq::Testing.fake! do
        expect(RequestSearchWorker.jobs.size).to eq 0
        expect { Tasks::WorkersHandler.execute(3, 4) }.to change { RequestSearchWorker.jobs.size }.by(26)
        expect(RequestSearchWorker.jobs.size).to eq 26
        expect(Request.find(req1.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req1.id).updated_at).not_to eq req1.updated_at
        expect(Request.find(req2.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req3.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req3.id).updated_at).to eq req3.updated_at
        expect(Request.find(req4.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req5.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req5.id).updated_at).not_to eq req5.updated_at

        expect(Request.find(req1.id).get_new_urls.size).to eq 0
        expect(Request.find(req1.id).get_only_waiting_urls.size).to eq 10
        expect(Request.find(req2.id).get_new_urls.size).to eq 0
        expect(Request.find(req2.id).get_only_waiting_urls.size).to eq 8
        expect(Request.find(req3.id).get_new_urls.size).to eq 0
        expect(Request.find(req3.id).get_working_urls.size).to eq 3
        expect(Request.find(req4.id).get_new_urls.size).to eq 0
        expect(Request.find(req4.id).get_only_waiting_urls.size).to eq 3
        expect(Request.find(req5.id).get_new_urls.size).to eq 0
        expect(Request.find(req5.id).get_only_waiting_urls.size).to eq 5
      end
    end
  end

  context '150リクエストを超えた場合' do

    it '150を超えたら、リクエスト投下が中断される1' do

      req1 = create(:request, user: user, status: EasySettings.status.new)

      90.times do |i|
        create(:company_info_requested_url, request: req1, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req2 = create(:request, user: user, status: EasySettings.status.working)

      20.times do |i|
        create(:company_info_requested_url, request: req2, status: EasySettings.status.working, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      90.times do |i|
        create(:company_info_requested_url, request: req2, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req3 = create(:request, user: user, status: EasySettings.status.all_working)

      3.times do |i|
        create(:company_info_requested_url, request: req3, status: EasySettings.status.working, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req4 = create(:request, user: user, status: EasySettings.status.new)

      3.times do |i|
        create(:company_info_requested_url, request: req4, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req5 = create(:request, user: user, status: EasySettings.status.working)

      5.times do |i|
        create(:company_info_requested_url, request: req5, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      sleep 2

      Sidekiq::Testing.fake! do
        expect(RequestSearchWorker.jobs.size).to eq 0
        expect { Tasks::WorkersHandler.execute(3, 80, max_queue: 200, stop_queue: 150) }.to change { RequestSearchWorker.jobs.size }.by(160)
        expect(RequestSearchWorker.jobs.size).to eq 160
        expect(Request.find(req1.id).status).to eq EasySettings.status.working
        expect(Request.find(req1.id).updated_at).not_to eq req1.updated_at
        expect(Request.find(req2.id).status).to eq EasySettings.status.working
        expect(Request.find(req3.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req3.id).updated_at).to eq req3.updated_at
        expect(Request.find(req4.id).status).to eq EasySettings.status.working
        expect(Request.find(req5.id).status).to eq EasySettings.status.working
        expect(Request.find(req5.id).updated_at).to eq req5.updated_at

        expect(Request.find(req1.id).get_new_urls.size).to eq 10
        expect(Request.find(req1.id).get_only_waiting_urls.size).to eq 80
        expect(Request.find(req2.id).get_new_urls.size).to eq 10
        expect(Request.find(req2.id).get_only_waiting_urls.size).to eq 80
        expect(Request.find(req3.id).get_new_urls.size).to eq 0
        expect(Request.find(req3.id).get_working_urls.size).to eq 3
        expect(Request.find(req4.id).get_new_urls.size).to eq 3
        expect(Request.find(req4.id).get_only_waiting_urls.size).to eq 0
        expect(Request.find(req5.id).get_new_urls.size).to eq 5
        expect(Request.find(req5.id).get_only_waiting_urls.size).to eq 0
      end
    end

    it '150を超えたら、リクエスト投下が中断される2' do

      req6 = create(:request, user: user, status: EasySettings.status.new)

      70.times do |i|
        create(:company_info_requested_url, request: req6, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req7 = create(:request, user: user, status: EasySettings.status.working)

      70.times do |i|
        create(:company_info_requested_url, request: req7, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      req8 = create(:request, user: user, status: EasySettings.status.new)

      70.times do |i|
        create(:company_info_requested_url, request: req8, status: EasySettings.status.new, url: 'https://www.hokkaido.ccbc.co.jp/')
      end

      Sidekiq::Testing.fake! do
        expect(RequestSearchWorker.jobs.size).to eq 0
        expect { Tasks::WorkersHandler.execute(4, 40, max_queue: 200, stop_queue: 150) }.to change { RequestSearchWorker.jobs.size }.by(180)
        expect(RequestSearchWorker.jobs.size).to eq 180
        expect(Request.find(req6.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req7.id).status).to eq EasySettings.status.all_working
        expect(Request.find(req8.id).status).to eq EasySettings.status.working

        expect(Request.find(req6.id).get_new_urls.size).to eq 0
        expect(Request.find(req6.id).get_only_waiting_urls.size).to eq 70
        expect(Request.find(req7.id).get_new_urls.size).to eq 0
        expect(Request.find(req7.id).get_only_waiting_urls.size).to eq 70
        expect(Request.find(req8.id).get_new_urls.size).to eq 30
        expect(Request.find(req8.id).get_only_waiting_urls.size).to eq 40
      end
    end
  end
end

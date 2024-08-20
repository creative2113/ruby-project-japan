require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RequestSearchWorker, type: :worker do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  let_it_be(:public_user) { create(:user_public) }

  let(:user)      { create(:user, billing: :credit) }
  let!(:plan)     { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
  let(:user_plan) { plan; user.my_plan_number }

  before do
    Sidekiq::Worker.clear_all
    ActionMailer::Base.deliveries.clear
    AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'example.com'])
    SealedPage.delete_items(['www.hokkaido.ccbc.co.jp', 'www.kurashijouzu.jp', 'example.com'])

    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end

  describe 'performのテスト' do

    let_it_be(:user) { create(:user, billing: :credit) }
    let_it_be(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
    let!(:history)  { create(:monthly_history, user: user, plan: user_plan) }
    let(:status)    { EasySettings.status.new }
    let(:req)       { create(:request, user: user, status: status, plan: user_plan ) }

    let(:req_url)  { create(:requested_url, request: req, url: 'https://www.hokkaido.ccbc.co.jp/', domain: 'www.hokkaido.ccbc.co.jp') }
    let(:req_url2) { create(:requested_url, request: req, url: 'https://www.nexway.co.jp/',        domain: 'www.nexway.co.jp') }

    before do
      # create(:monthly_history, user: user, plan: user.billing.plan)
      prepare_safe_stub
      # ActionMailer::Base.deliveries.clear
      cc = Crawler::Corporate.new('https://www.hokkaido.ccbc.co.jp/')
      cc.set({accessed_urls: ["www.hokkaido.ccbc.co.jp/", "www.hokkaido.ccbc.co.jp/company/company.html"],
              first_result: [['address', '','札幌市清田区清田一条一丁目2番1号'],['telephone number', '', 'TEL(011)888-2001 (総務人事部)']],
              optional_result: {additional_company_info: []},
              page_title: extract_value('title', RES_HOKKAIDO_COCA_COLA),
              result2: make_result2(RES_HOKKAIDO_COCA_COLA),
              seal_page_flag: false,
              target_page_urls: HOKKAIDO_COCA_COLA_TARGET_URLS
            })
      prepare_crawler_stub(cc)

      # https://www.hokkaido.ccbc.co.jp/のSSL証明書が有効期限切れの場合を考慮
      allow(Url).to receive(:get_response) do |url, _|
        http = Net::HTTP.new(url.host)
        http.verify_mode=OpenSSL::SSL::VERIFY_NONE
        http.get(url)
      end
    end

    context 'プランユーザの場合' do
      let(:user) { create(:user) }

      it do
        Sidekiq::Testing.fake! do
          expect { RequestSearchWorker.perform_async(req_url.id) }.to change { RequestSearchWorker.jobs.size }.by(1)
          expect(req_url.reload.status).to eq EasySettings.status.new
          expect(req.reload.status).to eq EasySettings.status.new
          RequestSearchWorker.drain
          expect(req_url.reload.status).to eq EasySettings.status.completed

          expect(ActionMailer::Base.deliveries.size).to eq(0)
        end
      end

      context 'Requestのステータスがstopの場合' do
        let(:status) { EasySettings.status.discontinued }

        it 'RequestUrlは完了にならない' do

          Sidekiq::Testing.fake! do
            expect { RequestSearchWorker.perform_async(req_url.id) }.to change { RequestSearchWorker.jobs.size }.by(1)
            expect(RequestedUrl.find(req_url.id).status).to eq EasySettings.status.new
            expect(Request.find(req.id).status).to eq EasySettings.status.discontinued
            RequestSearchWorker.drain
            expect(RequestedUrl.find(req_url.id).status).to eq EasySettings.status.discontinued
            expect(req.reload.status).to eq EasySettings.status.discontinued

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end
    end

    context 'パブリックユーザの場合' do
      let(:user) { User.get_public }

      context 'RequestUrlが複数あり、全て完了にならない場合' do
        it 'Requestのステータスはnewのまま' do

          Sidekiq::Testing.fake! do
            expect { RequestSearchWorker.perform_async(req_url.id) }.to change { RequestSearchWorker.jobs.size }.by(1)
            expect(RequestedUrl.find(req_url.id).status).to eq EasySettings.status.new
            expect(RequestedUrl.find(req_url2.id).status).to eq EasySettings.status.new
            expect(Request.find(req.id).status).to eq EasySettings.status.new
            RequestSearchWorker.drain
            expect(RequestedUrl.find(req_url.id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(req_url2.id).status).to eq EasySettings.status.new
            expect(Request.find(req.id).status).to eq EasySettings.status.new

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end

      context 'メールアドレスが指定された場合' do
        let(:req) { create(:request, user: user, plan: user_plan) }

        it 'Requestのステータスが完了になる' do

          Sidekiq::Testing.fake! do
            expect { RequestSearchWorker.perform_async(req_url.id) }.to change { RequestSearchWorker.jobs.size }.by(1)
            expect(RequestedUrl.find(req_url.id).status).to eq EasySettings.status.new
            expect(Request.find(req.id).status).to eq EasySettings.status.new
            RequestSearchWorker.drain
            expect(req_url.reload.status).to eq EasySettings.status.completed

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end

      context 'メールアドレスが空の場合' do
        let(:req) { create(:request, mail_address: '', user: user, plan: user_plan) }

        it 'Requestのステータスが完了になる' do

          Sidekiq::Testing.fake! do
            expect { RequestSearchWorker.perform_async(req_url.id) }.to change { RequestSearchWorker.jobs.size }.by(1)
            expect(RequestedUrl.find(req_url.id).status).to eq EasySettings.status.new
            expect(Request.find(req.id).status).to eq EasySettings.status.new
            RequestSearchWorker.drain
            expect(req_url.reload.status).to eq EasySettings.status.completed

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end
    end
  end

  describe 'execute_searchのテスト' do
    let_it_be(:user)         { create(:user, billing: :credit) }
    let_it_be(:plan)         { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }
    let!(:history)           { create(:monthly_history, user: user, plan: user_plan, acquisition_count: acquisition_count) }
    let(:request)            { create(:request, user: user, plan: user_plan, use_storage: use_storage, using_storage_days: using_storage_days) }
    let(:use_storage)        { false }
    let(:using_storage_days) { 0 }
    let(:domain)             { 'example.com' }
    let(:url)                { 'http://' + domain + '/' }
    let(:acquisition_count)  { 0 }
    let(:requested_url)      { create(:requested_url, url: url,
                                                      request_id: request.id ) }
    describe "#execute_search" do

      describe 'Sideki再起動中に関して' do
        let(:file_name) { "sidekiq_reboot_for_test_#{Random.alphanumeric}" }
        let(:cntl_path) { "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}" }
        before do
          # パラレルテストで他のrspecに影響が出るので
          allow(EasySettings.control_files).to receive('[]').and_return(file_name)
          FileUtils.touch(cntl_path)
        end
        after { FileUtils.rm_f(cntl_path) }

        context 'sidekiq_rebootファイルがあるとき' do

          it 'ステータスがnewで終了すること' do
            Sidekiq::Testing.fake! do
              id = requested_url.id

              RequestSearchWorker.perform_async(id)
              RequestSearchWorker.drain

              expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.new
              expect(RequestedUrl.find(id).status).to eq EasySettings.status.new
              expect(history.reload.acquisition_count).to eq 0
            end
          end
        end
      end

      describe 'ドメインチェックに関して' do
        context '最初のチェック' do
          let(:domain) { 'example.cn' }

          it 'banned_domainで終了すること' do
            Sidekiq::Testing.fake! do
              id = requested_url.id

              RequestSearchWorker.perform_async(id)
              RequestSearchWorker.drain

              expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.banned_domain
              expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
              expect(RequestedUrl.find(id).domain).to be_nil
              expect(history.reload.acquisition_count).to eq 0
            end
          end
        end

        context '最終ドメインのチェック' do
          let(:domain) { 'example.com' }

          before do
            allow(Url).to receive(:get_final_domain).and_return( 'example.cn' )
          end

          it 'banned_domainで終了すること' do
            Sidekiq::Testing.fake! do
              id = requested_url.id

              RequestSearchWorker.perform_async(id)
              RequestSearchWorker.drain

              expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.banned_domain
              expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
              expect(RequestedUrl.find(id).domain).to be_nil
              expect(history.reload.acquisition_count).to eq 0
            end
          end
        end
      end

      describe '存在しないページの企業(Company)レコードを削除する' do
        context '存在しないページのドメイン' do
          let(:domain) { 'dfsafsfdfsdfwewe.com' }
          let!(:company) { create(:company, domain: domain) }

          before { prepare_safe_stub }

          context '企業DBを利用' do
            let(:request) { create(:request, type: Request.types[:company_db_search], user: user, plan: user_plan, use_storage: use_storage, using_storage_days: using_storage_days) }

            it 'invalid urlで終了すること。企業レコードが削除されること' do
              Sidekiq::Testing.fake! do
                id = requested_url.id

                expect(Company.find_by(id: company.id)).to be_present

                RequestSearchWorker.perform_async(id)
                RequestSearchWorker.drain

                expect(Company.find_by(id: company.id)).to be_nil

                expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.invalid_url
                expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
                expect(RequestedUrl.find(id).domain).to be_nil
                expect(history.reload.acquisition_count).to eq 0
              end
            end
          end

          context '企業DBを利用ではない時' do
            it 'invalid urlで終了すること。企業レコードが削除されないこと' do
              Sidekiq::Testing.fake! do
                id = requested_url.id

                expect(Company.find_by(id: company.id)).to be_present

                RequestSearchWorker.perform_async(id)
                RequestSearchWorker.drain

                expect(Company.find_by(id: company.id)).to be_present

                expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.invalid_url
                expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
                expect(RequestedUrl.find(id).domain).to be_nil
                expect(history.reload.acquisition_count).to eq 0
              end
            end
          end
        end
      end

      describe '安全チェックに関して' do
        let(:domain) { 'example.com' }

        before { allow_any_instance_of(Crawler::Corporate).to receive(:start).and_return(true) }

        context 'SealedPageに安全でないと登録されている時' do
          before { SealedPage.create(:unsafe, {count: 5}) }

          it 'unsafe_and_sealed_pageで終了すること' do
            Sidekiq::Testing.fake! do
              id = requested_url.id

              RequestSearchWorker.perform_async(id)
              RequestSearchWorker.drain

              expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.unsafe_and_sealed_page
              expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
              expect(RequestedUrl.find(id).domain).to be_nil

              sealed_site = SealedPage.new(domain).get
              expect(sealed_site.count).to eq 5
              expect(sealed_site.last_access_date).to eq Time.zone.today - 3.day
              expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
              expect(sealed_site.reason).to eq EasySettings.sealed_reason['unsafe']
              expect(history.reload.acquisition_count).to eq 0
            end
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(0) }
        end

        context '安全でないと登録されているが、再チェックで安全と判定された時' do
          before do
            SealedPage.create(:unsafe, {count: 3})
          end

          context '取得できない時' do
            it 'can_not_get_infoで終了すること。安全と判明し、sealed_pageから一旦削除されるが、再度、取得できないで登録される' do
              id = requested_url.id

              RequestSearchWorker.perform_async(id)
              RequestSearchWorker.drain

              req_url = RequestedUrl.find(id).reload
              expect(req_url.finish_status).to eq EasySettings.finish_status.can_not_get_info
              expect(req_url.status).to eq EasySettings.status.completed
              expect(req_url.domain).to be_nil

              sealed_site = SealedPage.new(domain).get
              expect(sealed_site.count).to eq 1
              expect(sealed_site.last_access_date).to eq Time.zone.today
              expect(sealed_site.domain_type).to eq EasySettings.domain_type['final']
              expect(sealed_site.reason).to eq EasySettings.sealed_reason['can_not_get']
              expect(history.reload.acquisition_count).to eq 0
            end
          end
        end

        context '安全か不明と登録されているが、再チェックでgoogleから安全でないと判定された場合' do

          before do
            SealedPage.create(:unknown)
            allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, 'unsafe']) )
          end

          it 'unsafe_pageで終了すること、SealedPageが更新されること' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            req_url = RequestedUrl.find(id).reload
            expect(req_url.finish_status).to eq EasySettings.finish_status.unsafe_page
            expect(req_url.status).to eq EasySettings.status.completed
            expect(req_url.domain).to be_nil

            sealed_site = SealedPage.new(domain).get
            expect(sealed_site.count).to eq 2
            expect(sealed_site.last_access_date).to eq Time.zone.today
            expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
            expect(sealed_site.reason).to eq EasySettings.sealed_reason['unsafe']
            expect(history.reload.acquisition_count).to eq 0
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(0) }
        end

        context 'googleから安全でないと判定された時' do

          before do
            allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, 'unsafe']) )
          end

          it 'unsafe_pageで終了すること、SealedPageに登録されること' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.unsafe_page
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to be_nil

            sealed_site = SealedPage.new(domain).get
            expect(sealed_site.count).to eq 1
            expect(sealed_site.last_access_date).to eq Time.zone.today
            expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
            expect(sealed_site.reason).to eq EasySettings.sealed_reason['unsafe']
            expect(history.reload.acquisition_count).to eq 0
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(1) }
        end

        xcontext 'Be judged "unknown" in google url safety check but be judged "Dangerous" in trendmicro url safety check' do

          before do
            allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, 'No available data']),
                                                                        Crawler::UrlSafeChecker.new(url, :dummy, [:trendmicro, 'Dangerous']))
          end

          it 'unsafe_pageで終了すること、SealedPageに登録されること' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.unsafe_page
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to be_nil

            sealed_site = SealedPage.new(domain).get
            expect(sealed_site.count).to eq 1
            expect(sealed_site.last_access_date).to eq Time.zone.today
            expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
            expect(sealed_site.reason).to eq EasySettings.sealed_reason['unknown']
            expect(history.reload.acquisition_count).to eq 0
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(1) }
        end
      end

      describe 'sealed_pageに関して' do
        before { SealedPage.create(:can_not_get, { domain: domain, count: EasySettings.access_limit_to_sealed_page + 1 }) }

        it 'sealed_page制限に引っかかって終了すること' do
          id = requested_url.id

          RequestSearchWorker.perform_async(id)
          RequestSearchWorker.drain

          expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.access_sealed_page
          expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
          expect(RequestedUrl.find(id).domain).to be_nil
          expect(history.reload.acquisition_count).to eq 0
        end
      end

      describe '月間取得件数制限に関して' do
        context 'プランユーザの場合' do
          let(:acquisition_count)  { EasySettings.monthly_acquisition_limit[user.my_plan] }
          it '月間取得件数制限に引っかかること' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.monthly_limit
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to be_nil
            expect(history.reload.acquisition_count).to eq acquisition_count
          end
        end
      end

      describe 'access_recordに関して' do
        let(:use_storage)        { true }
        let(:using_storage_days) { 3 }
        let(:count)              { 1 }
        let!(:access_record)     { AccessRecord.create(domain: domain, count: count, result: {name: 'a', value: 'b', priority: 1}) }

        before { allow_any_instance_of(Crawler::Corporate).to receive(:start).and_return(true) }

        context '月間取得件数制限になっていない' do
          it 'access_recordのデータを使って終了すること' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.using_storaged_date
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to eq access_record.domain
            expect(AccessRecord.new(domain).get.count).to eq count + 1
            expect(history.reload.acquisition_count).to eq 1
            expect(requested_url.result.reload.main).to be_present
          end
        end

        context '月間取得件数制限になっている' do
          let(:acquisition_count)  { EasySettings.monthly_acquisition_limit[user.my_plan] }

          before { allow_any_instance_of(described_class).to receive(:over_monthly_limit?).and_return(false) }

          it '月間取得件数制限に引っかかること' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.monthly_limit
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to eq access_record.domain
            expect(AccessRecord.new(domain).get.count).to eq count + 1
            expect(history.reload.acquisition_count).to eq EasySettings.monthly_acquisition_limit[user.my_plan]
            expect(requested_url.result.reload.main).to be_nil
          end
        end
      end

      describe '情報を取得できないページに関して' do

        context 'URLの形式が間違っている場合' do
          let(:url) { 'http:abc.com' }
          it '無効URLと判定されて終了すること、SealedPageにもAccessRecordにも登録されないこと' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.invalid_url
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to be_nil
            expect(history.reload.acquisition_count).to eq 0
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(AccessRecord, :get_count).by(0) }
          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(0) }
        end

        context '存在しないページの場合' do
          let(:domain) { 'abcabcabc' }

          before { prepare_safe_stub }

          it '無効URLと判定されて終了すること、SealedPageにもAccessRecordにも登録されないこと' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.invalid_url
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to be_nil
            expect(history.reload.acquisition_count).to eq 0
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(AccessRecord, :get_count).by(0) }
          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(0) }
        end

        context '会社情報のないページに関して' do
          let(:domain) { 'www.kurashijouzu.jp' }

          before do
            prepare_safe_stub
            cp = Crawler::Corporate.new(url)
            cp.set({optional_result: {additional_company_info: []},
                    page_title: "丁寧に、心地よく暮らす。「暮らし上手」",
                    result2: [{:name=>"title", :value=>"丁寧に、心地よく暮らす。「暮らし上手」"}]},
                  )
            allow(Crawler::Corporate).to receive(:new).and_return(cp)
            allow_any_instance_of(Crawler::Corporate).to receive(:start).and_return(true)
          end

          it '情報を取得できずに終了すること、SealedPageには登録されるが、AccessRecordには登録されないこと' do
            id = requested_url.id

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(RequestedUrl.find(id).finish_status).to eq EasySettings.finish_status.can_not_get_info
            expect(RequestedUrl.find(id).status).to eq EasySettings.status.completed
            expect(RequestedUrl.find(id).domain).to be_nil

            sealed_page = SealedPage.new(domain).get
            expect(sealed_page.count).to eq 1
            expect(sealed_page.last_access_date).to eq Time.zone.today
            expect(history.reload.acquisition_count).to eq 0
          end

          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(AccessRecord, :get_count).by(0) }
          it { expect{ RequestSearchWorker.perform_async(requested_url.id); RequestSearchWorker.drain }.to change(SealedPage, :get_count).by(1) }
        end

        context 'クロールサーチでエラーになる場合' do
          let(:domain)     { 'www.hokkaido.ccbc.co.jp' }
          let(:req_url_id) { requested_url.id }
          let(:req_url)    { requested_url.reload }

          before do
            create(:requested_url, request_id: request.id )
            ActionMailer::Base.deliveries.clear
            prepare_safe_stub
            cp = Crawler::Corporate.new(url)
            allow(Crawler::Corporate).to receive(:new).and_return(cp)
            allow_any_instance_of(Crawler::Corporate).to receive(:start).and_raise(error)
          end

          context 'NameErrorになる場合' do
            let(:error) { NameError }

            it '情報を取得できずに完了になること、AccessRecordには登録されないこと' do
              Sidekiq::Testing.fake! do
                RequestSearchWorker.perform_async(req_url_id)
                RequestSearchWorker.drain

                expect(req_url.finish_status).to eq EasySettings.finish_status.error
                expect(req_url.status).to eq EasySettings.status.completed
                expect(req_url.domain).to eq domain
                expect(req_url.retry_count).to eq 0
                expect(history.reload.acquisition_count).to eq 0

                expect(ActionMailer::Base.deliveries.size).to eq(0)
                # expect(ActionMailer::Base.deliveries[0].subject).to match(/クローラサーチエラー/)
              end
            end

            it { Sidekiq::Testing.fake! { expect{ RequestSearchWorker.perform_async(req_url_id); RequestSearchWorker.drain }.to change(AccessRecord, :get_count).by(0) } }
          end

          context 'ScrapingAlchemistCanNotDocWithUnrepeatableErrorになる場合' do
            let(:error) { Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocWithUnrepeatableError }

            it '情報を取得できずに完了になること、AccessRecordには登録されないこと。メールは飛ばないこと。リトライはしないこと。' do
              Sidekiq::Testing.fake! do
                RequestSearchWorker.perform_async(req_url_id)
                RequestSearchWorker.drain

                expect(req_url.finish_status).to eq EasySettings.finish_status.unexist_page
                expect(req_url.status).to eq EasySettings.status.completed
                expect(req_url.domain).to eq domain
                expect(req_url.retry_count).to eq 0
                expect(history.reload.acquisition_count).to eq 0

                expect(ActionMailer::Base.deliveries.size).to eq(0)
              end
            end

            it { Sidekiq::Testing.fake! { expect{ RequestSearchWorker.perform_async(req_url_id); RequestSearchWorker.drain }.to change(AccessRecord, :get_count).by(0) } }
          end

          context 'ScrapingAlchemistCanNotDocErrorになる場合' do
            let(:error) { Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocError }

            it '情報を取得できずにエラー終了すること、AccessRecordには登録されないこと。メールは飛ばないこと。リトライカウントが増えること。' do
              Sidekiq::Testing.fake! do
                e = nil

                RequestSearchWorker.perform_async(req_url_id)
                begin
                  RequestSearchWorker.drain
                rescue => e
                  expect(e.class).to eq error
                end
                expect(e).not_to be_nil

                expect(req_url.finish_status).to eq EasySettings.finish_status.network_error
                expect(req_url.status).to eq EasySettings.status.retry
                expect(req_url.domain).to be_nil
                expect(req_url.retry_count).to eq 1
                expect(history.reload.acquisition_count).to eq 0

                expect(ActionMailer::Base.deliveries.size).to eq(0)
              end
            end

            it 'AccessRecordは増えないこと' do
              Sidekiq::Testing.fake! do
                expect{ RequestSearchWorker.perform_async(req_url_id)
                        begin
                           RequestSearchWorker.drain
                        rescue
                        end
                      }.to change(AccessRecord, :get_count).by(0)
              end
            end
          end
        end
      end

      describe '正常終了' do
        let(:domain) { 'www.hokkaido.ccbc.co.jp' }

        let!(:capital_group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
        let!(:capital_group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10_000_000, lower: 0) }
        let!(:capital_group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 100_000_000, lower: 10_000_001) }
        let!(:capital_group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 100_000_001) }
        let!(:employee_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: nil) }
        let!(:employee_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 50, lower: 0) }
        let!(:employee_group3) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 500, lower: 51) }
        let!(:employee_group4) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 501) }
        let!(:salse_group1) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: nil) }
        let!(:salse_group2) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 100_000_000, lower: 0) }
        let!(:salse_group3) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 10_000_000_000, lower: 100_000_001) }
        let!(:salse_group4) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: 10_000_000_001) }
        let!(:company) { create(:company, domain: domain) }

        before do
          Timecop.freeze(current_time)
          prepare_safe_stub
          cc = Crawler::Corporate.new(url)
          cc.set({accessed_urls: HOKKAIDO_COCA_COLA_ACCESSED_URLS,
                  first_result: [['address', '','札幌市清田区清田一条一丁目2番1号'],['telephone number', '', 'TEL(011)888-2001 (総務人事部)']],
                  optional_result: {additional_company_info: []},
                  page_title: extract_value('title', RES_HOKKAIDO_COCA_COLA),
                  result2: make_result2(RES_HOKKAIDO_COCA_COLA),
                  seal_page_flag: false,
                  target_page_urls: HOKKAIDO_COCA_COLA_TARGET_URLS
                })
          prepare_crawler_stub(cc)
        end
        after  { Timecop.return }

        context 'まだアクセスしていない場合、かつ、company_groupが未登録' do
          it '情報を取得できること' do
            id = requested_url.id

            access_record_cnt = AccessRecord.get_count
            sealed_page_cnt = SealedPage.get_count

            # 登録がないこと
            expect(company.company_company_groups.size).to eq 0

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(requested_url.reload.finish_status).to eq EasySettings.finish_status.successful
            expect(requested_url.status).to eq EasySettings.status.completed
            expect(requested_url.domain).to eq AccessRecord.new(domain).get.domain

            # company_group登録の確認
            expect(company.company_company_groups.reload.size).to eq 3
            expect(company.company_company_groups[0].company_group).to eq capital_group4
            expect(company.company_company_groups[0].source).to eq 'corporate_site'
            expect(company.company_company_groups[0].expired_at).to eq (Time.zone.now + CompanyCompanyGroup.source_list['corporate_site'][:expired_at]).iso8601
            expect(company.company_company_groups[1].company_group).to eq employee_group3
            expect(company.company_company_groups[1].source).to eq 'corporate_site'
            expect(company.company_company_groups[1].expired_at).to eq (Time.zone.now + CompanyCompanyGroup.source_list['corporate_site'][:expired_at]).iso8601
            expect(company.company_company_groups[2].company_group).to eq salse_group1
            expect(company.company_company_groups[2].source).to eq 'corporate_site'
            expect(company.company_company_groups[2].expired_at).to eq (Time.zone.now + CompanyCompanyGroup.source_list['corporate_site'][:expired_at]).iso8601


            access_record = AccessRecord.new(RequestedUrl.find(id).domain).get

            expect(access_record.count).to eq 1
            expect(access_record.domain).to eq domain
            expect(access_record.last_access_date).to eq current_time
            expect(access_record.name).to eq extract_value('商 号', RES_HOKKAIDO_COCA_COLA)
            expect(access_record.result).to eq delite_index_path(RES_HOKKAIDO_COCA_COLA)
            expect(access_record.last_fetch_date).to eq Time.zone.now
            expect(access_record.urls).to eq HOKKAIDO_COCA_COLA_TARGET_URLS
            expect(access_record.accessed_urls).to eq HOKKAIDO_COCA_COLA_ACCESSED_URLS

            expect(history.reload.acquisition_count).to eq 1

            # 増減の確認
            expect(AccessRecord.get_count).to eq access_record_cnt + 1
            expect(SealedPage.get_count).to eq sealed_page_cnt
          end
        end

        context '一度アクセスしている場合、かつ、company_groupを保有している' do
          let(:count)         { 3 }
          let(:access_record) { AccessRecord.create(domain: domain,
                                                    count: count,
                                                    result: {a: 'b'},
                                                    last_access_date: Time.zone.now - 2.days,
                                                    last_fetch_date: Time.zone.today - 2.days) }

          let(:initial_source) { 'biz_map' }
          let!(:company_capital_group) { create(:company_company_group, company: company, company_group: capital_group2, source: initial_source) }
          let!(:company_employee_group) { create(:company_company_group, company: company, company_group: employee_group1, source: initial_source) }
          let!(:company_salse_group) { create(:company_company_group, company: company, company_group: salse_group2, source: initial_source, expired_at: 3.months.from_now) }

          before { access_record }

          it '情報を取得でき、AccessRecordを更新できること' do
            id = requested_url.id

            access_record_cnt = AccessRecord.get_count
            sealed_page_cnt = SealedPage.get_count

            # 登録がないこと
            expect(company.company_company_groups.size).to eq 3

            RequestSearchWorker.perform_async(id)
            RequestSearchWorker.drain

            expect(requested_url.reload.finish_status).to eq EasySettings.finish_status.successful
            expect(requested_url.status).to eq EasySettings.status.completed
            expect(requested_url.domain).to eq access_record.domain

            # company_group登録の確認
            expect(company.company_company_groups.reload.size).to eq 3
            expect(company.company_company_groups[0].company_group).to eq capital_group4
            expect(company.company_company_groups[0].source).to eq 'corporate_site'
            expect(company.company_company_groups[0].expired_at).to eq (Time.zone.now + CompanyCompanyGroup.source_list['corporate_site'][:expired_at]).iso8601
            expect(company.company_company_groups[1].company_group).to eq employee_group3
            expect(company.company_company_groups[1].source).to eq 'corporate_site'
            expect(company.company_company_groups[1].expired_at).to eq (Time.zone.now + CompanyCompanyGroup.source_list['corporate_site'][:expired_at]).iso8601
            expect(company.company_company_groups[2].company_group).to eq salse_group2 # nilには更新されない
            expect(company.company_company_groups[2].source).to eq initial_source
            expect(company.company_company_groups[2].expired_at).to eq 3.months.from_now.iso8601


            access_record = AccessRecord.new(RequestedUrl.find(id).domain).get

            expect(access_record.count).to eq count + 1
            expect(access_record.domain).to eq domain
            expect(access_record.last_access_date).to eq current_time
            expect(access_record.name).to eq RES_HOKKAIDO_COCA_COLA[2][:value].to_s
            expect(access_record.result).to eq delite_index_path(RES_HOKKAIDO_COCA_COLA)
            expect(access_record.last_fetch_date).to eq Time.zone.now
            expect(access_record.urls).to eq HOKKAIDO_COCA_COLA_TARGET_URLS
            expect(access_record.accessed_urls).to eq HOKKAIDO_COCA_COLA_ACCESSED_URLS

            expect(history.reload.acquisition_count).to eq 1

            # 増減がないこと
            expect(AccessRecord.get_count).to eq access_record_cnt
            expect(SealedPage.get_count).to eq sealed_page_cnt
          end

          describe '月間取得件数制限に関して' do
            context 'corporate_list_siteの場合' do
              let(:request) { create(:request, user: user, plan: user_plan, type: Request.types[:corporate_list_site], use_storage: use_storage, using_storage_days: using_storage_days) }
              let(:acquisition_count)  { EasySettings.monthly_acquisition_limit[user.my_plan] + 3 }
              it '月間取得件数制限に引っかからないこと' do
                id = requested_url.id

                RequestSearchWorker.perform_async(id)
                RequestSearchWorker.drain

                expect(requested_url.reload.finish_status).to eq EasySettings.finish_status.successful
                expect(requested_url.status).to eq EasySettings.status.completed
                expect(requested_url.domain).to eq domain
                expect(history.reload.acquisition_count).to eq acquisition_count
              end
            end
          end
        end
      end
    end
  end
end

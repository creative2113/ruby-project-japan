require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe SearchWorker, type: :worker do

  let_it_be(:public_user) { create(:user_public) }

  before do
    Sidekiq::Worker.clear_all
    AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'example.com', 'www.example.com'])
    SealedPage.delete_items(['www.hokkaido.ccbc.co.jp', 'www.kurashijouzu.jp', 'example.com', 'www.example.com'])
  end

  describe 'performのテスト' do

    let(:user)   { create(:user) }
    let(:status) { EasySettings.status.new }
    let(:domain) { 'www.hokkaido.ccbc.co.jp' }
    let(:url)    { "https://#{domain}/" }
    let(:req)    { create(:search_request, user: user, url: url, domain: domain, status: status ) }

    before do
      prepare_safe_stub
      ActionMailer::Base.deliveries.clear
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

    describe 'performのテスト' do
      context 'プランユーザの場合' do
        let(:user) { create(:user) }

        it 'Requestのステータスは完了になり、メールは送られない' do
          Sidekiq::Testing.fake! do
            expect { SearchWorker.perform_async(req.id) }.to change { SearchWorker.jobs.size }.by(1)
            expect(SearchRequest.find(req.id).status).to eq EasySettings.status.new
            SearchWorker.drain
            expect(SearchRequest.find(req.id).status).to eq EasySettings.status.completed

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end

        describe 'company_groupに関して' do

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

          before { Timecop.freeze(current_time) }
          after  { Timecop.return }

          context 'companyが存在しない' do
            it do
              Sidekiq::Testing.fake! do
                expect { SearchWorker.perform_async(req.id) }.to change { SearchWorker.jobs.size }.by(1)
                expect(SearchRequest.find(req.id).status).to eq EasySettings.status.new

                count = CompanyCompanyGroup.count

                SearchWorker.drain
                expect(SearchRequest.find(req.id).status).to eq EasySettings.status.completed

                # CompanyCompanyGroupのカウントが増えないこと
                expect(CompanyCompanyGroup.count).to eq count

                expect(Company.find_by(domain: domain)).to be_nil
              end
            end
          end

          context 'companyが存在しない' do
            let!(:company) { create(:company, domain: domain) }

            context 'company_groupが未登録' do
              it '新しいcompany_groupが登録されること' do
                Sidekiq::Testing.fake! do
                  expect { SearchWorker.perform_async(req.id) }.to change { SearchWorker.jobs.size }.by(1)
                  expect(SearchRequest.find(req.id).status).to eq EasySettings.status.new

                  # 登録がないこと
                  expect(company.company_company_groups.size).to eq 0

                  SearchWorker.drain
                  expect(SearchRequest.find(req.id).status).to eq EasySettings.status.completed

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
                end
              end
            end

            context 'company_groupを保有している' do
              let(:initial_source) { 'biz_map' }
              let!(:company_capital_group) { create(:company_company_group, company: company, company_group: capital_group2, source: initial_source) }
              let!(:company_employee_group) { create(:company_company_group, company: company, company_group: employee_group1, source: initial_source) }
              let!(:company_salse_group) { create(:company_company_group, company: company, company_group: salse_group2, source: initial_source, expired_at: 3.months.from_now) }
            
              it '新しいcompany_groupに更新されること & SALESは更新されないこと' do
                Sidekiq::Testing.fake! do
                  expect { SearchWorker.perform_async(req.id) }.to change { SearchWorker.jobs.size }.by(1)
                  expect(SearchRequest.find(req.id).status).to eq EasySettings.status.new

                  expect(company.company_company_groups.size).to eq 3

                  SearchWorker.drain
                  expect(SearchRequest.find(req.id).status).to eq EasySettings.status.completed

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
                end
              end
            end
          end
        end
      end

      context 'パブリックユーザの場合' do
        let(:user) { User.get_public }

        it 'Requestのステータスは完了になり、メールは送られない' do

          Sidekiq::Testing.fake! do
            expect { SearchWorker.perform_async(req.id) }.to change { SearchWorker.jobs.size }.by(1)
            expect(SearchRequest.find(req.id).status).to eq EasySettings.status.new
            SearchWorker.drain
            expect(SearchRequest.find(req.id).status).to eq EasySettings.status.completed

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end
    end

    context 'クロールサーチでエラーになる場合' do
      let(:s_req)  { req.reload }

      before do
        allow_any_instance_of(Crawler::Corporate).to receive(:start).and_raise(error)
      end

      context 'NameErrorになる場合' do
        let(:error) { NameError }

        it '情報を取得できずに完了になること、AccessRecordには登録されないこと' do
          Sidekiq::Testing.fake! do
            SearchWorker.perform_async(req.id)
            SearchWorker.drain

            expect(s_req.finish_status).to eq EasySettings.finish_status.error
            expect(s_req.status).to eq EasySettings.status.completed
            expect(s_req.domain).to eq domain

            expect(ActionMailer::Base.deliveries.size).to eq(0)
            # expect(ActionMailer::Base.deliveries[0].subject).to match(/クローラサーチエラー/)
          end
        end

        it { Sidekiq::Testing.fake!{ expect{ SearchWorker.perform_async(req.id); SearchWorker.drain }.to change(AccessRecord, :get_count).by(0) } }
      end

      context 'ScrapingAlchemistCanNotDocWithUnrepeatableErrorになる場合' do
        let(:error) { Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocWithUnrepeatableError }

        it '情報を取得できずに完了になること、AccessRecordには登録されないこと。メールは飛ばないこと。' do
          Sidekiq::Testing.fake! do
            SearchWorker.perform_async(req.id)
            SearchWorker.drain

            expect(s_req.finish_status).to eq EasySettings.finish_status.unexist_page
            expect(s_req.status).to eq EasySettings.status.completed
            expect(s_req.domain).to eq domain

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end

        it { Sidekiq::Testing.fake! { expect{ SearchWorker.perform_async(req.id); SearchWorker.drain }.to change(AccessRecord, :get_count).by(0) } }
      end

      context 'ScrapingAlchemistCanNotDocErrorになる場合' do
        let(:error) { Crawler::Exceptions::ScrapingAlchemist::UnobtainableDocError }

        it '情報を取得できずにエラー終了すること、AccessRecordには登録されないこと。メールは飛ばないこと。リトライカウントが増えること。' do
          Sidekiq::Testing.fake! do

            SearchWorker.perform_async(req.id)
            SearchWorker.drain

            expect(s_req.finish_status).to eq EasySettings.finish_status.network_error
            expect(s_req.status).to eq EasySettings.status.completed
            expect(s_req.domain).to eq domain

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end

        it { Sidekiq::Testing.fake! { expect{ SearchWorker.perform_async(req.id); SearchWorker.drain }.to change(AccessRecord, :get_count).by(0) } }
      end
    end
  end
end

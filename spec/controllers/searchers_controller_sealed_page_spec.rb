require 'rails_helper'
require 'corporate_results'

RSpec.describe SearchersController, type: :controller do

  before do
    SealedPage.delete_items(['www.google.com', 'www.abcdefghi.com', 'www.samplesamplesampelaaaa.com', 'www.samplesamplesampelaaaa.com'])
  end

  describe "POST search" do
    subject { post :search_request, params: params }

    let(:user)   { create(:user) }
    let(:domain) { 'www.google.com' }
    let(:url)    { 'https://' + domain + '/' }
    let(:agree)  { 1 }
    let(:params) { { url: url, agree_terms_of_service: agree } }
    let(:body)   { JSON.parse(response.body).symbolize_keys }

    describe 'About Judge Safety' do

      before { sign_in user }

      context 'Be judged unsafe in sealed safety check' do
        before { SealedPage.create(:unsafe, { count: 6, domain: domain}) }

        it ':sealed_unsafe_urlでレンダーされること、ステータス400が返ること' do
          sp_count = SealedPage.get_count
          subject

          expect(assigns(:finish_status)).to eq :sealed_unsafe_url

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:unsafe_url]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq 6
          expect(sealed_site.last_access_date).to eq Time.zone.today - 3.day
          expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
          expect(sealed_site.reason).to eq EasySettings.sealed_reason['unsafe']

          expect(SealedPage.get_count).to eq sp_count
        end
      end

      context 'Be judged unsafe in sealed safety check but be judged safe in trendmicro url safety check' do
        let(:domain) { 'www.abcdefghi.com' }

        before do
          allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200}))
          SealedPage.create(:unsafe, { count: 2, domain: domain })
          allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:trendmicro, Crawler::UrlSafeChecker::TRENDMICRO_SITEADVISER_RATINGS[0]]) )
        end

        it ':invalid_urlでレンダーされること、ステータス400が返ること' do
          sp_count = SealedPage.get_count
          subject

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 200

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.exist?).to be_falsey

          expect(SealedPage.get_count).to eq sp_count - 1
        end
      end

      context 'Be judged unknown in sealed safety check but be judged unsafe in google url safety check' do

        before do
          SealedPage.create(:unknown, {domain: domain})
          allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, 'unsafe']) )
        end

        it ':checked_unsafe_urlでレンダーされること、ステータス400が返ること、SealedPageが更新されること' do
          sp_count = SealedPage.get_count
          subject

          expect(assigns(:finish_status)).to eq :checked_unsafe_url

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:unsafe_url]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq 2
          expect(sealed_site.last_access_date).to eq Time.zone.today
          expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
          expect(sealed_site.reason).to eq EasySettings.sealed_reason['unsafe']

          expect(SealedPage.get_count).to eq sp_count
        end
      end

      context 'Be judged unsafe in trendmicro url safety check' do

        before do
          allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:trendmicro, Crawler::UrlSafeChecker::TRENDMICRO_SITEADVISER_RATINGS[1]]) )
        end

        it ':checked_unsafe_urlでレンダーされること、ステータス400が返ること、SealedPageに登録されること' do
          sp_count = SealedPage.get_count
          subject

          expect(assigns(:finish_status)).to eq :checked_unsafe_url

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:unsafe_url]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq 1
          expect(sealed_site.last_access_date).to eq Time.zone.today
          expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
          expect(sealed_site.reason).to eq EasySettings.sealed_reason['unsafe']

          expect(SealedPage.get_count).to eq sp_count + 1
        end
      end

      xcontext 'Be judged unknown in google url safety check but be judged dangerous in trendmicro url safety check' do

        before do
          allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, Crawler::UrlSafeChecker::GOOGLE_CHECK_RATING[1]]),
                                                                      Crawler::UrlSafeChecker.new(url, :dummy, [:trendmicro, Crawler::UrlSafeChecker::TRENDMICRO_SITEADVISER_RATINGS[1]]))
        end

        it ':checked_unsafe_urlでレンダーされること、ステータス400が返ること、SealedPageに登録されること' do
          sp_count = SealedPage.get_count
          subject

          expect(assigns(:finish_status)).to eq :checked_unsafe_url

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:unsafe_url]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq 1
          expect(sealed_site.last_access_date).to eq Time.zone.today
          expect(sealed_site.domain_type).to eq EasySettings.domain_type['entrance']
          expect(sealed_site.reason).to eq EasySettings.sealed_reason['unknown']

          expect(SealedPage.get_count).to eq sp_count + 1
        end
      end

      context 'Be judged unknown in google and trendmicro url safety check' do
        let(:domain) { 'www.samplesamplesampelaaaa.com' }

        before do
          allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, Crawler::UrlSafeChecker::GOOGLE_CHECK_RATING[1]]),
                                                                      Crawler::UrlSafeChecker.new(url, :dummy, [:trendmicro, Crawler::UrlSafeChecker::TRENDMICRO_SITEADVISER_RATINGS[3]]))
        end

        it ':invalid_urlでレンダーされること、ステータス400が返ること、SealedPageに登録されないこと' do
          sp_count = SealedPage.get_count
          subject

          expect(assigns(:finish_status)).to eq :invalid_url

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:confirm_url]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.exist?).to be_falsey

          expect(SealedPage.get_count).to eq sp_count
        end
      end
    end

    describe 'パブリックユーザーによるSealedPageへのアクセス' do
      before { create_public_user }

      before do
        allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200}))
        allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, Crawler::UrlSafeChecker::GOOGLE_CHECK_RATING[0]]) )
      end

      context 'first access to sealed page' do
        it 'normal_finish、SealedPageは作られない' do
          sq_count = SearchRequest.count
          sp_count = SealedPage.get_count
          ac_count = AccessRecord.get_count
          subject

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 200
          expect(body[:complete]).to be_falsey
          expect(body[:accept_id]).to eq SearchRequest.where(url: url).last.accept_id

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.exist?).to be_falsey

          expect(SearchRequest.count).to eq sq_count + 1
          expect(SealedPage.get_count).to eq sp_count
          expect(AccessRecord.get_count).to eq ac_count
        end
      end

      context '3rd access to sealed page' do
        before { SealedPage.create(:can_not_get, { domain: domain, count: 2 }) }

        it 'normal_finish、SealedPageは更新されない' do
          sq_count = SearchRequest.count
          sp_count = SealedPage.get_count
          ac_count = AccessRecord.get_count
          before_sealed_site = SealedPage.new(domain).get

          subject

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 200
          expect(body[:complete]).to be_falsey
          expect(body[:accept_id]).to eq SearchRequest.where(url: url).last.accept_id

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq before_sealed_site.count
          expect(sealed_site.last_access_date).to eq before_sealed_site.last_access_date
          expect(sealed_site.domain_type).to eq before_sealed_site.domain_type
          expect(sealed_site.reason).to eq before_sealed_site.reason

          expect(SearchRequest.count).to eq sq_count + 1
          expect(SealedPage.get_count).to eq sp_count
          expect(AccessRecord.get_count).to eq ac_count
        end
      end

      context 'limit access to sealed page' do
        let(:access_count) { EasySettings.access_limit_to_sealed_page + 1 }
        before { SealedPage.create(:can_not_get, { domain: domain, count: access_count }) }

        it 'シールドされる、SealedPageは更新されない' do
          sq_count = SearchRequest.count
          sp_count = SealedPage.get_count
          ac_count = AccessRecord.get_count
          subject

          expect(assigns(:finish_status)).to eq :access_sealed_page

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:can_not_get_info]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq access_count
          expect(sealed_site.last_access_date).to eq Time.zone.today - 3.day
          expect(sealed_site.domain_type).to eq EasySettings.domain_type['final']
          expect(sealed_site.reason).to eq EasySettings.sealed_reason['can_not_get']

          expect(SearchRequest.count).to eq sq_count
          expect(SealedPage.get_count).to eq sp_count
          expect(AccessRecord.get_count).to eq ac_count
        end
      end
    end

    describe 'プランユーザによるSealedPageへのアクセス' do

      before do
        sign_in user
        allow_any_instance_of(BatchAccessor).to receive(:request_search).and_return(StabMaker.new({code: 200}))
        allow(Crawler::UrlSafeChecker).to receive(:new).and_return( Crawler::UrlSafeChecker.new(url, :dummy, [:google, Crawler::UrlSafeChecker::GOOGLE_CHECK_RATING[0]]) )
      end

      context 'first access to sealed page' do
        it 'normal_finish、SealedPageは作成されない' do
          sq_count = SearchRequest.count
          sp_count = SealedPage.get_count
          ac_count = AccessRecord.get_count
          subject

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 200
          expect(body[:complete]).to be_falsey
          expect(body[:accept_id]).to eq SearchRequest.where(url: url).last.accept_id

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.exist?).to be_falsey

          expect(SearchRequest.count).to eq sq_count + 1
          expect(SealedPage.get_count).to eq sp_count
          expect(AccessRecord.get_count).to eq ac_count
        end
      end

      context '3rd access to sealed page' do
        before { SealedPage.create(:can_not_get, { domain: domain, count: 2 }) }

        it 'normal_finish、SealedPageは更新されない' do
          sq_count = SearchRequest.count
          sp_count = SealedPage.get_count
          ac_count = AccessRecord.get_count
          before_sealed_site = SealedPage.new(domain).get

          subject

          expect(assigns(:finish_status)).to eq :normal_finish

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 200
          expect(body[:complete]).to be_falsey
          expect(body[:accept_id]).to eq SearchRequest.where(url: url).last.accept_id

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq before_sealed_site.count
          expect(sealed_site.last_access_date).to eq before_sealed_site.last_access_date
          expect(sealed_site.domain_type).to eq before_sealed_site.domain_type
          expect(sealed_site.reason).to eq before_sealed_site.reason

          expect(SearchRequest.count).to eq sq_count + 1
          expect(SealedPage.get_count).to eq sp_count
          expect(AccessRecord.get_count).to eq ac_count
        end
      end

      context 'limit access to sealed page' do
        let(:access_count) { EasySettings.access_limit_to_sealed_page + 1 }
        before { SealedPage.create(:can_not_get, { domain: domain, count: access_count }) }

        it 'シールドされる、SealedPageは更新されない' do
          sq_count = SearchRequest.count
          sp_count = SealedPage.get_count
          ac_count = AccessRecord.get_count
          before_sealed_site = SealedPage.new(domain).get
          subject

          expect(assigns(:finish_status)).to eq :access_sealed_page

          expect(response.status).to eq(200)
          expect(body[:status]).to eq 400
          expect(body[:message]).to eq Message.const[:can_not_get_info]

          sealed_site = SealedPage.new(domain).get
          expect(sealed_site.count).to eq before_sealed_site.count
          expect(sealed_site.last_access_date).to eq before_sealed_site.last_access_date
          expect(sealed_site.domain_type).to eq before_sealed_site.domain_type
          expect(sealed_site.reason).to eq before_sealed_site.reason

          expect(SearchRequest.count).to eq sq_count
          expect(SealedPage.get_count).to eq sp_count
          expect(AccessRecord.get_count).to eq ac_count
        end
      end
    end
  end
end

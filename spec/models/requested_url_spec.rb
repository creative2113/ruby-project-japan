require 'rails_helper'

RSpec.describe RequestedUrl, type: :model do

  describe 'バリデーション' do
    let(:url) { 'https://example.com' }
    let(:req) { create(:request) }
    let(:req2) { create(:request) }
    before do
      create(:corporate_list_requested_url, url: url, test: false, request: req)
      create(:corporate_single_requested_url, url: url, test: false, request: req)
      create(:company_info_requested_url, url: url, test: false, request: req)
    end

    context 'リクエストが同じ' do
      context 'テスト同じ' do
        it do
          expect{ RequestedUrl.create!(url: url, type: SearchRequest::CorporateList::TYPE, test: false, request: req) }.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Urlはすでに存在します')
          expect{ RequestedUrl.create!(url: url, type: SearchRequest::CorporateSingle::TYPE, test: false, request: req) }.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Urlはすでに存在します')
          expect{ RequestedUrl.create!(url: url, type: SearchRequest::CompanyInfo::TYPE, test: false, request: req) }.not_to raise_error
        end

        it do
          expect{ SearchRequest::CorporateList.create!(url: url, test: false, request: req) }.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Urlはすでに存在します')
          expect{ SearchRequest::CorporateSingle.create!(url: url, test: false, request: req) }.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Urlはすでに存在します')
          expect{ SearchRequest::CompanyInfo.create!(url: url, test: false, request: req) }.not_to raise_error
        end
      end

      context 'テスト違う' do
        it do
          expect{ RequestedUrl.create!(url: url, type: SearchRequest::CorporateList::TYPE, test: true, request: req) }.not_to raise_error
          expect{ RequestedUrl.create!(url: url, type: SearchRequest::CorporateSingle::TYPE, test: true, request: req) }.not_to raise_error
          expect{ RequestedUrl.create!(url: url, type: SearchRequest::CompanyInfo::TYPE, test: true, request: req) }.not_to raise_error
        end

        it do
          expect{ SearchRequest::CorporateList.create!(url: url, test: true, request: req) }.not_to raise_error
          expect{ SearchRequest::CorporateSingle.create!(url: url, test: true, request: req) }.not_to raise_error
          expect{ SearchRequest::CompanyInfo.create!(url: url, test: true, request: req) }.not_to raise_error
        end
      end
    end

    context 'リクエストが違う' do
      it do
        expect{ RequestedUrl.create!(url: url, type: SearchRequest::CorporateList::TYPE, test: false, request: req2) }.not_to raise_error
        expect{ RequestedUrl.create!(url: url, type: SearchRequest::CorporateSingle::TYPE, test: false, request: req2) }.not_to raise_error
        expect{ RequestedUrl.create!(url: url, type: SearchRequest::CompanyInfo::TYPE, test: false, request: req2) }.not_to raise_error
      end

      it do
        expect{ SearchRequest::CorporateList.create!(url: url, test: false, request: req2) }.not_to raise_error
        expect{ SearchRequest::CorporateSingle.create!(url: url, test: false, request: req2) }.not_to raise_error
        expect{ SearchRequest::CompanyInfo.create!(url: url, test: false, request: req2) }.not_to raise_error
      end
    end
  end

  describe '#complete' do
    before { AccessRecord.delete_items(['www.example.com']) }

    let!(:r)  { create(:request) }
    let!(:ar) { AccessRecord.create }
    let!(:ru) { create(:requested_url,
                request_id:        r.id,
                status:            EasySettings.status.new,
                finish_status:     EasySettings.finish_status.new)
              }
    it 'completeでステータスが完了になること' do
      ru.complete(EasySettings.finish_status.successful)

      expect(ru.status).to eq EasySettings.status.completed
      expect(ru.finish_status).to eq EasySettings.finish_status.successful
      expect(ru.domain).to be_nil
    end

    it 'ドメインが連携されること' do
      ru.complete(EasySettings.finish_status.successful, ar.domain)

      expect(ru.domain).to eq ar.domain
    end

    it 'domainでaccess_recordが取得できること' do
      ru.complete(EasySettings.finish_status.successful, ar.domain)

      expect(ru.get_access_record.items).to eq AccessRecord.new(ar.domain).get.items
    end
  end

  describe '#fetch_access_record' do
    let(:req) { create(:request) }
    let(:req_url) { create(:requested_url, url: 'https://example.com', request: req) }
    let(:history) { create(:monthly_history, user: req.user) }

    before { history }

    context 'AccessRecordスタブを使用しない' do
      before { AccessRecord.delete_items(['example.com']) }

      context 'アクセスレコードがない' do
        let(:req_url) { create(:requested_url, url: 'https://example.com', request: req) }

        it { expect(req_url.fetch_access_record).to be_falsey }
      end

      context 'アクセスレコードはあるが、結果がない' do
        let(:req_url) { create(:requested_url, url: 'https://example.com', request: req) }
        before { AccessRecord.create(:normal) }

        it { expect(req_url.fetch_access_record).to be_falsey }
      end

      context '過去データを使用しないが、取得日が直近5時間以内' do
        let(:req) { create(:request, use_storage: false, using_storage_days: nil) }
        before { AccessRecord.create(:normal, { result: {name: 'a', value: 'b', priority: 1}, last_fetch_date: 4.hours.ago }) }

        it { expect(req_url.fetch_access_record).to be_truthy }
      end

      context '過去データを使用して、取得日がデータ使用設定日以内' do
        let(:req) { create(:request, use_storage: true, using_storage_days: 4) }

        before do
          Timecop.freeze(current_time)
          AccessRecord.create(:normal, { result: {name: 'a', value: 'b', priority: 1}, last_fetch_date: 4.hours.ago, count: 2, last_access_date: 1.days.ago })
        end

        after { Timecop.return }

        it do
          expect(req_url.fetch_access_record).to be_truthy

          ar = AccessRecord.new('example.com').get
          expect(ar.count).to eq 3
          expect(ar.last_access_date).to eq Time.zone.now
          expect(req_url.result.main).to eq([{name: 'a', priority: 1, value: 'b'}].to_json)
          expect(req_url.finish_status).to eq EasySettings.finish_status.using_storaged_date
          expect(req_url.status).to eq EasySettings.status.completed
          expect(req_url.domain).to eq 'example.com'

          expect(req_url.request.company_info_result_headers).to be_present
        end
      end
    end

    context 'AccessRecordスタブを使用する' do
      AccessRecord.delete_items(['example.com'])
      ac = AccessRecord.create(:normal, { result: {name: 'a', value: 'b', priority: 1}, last_fetch_date: 3.days.ago, count: 2, last_access_date: 1.days.ago }).get

      before do
        allow_any_instance_of(AccessRecord).to receive(:get) do |ar, _|
          ac if ar.domain.include?('example.com')
        end
      end

      context '過去データを使用しない' do
        let(:req) { create(:request, use_storage: false) }
        before { AccessRecord.create(:normal) }

        it { expect(req_url.fetch_access_record).to be_falsey }
      end

      context '過去データを使用するが、データ使用設定日より取得日が古い' do
        let(:req) { create(:request, use_storage: true, using_storage_days: 2) }

        it { expect(req_url.fetch_access_record).to be_falsey }
      end

      context '過去データを使用して、データ使用設定日がnil' do
        let(:req) { create(:request, use_storage: true, using_storage_days: nil) }

        it { expect(req_url.fetch_access_record).to be_truthy }
      end

      context '強制使用モード' do
        let(:req) { create(:request, use_storage: false, using_storage_days: nil) }

        it { expect(req_url.fetch_access_record(force_fetch: true)).to be_truthy }
      end

      describe 'monthly_acquisition_limitに関して' do
        let(:user)    { create(:user, plan: plan) }
        let(:req)     { create(:request, use_storage: true, using_storage_days: nil, user: user, plan: plan) }
        let(:history) { create(:monthly_history, user: user, plan: plan, acquisition_count: count) }

        context 'プランユーザの場合' do
          let(:plan) { EasySettings.plan[:testerA] }

          context '制限に引っかからない時' do
            let(:count) { 0 }
            it do
              expect(req_url.fetch_access_record).to be_truthy
              expect(history.reload.acquisition_count).to eq 1
              expect(req_url.reload.status).to eq EasySettings.status.completed
              expect(req_url.reload.finish_status).to eq EasySettings.finish_status.using_storaged_date
              expect(req_url.result.main).to eq([{name: 'a', priority: 1, value: 'b'}].to_json)
              expect(req.company_info_result_headers).to be_present
            end
          end

          context 'corporate_listの時' do
            let(:count) { EasySettings.monthly_acquisition_limit[req.plan_name] }
            let(:req)   { create(:request, type: :corporate_list_site, use_storage: true, using_storage_days: nil, user: user, plan: plan) }

            it '制限に引っかからない' do
              expect(req_url.fetch_access_record).to be_truthy
              expect(history.reload.acquisition_count).to eq count
              expect(req_url.reload.status).to eq EasySettings.status.completed
              expect(req_url.reload.finish_status).to eq EasySettings.finish_status.using_storaged_date
              expect(req_url.result.main).to eq([{name: 'a', priority: 1, value: 'b'}].to_json)
              expect(req.company_info_result_headers).to be_present
            end
          end

          context '制限に引っかかる時' do
            let(:count) { EasySettings.monthly_acquisition_limit[req.plan_name] }
            it do
              expect(req_url.fetch_access_record).to be_truthy
              expect(history.reload.acquisition_count).to eq count
              expect(req_url.reload.status).to eq EasySettings.status.completed
              expect(req_url.reload.finish_status).to eq EasySettings.finish_status.monthly_limit
              expect(req_url.result.main).to be_nil
              expect(req.company_info_result_headers).to be_nil
            end
          end
        end

        context 'パブリックユーザの場合' do
          let(:history) { nil }
          let(:user) { create(:user_public) }
          let(:plan) { EasySettings.plan[:public] }

          context '制限に引っかからない時' do
            it do
              expect(req_url.fetch_access_record).to be_truthy
              expect(req_url.reload.status).to eq EasySettings.status.completed
              expect(req_url.reload.finish_status).to eq EasySettings.finish_status.using_storaged_date
              expect(req_url.result.main).to eq([{name: 'a', priority: 1, value: 'b'}].to_json)
              expect(req.company_info_result_headers).to be_present
            end
          end
        end
      end
    end
  end

  describe '#update_waiting' do
    let(:url) { 'https://example.com' }
    let(:req) { create(:request) }
    let(:req_url1) { create(:corporate_list_requested_url, status: EasySettings.status.new, request: req) }
    let(:req_url2) { create(:corporate_list_requested_url, status: EasySettings.status.new, request: req) }
    let(:req_url3) { create(:corporate_list_requested_url, status: EasySettings.status.new, request: req) }

    context '重複がない時' do
      it do
        expect(req_url1.update_waiting).to be_truthy
        expect(req_url1.status).to eq EasySettings.status.waiting
      end
    end

    context '重複がある時' do
      before do
        req_url1.url = url
        req_url1.save(validate: false)
        req_url2.url = url
        req_url2.save(validate: false)
        req_url3.url = url
        req_url3.save(validate: false)
      end

      it do
        expect(req_url1.update_waiting).to be_falsey
        expect(req_url1.reload.status).to eq EasySettings.status.new
        expect(RequestedUrl.find_by_id(req_url2.id)).to be_nil
        expect(RequestedUrl.find_by_id(req_url3.id)).to be_nil
      end

      it do
        expect(req_url2.update_waiting).to be_falsey
        expect(req_url1.reload.status).to eq EasySettings.status.new
        expect(RequestedUrl.find_by_id(req_url2.id)).to be_nil
        expect(RequestedUrl.find_by_id(req_url3.id)).to be_nil
      end

      it do
        expect(req_url3.update_waiting).to be_falsey
        expect(req_url1.reload.status).to eq EasySettings.status.new
        expect(RequestedUrl.find_by_id(req_url2.id)).to be_nil
        expect(RequestedUrl.find_by_id(req_url3.id)).to be_nil
      end
    end
  end
end

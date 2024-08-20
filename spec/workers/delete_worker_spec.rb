require 'rails_helper'

RSpec.describe DeleteWorker, type: :worker do

  before do
    create_public_user
  end

  let(:public_user) { User.get_public }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }

  after { ActionMailer::Base.deliveries.clear }
 
  describe '#delete_requests' do
    subject { described_class.delete_requests }

    context '未完了の様々なステータスがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: public_user, file_name: '新規', status: EasySettings.status.new, updated_at: Time.zone.today - 2.months) }
      let!(:r2) { create(:request,                       user: user1, file_name: '未着手', status: EasySettings.status.waiting, updated_at: Time.zone.today - 2.months) }
      let!(:r3) { create(:request, :corporate_site_list, user: user2, file_name: '着手', status: EasySettings.status.working, updated_at: Time.zone.today - 2.months) }
      let!(:r4) { create(:request,                       user: user1, file_name: 'all着手', status: EasySettings.status.all_working, updated_at: Time.zone.today - 2.months) }
      let!(:r5) { create(:request, :corporate_site_list, user: user2, file_name: '新規', status: EasySettings.status.new, updated_at: Time.zone.today - 2.months + 1.day) }
      let!(:r6) { create(:request,                       user: public_user, file_name: '未着手', status: EasySettings.status.waiting, updated_at: Time.zone.today - 2.months + 1.day) }
      let!(:r7) { create(:request, :corporate_site_list, user: user1, file_name: '着手', status: EasySettings.status.working, updated_at: Time.zone.today - 2.months + 1.day) }

      it '対象が削除されること' do
        subject
        expect(Request.find_by_id(r1.id)).to be_nil
        expect(Request.find_by_id(r2.id)).to be_nil
        expect(Request.find_by_id(r3.id)).to be_nil
        expect(Request.find_by_id(r4.id)).to be_nil
        expect(Request.find_by_id(r5.id)).to be_present
        expect(Request.find_by_id(r6.id)).to be_present
        expect(Request.find_by_id(r7.id)).to be_present
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/リクエスト削除 delete_requests/)
      end

      it { expect{ subject }.to change(Request, :count).by(-4) }
    end

    context '完了の様々なステータスがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: user1, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months) }
      let!(:r2) { create(:request,                       user: public_user, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months) }
      let!(:r3) { create(:request, :corporate_site_list, user: user2, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months + 1.day) }
      let!(:r4) { create(:request,                       user: public_user, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months + 1.day) }

      let!(:r5) { create(:request, :corporate_site_list, user: user2, file_name: '中断', status: EasySettings.status.discontinued, expiration_date: Time.zone.today - 2.months) }
      let!(:r6) { create(:request,                       user: user1, file_name: '中断', status: EasySettings.status.discontinued, expiration_date: Time.zone.today - 2.months) }
      let!(:r7) { create(:request, :corporate_site_list, user: public_user, file_name: '中断', status: EasySettings.status.discontinued, expiration_date: Time.zone.today - 2.months + 1.day) }
      let!(:r8) { create(:request,                       user: user1, file_name: '中断', status: EasySettings.status.discontinued, expiration_date: Time.zone.today - 2.months + 1.day) }

      it '対象が削除されること' do
        subject
        expect(Request.find_by_id(r1.id)).to be_nil
        expect(Request.find_by_id(r2.id)).to be_nil
        expect(Request.find_by_id(r5.id)).to be_nil
        expect(Request.find_by_id(r6.id)).to be_nil
        expect(Request.find_by_id(r3.id)).to be_present
        expect(Request.find_by_id(r4.id)).to be_present
        expect(Request.find_by_id(r7.id)).to be_present
        expect(Request.find_by_id(r8.id)).to be_present
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/リクエスト削除 delete_requests/)
      end

      it { expect{ subject }.to change(Request, :count).by(-4) }
    end

    context 'requested_urlsとtmp_company_info_urlsがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: user1, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months) }
      let!(:ru1) { create(:requested_url, request: r1) }
      let!(:ru2) { create(:requested_url, request: r1) }
      let!(:tcu1) { create(:tmp_company_info_url, request: r1) }
      let!(:tcu2) { create(:tmp_company_info_url, request: r1) }

      let!(:r2) { create(:request, :corporate_site_list, user: user1, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months + 1.day) }
      let!(:ru3) { create(:requested_url, request: r2) }
      let!(:ru4) { create(:requested_url, request: r2) }
      let!(:tcu3) { create(:tmp_company_info_url, request: r2) }
      let!(:tcu4) { create(:tmp_company_info_url, request: r2) }

      it '対象のrequested_urlsとtmp_company_info_urlsも削除されること' do
        subject
        expect(Request.find_by_id(r1.id)).to be_nil
        expect(RequestedUrl.find_by_id(ru1.id)).to be_nil
        expect(RequestedUrl.find_by_id(ru2.id)).to be_nil
        expect(Result.find_by_requested_url_id(ru1.id)).to be_nil
        expect(Result.find_by_requested_url_id(ru2.id)).to be_nil
        expect(TmpCompanyInfoUrl.find_by_id(tcu1.id)).to be_nil
        expect(TmpCompanyInfoUrl.find_by_id(tcu2.id)).to be_nil

        expect(Request.find_by_id(r2.id)).to be_present
        expect(RequestedUrl.find_by_id(ru3.id)).to be_present
        expect(RequestedUrl.find_by_id(ru4.id)).to be_present
        expect(Result.find_by_requested_url_id(ru3.id)).to be_present
        expect(Result.find_by_requested_url_id(ru4.id)).to be_present
        expect(TmpCompanyInfoUrl.find_by_id(tcu3.id)).to be_present
        expect(TmpCompanyInfoUrl.find_by_id(tcu4.id)).to be_present
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/リクエスト削除 delete_requests/)
      end

      it { expect{ subject }.to change(Request, :count).by(-1) }
      it { expect{ subject }.to change(RequestedUrl, :count).by(-2) }
      it { expect{ subject }.to change(Result, :count).by(-2) }
      it { expect{ subject }.to change(TmpCompanyInfoUrl, :count).by(-2) }
    end

    context '結果ファイルがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: user1, file_name: '完了', status: EasySettings.status.completed, result_file_path: s3_path, expiration_date: Time.zone.today - 2.months) }

      let(:file_name) { 'result_download.xlsx' }
      let(:file_path) { Rails.root.join('spec', 'fixtures', file_name).to_s }
      let(:s3_hdl)    { S3Handler.new }
      let(:day_str)   { Time.zone.today.strftime("%Y/%-m/%-d") }
      let(:s3_path)   { "#{Rails.application.credentials.s3_bucket[:results]}/#{day_str}/#{file_name}" }

      before do
        s3_hdl.upload(s3_path: s3_path, file_path: file_path)
      end

      it '対象の結果ファイルも削除されること' do
        expect(s3_hdl.exist_object?(s3_path: s3_path)).to be_truthy
        subject
        expect(Request.find_by_id(r1.id)).to be_nil
        expect(s3_hdl.exist_object?(s3_path: s3_path)).to be_falsey

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/リクエスト削除 delete_requests/)
      end
    end

    context 'result_fileがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: user1, file_name: '完了', status: EasySettings.status.completed, result_file_path: s3_path, expiration_date: Time.zone.today - 2.months) }

      let(:file_name) { 'result_download.xlsx' }
      let(:file_path) { Rails.root.join('spec', 'fixtures', file_name).to_s }
      let(:s3_hdl)    { S3Handler.new }
      let(:day_str1)  { Time.zone.today.strftime("%Y/%-m/%-d") }
      let(:day_str2)  { (Time.zone.today - 1.day).strftime("%Y/%-m/%-d") }
      let(:day_str)   { (Time.zone.today - 2.day).strftime("%Y/%-m/%-d") }
      let(:s3_path)   { "#{Rails.application.credentials.s3_bucket[:results]}/#{day_str}/#{file_name}" }
      let(:s3_path1)  { "#{Rails.application.credentials.s3_bucket[:results]}/#{day_str1}/#{file_name}" }
      let(:s3_path2)  { "#{Rails.application.credentials.s3_bucket[:results]}/#{day_str2}/#{file_name}" }

      let(:result_file1) { create(:result_file, path: s3_path1, deletable: false, request: r1) }
      let(:result_file2) { create(:result_file, path: s3_path2, deletable: false, request: r1) }

      before do
        result_file1
        result_file2
        s3_hdl.upload(s3_path: s3_path, file_path: file_path)
        s3_hdl.upload(s3_path: s3_path1, file_path: file_path)
        s3_hdl.upload(s3_path: s3_path2, file_path: file_path)
      end

      it '対象のesult_fileも削除されること' do
        expect(s3_hdl.exist_object?(s3_path: s3_path)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path1)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path2)).to be_truthy
        subject
        expect(Request.find_by_id(r1.id)).to be_nil
        expect(ResultFile.find_by_id(result_file1.id)).to be_nil
        expect(ResultFile.find_by_id(result_file2.id)).to be_nil
        expect(s3_hdl.exist_object?(s3_path: s3_path)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path1)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path2)).to be_falsey

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/リクエスト削除 delete_requests/)
      end
    end
  end

  describe '#delete_results' do
    subject { described_class.delete_results }

    context '未完了でupdated_atがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: public_user, file_name: '未完了', status: EasySettings.status.working, updated_at: Time.zone.today - 39.days) }
      let!(:r2) { create(:request,                       user: user1, file_name: '未完了', status: EasySettings.status.working, updated_at: Time.zone.today - 39.days) }
      let!(:r3) { create(:request, :corporate_site_list, user: user2, file_name: '未完了', status: EasySettings.status.working, updated_at: Time.zone.today - 39.days + 1.day) }
      let!(:r4) { create(:request,                       user: user1, file_name: '未完了', status: EasySettings.status.working, updated_at: Time.zone.today - 39.days + 1.day) }
 
      let!(:ru1) { create(:corporate_list_requested_url,   request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru2) { create(:corporate_single_requested_url, request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru3) { create(:corporate_single_requested_url, request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru4) { create(:company_info_requested_url,     request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru5) { create(:company_info_requested_url,     request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      let!(:ru6) { create(:company_info_requested_url,     request: r2, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru7) { create(:company_info_requested_url,     request: r2, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      let!(:ru8)  { create(:corporate_list_requested_url,   request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru9)  { create(:corporate_single_requested_url, request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru10) { create(:corporate_single_requested_url, request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru11) { create(:company_info_requested_url,     request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru12) { create(:company_info_requested_url,     request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      let!(:ru13) { create(:company_info_requested_url,     request: r4, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru14) { create(:company_info_requested_url,     request: r4, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      it '対象が削除されること' do
        subject

        expect(ru1.result.reload.free_search).to be_nil
        expect(ru1.result.candidate_crawl_urls).to be_nil
        expect(ru1.result.single_url_ids).to be_nil
        expect(ru1.result.main).to be_nil
        expect(ru1.result.corporate_list).to be_nil

        expect(ru2.result.reload.free_search).to be_nil
        expect(ru2.result.candidate_crawl_urls).to be_nil
        expect(ru2.result.single_url_ids).to be_nil
        expect(ru2.result.main).to be_nil
        expect(ru2.result.corporate_list).to be_nil

        expect(ru3.result.reload.free_search).to be_nil
        expect(ru3.result.candidate_crawl_urls).to be_nil
        expect(ru3.result.single_url_ids).to be_nil
        expect(ru3.result.main).to be_nil
        expect(ru3.result.corporate_list).to be_nil

        expect(ru4.result.reload.free_search).to be_nil
        expect(ru4.result.candidate_crawl_urls).to be_nil
        expect(ru4.result.single_url_ids).to be_nil
        expect(ru4.result.main).to be_nil
        expect(ru4.result.corporate_list).to be_nil

        expect(ru5.result.reload.free_search).to be_nil
        expect(ru5.result.candidate_crawl_urls).to be_nil
        expect(ru5.result.single_url_ids).to be_nil
        expect(ru5.result.main).to be_nil
        expect(ru5.result.corporate_list).to be_nil

        expect(ru7.result.reload.free_search).to be_nil
        expect(ru7.result.candidate_crawl_urls).to be_nil
        expect(ru7.result.single_url_ids).to be_nil
        expect(ru7.result.main).to be_nil
        expect(ru7.result.corporate_list).to be_nil

        expect(ru7.result.reload.free_search).to be_nil
        expect(ru7.result.candidate_crawl_urls).to be_nil
        expect(ru7.result.single_url_ids).to be_nil
        expect(ru7.result.main).to be_nil
        expect(ru7.result.corporate_list).to be_nil
      end

      it '対象が削除されないこと' do
        subject
        expect(ru8.result.reload.free_search).to be_present
        expect(ru8.result.candidate_crawl_urls).to be_present
        expect(ru8.result.single_url_ids).to be_present
        expect(ru8.result.main).to be_present
        expect(ru8.result.corporate_list).to be_present

        expect(ru9.result.reload.free_search).to be_present
        expect(ru9.result.candidate_crawl_urls).to be_present
        expect(ru9.result.single_url_ids).to be_present
        expect(ru9.result.main).to be_present
        expect(ru9.result.corporate_list).to be_present

        expect(ru10.result.reload.free_search).to be_present
        expect(ru10.result.candidate_crawl_urls).to be_present
        expect(ru10.result.single_url_ids).to be_present
        expect(ru10.result.main).to be_present
        expect(ru10.result.corporate_list).to be_present

        expect(ru11.result.reload.free_search).to be_present
        expect(ru11.result.candidate_crawl_urls).to be_present
        expect(ru11.result.single_url_ids).to be_present
        expect(ru11.result.main).to be_present
        expect(ru11.result.corporate_list).to be_present

        expect(ru12.result.reload.free_search).to be_present
        expect(ru12.result.candidate_crawl_urls).to be_present
        expect(ru12.result.single_url_ids).to be_present
        expect(ru12.result.main).to be_present
        expect(ru12.result.corporate_list).to be_present

        expect(ru13.result.reload.free_search).to be_present
        expect(ru13.result.candidate_crawl_urls).to be_present
        expect(ru13.result.single_url_ids).to be_present
        expect(ru13.result.main).to be_present
        expect(ru13.result.corporate_list).to be_present

        expect(ru14.result.reload.free_search).to be_present
        expect(ru14.result.candidate_crawl_urls).to be_present
        expect(ru14.result.single_url_ids).to be_present
        expect(ru14.result.main).to be_present
        expect(ru14.result.corporate_list).to be_present
      end

      it '報告メールが飛ぶこと' do
        subject
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/結果削除 delete_results/)
      end

      # レコードは削除されないこと
      it { expect{ subject }.to change(Request, :count).by(0) }
      it { expect{ subject }.to change(RequestedUrl, :count).by(0) }
      it { expect{ subject }.to change(Result, :count).by(0) }
    end

    context '完了でexpiration_dateがある時' do
      let!(:r1) { create(:request, :corporate_site_list, user: public_user, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 8.days) }
      let!(:r2) { create(:request,                       user: user1, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 8.days) }
      let!(:r3) { create(:request, :corporate_site_list, user: user2, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 8.days + 1.day) }
      let!(:r4) { create(:request,                       user: user1, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 8.days + 1.day) }
 
      let!(:ru1) { create(:corporate_list_requested_url,   request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru2) { create(:corporate_single_requested_url, request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru3) { create(:corporate_single_requested_url, request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru4) { create(:company_info_requested_url,     request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru5) { create(:company_info_requested_url,     request: r1, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      let!(:ru6) { create(:company_info_requested_url,     request: r2, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru7) { create(:company_info_requested_url,     request: r2, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      let!(:ru8)  { create(:corporate_list_requested_url,   request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru9)  { create(:corporate_single_requested_url, request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru10) { create(:corporate_single_requested_url, request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru11) { create(:company_info_requested_url,     request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru12) { create(:company_info_requested_url,     request: r3, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      let!(:ru13) { create(:company_info_requested_url,     request: r4, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }
      let!(:ru14) { create(:company_info_requested_url,     request: r4, result_attrs: { free_search: 'a', candidate_crawl_urls: 'b', single_url_ids: 'c', main: 'd', corporate_list: 'e' } ) }

      it '対象が削除されること' do
        subject

        expect(ru1.result.reload.free_search).to be_nil
        expect(ru1.result.candidate_crawl_urls).to be_nil
        expect(ru1.result.single_url_ids).to be_nil
        expect(ru1.result.main).to be_nil
        expect(ru1.result.corporate_list).to be_nil

        expect(ru2.result.reload.free_search).to be_nil
        expect(ru2.result.candidate_crawl_urls).to be_nil
        expect(ru2.result.single_url_ids).to be_nil
        expect(ru2.result.main).to be_nil
        expect(ru2.result.corporate_list).to be_nil

        expect(ru3.result.reload.free_search).to be_nil
        expect(ru3.result.candidate_crawl_urls).to be_nil
        expect(ru3.result.single_url_ids).to be_nil
        expect(ru3.result.main).to be_nil
        expect(ru3.result.corporate_list).to be_nil

        expect(ru4.result.reload.free_search).to be_nil
        expect(ru4.result.candidate_crawl_urls).to be_nil
        expect(ru4.result.single_url_ids).to be_nil
        expect(ru4.result.main).to be_nil
        expect(ru4.result.corporate_list).to be_nil

        expect(ru5.result.reload.free_search).to be_nil
        expect(ru5.result.candidate_crawl_urls).to be_nil
        expect(ru5.result.single_url_ids).to be_nil
        expect(ru5.result.main).to be_nil
        expect(ru5.result.corporate_list).to be_nil

        expect(ru7.result.reload.free_search).to be_nil
        expect(ru7.result.candidate_crawl_urls).to be_nil
        expect(ru7.result.single_url_ids).to be_nil
        expect(ru7.result.main).to be_nil
        expect(ru7.result.corporate_list).to be_nil

        expect(ru7.result.reload.free_search).to be_nil
        expect(ru7.result.candidate_crawl_urls).to be_nil
        expect(ru7.result.single_url_ids).to be_nil
        expect(ru7.result.main).to be_nil
        expect(ru7.result.corporate_list).to be_nil
      end

      it '対象が削除されないこと' do
        subject
        expect(ru8.result.reload.free_search).to be_present
        expect(ru8.result.candidate_crawl_urls).to be_present
        expect(ru8.result.single_url_ids).to be_present
        expect(ru8.result.main).to be_present
        expect(ru8.result.corporate_list).to be_present

        expect(ru9.result.reload.free_search).to be_present
        expect(ru9.result.candidate_crawl_urls).to be_present
        expect(ru9.result.single_url_ids).to be_present
        expect(ru9.result.main).to be_present
        expect(ru9.result.corporate_list).to be_present

        expect(ru10.result.reload.free_search).to be_present
        expect(ru10.result.candidate_crawl_urls).to be_present
        expect(ru10.result.single_url_ids).to be_present
        expect(ru10.result.main).to be_present
        expect(ru10.result.corporate_list).to be_present

        expect(ru11.result.reload.free_search).to be_present
        expect(ru11.result.candidate_crawl_urls).to be_present
        expect(ru11.result.single_url_ids).to be_present
        expect(ru11.result.main).to be_present
        expect(ru11.result.corporate_list).to be_present

        expect(ru12.result.reload.free_search).to be_present
        expect(ru12.result.candidate_crawl_urls).to be_present
        expect(ru12.result.single_url_ids).to be_present
        expect(ru12.result.main).to be_present
        expect(ru12.result.corporate_list).to be_present

        expect(ru13.result.reload.free_search).to be_present
        expect(ru13.result.candidate_crawl_urls).to be_present
        expect(ru13.result.single_url_ids).to be_present
        expect(ru13.result.main).to be_present
        expect(ru13.result.corporate_list).to be_present

        expect(ru14.result.reload.free_search).to be_present
        expect(ru14.result.candidate_crawl_urls).to be_present
        expect(ru14.result.single_url_ids).to be_present
        expect(ru14.result.main).to be_present
        expect(ru14.result.corporate_list).to be_present
      end

      it '報告メールが飛ぶこと' do
        subject
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/結果削除 delete_results/)
      end

      # レコードは削除されないこと
      it { expect{ subject }.to change(Request, :count).by(0) }
      it { expect{ subject }.to change(RequestedUrl, :count).by(0) }
      it { expect{ subject }.to change(Result, :count).by(0) }
    end
  end

  describe '#delete_tmp_results_files' do
    subject { described_class.delete_tmp_results_files(20) }

    context '結果ファイルがある時' do
      let(:file_name1) { 'result_download.xlsx' }
      let(:file_name2) { 'result_download_for_unzip.xlsx' }
      let(:file_path1)  { Rails.root.join('spec', 'fixtures', file_name1).to_s }
      let(:file_path2)  { Rails.root.join('spec', 'fixtures', file_name2).to_s }
      let(:s3_hdl)     { S3Handler.new }
      let(:day_str1)   { (Time.zone.today - 60.days).strftime("%Y/%-m/%-d") }
      let(:day_str2)   { (Time.zone.today - 61.days).strftime("%Y/%-m/%-d") }
      let(:day_str3)   { (Time.zone.today - 59.days).strftime("%Y/%-m/%-d") }
      let(:req_id1)     { 5 }
      let(:req_id2)     { 6 }

      let(:s3_path1) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str1}/#{req_id1}/#{file_name1}" }
      let(:s3_path2) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str1}/#{req_id1}/#{file_name2}" }
      let(:s3_path3) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str1}/#{req_id2}/#{file_name1}" }
      let(:s3_path4) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str1}/#{req_id2}/#{file_name2}" }
      let(:s3_path5) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str2}/#{req_id1}/#{file_name1}" }
      let(:s3_path6) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str2}/#{req_id1}/#{file_name2}" }
      let(:s3_path7) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str2}/#{req_id2}/#{file_name1}" }
      let(:s3_path8) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str2}/#{req_id2}/#{file_name2}" }
      let(:s3_path9) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str3}/#{req_id2}/#{file_name1}" }

      before do
        s3_hdl.upload(s3_path: s3_path1, file_path: file_path1)
        s3_hdl.upload(s3_path: s3_path2, file_path: file_path2)
        s3_hdl.upload(s3_path: s3_path3, file_path: file_path1)
        s3_hdl.upload(s3_path: s3_path4, file_path: file_path2)
        s3_hdl.upload(s3_path: s3_path5, file_path: file_path1)
        s3_hdl.upload(s3_path: s3_path6, file_path: file_path2)
        s3_hdl.upload(s3_path: s3_path7, file_path: file_path1)
        s3_hdl.upload(s3_path: s3_path8, file_path: file_path2)
        s3_hdl.upload(s3_path: s3_path9, file_path: file_path1)
      end

      after do
        s3_hdl.delete(s3_path: s3_path9)

        raise 'ファイルが残っています。' if s3_hdl.exist_object?(s3_path: s3_path9)
      end

      it '対象の結果ファイルも削除されること' do
        expect(s3_hdl.exist_object?(s3_path: s3_path1)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path2)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path3)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path4)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path5)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path6)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path7)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path8)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path9)).to be_truthy

        subject
        expect(s3_hdl.exist_object?(s3_path: s3_path1)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path2)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path3)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path4)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path5)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path6)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path7)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path8)).to be_falsey

        expect(s3_hdl.exist_object?(s3_path: s3_path9)).to be_truthy

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/TMP結果ファイル削除 delete_tmp_results_files/)
      end
    end

    context '削除可能なresult_fileがある時' do
      let(:file_name1) { 'result_download.xlsx' }
      let(:file_name2) { 'result_download_for_unzip.xlsx' }
      let(:file_path1) { Rails.root.join('spec', 'fixtures', file_name1).to_s }
      let(:file_path2) { Rails.root.join('spec', 'fixtures', file_name2).to_s }
      let(:s3_hdl)     { S3Handler.new }
      let!(:r1) { create(:request, :corporate_site_list, user: user2, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months + 1.day) }
      let!(:r2) { create(:request,                       user: user1, file_name: '完了', status: EasySettings.status.completed, expiration_date: Time.zone.today - 2.months + 1.day) }

      let(:result_file1) { create(:result_file, path: s3_path1, deletable: true, request: r1) }
      let(:result_file2) { create(:result_file, path: s3_path2, deletable: false, request: r1) }
      let(:result_file3) { create(:result_file, path: s3_path3, deletable: true, request: r2) }
      let(:result_file4) { create(:result_file, path: s3_path4, deletable: false, request: r2) }
      let(:day_str)      { (Time.zone.today - 3.days).strftime("%Y/%-m/%-d") }
      let(:req_id1)      { 5 }
      let(:req_id2)      { 6 }

      let(:s3_path1) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str}/#{req_id1}/#{file_name1}" }
      let(:s3_path2) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str}/#{req_id1}/#{file_name2}" }
      let(:s3_path3) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str}/#{req_id2}/#{file_name1}" }
      let(:s3_path4) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day_str}/#{req_id2}/#{file_name2}" }

      before do
        result_file1
        result_file2
        result_file3
        result_file4
        s3_hdl.upload(s3_path: s3_path1, file_path: file_path1)
        s3_hdl.upload(s3_path: s3_path2, file_path: file_path2)
        s3_hdl.upload(s3_path: s3_path3, file_path: file_path1)
        s3_hdl.upload(s3_path: s3_path4, file_path: file_path2)
      end

      after do
        s3_hdl.delete(s3_path: s3_path2)
        s3_hdl.delete(s3_path: s3_path4)

        raise "ファイルが残っています。#{s3_path2}" if s3_hdl.exist_object?(s3_path: s3_path2)
        raise "ファイルが残っています。#{s3_path4}" if s3_hdl.exist_object?(s3_path: s3_path4)
      end

      it '対象の結果ファイルも削除されること' do
        expect(s3_hdl.exist_object?(s3_path: s3_path1)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path2)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path3)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path4)).to be_truthy

        subject
        expect(s3_hdl.exist_object?(s3_path: s3_path1)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path2)).to be_truthy
        expect(s3_hdl.exist_object?(s3_path: s3_path3)).to be_falsey
        expect(s3_hdl.exist_object?(s3_path: s3_path4)).to be_truthy

        expect(ResultFile.find_by_id(result_file1.id)).to be_nil
        expect(ResultFile.find_by_id(result_file2.id)).to be_present
        expect(ResultFile.find_by_id(result_file3.id)).to be_nil
        expect(ResultFile.find_by_id(result_file4.id)).to be_present


        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/TMP結果ファイル削除 delete_tmp_results_files/)
      end
    end
  end
end

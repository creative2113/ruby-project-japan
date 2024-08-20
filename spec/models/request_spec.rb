require 'rails_helper'

# このテストではユーザプランによる違いは生じない
# publicのみのテストでOK

RSpec.describe Request, type: :model do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  let_it_be(:pu) { create(:user_public) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
  end

  describe 'スコープおよびメソッドの確認' do
    let!(:r1)  { create(:request, user_id: pu.id, file_name: '新規', status: EasySettings.status.new) }
    let!(:r2)  { create(:request, user_id: pu.id, file_name: '未着手', status: EasySettings.status.waiting) }
    let!(:r3)  { create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working) }
    let!(:r4)  { create(:request, user_id: pu.id, file_name: '完了', status: EasySettings.status.completed) }
    let!(:r5)  { create(:request, user_id: pu.id, file_name: '中止', status: EasySettings.status.discontinued) }
    let!(:r6)  { create(:request, user_id: pu.id, file_name: '保留', status: EasySettings.status.pending) }
    let!(:r7)  { create(:request, user_id: pu.id, file_name: '着手2', status: EasySettings.status.working) }
    let!(:r8)  { create(:request, user_id: pu.id, file_name: 'エラー', status: EasySettings.status.error) }
    let!(:r9)  { create(:request, user_id: pu.id, file_name: '全件着手', status: EasySettings.status.all_working) }
    let!(:r10) { create(:request, user_id: pu.id, file_name: '完了2', status: EasySettings.status.completed) }
    let!(:r11) { create(:request, user_id: pu.id, file_name: 'エラー2', status: EasySettings.status.error) }
    let!(:r12) { create(:request, user_id: pu.id, file_name: 'アレンジ', status: EasySettings.status.arranging) }

    describe 'スコープに関して' do
      it 'スコープunfinishedで新規から着手中のものが取れること' do
        expect(Request.unfinished.count).to eq 4
        expect(Request.unfinished[0]).to eq r1
        expect(Request.unfinished[1]).to eq r2
        expect(Request.unfinished[2]).to eq r3
        expect(Request.unfinished[3]).to eq r7
      end

      it 'スコープcompletedで完了のものが取れること' do
        expect(Request.completed.count).to eq 2
        expect(Request.completed[0]).to eq r4
        expect(Request.completed[1]).to eq r10
      end

      it 'スコープerrorで新規から着手中のものが取れること' do
        expect(Request.error.count).to eq 2
        expect(Request.error[0]).to eq r8
        expect(Request.error[1]).to eq r11
      end
    end

    describe 'メソッドstop?に関して' do
      it 'ステータスが中止ならtrueが返ること' do
        expect(r5.stop?).to be_truthy
      end

      it 'ステータスが中止以外ならfalseが返ること' do
        expect(r1.stop?).to be_falsey
        expect(r2.stop?).to be_falsey
        expect(r3.stop?).to be_falsey
        expect(r4.stop?).to be_falsey
        expect(r6.stop?).to be_falsey
        expect(r8.stop?).to be_falsey
        expect(r9.stop?).to be_falsey
      end
    end

    describe 'メソッドget_status_stringに関して' do
      it '未完了と表示されること' do
        unfinished_status = '未完了'
        expect(r1.get_status_string).to eq unfinished_status
        expect(r2.get_status_string).to eq unfinished_status
        expect(r3.get_status_string).to eq unfinished_status
        expect(r9.get_status_string).to eq unfinished_status
        expect(r12.get_status_string).to eq unfinished_status
      end

      it '完了と表示されること' do
        finished_status = '完了'
        expect(r4.get_status_string).to eq finished_status
        expect(r6.get_status_string).to eq finished_status
        expect(r8.get_status_string).to eq finished_status
      end

      it '中止と表示されること' do
        finished_status = '中止'
        expect(r5.get_status_string).to eq finished_status
      end
    end

    describe '#finished?' do
      it '未完了' do
        expect(r1.finished?).to be_falsey
        expect(r2.finished?).to be_falsey
        expect(r3.finished?).to be_falsey
        expect(r9.finished?).to be_falsey
        expect(r12.finished?).to be_falsey
      end

      it '完了のもの' do
        expect(r4.finished?).to be_truthy
        expect(r6.finished?).to be_truthy
        expect(r8.finished?).to be_truthy
        expect(r5.finished?).to be_truthy
      end
    end

    describe 'メソッドget_expiration_dateに関して' do
      it 'nilが返ること' do
        expect(r1.get_expiration_date).to be_nil
        expect(r2.get_expiration_date).to be_nil
        expect(r3.get_expiration_date).to be_nil
        expect(r9.get_expiration_date).to be_nil
      end

      it 'dateが取得できること' do
        expect(r4.get_expiration_date).to eq Time.zone.today.strftime("%Y年%m月%d日")
        expect(r5.get_expiration_date).to eq Time.zone.today.strftime("%Y年%m月%d日")
        expect(r6.get_expiration_date).to eq Time.zone.today.strftime("%Y年%m月%d日")
        expect(r8.get_expiration_date).to eq Time.zone.today.strftime("%Y年%m月%d日")
      end
    end

    describe 'クラスメソッドcatch_unfinished_requestsに関して' do
      it '未完了のRequestモデルのidが取得できること(limit=2)' do
        expect(Request.catch_unfinished_requests(2)).to eq Request.where(id: [r1.id, r2.id])
      end

      it '未完了のRequestモデルのidが取得できること(limit=5)' do
        expect(Request.catch_unfinished_requests(5)).to eq Request.where(id: [r1.id, r2.id, r3.id, r7.id])
      end

      it 'ステータスが着手中に変化していること(limit=1)' do
        Request.catch_unfinished_requests(1)

        expect(Request.find(r1.id).status).to eq EasySettings.status.working
        expect(Request.find(r2.id).status).to eq EasySettings.status.waiting # ここは変化しない
        expect(Request.find(r3.id).status).to eq EasySettings.status.working
        expect(Request.find(r7.id).status).to eq EasySettings.status.working
      end

      it 'ステータスが着手中に変化していること(limit=5)' do
        Request.catch_unfinished_requests(5)

        expect(Request.find(r1.id).status).to eq EasySettings.status.working
        expect(Request.find(r2.id).status).to eq EasySettings.status.working
        expect(Request.find(r3.id).status).to eq EasySettings.status.working
        expect(Request.find(r7.id).status).to eq EasySettings.status.working
      end

      context 'テストリクエストが含まれているとき' do
        let!(:r12)  { create(:request, user_id: pu.id, file_name: '新規', status: EasySettings.status.new, test: true) }
        let!(:r13)  { create(:request, user_id: pu.id, file_name: '未着手', status: EasySettings.status.waiting, test: true) }
        let!(:r14)  { create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working, test: true) }

        it 'テストリクエストは選ばれないこと' do
          expect(Request.catch_unfinished_requests(10)).to eq Request.where(id: [r1.id, r2.id, r3.id, r7.id])
        end
      end
    end
  end

  describe 'スコープ viewable' do
    let(:user) { create(:user) }
    context do
      let!(:r1)  { create(:request, user_id: user.id, file_name: '新規', status: EasySettings.status.new, updated_at: Time.zone.today - 33.days) }
      let!(:r2)  { create(:request, user_id: user.id, file_name: '未着手', status: EasySettings.status.waiting, updated_at: Time.zone.today - 33.days) }
      let!(:r3)  { create(:request, user_id: user.id, file_name: '着手', status: EasySettings.status.working, updated_at: Time.zone.today - 33.days) }
      let!(:r4)  { create(:request, user_id: user.id, file_name: 'all着手', status: EasySettings.status.all_working, updated_at: Time.zone.today - 33.days) }

      it { expect(Request.viewable).to eq [r1, r2, r3, r4] }
    end

    context do
      let!(:r5)  { create(:request, user_id: user.id, file_name: '完了1', status: EasySettings.status.completed, updated_at: Time.zone.today - 1.month) }
      let!(:r6)  { create(:request, user_id: user.id, file_name: '完了2', status: EasySettings.status.completed, updated_at: Time.zone.today - 1.month + 1.day) }
      let!(:r7)  { create(:request, user_id: user.id, file_name: '完了3', status: EasySettings.status.completed, updated_at: Time.zone.today - 1.month - 1.day) }
      it { expect(Request.viewable).to eq [r5, r6] }
    end

    context do
      let!(:r8)   { create(:request, user_id: user.id, file_name: '中止1', status: EasySettings.status.discontinued, updated_at: Time.zone.today - 1.month) }
      let!(:r9)   { create(:request, user_id: user.id, file_name: '中止2', status: EasySettings.status.discontinued, updated_at: Time.zone.today - 1.month + 1.day) }
      let!(:r10)  { create(:request, user_id: user.id, file_name: '中止3', status: EasySettings.status.discontinued, updated_at: Time.zone.today - 1.month - 1.day) }
      it { expect(Request.viewable).to eq [r8, r9] }
    end

    context do
      let!(:r11)  { create(:request, user_id: user.id, file_name: 'エラー1', status: EasySettings.status.error, updated_at: Time.zone.today - 1.month) }
      let!(:r12)  { create(:request, user_id: user.id, file_name: 'エラー2', status: EasySettings.status.error, updated_at: Time.zone.today - 1.month + 1.day) }
      let!(:r13)  { create(:request, user_id: user.id, file_name: 'エラー3', status: EasySettings.status.error, updated_at: Time.zone.today - 1.month - 1.day) }
      it { expect(Request.viewable).to eq [r11, r12] }
    end
  end

  describe '#available?' do
    subject { request.available? }
    let(:request) { create(:request, updated_at: updated_at, status: status) }

    context 'expiration_dateがblank' do
      let(:updated_at) { Time.zone.today - 1.month - 3.days }
      let(:status) { EasySettings.status.new }
      it { expect(subject).to be_truthy }
    end

    context 'expiration_dateがblank' do
      let(:updated_at) { Time.zone.today - 1.month + 1.days }
      let(:status) { EasySettings.status.completed }
      it { expect(subject).to be_truthy }
    end

    context 'expiration_dateがblank' do
      let(:updated_at) { Time.zone.today - 1.month - 1.days }
      let(:status) { EasySettings.status.completed }
      it { expect(subject).to be_falsey }
    end
  end

  describe '#available_download?' do
    subject { request.available_download? }

    context '有効期限切れの判定' do
      let(:request) { create(:request, expiration_date: expiration_date, status: ResultFile.statuses[:completed]) }

      context 'expiration_dateが昨日' do
        let(:expiration_date) { Time.zone.today - 1.day }
        it { expect(subject).to be_falsey }
      end
    end

    context 'DLできるようになったのかの判定' do
      let(:request) { create(:request, type: type, test: test_flg ) }
      let(:test_flg) { false }

      context 'testの時' do
        let(:test_flg) { true }
        let(:type) { Request.types[:corporate_list_site] }
        it { expect(subject).to be_falsey }
      end

      context 'corporate_site_listの時' do
        let(:type) { Request.types[:corporate_list_site] }

        context 'corporate_list_requested_urlのsuccessがない時' do
          before { create(:corporate_list_requested_url, request: request, status: EasySettings.status.new ) }
          it { expect(subject).to be_falsey }
        end

        context 'corporate_list_requested_urlのsuccessがある時' do
          before { create(:corporate_list_requested_url, request: request, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.successful) }
          it { expect(subject).to be_truthy }
        end

        context 'corporate_list_requested_urlのsuccessがない時' do
          before {
            create(:corporate_list_requested_url, request: request, status: EasySettings.status.completed )
            create(:company_info_requested_url, request: request, status: EasySettings.status.new ) }
          it { expect(subject).to be_truthy }
        end
      end

      context 'corporate_site_listの時' do
        let(:type) { Request.types[:file] }

        context 'corporate_list_requested_urlのsuccessがない時' do
          before { create(:company_info_requested_url, request: request, status: EasySettings.status.new ) }
          it { expect(subject).to be_falsey }
        end

        context 'corporate_list_requested_urlのsuccessがある時' do
          before { create(:company_info_requested_url, request: request, status: EasySettings.status.completed ) }
          it { expect(subject).to be_truthy }
        end
      end
    end
  end

  describe '#downloadable?' do
    subject { request.downloadable? }
    let(:request) { create(:request, type: type, test: test_flg ) }
    let(:test_flg) { false }

    context 'testの時' do
      let(:test_flg) { true }
      let(:type) { Request.types[:corporate_list_site] }
      it { expect(subject).to be_falsey }
    end

    context 'corporate_site_listの時' do
      let(:type) { Request.types[:corporate_list_site] }

      context 'corporate_list_requested_urlのsuccessがない時' do
        before { create(:corporate_list_requested_url, request: request, status: EasySettings.status.new ) }
        it { expect(subject).to be_falsey }
      end

      context 'corporate_list_requested_urlのsuccessがある時' do
        before { create(:corporate_list_requested_url, request: request, status: EasySettings.status.completed, finish_status: EasySettings.finish_status.successful) }
        it { expect(subject).to be_truthy }
      end

      context 'corporate_list_requested_urlのsuccessがない時' do
        before {
          create(:corporate_list_requested_url, request: request, status: EasySettings.status.completed )
          create(:company_info_requested_url, request: request, status: EasySettings.status.new ) }
        it { expect(subject).to be_truthy }
      end
    end

    context 'corporate_site_listの時' do
      let(:type) { Request.types[:file] }

      context 'corporate_list_requested_urlのsuccessがない時' do
        before { create(:company_info_requested_url, request: request, status: EasySettings.status.new ) }
        it { expect(subject).to be_falsey }
      end

      context 'corporate_list_requested_urlのsuccessがある時' do
        before { create(:company_info_requested_url, request: request, status: EasySettings.status.completed ) }
        it { expect(subject).to be_truthy }
      end
    end
  end

  describe '#over_expiration_date?' do
    subject { request.over_expiration_date? }
    let(:request) { create(:request, expiration_date: expiration_date, status: ResultFile.statuses[:completed]) }

    context 'expiration_dateがblank' do
      let(:expiration_date) { nil }
      it { expect(subject).to be_falsey }
    end

    context 'expiration_dateが本日' do
      let(:expiration_date) { Time.zone.today }
      it { expect(subject).to be_falsey }
    end

    context 'expiration_dateが昨日' do
      let(:expiration_date) { Time.zone.today - 1.day }
      it { expect(subject).to be_truthy }
    end
  end

  describe '#get_new_urls_and_update_status' do
    let!(:r)    { create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working) }
    let!(:ru1)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.new) }
    let!(:ru2)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.waiting) }
    let!(:ru3)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.working) }
    let!(:ru4)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.all_working) }
    let!(:ru5)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.completed) }
    let!(:ru6)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.new) }
    let!(:ru7)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.discontinued) }
    let!(:ru8)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.pending) }
    let!(:ru9)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.waiting) }
    let!(:ru10) { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.new) }

    it '新しいリクエストURLが取得できること(limit = 4)' do
      result = r.get_new_urls_and_update_status(4)
      ru1.assign_attributes({status: EasySettings.status.working})
      ru6.assign_attributes({status: EasySettings.status.working})
      ru10.assign_attributes({status: EasySettings.status.working})

      expect(result.count).to eq 3
      expect(result[0]).to eq ru1
      expect(result[1]).to eq ru6
      expect(result[2]).to eq ru10
      expect(RequestedUrl.find_by_id(ru2.id)).to eq ru2
      expect(RequestedUrl.find_by_id(ru3.id)).to eq ru3
      expect(RequestedUrl.find_by_id(ru4.id)).to eq ru4
      expect(RequestedUrl.find_by_id(ru5.id)).to eq ru5
      expect(RequestedUrl.find_by_id(ru7.id)).to eq ru7
      expect(RequestedUrl.find_by_id(ru8.id)).to eq ru8
      expect(RequestedUrl.find_by_id(ru9.id)).to eq ru9

      expect(r.status).to eq EasySettings.status.all_working
    end

    it '新しいリクエストURLが取得できること(limit = 1)' do
      result = r.get_new_urls_and_update_status(1)
      ru1.assign_attributes({status: EasySettings.status.working})

      expect(result.count).to eq 1
      expect(result[0]).to eq ru1
      expect(RequestedUrl.find_by_id(ru2.id)).to eq ru2
      expect(RequestedUrl.find_by_id(ru3.id)).to eq ru3
      expect(RequestedUrl.find_by_id(ru4.id)).to eq ru4
      expect(RequestedUrl.find_by_id(ru5.id)).to eq ru5
      expect(RequestedUrl.find_by_id(ru6.id)).to eq ru6
      expect(RequestedUrl.find_by_id(ru7.id)).to eq ru7
      expect(RequestedUrl.find_by_id(ru8.id)).to eq ru8
      expect(RequestedUrl.find_by_id(ru9.id)).to eq ru9
      expect(RequestedUrl.find_by_id(ru10.id)).to eq ru10

      expect(r.status).to eq EasySettings.status.working
    end
  end

  describe '#all_urls_finished?' do
    let!(:r)   { create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working) }
    let!(:ru1) { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.completed) }
    let!(:ru2) { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.completed) }

    it '全て完了していたらtrueが返ること' do
      expect(r.all_urls_finished?).to be_truthy
    end

    it '着手中のものがあればfalseが返ること' do
      create(:requested_url, request_id: r.id, status: EasySettings.status.working)

      expect(r.all_urls_finished?).to be_falsey
    end
  end

  describe '#update_list_site_result_headers' do
    let(:headers) { {'a' => 3, 'b' => 2 }.to_json }
    let(:absolute_headers) { [] }
    let(:req)   { create(:request, user_id: pu.id, list_site_result_headers: headers) }

    before { req.update_list_site_result_headers(new_headers, absolute_headers) }

    context 'list_site_result_headersが空の場合' do
      let(:headers) { nil }
      let(:new_headers) { ['a', 'b'] }
      it { expect(req.list_site_result_headers).to eq( {'a' => 1, 'b' => 1}.to_json ) }
    end

    context 'list_site_result_headersがある場合' do
      let(:new_headers) { ['c', 'd'] }
      it { expect(req.list_site_result_headers).to eq( {'a' => 3, 'b' => 2, 'c' => 1, 'd' => 1}.to_json ) }
    end

    context 'list_site_result_headersがある場合、並び替えが発生する場合' do
      let(:headers) { {'a' => 3, 'b' => 2, 'c' => 2 }.to_json }
      let(:new_headers) { ['c', 'd'] }
      it { expect(req.list_site_result_headers).to eq( {'a' => 3, 'c' => 3, 'b' => 2, 'd' => 1}.to_json ) }
    end

    context 'list_site_result_headersが499個ある場合' do
      let(:row_headers) do
        a = {}
        499.times { |i| a["a#{i}"] = 499 - i }
        a
      end
      let(:headers) { row_headers.to_json }
      let(:new_headers) { ['c'] }
      let(:result_headers) { row_headers['c'] = 1; row_headers }
      it { expect(req.list_site_result_headers).to eq( result_headers.to_json ) }
    end

    context 'list_site_result_headersが500個ある場合' do
      let(:row_headers) do
        a = {}
        500.times { |i| a["a#{i}"] = 500 - i }
        a
      end
      let(:headers) { row_headers.to_json }
      let(:new_headers) { ['c', 'd'] }
      it { expect(req.list_site_result_headers).to eq( row_headers.to_json ) }
      it { expect(JSON.parse(req.list_site_result_headers).size).to eq( 500 ) }
    end

    context 'list_site_result_headersが500個ある場合' do
      let(:row_headers) do
        a = {}
        500.times { |i| a["a#{i}"] = 500 - i }
        a
      end
      let(:headers) { row_headers.to_json }
      let(:new_headers) { ['c', 'd'] }
      it { expect(req.list_site_result_headers).to eq( row_headers.to_json ) }
      it { expect(JSON.parse(req.list_site_result_headers).size).to eq( 500 ) }
    end
  end

  describe '#get_list_site_result_headers' do
    let(:headers) do
      { Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 10, Analyzer::BasicAnalyzer::ATTR_PAGE => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE => 10,
        Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)'  => 10,
        'aa(個別ページ)' => 10, 'bb(個別ページ)' => 10, 'cc(個別ページ)' => 10,
        'aa' => 10, 'bb' => 10, 'cc' => 10,
        'ee' => 9, 'ff' => 9, 'gg' => 9,
        'ee(個別ページ)' => 9, 'ff(個別ページ)' => 9, 'gg(個別ページ)' => 9
      }
    end
    let(:req) { create(:request, user_id: pu.id, list_site_result_headers: headers.to_json) }

    context do
      it { expect(req.get_list_site_result_headers).to eq( [Analyzer::BasicAnalyzer::ATTR_ORG_NAME, Analyzer::BasicAnalyzer::ATTR_PAGE, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE,
                                                            'aa', 'bb', 'cc','ee', 'ff', 'gg',
                                                            Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)',
                                                            'aa(個別ページ)', 'bb(個別ページ)', 'cc(個別ページ)','ee(個別ページ)', 'ff(個別ページ)', 'gg(個別ページ)'
                                                            ] ) }
    end

    context do
      let(:headers) do
        { Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ2)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ2)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ2)'  => 10,
          Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 10, Analyzer::BasicAnalyzer::ATTR_PAGE => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE => 10,
          Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)'  => 10,
          'aa(個別ページ2)' => 10, 'bb(個別ページ2)' => 10, 'cc(個別ページ2)' => 10,
          'ee(個別ページ2)' => 9, 'ff(個別ページ2)' => 9, 'gg(個別ページ2)' => 9,
          'aa(個別ページ)' => 10, 'bb(個別ページ)' => 10, 'cc(個別ページ)' => 10,
          'aa' => 10, 'bb' => 10, 'cc' => 10,
          'ee' => 9, 'ff' => 9, 'gg' => 9,
          'ee(個別ページ)' => 9, 'ff(個別ページ)' => 9, 'gg(個別ページ)' => 9
        }
      end
      it { expect(req.get_list_site_result_headers).to eq( [Analyzer::BasicAnalyzer::ATTR_ORG_NAME, Analyzer::BasicAnalyzer::ATTR_PAGE, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE,
                                                            'aa', 'bb', 'cc','ee', 'ff', 'gg',
                                                            Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)',
                                                            'aa(個別ページ)', 'bb(個別ページ)', 'cc(個別ページ)','ee(個別ページ)', 'ff(個別ページ)', 'gg(個別ページ)',
                                                            Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ2)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ2)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ2)',
                                                            'aa(個別ページ2)', 'bb(個別ページ2)', 'cc(個別ページ2)','ee(個別ページ2)', 'ff(個別ページ2)', 'gg(個別ページ2)'
                                                            ] ) }
    end

    context do
      let(:headers) do
        { Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ2)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ2)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ2)'  => 10,
          'aa(個別ページ3)' => 10, 'bb(個別ページ3)' => 10, 'cc(個別ページ3)' => 10,
          Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 10, Analyzer::BasicAnalyzer::ATTR_PAGE => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE => 10,
          Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)'  => 10,
          'aa(個別ページ2)' => 10, 'bb(個別ページ2)' => 10, 'cc(個別ページ2)' => 10,
          'ee(個別ページ3)' => 9, 'ff(個別ページ3)' => 9, 'gg(個別ページ3)' => 9,
          'ee(個別ページ2)' => 9, 'ff(個別ページ2)' => 9, 'gg(個別ページ2)' => 9,
          'aa(個別ページ)' => 10, 'bb(個別ページ)' => 10, 'cc(個別ページ)' => 10,
          'aa' => 10, 'bb' => 10, 'cc' => 10,
          'ee' => 9, 'ff' => 9, 'gg' => 9,
          'ee(個別ページ)' => 9, 'ff(個別ページ)' => 9, 'gg(個別ページ)' => 9,
          Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ3)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ3)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ3)'  => 10,
        }
      end
      it { expect(req.get_list_site_result_headers).to eq( [Analyzer::BasicAnalyzer::ATTR_ORG_NAME, Analyzer::BasicAnalyzer::ATTR_PAGE, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE,
                                                            'aa', 'bb', 'cc','ee', 'ff', 'gg',
                                                            Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)',
                                                            'aa(個別ページ)', 'bb(個別ページ)', 'cc(個別ページ)','ee(個別ページ)', 'ff(個別ページ)', 'gg(個別ページ)',
                                                            Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ2)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ2)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ2)',
                                                            'aa(個別ページ2)', 'bb(個別ページ2)', 'cc(個別ページ2)','ee(個別ページ2)', 'ff(個別ページ2)', 'gg(個別ページ2)',
                                                            Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ3)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ3)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ3)',
                                                            'aa(個別ページ3)', 'bb(個別ページ3)', 'cc(個別ページ3)','ee(個別ページ3)', 'ff(個別ページ3)', 'gg(個別ページ3)'
                                                            ] ) }
    end

    context '300個以上あるとき' do
      let(:headers) do
        h = { Analyzer::BasicAnalyzer::ATTR_ORG_NAME => 10, Analyzer::BasicAnalyzer::ATTR_PAGE => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE => 10,
              Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)' => 10, Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)'  => 10, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)'  => 10,
              'aa(個別ページ)' => 10, 'bb(個別ページ)' => 10, 'cc(個別ページ)' => 10,
              'aa' => 10, 'bb' => 10, 'cc' => 10,
              'ee' => 9, 'ff' => 9, 'gg' => 9,
              'ee(個別ページ)' => 9, 'ff(個別ページ)' => 9, 'gg(個別ページ)' => 9,
            }

        150.times { |i| h["aa#{i}"] = 5; h["aa#{i}(個別ページ)"] = 5 }
        h
      end
      let(:multi_other_headers) do
        h = []
        141.times { |i| h << "aa#{i}" }
        h
      end
      let(:single_other_headers) do
        h = []
        141.times { |i| h << "aa#{i}(個別ページ)" }
        h
      end
      it { expect(req.get_list_site_result_headers).to eq( [Analyzer::BasicAnalyzer::ATTR_ORG_NAME, Analyzer::BasicAnalyzer::ATTR_PAGE, Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE,
                                                            'aa', 'bb', 'cc','ee', 'ff', 'gg'] + multi_other_headers +
                                                           [Analyzer::BasicAnalyzer::ATTR_ORG_NAME + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE + '(個別ページ)', Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE + '(個別ページ)',
                                                            'aa(個別ページ)', 'bb(個別ページ)', 'cc(個別ページ)','ee(個別ページ)', 'ff(個別ページ)', 'gg(個別ページ)'] + single_other_headers
                                                          ) }
      it { expect(req.get_list_site_result_headers.size).to eq(300) }
    end
  end

  describe '#complete' do
    it 'completeでステータスが完了になること' do
      r = create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working)
      r.complete

      expect(r.status).to eq EasySettings.status.completed
      expect(r.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[r.user.my_plan]
    end
  end

  describe '#copy_analysis_result_from' do
    let_it_be(:user_from) { create(:user) }
    let_it_be(:user_to)   { create(:user) }
    let(:request_from) { create(:request, user: user_from, list_site_analysis_result: analysis_result_from) }
    let(:request_to)   { create(:request, user: user_to, list_site_analysis_result: analysis_result_to) }
    let(:analysis_result_from) { {'multi' => {'aa' => 'bb', 'cc' => 'dd'}, 'single' => {'ee' => 'ff', 'gg' => 'hh'} }.to_json }
    let(:analysis_result_to)   { {'multi' => {'rrr' => 'eee', 'f' => 'd'}, 'single' => {'oo' => 'ss', 'xx' => 'yy'} }.to_json }

    context 'request_fromのIDが間違っている時' do
      it do
        expect(request_to.copy_analysis_result_from(request_from.id + 1000000)).to be_nil
        expect(request_to.reload.list_site_analysis_result).to eq analysis_result_to
      end
    end

    context 'analysis_resultがある時' do
      it do
        expect(request_to.copy_analysis_result_from(request_from.id)).to be_truthy
        expect(request_to.reload.list_site_analysis_result).to eq analysis_result_from
      end
    end

    context 'analysis_result_fromがnil' do
      let(:analysis_result_from) { nil }

      it do
        expect(request_to.copy_analysis_result_from(request_from.id)).to be_truthy
        expect(request_to.reload.list_site_analysis_result).to be_nil
      end
    end

    context 'analysis_result_toがnil' do
      let(:analysis_result_to) { nil }

      it do
        expect(request_to.copy_analysis_result_from(request_from.id)).to be_truthy
        expect(request_to.reload.list_site_analysis_result).to eq analysis_result_from
      end
    end
  end

  describe '#copy_to' do
    def make_attrs(obj)
      attrs = obj.attributes
      attrs.delete('id')
      attrs.delete('request_id')
      attrs.delete('created_at')
      attrs.delete('updated_at')
      attrs.delete('corporate_list_url_id')
      attrs.delete('single_url_ids')
      attrs.delete('requested_url_id')
      attrs
    end

    let(:user_from) { create(:user, role: :administrator) }
    let(:user_to)   { create(:user, billing: :credit) }
    let!(:plan_to)  { create(:billing_plan, name: master_standard_plan.name, billing: user_to.billing) }
    let(:user_plan) { plan_to; user_to.my_plan_number }
    let(:accept_id) { Request.create_accept_id }
    let!(:request)   { create(:request, user: user_from, accept_id: accept_id, plan: user_plan, file_name: '着手', status: EasySettings.status.working) }
    let!(:list_url1) { create(:corporate_list_requested_url_finished, :result_1, request: request, result_attrs: { single_url_ids: [single_url1.id, single_url2.id].to_json } ) }
    let!(:single_url1) { create(:corporate_single_requested_url, :a, request: request, result_attrs: { main: 'aa', candidate_crawl_urls: 'aa1', free_search: 'aa2' } ) }
    let!(:single_url2) { create(:corporate_single_requested_url, :b, request: request, result_attrs: { main: 'bb', candidate_crawl_urls: 'bb1', free_search: 'bb2' } ) }
    let!(:list_url2) { create(:corporate_list_requested_url_finished, :result_2, request: request, result_attrs: { single_url_ids: [single_url3.id, single_url4.id].to_json } ) }
    let!(:single_url3) { create(:corporate_single_requested_url, :c, request: request, result_attrs: { main: 'cc', candidate_crawl_urls: 'cc1', free_search: 'cc2' } ) }
    let!(:single_url4) { create(:corporate_single_requested_url, :d, request: request, result_attrs: { main: 'dd', candidate_crawl_urls: 'dd1', free_search: 'dd2' } ) }

    before do
      # 無限ループするので、ここでアップデートする
      single_url1.update!(corporate_list_url_id: list_url1.id)
      single_url2.update!(corporate_list_url_id: list_url1.id)
      single_url3.update!(corporate_list_url_id: list_url2.id)
      single_url4.update!(corporate_list_url_id: list_url2.id)
    end

    it do
      req_last_id = Request.last.id
      req_url_last_id = RequestedUrl.last.id
      res_last_id = Result.last.id

      req_cnt = Request.count
      req_url_cnt = RequestedUrl.count
      res_cnt = Result.count

      new_request = request.copy_to(user_to.id)

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 6
      expect(Result.count).to eq res_cnt + 6


      expect(new_request.id).to be > req_last_id
      expect(new_request.user_id).to eq user_to.id
      expect(new_request.status).to eq EasySettings.status.completed
      expect(new_request.accept_id).not_to eq accept_id
      expect(new_request.expiration_date).to be_nil
      expect(new_request.plan).to eq EasySettings.plan[user_to.my_plan]
      expect(new_request.ip).to be_nil
      expect(new_request.token).to be_nil

      expect(new_request.corporate_list_urls.size).to eq 2
      expect(new_request.corporate_single_urls.size).to eq 4

      attrs = new_request.corporate_list_urls[0].attributes

      # マルチ
      expect(make_attrs(new_request.corporate_list_urls[0])).to eq make_attrs(list_url1)
      expect(new_request.corporate_list_urls[0].id).to be > req_url_last_id
      expect(new_request.corporate_list_urls[0].request_id).not_to eq request.id
      expect(new_request.corporate_list_urls[0].corporate_list_url_id).to be_nil

      expect(make_attrs(new_request.corporate_list_urls[1])).to eq make_attrs(list_url2)
      expect(new_request.corporate_list_urls[1].id).to be > req_url_last_id
      expect(new_request.corporate_list_urls[1].request_id).not_to eq request.id
      expect(new_request.corporate_list_urls[1].corporate_list_url_id).to be_nil

      # シングル
      expect(make_attrs(new_request.corporate_single_urls[0])).to eq make_attrs(single_url1)
      expect(new_request.corporate_single_urls[0].id).to be > req_url_last_id
      expect(new_request.corporate_single_urls[0].request_id).not_to eq request.id
      expect(new_request.corporate_single_urls[0].corporate_list_url_id).to eq new_request.corporate_list_urls[0].id

      expect(make_attrs(new_request.corporate_single_urls[1])).to eq make_attrs(single_url2)
      expect(new_request.corporate_single_urls[1].id).to be > req_url_last_id
      expect(new_request.corporate_single_urls[1].request_id).not_to eq request.id
      expect(new_request.corporate_single_urls[1].corporate_list_url_id).to eq new_request.corporate_list_urls[0].id

      expect(make_attrs(new_request.corporate_single_urls[2])).to eq make_attrs(single_url3)
      expect(new_request.corporate_single_urls[2].id).to be > req_url_last_id
      expect(new_request.corporate_single_urls[2].request_id).not_to eq request.id
      expect(new_request.corporate_single_urls[2].corporate_list_url_id).to eq new_request.corporate_list_urls[1].id

      expect(make_attrs(new_request.corporate_single_urls[3])).to eq make_attrs(single_url4)
      expect(new_request.corporate_single_urls[3].id).to be > req_url_last_id
      expect(new_request.corporate_single_urls[3].request_id).not_to eq request.id
      expect(new_request.corporate_single_urls[3].corporate_list_url_id).to eq new_request.corporate_list_urls[1].id


      # マルチ リザルト
      expect(make_attrs(new_request.corporate_list_urls[0].result)).to eq make_attrs(list_url1.result)
      expect(new_request.corporate_list_urls[0].result.id).to be > res_last_id
      expect(new_request.corporate_list_urls[0].result.requested_url_id).not_to eq list_url1.id
      expect(JSON.parse(new_request.corporate_list_urls[0].result.single_url_ids)).to contain_exactly new_request.corporate_single_urls[0].id, new_request.corporate_single_urls[1].id

      expect(make_attrs(new_request.corporate_list_urls[1].result)).to eq make_attrs(list_url2.result)
      expect(new_request.corporate_list_urls[1].result.id).to be > res_last_id
      expect(new_request.corporate_list_urls[1].result.requested_url_id).not_to eq list_url2.id
      expect(JSON.parse(new_request.corporate_list_urls[1].result.single_url_ids)).to contain_exactly new_request.corporate_single_urls[2].id, new_request.corporate_single_urls[3].id


      # シングル リザルト
      expect(make_attrs(new_request.corporate_single_urls[0].result)).to eq make_attrs(single_url1.result)
      expect(new_request.corporate_single_urls[0].result.id).to be > res_last_id
      expect(new_request.corporate_single_urls[0].result.requested_url_id).not_to eq single_url1.id
      expect(new_request.corporate_single_urls[0].result.single_url_ids).to be_nil

      expect(make_attrs(new_request.corporate_single_urls[1].result)).to eq make_attrs(single_url2.result)
      expect(new_request.corporate_single_urls[1].result.id).to be > res_last_id
      expect(new_request.corporate_single_urls[1].result.requested_url_id).not_to eq single_url2.id
      expect(new_request.corporate_single_urls[1].result.single_url_ids).to be_nil

      expect(make_attrs(new_request.corporate_single_urls[2].result)).to eq make_attrs(single_url3.result)
      expect(new_request.corporate_single_urls[2].result.id).to be > res_last_id
      expect(new_request.corporate_single_urls[2].result.requested_url_id).not_to eq single_url2.id
      expect(new_request.corporate_single_urls[2].result.single_url_ids).to be_nil

      expect(make_attrs(new_request.corporate_single_urls[3].result)).to eq make_attrs(single_url4.result)
      expect(new_request.corporate_single_urls[3].result.id).to be > res_last_id
      expect(new_request.corporate_single_urls[3].result.requested_url_id).not_to eq single_url3.id
      expect(new_request.corporate_single_urls[3].result.single_url_ids).to be_nil

    end
  end

  describe '#move_to' do
    let(:user_from) { create(:user, role: :administrator) }
    let(:user_to)   { create(:user, billing: :credit) }
    let!(:plan_to)  { create(:billing_plan, name: master_standard_plan.name, billing: user_to.billing) }
    let(:user_plan) { plan_to; user_to.my_plan_number }
    let(:accept_id) { Request.create_accept_id }
    let(:request)   { create(:request, user: user_from, accept_id: accept_id, plan: user_plan, file_name: '着手', status: EasySettings.status.working) }

    it do
      request.move_to(user_to.id)

      request.reload
      expect(request.user_id).to eq user_to.id
      expect(request.status).to eq EasySettings.status.completed
      expect(request.accept_id).not_to eq accept_id
      expect(request.expiration_date).to be_nil
      expect(request.plan).to eq EasySettings.plan[user_to.my_plan]
      expect(request.ip).to be_nil
      expect(request.token).to be_nil
    end
  end

  describe 'メソッド群get_XXXX_urlsに関して' do
    let_it_be(:r)    { create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working) }
    let_it_be(:r2)   { create(:request, user_id: pu.id, file_name: '着手', status: EasySettings.status.working) }
    let_it_be(:ru1)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.new) }
    let_it_be(:ru2)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.waiting) }
    let_it_be(:ru3)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.working) }
    let_it_be(:ru4)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.all_working) }
    let_it_be(:ru5)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.completed) }
    let_it_be(:ru6)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.discontinued) }
    let_it_be(:ru7)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.pending) }
    let_it_be(:ru8)  { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.waiting) }
    let_it_be(:ru9)  { create(:company_info_requested_url, request_id: r2.id, status: EasySettings.status.new) }
    let_it_be(:ru10) { create(:company_info_requested_url, request_id: r2.id, status: EasySettings.status.waiting) }
    let_it_be(:ru11) { create(:company_info_requested_url, request_id: r2.id, status: EasySettings.status.working) }
    let_it_be(:ru12) { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.completed) }
    let_it_be(:ru13) { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.error) }
    let_it_be(:ru14) { create(:company_info_requested_url, request_id: r.id, status: EasySettings.status.error) }

    it 'get_waiting_urlsで未着手のものが取れること' do
      expect(r.get_waiting_urls.count).to eq 3
      expect(r.get_waiting_urls[0]).to eq ru1
      expect(r.get_waiting_urls[1]).to eq ru2
      expect(r.get_waiting_urls[2]).to eq ru8

      expect(r2.get_waiting_urls.count).to eq 2
      expect(r2.get_waiting_urls[0]).to eq ru9
      expect(r2.get_waiting_urls[1]).to eq ru10
    end

    it 'get_unfinished_urlsで未完了のものが取れること' do
      expect(r.get_unfinished_urls.count).to eq 4
      expect(r.get_unfinished_urls[0]).to eq ru1
      expect(r.get_unfinished_urls[1]).to eq ru2
      expect(r.get_unfinished_urls[2]).to eq ru3
      expect(r.get_unfinished_urls[3]).to eq ru8

      expect(r2.get_unfinished_urls.count).to eq 3
      expect(r2.get_unfinished_urls[0]).to eq ru9
      expect(r2.get_unfinished_urls[1]).to eq ru10
      expect(r2.get_unfinished_urls[2]).to eq ru11
    end

    it 'get_completed_urlsで完了のものが取れること' do
      expect(r.get_error_urls.count).to eq 2
      expect(r.get_error_urls[0]).to eq ru13
      expect(r.get_error_urls[1]).to eq ru14

      expect(r2.get_error_urls.count).to eq 0
    end
  end
end

require 'rails_helper'

RSpec.describe RequestsController, type: :controller do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end

  describe "PUT request_simple_investigation" do
    subject { put :request_simple_investigation, params: params }
    let_it_be(:user)         { create(:user) }
    let_it_be(:unlogin_user) { create(:user) }
    let_it_be(:public_user)  { create(:user_public) }
    let_it_be(:plan)         { create(:billing_plan,  name: master_standard_plan.name, billing: user.billing) }
    let!(:history)           { create(:monthly_history, user: user, plan: EasySettings.plan[:standard]) }
    let(:correct_accept_id)  { 'abcdef' }
    let(:wrong_accept_id)    { 'abcdefghijk' }
    let(:accept_id)          { correct_accept_id }
    let(:correct_url)        { 'https://example.com' }
    let(:wrong_url)          { 'https://example2.com' }
    let(:url)                { correct_url }
    let(:params)             { { accept_id: accept_id, url: url } }
    let(:status)             { EasySettings.status.completed }
    let!(:r0)                { create(:request, :corporate_site_list, accept_id: accept_id, corporate_list_site_start_url: url, status: status, user: user) }
    let_it_be(:r1)           { create(:request, user: user) }
    let_it_be(:r2)           { create(:request, :corporate_site_list, status: EasySettings.status.completed, user: user) }
    let_it_be(:r3)           { create(:request, user: public_user) }
    let_it_be(:r4)           { create(:request, :corporate_site_list, user: public_user) }
    let!(:other_user_req)    { create(:request, :corporate_site_list, accept_id: wrong_accept_id, corporate_list_site_start_url: correct_url, status: EasySettings.status.completed, user: unlogin_user) }
    let(:request)            { Request.find_by_accept_id(correct_accept_id) }
    let(:json)               { JSON.parse(response.body) }

    context '異常系' do
      context '非ログインユーザ' do
        it '失敗すること' do
          history_count = SimpleInvestigationHistory.count
          investigation_count = history.simple_investigation_count
          subject

          expect(response.status).to eq 403
          expect(json.keys).to eq ['error']
          expect(json['error']).to eq '依頼に失敗しました。'

          expect(SimpleInvestigationHistory.count).to eq history_count + 0
          expect(history.reload.simple_investigation_count).to eq investigation_count + 0
        end
      end

      context 'ログインユーザ' do
        before { sign_in user }

        context 'accept_idが空' do
          let(:accept_id) { nil }

          it '失敗すること' do
            history_count = SimpleInvestigationHistory.count
            investigation_count = history.simple_investigation_count
            subject

            expect(response.status).to eq 400
            expect(json.keys).to eq ['error']
            expect(json['error']).to eq '依頼に失敗しました。'

            expect(SimpleInvestigationHistory.count).to eq history_count + 0
            expect(history.reload.simple_investigation_count).to eq investigation_count + 0
          end
        end

        context 'requestが完了で、1ヶ月以上前' do
          let(:r0) { create(:request, :corporate_site_list, accept_id: correct_accept_id, status: status, user: user, updated_at: Time.zone.today.beginning_of_day - 1.month) }

          it '失敗すること' do
            history_count = SimpleInvestigationHistory.count
            investigation_count = history.simple_investigation_count
            subject

            expect(response.status).to eq 400
            expect(json.keys).to eq ['error']
            expect(json['error']).to eq '依頼に失敗しました。'

            expect(SimpleInvestigationHistory.count).to eq history_count + 0
            expect(history.reload.simple_investigation_count).to eq investigation_count + 0
          end
        end

        context 'リクエストのユーザが違う時' do
          let(:accept_id) { other_user_req.accept_id }

          it '失敗すること' do
            history_count = SimpleInvestigationHistory.count
            investigation_count = history.simple_investigation_count
            subject

            expect(response.status).to eq 400
            expect(json.keys).to eq ['error']
            expect(json['error']).to eq '依頼に失敗しました。'

            expect(SimpleInvestigationHistory.count).to eq history_count + 0
            expect(history.reload.simple_investigation_count).to eq investigation_count + 0
          end
        end

        context 'パラメータのURLがリクエストのURLと違う時' do
          let(:params) { { accept_id: accept_id, url: wrong_url } }

          it '失敗すること' do
            history_count = SimpleInvestigationHistory.count
            investigation_count = history.simple_investigation_count
            subject

            expect(response.status).to eq 400
            expect(json.keys).to eq ['error']
            expect(json['error']).to eq '依頼に失敗しました。'

            expect(SimpleInvestigationHistory.count).to eq history_count + 0
            expect(history.reload.simple_investigation_count).to eq investigation_count + 0
          end
        end

        context '既に簡易調査依頼を受け付けているリクエストの時' do

          before do
            create(:simple_investigation_history, user: user, request: r0, url: url)
          end

          it '失敗すること' do
            history_count = SimpleInvestigationHistory.count
            investigation_count = history.simple_investigation_count
            subject

            expect(response.status).to eq 400
            expect(json.keys).to eq ['error']
            expect(json['error']).to eq 'すでに簡易調査の申請を出しています。運営からの連絡をお待ちくださいませ。'

            expect(SimpleInvestigationHistory.count).to eq history_count + 0
            expect(history.reload.simple_investigation_count).to eq investigation_count + 0
          end
        end

        context '月間の上限に達している時' do
          let(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[:standard], simple_investigation_count: EasySettings.simple_investigation_limit[:standard]) }

          it '失敗すること' do
            history_count = SimpleInvestigationHistory.count
            investigation_count = history.simple_investigation_count
            subject

            expect(response.status).to eq 400
            expect(json.keys).to eq ['error']
            expect(json['error']).to eq '利用制限に達しています。'

            expect(SimpleInvestigationHistory.count).to eq history_count + 0
            expect(history.reload.simple_investigation_count).to eq investigation_count + 0
          end
        end
      end
    end

    context '正常系' do
      before { sign_in user }

      after do
        ActionMailer::Base.deliveries.clear
      end

      it '成功すること' do
        history_count = SimpleInvestigationHistory.count
        investigation_count = history.simple_investigation_count
        expect(SimpleInvestigationHistory.find_by_request_id(r0.id)).to be_blank
        subject

        expect(response.status).to eq 200
        expect(json.keys).to eq ['ok']
        expect(json['ok']).to eq 'accepted'

        expect(SimpleInvestigationHistory.count).to eq history_count + 1
        investigation_history = SimpleInvestigationHistory.find_by_request_id(r0.id).reload
        expect(investigation_history.user_id).to eq user.id
        expect(investigation_history.url).to eq url
        expect(investigation_history.domain).to eq 'example.com'
        expect(history.reload.simple_investigation_count).to eq investigation_count + 1

        # メールが飛ぶこと
        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].from).to eq ['notifications@corp-list-pro.com']
        expect(ActionMailer::Base.deliveries[0].to).to include user.email
        expect(ActionMailer::Base.deliveries[0].subject).to match(/簡易調査と簡易設定の申請が完了しました。/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/以下のURLの簡易調査と簡易設定の依頼を受け付けました。/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/クエスト名: #{r0.title}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/調査対象URL: #{r0.corporate_list_site_start_url}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/調査の結果はこちらのメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。/)
        
        expect(ActionMailer::Base.deliveries[1].from).to eq ['info@corp-list-pro.com']
        expect(ActionMailer::Base.deliveries[1].to).to eq ['info@corp-list-pro.com']
        expect(ActionMailer::Base.deliveries[1].subject).to match(/簡易調査の依頼が届きました。【リクエストID: #{r0.id}】【ユーザID: #{user.id}】/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/簡易調査の依頼が届きました。/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ユーザID: #{user.id}/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ユーザメール: #{user.email}/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ユーザ会社: #{user.company_name}/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/調査URL: #{r0.corporate_list_site_start_url}/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/リクエストID: #{r0.id}/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/リクエストタイトル: #{r0.title}/)
      end
    end
  end
end

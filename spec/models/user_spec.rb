require 'rails_helper'

RSpec.describe User, type: :model do
  let_it_be(:master_standard_plan) { create(:master_billing_plan, :standard) }
  let_it_be(:master_gold_plan)     { create(:master_billing_plan, :gold) }
  let_it_be(:master_platinum_plan) { create(:master_billing_plan, :platinum) }

  let_it_be(:user) { create(:user) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['standard', 'gold', 'platinum'])
  end

  describe 'user create (validation check)' do
    it 'is valid' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'is invalid without a email' do
      user = build(:user, email: '')
      user.valid?
      expect(user.errors[:email]).to include("を入力してください")
    end

    it 'is invalid without a company_name' do
     user = build(:user, company_name: '')
     user.valid?
     expect(user.errors[:company_name]).to include('を入力してください')
    end

    it "is invalid without a password" do
      user = build(:user, password: '')
      user.valid?
      expect(user.errors[:password]).to include("を入力してください")
    end

    it 'is invalid without a password_confirmation although with a password' do
      user = build(:user, password_confirmation: '')
      user.valid?
      expect(user.errors[:password_confirmation]).to include("とパスワードの入力が一致しません")
    end

    it 'is invalid with a duplicate email address' do
      user = create(:user)
      another_user = build(:user, email: user.email)
      another_user.valid?
      expect(another_user.errors[:email]).to include('はすでに存在します')
    end

    it "is invalid with a password that has less than 8 characters " do
      user = build(:user, password: "a234567", password_confirmation: "a234567")
      user.valid?
      expect(user.errors[:password][0]).to include("は8文字以上で入力してください")
    end

    it "is valid with a password that has more than 8 characters " do
      user = build(:user, password: "a2345678", password_confirmation: "a2345678")
      user.valid?
      expect(user).to be_valid
    end

    it "is invalid a password that has only alphabets" do
      user = build(:user, password: "abcdefgh", password_confirmation: "abcdefgh")
      user.valid?
      expect(user.errors[:password][0]).to include("は英字、数字をそれぞれ1文字ずつ含めてください")
    end

    it "is invalid a password that has only digits" do
      user = build(:user, password: "12345678", password_confirmation: "12345678")
      user.valid?
      expect(user.errors[:password][0]).to include("は英字、数字をそれぞれ1文字ずつ含めてください")
    end
  end

  describe 'メソッドに関して' do
    let(:today) { Time.zone.today }

    xdescribe '#over_access?' do
      it 'アクセス制限に引っかかること' do
        user = create(:user_exceed_access)
        expect(user.over_access?).to be_truthy
      end

      it 'アクセス制限に引っかからないこと、またレコードが更新されないこと' do
        user  = create(:user, plan: EasySettings.plan[:standard], search_count: EasySettings.access_limit[:standard] - 1)
        user2 = create(:user_exceed_access_yesterday)
        expect(user.over_access?).to be_falsey
        expect(user2.over_access?).to be_falsey
        expect(user.search_count).to eq EasySettings.access_limit[:standard] - 1
        expect(user2.latest_access_date).to eq today - 1.day
      end

      it 'レコードがnilでも、アクセス制限に引っかからないこと、また、レコードが更新されること' do
        user  = create(:user, search_count: nil, last_search_count: nil, latest_access_date: nil)
        expect(user.over_access?).to be_falsey
        expect(user.search_count).to eq 0
        expect(user.last_search_count).to eq nil
        expect(user.latest_access_date).to eq today
      end
    end

    describe '#over_monthly_limit?' do
      it 'アクセス制限に引っかかること' do
        user = create(:user)
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], search_count: EasySettings.monthly_access_limit[:standard] + 1)
        expect(user.over_monthly_limit?).to be_truthy
      end

      it 'アクセス制限に引っかからないこと、またレコードが更新されないこと' do
        user  = create(:user)
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], search_count: EasySettings.monthly_access_limit[:standard] - 1)

        expect(user.over_monthly_limit?).to be_falsey
        expect(MonthlyHistory.find_around(user).search_count).to eq EasySettings.monthly_access_limit[:standard] - 1
      end

      it 'レコードがnilでも、アクセス制限に引っかからないこと、また、レコードが更新されること' do
        user  = create(:user)
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], search_count: nil)

        expect(user.over_monthly_limit?).to be_falsey
        expect(MonthlyHistory.find_around(user).search_count).to eq 0
      end
    end

    describe '#count_up' do
      it 'カウントアップで昨日のアクセスカウントが新しくなり、今日のカウントが1になること、月のカウントがカウントされること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], search_count: 14)
        user.count_up
        expect(MonthlyHistory.find_around(user).search_count).to eq 15
      end

      it 'レコードがnilでも、カウントアップで新しくカウントが1になること、月のカウントがカウントされること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], search_count: nil)
        user.count_up
        expect(MonthlyHistory.find_around(user).search_count).to eq 1
      end
    end

    xdescribe '#request_limit?' do
      it '複数リクエストでアクセス制限に引っかかること' do
        user = create(:user_exceed_request_access)
        expect(user.request_limit?).to be_truthy
      end

      it '複数リクエストでアクセス制限に引っかからないこと' do
        user  = create(:user, plan: EasySettings.plan[:standard], request_count: EasySettings.request_limit[:standard] - 1)
        user2 = create(:user_exceed_request_access_yesterday)
        expect(user.request_limit?).to be_falsey
        expect(user2.request_limit?).to be_falsey
      end

      it 'もしレコードがnilでも、複数リクエストでアクセス制限に引っかからないこと' do
        user  = create(:user, request_count: nil, last_request_date: nil)
        user2 = create(:user, request_count: -1,  last_request_date: nil)
        expect(user.request_limit?).to be_falsey
        expect(user2.request_limit?).to be_falsey
        expect(user.request_count).to eq 0
        expect(user.last_request_date).to eq today
        expect(user2.request_count).to eq 0
        expect(user2.last_request_date).to eq today
      end
    end

    describe '#monthly_request_limit?' do
      it '複数リクエストでアクセス制限に引っかかること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: EasySettings.monthly_request_limit[:standard] + 1)
        expect(user.monthly_request_limit?).to be_truthy
      end

      it '複数リクエストでアクセス制限に引っかからないこと' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: EasySettings.monthly_request_limit[:standard] - 1)
        expect(user.monthly_request_limit?).to be_falsey
      end

      it 'もしレコードがnilでもマイナスでも、複数リクエストでアクセス制限に引っかからないこと、カウントが0になること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: nil)
        expect(user.monthly_request_limit?).to be_falsey
        expect(MonthlyHistory.find_around(user).request_count).to eq 0
      end

      it 'もしレコードがnilでもマイナスでも、複数リクエストでアクセス制限に引っかからないこと、カウントが0になること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: -1)
        expect(user.monthly_request_limit?).to be_falsey
        expect(MonthlyHistory.find_around(user).request_count).to eq 0
      end
    end

    describe '#request_count_up' do
      subject { user.request_count_up }

      it '複数リクエストでカウントアップで昨日のアクセスカウントが新しくなり、今日のカウントが1になること、今月のカウントが+1されること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: 14)
        subject
        expect(MonthlyHistory.find_around(user).request_count).to eq 15
      end

      it '複数リクエストでカウントアップでカウントがプラス1されること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: 10)
        subject
        expect(MonthlyHistory.find_around(user).request_count).to eq 11
      end

      it 'もしレコードがnilでも、複数リクエストでカウントアップでカウントがプラス1されること' do
        create(:monthly_history, user: user, plan: EasySettings.plan[:standard], request_count: nil)
        subject
        expect(MonthlyHistory.find_around(user).request_count).to eq 1
      end
    end

    describe '#monthly_simple_investigation_limit?' do
      let!(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[:standard], simple_investigation_count: simple_investigation_count) }

      context '制限より低い時' do
        let!(:simple_investigation_count) { EasySettings.simple_investigation_limit[:standard] - 1 }
        it do
          expect(user.monthly_simple_investigation_limit?).to be_falsey
        end
      end

      context '制限と同じ時' do
        let!(:simple_investigation_count) { EasySettings.simple_investigation_limit[:standard] }
        it do
          expect(user.monthly_simple_investigation_limit?).to be_truthy
        end
      end

      context 'nilの時' do
        let!(:simple_investigation_count) { nil }
        it do
          expect(user.monthly_simple_investigation_limit?).to be_falsey
          expect(history.reload.simple_investigation_count).to eq 0
        end
      end

      context 'マイナスの時' do
        let!(:simple_investigation_count) { -50 }
        it do
          expect(user.monthly_simple_investigation_limit?).to be_falsey
          expect(history.reload.simple_investigation_count).to eq 0
        end
      end
    end

    describe '#simple_investigation_count_up' do
      subject { user.simple_investigation_count_up }

      let!(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[:standard], simple_investigation_count: simple_investigation_count) }

      context 'nilの時' do
        let!(:simple_investigation_count) { nil }

        it 'カウントアップすること' do
          subject
          expect(history.reload.simple_investigation_count).to eq 1
        end
      end

      context '2の時' do
        let!(:simple_investigation_count) { 2 }

        it 'カウントアップすること' do
          subject
          expect(history.reload.simple_investigation_count).to eq 3
        end
      end
    end

    describe '#my_plan' do 
      it 'my_planでplan名がわかること' do
        user1 = create(:admin_user)
        user2 = create(:user_public)
        user3 = create(:user)
        user3.billing.create_plan!(master_standard_plan.id)
        user4 = create(:user)
        user4.billing.create_plan!(master_gold_plan.id)
        user5 = create(:user)
        user5.billing.create_plan!(master_platinum_plan.id)
        user6 = create(:user)

        expect(user1.my_plan).to eq :administrator
        expect(user2.my_plan).to eq :public
        expect(user3.my_plan).to eq :standard
        expect(user4.my_plan).to eq :gold
        expect(user5.my_plan).to eq :platinum
        expect(user6.my_plan).to eq :free
      end
    end

    describe '#paid?' do
      let_it_be(:user) { create(:user) }
      context 'current_planがある時' do
        it do
          user.billing.create_plan!(master_standard_plan.id)
          expect(user.paid?).to be_truthy
        end
      end

      context 'current_planがない時' do
        it do
          expect(user.paid?).to be_falsey
        end
      end

      context 'current_planがない、過去のプランはある' do
        it do
          user.billing.create_plan!(master_standard_plan.id)
          user.billing.plans[0].update!(start_at: Time.zone.now.last_month, end_at: Time.zone.now.yesterday.end_of_day)
          expect(user.paid?).to be_falsey
        end
      end
    end

    describe '#unpaid?' do
      let_it_be(:user) { create(:user) }
      context 'current_planがある時' do
        it do
          user.billing.create_plan!(master_standard_plan.id)
          expect(user.unpaid?).to be_falsey
        end
      end

      context 'current_planがない時' do
        it do
          expect(user.unpaid?).to be_truthy
        end
      end

      context 'current_planがない、過去のプランはある' do
        it do
          user.billing.create_plan!(master_standard_plan.id)
          user.billing.plans[0].update!(start_at: Time.zone.now.last_month, end_at: Time.zone.now.yesterday.end_of_day)
          expect(user.unpaid?).to be_truthy
        end
      end
    end

    describe '#trial?' do
      context 'current_planがtrial' do
        it do
          user.billing.create_plan!(master_standard_plan.id, trial: true)
          expect(user.trial?).to be_truthy
        end
      end

      context 'current_planがtrial' do
        it do
          user.billing.create_plan!(master_standard_plan.id, trial: false)
          expect(user.trial?).to be_falsey
        end
      end

      context 'current_planがない時' do
        it do
          expect(user.trial?).to be_falsey
        end
      end
    end

    describe '#credit_payment?' do

      it 'クレジット課金ユーザであればtrueが返ること' do
        user.billing.update!(payment_method: :credit)
        expect(user.credit_payment?).to be_truthy
      end

      it '銀行振込課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: :bank_transfer)
        expect(user.credit_payment?).to be_falsey
      end

      it '請求書ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: :invoice)
        expect(user.credit_payment?).to be_falsey
      end

      it '非課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: nil)
        expect(user.credit_payment?).to be_falsey
      end
    end

    describe '#bank_payment?' do

      it '銀行振込課金ユーザであればtrueが返ること' do
        user.billing.update!(payment_method: :bank_transfer)
        expect(user.bank_payment?).to be_truthy
      end

      it '銀行振込課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: :credit)
        expect(user.bank_payment?).to be_falsey
      end

      it '請求書ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: :invoice)
        expect(user.bank_payment?).to be_falsey
      end

      it '非課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: nil)
        expect(user.bank_payment?).to be_falsey
      end
    end

    describe '#invoice_payment?' do

      it '銀行振込課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: :bank_transfer)
        expect(user.invoice_payment?).to be_falsey
      end

      it '銀行振込課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: :credit)
        expect(user.invoice_payment?).to be_falsey
      end

      it '請求書ユーザであればtrueが返ること' do
        user.billing.update!(payment_method: :invoice)
        expect(user.invoice_payment?).to be_truthy
      end

      it '非課金ユーザであればfalseが返ること' do
        user.billing.update!(payment_method: nil)
        expect(user.invoice_payment?).to be_falsey
      end
    end

    describe '#public_id' do
      it 'publicユーザのidが取得できること' do
        id = create(:user_public).id
        create(:user)
        expect(User.public_id).to eq id
        expect(User.find(id).my_plan).to eq :public
      end
    end

    describe '#referrer_trial_coupon' do
      subject { user.referrer_trial_coupon }
      let(:user)    { create(:user) }
      let(:coupon1) { create(:coupon, title: 'クーポン1') }
      let(:coupon2) { create(:referrer_trial) }
      let(:coupon3) { create(:coupon, title: 'クーポン3') }
      let!(:user_coupon1) { create(:user_coupon, user: user, coupon: coupon1) }
      let!(:user_coupon2) { create(:user_coupon, user: user, coupon: coupon2) }
      let!(:user_coupon3) { create(:user_coupon, user: user, coupon: coupon3) }

      it do
        expect(subject).to eq user_coupon2
      end
    end

    describe '#confirm_count_period' do
      subject { user.confirm_count_period }

      let!(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[:standard]) }
      let(:trial) { false }

      before do
        allow(user).to receive(:confirm_count_period_for_credit)
        allow(user).to receive(:confirm_count_period_for_bank)
        allow(user).to receive(:confirm_count_period_for_free_or_admin)
        allow(Lograge).to receive(:logging)
        user.billing.update!(payment_method: payment_method)
      end

      context 'creditユーザ' do
        let(:payment_method) { Billing.payment_methods[:credit] }

        before { user.billing.create_plan!(master_standard_plan.id, trial: trial) }

        it do
          subject
          expect(user).to have_received(:confirm_count_period_for_credit).once
          expect(user).not_to have_received(:confirm_count_period_for_bank)
          expect(user).not_to have_received(:confirm_count_period_for_free_or_admin)
          expect(Lograge).not_to have_received(:logging)
        end
      end

      context 'bank_transferユーザ' do
        let(:payment_method) { Billing.payment_methods[:bank_transfer] }

        before { user.billing.create_plan!(master_standard_plan.id, trial: trial) }

        it do
          subject
          expect(user).not_to have_received(:confirm_count_period_for_credit)
          expect(user).to have_received(:confirm_count_period_for_bank).once
          expect(user).not_to have_received(:confirm_count_period_for_free_or_admin)
          expect(Lograge).not_to have_received(:logging)
        end
      end

      context 'trialユーザ' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        let(:trial) { true }

        before { user.billing.create_plan!(master_standard_plan.id, trial: trial) }

        it do
          subject
          expect(user).to have_received(:confirm_count_period_for_credit).once
          expect(user).not_to have_received(:confirm_count_period_for_bank)
          expect(user).not_to have_received(:confirm_count_period_for_free_or_admin)
          expect(Lograge).not_to have_received(:logging)
        end
      end

      context 'freeユーザ' do
        let(:payment_method) { nil }

        it do
          subject
          expect(user).not_to have_received(:confirm_count_period_for_credit)
          expect(user).not_to have_received(:confirm_count_period_for_bank)
          expect(user).to have_received(:confirm_count_period_for_free_or_admin).once
          expect(Lograge).not_to have_received(:logging)
        end
      end

      context 'administratorユーザ' do
        let(:payment_method) { nil }

        before { user.update!(role: :administrator) }
        after { user.update!(role: :general_user) }

        it do
          subject
          expect(user).not_to have_received(:confirm_count_period_for_credit)
          expect(user).not_to have_received(:confirm_count_period_for_bank)
          expect(user).to have_received(:confirm_count_period_for_free_or_admin).once
          expect(Lograge).not_to have_received(:logging)
        end
      end
    end

    describe '#confirm_count_period_for_credit' do
      subject { user.confirm_count_period_for_credit }
      let(:user) { create(:user, billing_attrs: {payment_method: Billing.payment_methods[:credit]}) }
      let(:plan_number) { EasySettings.plan[:standard] }

      let!(:history) { create(:monthly_history, user: user, plan: plan_number, start_at: start_at, end_at: end_at) }
      let(:trial) { false }
      let(:plan_start_at) { Time.zone.now - 15.days }
      let!(:plan) {
        user.billing.create_plan!(master_standard_plan.id, start_at: plan_start_at, trial: trial)
        user.billing.plans.reload[0]
      }

      before { Timecop.freeze(current_time) }

      after do
        ActionMailer::Base.deliveries.clear
        Timecop.return
      end

      shared_context '一通りの確認' do |trial|
        context 'monthly_historyがない時' do
          let!(:history) { nil }
          context '更新日が現在より１ヶ月以内の時' do
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.reload.count).to eq 1
              expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.first.start_at).to eq Time.zone.now.iso8601
              expect(user.monthly_histories.first.end_at).to eq user.expiration_date.iso8601
            end
          end
        end

        context 'monthly_historyがfreeの時' do
          let(:plan_start_at) {
            if history.start_at < Time.zone.now - 10.days
              Time.zone.now - 9.days
            elsif history.start_at < Time.zone.now - 6.hours
              Time.zone.now - 5.hours
            else
              Time.zone.now - 2.seconds
            end
          }
          let!(:history) { create(:monthly_history, user: user, plan: EasySettings.plan[:free]) }

          it do
            if trial
              first_end_at  = (user.referrer_trial_coupon.created_at.beginning_of_day - 1.second).iso8601
              last_start_at = user.referrer_trial_coupon.created_at.beginning_of_day
            else
              first_end_at  = (plan.start_at - 1.second).iso8601
              last_start_at = plan.start_at
            end

            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq first_end_at
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq last_start_at
            expect(user.monthly_histories.last.end_at).to eq user.next_planned_expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq (user.expiration_date + 1.month).iso8601
          end
        end

        context 'monthly_historyが期限切れの時' do
          context '前回の更新日が次回更新日の１ヶ月以内の時' do
            let(:start_at) { Time.zone.now - 33.days }
            let(:end_at) { Time.zone.now - 3.days }
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.reload.count).to eq 2
              expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.first.end_at).to eq end_at.iso8601
              expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.last.start_at).to eq (end_at + 1.second).iso8601
              expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            end
          end

          context '前回の更新日が１ヶ月以上前の時、現在より更新日が１ヶ月以内の時' do
            let(:start_at) { Time.zone.now - 62.days }
            let(:end_at) { Time.zone.now - 32.days }
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.reload.count).to eq 2
              expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.first.end_at).to eq end_at.iso8601
              expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.last.start_at).to eq (end_at + 1.second).iso8601
              expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            end
          end

          context '前回の更新日が１ヶ月以上前の時、現在より更新日が１ヶ月以内の時。end_atがend_of_day' do
            let(:start_at) { Time.zone.now - 62.days }
            let(:end_at) { (Time.zone.now - 38.days).end_of_day }
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.reload.count).to eq 2
              expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.first.end_at).to eq end_at.iso8601
              expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.last.start_at).to eq (end_at + 1.second).iso8601
              expect(user.monthly_histories.last.start_at).to eq end_at.next_day.beginning_of_day.iso8601
              expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            end
          end

          context '本日が更新日の当日の時。前回の更新日が１ヶ月以上前の時、現在より更新日が１ヶ月以上の時。end_atがend_of_day' do
            let!(:plan) {
              user.billing.create_plan!(master_standard_plan.id, charge_date: Time.zone.now.day.to_s, start_at: Time.zone.now - 45.days, trial: trial)
              user.billing.plans.reload[0].update!(next_charge_date: Time.zone.today)
              user.billing.plans.reload[0].reload
            }
            let(:start_at) { Time.zone.now - 102.days }
            let(:end_at) { (Time.zone.now - 72.days).end_of_day }
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.reload.count).to eq 2
              expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.first.end_at).to eq end_at.iso8601
              expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.last.start_at).to eq (end_at + 1.second).iso8601
              expect(user.monthly_histories.last.start_at).to eq end_at.next_day.beginning_of_day.iso8601
              expect(user.monthly_histories.last.end_at).to eq Time.zone.now.next_month.yesterday.end_of_day.iso8601
            end
          end
        end

        context 'monthly_historyが期限内の時。更新しない時' do
          let(:start_at) { Time.zone.now - 27.days }
          let(:end_at) { Time.zone.now + 3.days }

          context 'プラン変更もない' do
            it '何も変更をしない' do
              expect { subject }.to change(MonthlyHistory, :count).by(0)
              expect(user.monthly_histories.reload.count).to eq 1
              expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
              expect(user.monthly_histories.last.end_at).to eq end_at.iso8601
            end
          end

          context 'プラン変更の時。gold => standard' do
            let(:plan_number) { EasySettings.plan[:gold] }

            it do
              expect { subject }.to change(MonthlyHistory, :count).by(0)
              expect(user.monthly_histories.reload.count).to eq 1
              expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
              expect(user.monthly_histories.last.memo).to eq({EasySettings.plan[:gold] => Time.zone.now}.to_json)
              expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
              expect(user.monthly_histories.last.end_at).to eq end_at.iso8601
            end
          end
        end
      end

      context '支払い済みの時' do
        include_context '一通りの確認', false
      end

      # context 'トライアルの時' do
      #   let(:user) { create(:user, billing_attrs: {payment_method: Billing.payment_methods[:credit]}) }
      #   let!(:coupon) { create(:referrer_trial) }
      #   let!(:user_coupon) { create(:user_coupon, user: user, coupon: coupon) }
      #   let(:trial) { true }

      #   include_context '一通りの確認', true
      # end
    end

    describe '#confirm_count_period_for_bank' do
      subject { user.confirm_count_period_for_bank }
      let(:user) { create(:user, billing_attrs: {payment_method: Billing.payment_methods[:bank_transfer]}) }
      let(:plan_number) { EasySettings.plan[:standard] }
      let!(:history) { create(:monthly_history, user: user, plan: plan_number, start_at: start_at, end_at: history_end_at) }
      let!(:plan) {
        user.billing.create_plan!(master_standard_plan.id, start_at: start_at, end_at: plan_end_at)
        user.billing.plans.reload[0]
      }
      let(:history_end_at) { Time.zone.now + 3.days }
      let(:start_at) { Time.zone.now - 15.days }
      let(:plan_end_at) { (Time.zone.now + 60.days).end_of_day }

      before { Timecop.freeze(current_time) }
      after { Timecop.return }

      context 'monthly_historyがない時' do
        let!(:history) { nil }
        context 'プラン更新日が現在より１ヶ月以上先の時' do
          let(:plan_end_at) { (Time.zone.now + 60.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq Time.zone.now.iso8601
            expect(user.monthly_histories.first.end_at).to eq (Time.zone.now + 1.month - 1.day).end_of_day.iso8601
          end
        end

        context 'プラン更新日が現在より１ヶ月以内の時' do
          let(:plan_end_at) { (Time.zone.now + 15.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq Time.zone.now.iso8601
            expect(user.monthly_histories.first.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.first.end_at).to eq plan_end_at.iso8601
          end
        end
      end

      context 'monthly_historyがfreeの時' do
        let!(:history) { create(:monthly_history, user: user, start_at: Time.zone.now - 100.days, plan: EasySettings.plan[:free]) }
        context 'プラン更新日が現在より１ヶ月以上先の時' do
          let(:plan_end_at) { (Time.zone.now + 36.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq (plan.start_at - 1.second).iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq plan.start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq (start_at + 1.month - 1.day).end_of_day.iso8601
          end
        end

        context 'プラン更新日が現在より１ヶ月以上先の時。start_atが1ヶ月以上前の時' do
          let(:start_at) { Time.zone.now - 47.days }
          let(:plan_end_at) { (Time.zone.now + 36.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq (plan.start_at - 1.second).iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq plan.start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq (start_at + 2.month - 1.day).end_of_day.iso8601
          end
        end

        context 'プラン更新日が現在より１ヶ月以内の時' do
          let(:plan_end_at) { (Time.zone.now + 6.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq (plan.start_at - 1.second).iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq plan.start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
          end
        end
      end

      context 'monthly_historyを更新しない時。期限内の時' do
        let(:start_at) { Time.zone.now - 27.days }
        let(:history_end_at) { Time.zone.now + 3.days }

        context 'プラン変更もない' do
          it '何も変更をしない' do
            expect { subject }.to change(MonthlyHistory, :count).by(0)
            expect(user.monthly_histories.count).to eq 1
            expect(user.monthly_histories.last.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq history_end_at.iso8601
          end
        end

        context 'プラン変更の時。gold => standard' do
          let(:plan_number) { EasySettings.plan[:gold] }

          it do
            expect { subject }.to change(MonthlyHistory, :count).by(0)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.memo).to eq({EasySettings.plan[:gold] => Time.zone.now}.to_json)
            expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq history_end_at.iso8601
          end
        end
      end

      context 'monthly_historyを更新する時。期限が切れている時' do
        let(:start_at) { Time.zone.now - 30.days }
        let(:history_end_at) { Time.zone.now - 1.days }

        context 'プラン更新日が現在より１ヶ月以上先の時' do
          let(:plan_end_at) { (Time.zone.now + 39.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq history_end_at.iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq (history_end_at + 1.second).iso8601
            expect(user.monthly_histories.last.end_at).to eq (user.monthly_histories.last.start_at + 1.month - 1.day).end_of_day.iso8601
          end
        end

        context 'プラン更新日が現在より１ヶ月以上先の時。history_end_atが1ヶ月以上前の時' do
          let(:start_at) { Time.zone.now - 70.days }
          let(:history_end_at) { Time.zone.now - 40.days }
          let(:plan_end_at) { (Time.zone.now + 39.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq history_end_at.iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq (history_end_at + 1.second).iso8601
            expect(user.monthly_histories.last.end_at).to eq (user.monthly_histories.last.start_at + 2.month - 1.day).end_of_day.iso8601
          end
        end

        context 'プラン更新日が現在より１ヶ月以内の時' do
          let(:plan_end_at) { (Time.zone.now + 11.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq history_end_at.iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq (history.end_at + 1.second).iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq plan_end_at.iso8601
          end
        end
      end
    end

    describe '#confirm_count_period_for_invoice' do
      subject { user.confirm_count_period_for_invoice }
      let(:user) { create(:user, billing_attrs: {payment_method: Billing.payment_methods[:invoice]}) }
      let(:plan_number) { EasySettings.plan[:standard] }
      let!(:history) { create(:monthly_history, user: user, plan: plan_number, start_at: start_at, end_at: history_end_at) }
      let!(:plan) {
        user.billing.create_plan!(master_standard_plan.id, charge_date: charge_date, start_at: start_at, end_at: plan_end_at)
        user.billing.plans.reload[0]
      }
      let(:history_end_at) { Time.zone.now + 3.days }
      let(:next_charge_date) { (Time.zone.now + 7.days) }
      let(:charge_date) { next_charge_date.day.to_s }
      let(:start_at) { Time.zone.now - 15.days }
      let(:plan_end_at) { nil }

      before { Timecop.freeze(current_time) }
      after { Timecop.return }

      context 'monthly_historyがない時' do
        let!(:history) { nil }

        context 'プラン終了日が決まっていない時' do
          let(:plan_end_at) { nil }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.first.end_at).to eq next_charge_date.yesterday.end_of_day.iso8601
          end
        end

        context 'プラン終了日が決まっている時、プラン更新日が先に来る時' do
          let(:plan_end_at) { (Time.zone.now + 34.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.first.end_at).to eq next_charge_date.yesterday.end_of_day.iso8601
            expect(user.monthly_histories.first.end_at).to be < plan_end_at.iso8601
          end
        end

        context 'プラン終了日が決まっている時、プラン終了日が先に来る時' do
          let(:charge_date) { (Time.zone.now + 20.days).day.to_s }
          let(:plan_end_at) { (Time.zone.now + 7.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.first.end_at).to eq plan_end_at.iso8601
          end
        end
      end

      context 'monthly_historyがfreeの時' do
        let!(:history) { create(:monthly_history, user: user, start_at: Time.zone.now - 100.days, plan: EasySettings.plan[:free]) }

        context 'プラン終了日が決まっていない時' do
          let(:plan_end_at) { nil }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq (plan.start_at - 1.second).iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq plan.start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq next_charge_date.yesterday.end_of_day.iso8601
          end
        end

        context 'プラン終了日が決まっている時、プラン更新日が先に来る時' do
          let(:plan_end_at) { (Time.zone.now + 34.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq (plan.start_at - 1.second).iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq plan.start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq next_charge_date.yesterday.end_of_day.iso8601
            expect(user.monthly_histories.last.end_at).to be < plan_end_at.iso8601
          end
        end

        context 'プラン終了日が決まっている時、プラン終了日が先に来る時' do
          let(:charge_date) { (Time.zone.now + 10.days).day.to_s }
          let(:plan_end_at) { (Time.zone.now + 5.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:free]
            expect(user.monthly_histories.first.end_at).to eq (plan.start_at - 1.second).iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq plan.start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq plan_end_at.iso8601
          end
        end
      end

      context 'monthly_historyを更新しない時。期限内の時' do
        let(:start_at) { Time.zone.now - 27.days }
        let(:history_end_at) { Time.zone.now + 3.days }

        context 'プラン変更もない' do
          it '何も変更をしない' do
            expect { subject }.to change(MonthlyHistory, :count).by(0)
            expect(user.monthly_histories.count).to eq 1
            expect(user.monthly_histories.last.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq history_end_at.iso8601
          end
        end

        context 'プラン変更の時。gold => standard' do
          let(:plan_number) { EasySettings.plan[:gold] }

          it do
            expect { subject }.to change(MonthlyHistory, :count).by(0)
            expect(user.monthly_histories.reload.count).to eq 1
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.memo).to eq({EasySettings.plan[:gold] => Time.zone.now}.to_json)
            expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq history_end_at.iso8601
          end
        end
      end

      context 'monthly_historyを更新する時。期限が切れている時' do
        let(:start_at) { Time.zone.now - 30.days }
        let(:history_end_at) { Time.zone.now - 1.days }

        context 'プラン終了日が決まっていない時' do
          let(:plan_end_at) { nil }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq history_end_at.iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq (history_end_at + 1.second).iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq next_charge_date.yesterday.end_of_day.iso8601
          end
        end

        context 'プラン終了日が決まっており、課金日が先に来る' do
          let(:start_at) { Time.zone.now - 70.days }
          let(:history_end_at) { Time.zone.now - 40.days }
          let(:plan_end_at) { (Time.zone.now + 39.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq history_end_at.iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq (history_end_at + 1.second).iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq next_charge_date.yesterday.end_of_day.iso8601
            expect(user.monthly_histories.last.end_at).to be < plan_end_at
          end
        end

        context 'プラン終了日が決まっており、終了日が先に来る' do
          let(:start_at) { Time.zone.now - 113.days }
          let(:history_end_at) { Time.zone.now - 83.days }
          let(:charge_date) { (Time.zone.now + 12.days).day.to_s }
          let(:plan_end_at) { (Time.zone.now + 11.days).end_of_day }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.reload.count).to eq 2
            expect(user.monthly_histories.first.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.first.end_at).to eq history_end_at.iso8601
            expect(user.monthly_histories.last.reload.plan).to eq EasySettings.plan[:standard]
            expect(user.monthly_histories.last.start_at).to eq (history.end_at + 1.second).iso8601
            expect(user.monthly_histories.last.end_at).to eq user.expiration_date.iso8601
            expect(user.monthly_histories.last.end_at).to eq plan_end_at.iso8601
          end
        end
      end
    end

    describe '#confirm_count_period_for_free_or_admin' do
      subject { user.confirm_count_period_for_free_or_admin }
      let(:user) { create(:user, billing_attrs: {payment_method: payment_method}) }
      let(:plan_number) { EasySettings.plan[:free] }
      let(:payment_method) { Billing.payment_methods[:credit] }

      let!(:history) { create(:monthly_history, user: user, plan: plan_number, start_at: start_at, end_at: end_at) }
      let(:end_at) { Time.zone.now + 3.days }
      let(:start_at) { Time.zone.now - 15.days }

      before { Timecop.freeze(current_time) }
      after { Timecop.return }

      context '課金プラン' do
        let(:plan_number) { EasySettings.plan[:standard] }
        let!(:plan) {
          user.billing.create_plan!(master_standard_plan.id)
          user.billing.plans.reload[0]
        }

        it do
          expect { subject }.to change(MonthlyHistory, :count).by(0)
          expect(subject).to be_nil
        end
      end

      shared_context 'adminとfreeの全パターンを確認' do
        context 'monthly_historyがない時' do
          let!(:history) { nil }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(1)
            expect(user.monthly_histories.count).to eq 1
            expect(user.monthly_histories.first.plan).to eq plan_number
            expect(user.monthly_histories.first.start_at).to eq Time.zone.now.beginning_of_month.iso8601
            expect(user.monthly_histories.first.end_at).to eq Time.zone.now.end_of_month.iso8601
          end
        end

        context 'monthly_historyの期限内' do
          let(:start_at) { Time.zone.now - 27.days }
          let(:end_at) { Time.zone.now + 3.days }
          it do
            expect { subject }.to change(MonthlyHistory, :count).by(0)
            expect(user.monthly_histories.count).to eq 1
            expect(user.monthly_histories.last.plan).to eq plan_number
            expect(user.monthly_histories.last.start_at).to eq start_at.iso8601
            expect(user.monthly_histories.last.end_at).to eq end_at.iso8601
          end
        end

        context 'monthly_historyを更新する時' do
          context '最後の更新日が現在より１ヶ月以上前の時' do
            let(:start_at) { Time.zone.now - 60.days }
            let(:end_at) { Time.zone.now - 1.month }
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.count).to eq 2
              expect(user.monthly_histories.first.plan).to eq plan_number
              expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
              expect(user.monthly_histories.first.end_at).to eq end_at.iso8601
              expect(user.monthly_histories.last.plan).to eq plan_number
              expect(user.monthly_histories.last.start_at).to eq Time.zone.now.beginning_of_month.iso8601
              expect(user.monthly_histories.last.end_at).to eq Time.zone.now.end_of_month.iso8601
            end
          end

          context '最後の更新日が直近の月初より後の時' do
            let(:start_at) { Time.zone.now - 30.days }
            let(:end_at) { Time.zone.now.beginning_of_month + 3.seconds }
            it do
              expect { subject }.to change(MonthlyHistory, :count).by(1)
              expect(user.monthly_histories.count).to eq 2
              expect(user.monthly_histories.first.plan).to eq plan_number
              expect(user.monthly_histories.first.start_at).to eq start_at.iso8601
              expect(user.monthly_histories.first.end_at).to eq end_at.iso8601
              expect(user.monthly_histories.last.plan).to eq plan_number
              expect(user.monthly_histories.last.start_at).to eq (end_at + 1.second).iso8601
              expect(user.monthly_histories.last.end_at).to eq Time.zone.now.end_of_month.iso8601
            end
          end
        end
      end

      context 'freeユーザ' do
        include_context 'adminとfreeの全パターンを確認'
      end

      context 'adminユーザ' do
        let(:user) { create(:user, role: :administrator, billing_attrs: {payment_method: payment_method}) }
        let(:plan_number) { EasySettings.plan[:administrator] }
        let!(:plan) {
          user.billing.create_plan!(master_standard_plan.id)
          user.billing.plans.reload[0]
        }

        include_context 'adminとfreeの全パターンを確認'
      end
    end

    describe '#expiration_date' do
      subject { user.expiration_date }

      let!(:billing) { user.billing.update!(payment_method: payment_method) }
      let!(:plan) {
        user.billing.create_plan!(master_standard_plan.id, charge_date: charge_date, start_at: start_at, end_at: end_at)
        user.billing.plans.reload[0]
      }
      let(:payment_method) { :credit }
      let(:start_at) { Time.zone.now - 2.months }
      let(:controlled_next_charge_date) { (Time.zone.now + 10.days).beginning_of_day }
      let(:charge_date) { (Time.zone.now + 10.days).day.to_s }

      shared_context 'クレジット、請求書のexpiration_dateの全パターンを確認' do
        context 'next_charge_dateがない' do
          before { user.billing.plans.reload[0].update!(next_charge_date: nil) }

          context 'end_atがnil' do
            let(:end_at) { nil }
            it do
              expect(plan.cal_next_charge_date).to eq controlled_next_charge_date
              expect(subject).to eq controlled_next_charge_date.yesterday.end_of_day
            end
          end

          context 'end_atがある、かつ、end_atが先' do
            let(:end_at) { (Time.zone.now + 5.days).end_of_day }
            it do
              expect(plan.cal_next_charge_date).to be_nil
              expect(subject).to eq end_at.end_of_day.iso8601
            end
          end

          context 'end_atがある、かつ、charge_dateが先' do
            let(:end_at) { (Time.zone.now + 11.days).end_of_day }
            it do
              expect(plan.cal_next_charge_date).to eq controlled_next_charge_date
              expect(subject).to eq controlled_next_charge_date.yesterday.end_of_day
            end
          end
        end

        context 'next_charge_dateがある' do
          before { user.billing.plans.reload[0].update!(next_charge_date: controlled_next_charge_date) }

          context 'end_atがnil' do
            let(:end_at) { nil }
            it do
              expect(subject).to eq controlled_next_charge_date.yesterday.end_of_day
            end
          end

          context 'end_atがある、かつ、end_atが先' do
            let(:end_at) { (Time.zone.now + 5.days).end_of_day }
            it do
              expect(subject).to eq end_at.end_of_day.iso8601
            end
          end

          context 'end_atがある、かつ、charge_dateが先' do
            let(:end_at) { (Time.zone.now + 11.days).end_of_day }
            it do
              expect(subject).to eq controlled_next_charge_date.yesterday.end_of_day
            end
          end
        end
      end

      context 'current_planがない時' do
        let!(:plan) { nil }
        it { expect(subject).to be_nil }
      end

      context 'credit' do
        let(:payment_method) { :credit }
        include_context 'クレジット、請求書のexpiration_dateの全パターンを確認'
      end

      context 'invoice' do
        let(:payment_method) { :invoice }
        include_context 'クレジット、請求書のexpiration_dateの全パターンを確認'
      end

      context 'bank_transfer' do
        let(:payment_method) { :bank_transfer }
        let(:end_at) { (Time.zone.now + 5.days).end_of_day }

        context 'future_planがない' do
          it { expect(subject).to eq end_at.iso8601 }
        end

        context 'future_planがある' do
          let!(:future_plan) { create(:billing_plan, status: :waiting, next_charge_date: nil, start_at: end_at.tomorrow, end_at: future_plan_end_at, billing: user.billing) }
          let(:future_plan_end_at) { (end_at + 3.months).end_of_day }
          it { expect(subject).to eq future_plan_end_at.iso8601 }
        end
      end
    end

    describe '#next_planned_expiration_date' do
      subject { user.next_planned_expiration_date }

      let!(:billing) { user.billing.update!(payment_method: payment_method) }
      let!(:plan) {
        user.billing.create_plan!(master_standard_plan.id, charge_date: charge_date, start_at: start_at, end_at: end_at)
        user.billing.plans.reload[0]
      }
      let(:payment_method) { :credit }
      let(:start_at) { Time.zone.now - 2.months }
      let(:controlled_next_charge_date) { Time.zone.now.beginning_of_day }
      let(:charge_date) { controlled_next_charge_date.day.to_s }
      let(:end_at) { nil }

      context 'current_planがない時' do
        let!(:plan) { nil }
        it { expect(subject).to be_nil }
      end

      context 'bank_transferの時' do
        let(:payment_method) { :bank_transfer }
        it { expect(subject).to be_nil }
      end

      shared_context 'クレジット、請求書のnext_planned_expiration_dateの全パターンを確認' do
        context 'charge_dateを過ぎていない時' do
          let(:controlled_next_charge_date) { Time.zone.now.tomorrow.beginning_of_day }
          before { user.billing.plans.reload[0].update!(next_charge_date: controlled_next_charge_date) }
          it { expect(subject).to be_nil }
        end

        context 'charge_dateを過ぎている時' do
          context 'end_atがnil' do
            let(:end_at) { nil }
            let(:controlled_next_charge_date) { Time.zone.now.beginning_of_day }
            before { user.billing.plans.reload[0].update!(next_charge_date: controlled_next_charge_date) }
            it { expect(subject).to eq controlled_next_charge_date.next_month.yesterday.end_of_day }
          end

          context 'end_atがあるが、まだ来ていない、かつ、end_atが先' do
            let(:end_at) { (Time.zone.now + 3.days).end_of_day }
            let(:controlled_next_charge_date) { Time.zone.now.beginning_of_day }
            before { user.billing.plans.reload[0].update!(next_charge_date: controlled_next_charge_date) }
            it { expect(subject).to eq end_at.iso8601 }
          end

          context 'end_atがあるが、まだ来ていない、かつ、次の課金日が先' do
            let(:end_at) { (Time.zone.now + 32.days).end_of_day }
            let(:controlled_next_charge_date) { Time.zone.now.beginning_of_day }
            before { user.billing.plans.reload[0].update!(next_charge_date: controlled_next_charge_date) }
            it { expect(subject).to eq controlled_next_charge_date.next_month.yesterday.end_of_day }
          end
        end
      end

      context 'credit' do
        let(:payment_method) { :credit }
        include_context 'クレジット、請求書のnext_planned_expiration_dateの全パターンを確認'
      end

      context 'invoice' do
        let(:payment_method) { :invoice }
        include_context 'クレジット、請求書のnext_planned_expiration_dateの全パターンを確認'
      end
    end
  end
end

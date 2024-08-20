require 'rails_helper'


RSpec.describe BillingPlan, type: :model do
  let_it_be(:user)  { create(:user) }
  let(:plan) { create(:billing_plan, type: type, status: status, charge_date: charge_date, start_at: start_at, end_at: end_at, billing: user.billing) }
  let(:type) { :monthly }
  let(:status) { :ongoing }
  let(:charge_date) { '1' }
  let(:start_at) { Time.zone.parse('2023/01/01') }
  let(:end_at) { nil }

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }
  let_it_be(:user4) { create(:user) }
  let_it_be(:user5) { create(:user) }
  let_it_be(:user6) { create(:user) }
  let_it_be(:user7) { create(:user) }
  let_it_be(:user8) { create(:user) }
  let_it_be(:p1) { create(:billing_plan, status: :waiting, next_charge_date: Time.zone.today,           start_at: Time.zone.now - 2.day,     end_at: Time.zone.now - 1.minutes, billing: user1.billing) }
  let_it_be(:p2) { create(:billing_plan, status: :ongoing, next_charge_date: Time.zone.today - 3.days,  start_at: Time.zone.now - 1.minutes, end_at: Time.zone.now + 1.minutes, billing: user2.billing) }
  let_it_be(:p3) { create(:billing_plan, status: :ongoing, next_charge_date: Time.zone.today - 30.days, start_at: Time.zone.now + 1.minutes, end_at: Time.zone.now + 2.days,    billing: user3.billing) }
  let_it_be(:p4) { create(:billing_plan, status: :ongoing, next_charge_date: Time.zone.today - 30.days, start_at: Time.zone.now - 3.minutes, end_at: Time.zone.now - 1.minutes, billing: user4.billing) }
  let_it_be(:p5) { create(:billing_plan, status: :stopped, next_charge_date: Time.zone.today - 30.days, start_at: Time.zone.now - 3.minutes, end_at: Time.zone.now - 1.minutes, billing: user5.billing) }
  let_it_be(:p6) { create(:billing_plan, status: :waiting, next_charge_date: Time.zone.today,           start_at: Time.zone.now - 1.minutes, end_at: nil,                       billing: user6.billing) }
  let_it_be(:p7) { create(:billing_plan, status: :waiting, next_charge_date: Time.zone.today - 3.days,  start_at: Time.zone.now + 1.minutes, end_at: nil,                       billing: user7.billing) }
  let_it_be(:p8) { create(:billing_plan, status: :ongoing, next_charge_date: Time.zone.today - 3.days,  start_at: Time.zone.now + 1.minutes, end_at: nil,                       billing: user8.billing) }


  describe 'バリデーション' do
    describe 'check_time_range' do
      let(:plan_attrs) {
        {
          name: 'テストプラン',
          price: 10_000,
          type: :monthly,
          status: :ongoing,
          charge_date: '1',
          start_at: start_at,
          end_at: end_at,
          tax_included: true,
          tax_rate: 10,
          next_charge_date: nil,
          last_charge_date: nil,
          billing: user.billing,
        }
      }
      let(:start_at) { Time.zone.now }
      let(:end_at) { nil }

      context 'start_at >= end_at' do
        let(:start_at) { Time.zone.now }
        let(:end_at)   { Time.zone.now - 1.seconds }

        it do
          expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /start_atはend_atより小さい値にしてください。/)
        end
      end

      context '他のプランと期間がかぶっている' do
        let!(:plan) { create(:billing_plan, start_at: Time.zone.now.yesterday, end_at: nil, billing: user.billing) }

        it do
          expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /同じbilling_idで有効時間の範囲が被っています。/)
        end
      end

      context '他のプランと期間がかぶっている' do
        let(:end_at)   { Time.zone.now + 2.month }
        let!(:plan) { create(:billing_plan, start_at: Time.zone.now.next_month, end_at: Time.zone.now + 3.months, billing: user.billing) }

        it do
          expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /同じbilling_idで有効時間の範囲が被っています。/)
        end
      end

      context '他のプランと期間がかぶっている' do
        let(:start_at) { Time.zone.now - 1.month }
        let!(:plan) { create(:billing_plan, start_at: Time.zone.now.next_month, end_at: nil, billing: user.billing) }

        it do
          expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /同じbilling_idで有効時間の範囲が被っています。/)
        end
      end
    end

    describe 'check_charge_date' do
      let(:plan_attrs) {
        {
          name: 'テストプラン',
          price: 10_000,
          type: type,
          status: :ongoing,
          charge_date: charge_date,
          start_at: Time.zone.now,
          end_at: nil,
          tax_included: true,
          tax_rate: 10,
          next_charge_date: nil,
          last_charge_date: nil,
          billing: user.billing,
        }
      }
      let(:type) { :monthly }
      let(:charge_date) { '1' }

      context 'weekly' do
        let(:type) { :weekly }

        context 'あ' do
          let(:charge_date) { 'あ' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:weeklyの場合はcharge_dateは\[月 火 水 木 金 土 日\]のいずれかの値にしてください。/)
          end
        end

        context '火' do
          let(:charge_date) { '火' }
          it do
            expect{ described_class.create!(plan_attrs) }.not_to raise_error
          end
        end
      end

      context 'monthly' do
        let(:type) { :monthly }

        context 'a' do
          let(:charge_date) { 'a' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:monthlyの場合はcharge_dateは1~31の数値にしてください。/)
          end
        end

        context '0' do
          let(:charge_date) { '0' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:monthlyの場合はcharge_dateは1~31の数値にしてください。/)
          end
        end

        context '32' do
          let(:charge_date) { '32' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:monthlyの場合はcharge_dateは1~31の数値にしてください。/)
          end
        end

        context '1' do
          let(:charge_date) { '1' }
          it do
            expect{ described_class.create!(plan_attrs) }.not_to raise_error
          end
        end
      end

      context 'annually' do
        let(:type) { :annually }

        context 'aa/gg' do
          let(:charge_date) { 'aa/gg' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:annuallyの場合はcharge_dateはMM\/DDの値にしてください。/)
          end
        end

        context '5/8' do
          let(:charge_date) { '5/8' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:annuallyの場合はcharge_dateはMM\/DDの値にしてください。/)
          end
        end

        context '3245' do
          let(:charge_date) { '0215' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:annuallyの場合はcharge_dateはMM\/DDの値にしてください。/)
          end
        end

        context '13/45' do
          let(:charge_date) { '13/15' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:annuallyの場合はcharge_dateはMM\/DDの値にしてください。/)
          end
        end

        context '10/33' do
          let(:charge_date) { '10/33' }
          it do
            expect{ described_class.create!(plan_attrs) }.to raise_error(ActiveRecord::RecordInvalid, /typeが:annuallyの場合はcharge_dateはMM\/DDの値にしてください。/)
          end
        end

        context '03/07' do
          let(:charge_date) { '03/07' }
          it do
            expect{ described_class.create!(plan_attrs) }.not_to raise_error
          end
        end
      end
    end
  end

  describe 'スコープ' do

    before { Timecop.freeze }
    after  { Timecop.return }

    describe 'current' do
      it do
        expect(described_class.current).to match([p2, p6])
      end
    end

    describe 'search_by_time' do
      it do
        expect(described_class.search_by_time(Time.zone.now - 30.seconds)).to match([p2, p6])
        expect(described_class.search_by_time(Time.zone.now + 2.minutes)).to match([p3, p6, p7, p8])
      end
    end

    describe 'charge_on_date' do
      it do
        expect(described_class.charge_on_date).to match([p1, p6])
        expect(described_class.charge_on_date(Time.zone.today - 3.days)).to match([p2, p7, p8])
        expect(described_class.charge_on_date(Time.zone.today - 30.days)).to match([p3, p4, p5])
      end
    end

    describe 'starting' do
      it do
        expect(described_class.starting).to match([p1, p6])
        expect(described_class.starting(Time.zone.now + 2.minutes)).to match([p1, p6, p7])
      end
    end

    describe 'ending' do
      it do
        expect(described_class.ending).to match([p1, p4])
        expect(described_class.ending(Time.zone.now + 3.minutes)).to match([p1, p2, p4])
      end
    end
  end

  describe '#charge_day?' do
    it do
      expect(p1.charge_day?).to be_truthy
      expect(p2.charge_day?).to be_falsey
      expect(p3.charge_day?).to be_falsey

      expect(p1.charge_day?(Time.zone.now - 3.days)).to be_falsey
      expect(p2.charge_day?(Time.zone.now - 3.days)).to be_truthy
      expect(p3.charge_day?(Time.zone.now - 3.days)).to be_falsey

      expect(p1.charge_day?(Time.zone.now - 30.days)).to be_falsey
      expect(p2.charge_day?(Time.zone.now - 30.days)).to be_falsey
      expect(p3.charge_day?(Time.zone.now - 30.days)).to be_truthy
    end
  end

  describe '#charge_and_status_update_by_credit' do
    let(:plan) { create(:billing_plan, status: status, charge_date: charge_date, next_charge_date: next_charge_date, price: price,
                                       start_at: start_at, end_at: end_at, trial: trial, billing: user.billing) }
    let(:status) { :ongoing }
    let(:price) { 4400 }
    let(:charge_date) { next_charge_date.day.to_s }
    let(:start_at) { Time.zone.now - 7.days }
    let(:end_at) { nil }
    let(:next_charge_date) { Time.zone.today }
    let(:trial) { false }

    context 'trialの時' do
      let(:trial) { true }
      it do
        expect(plan.charge_and_status_update_by_credit).to eq price
      end
    end

    context 'charge_dayじゃない時' do
      let(:next_charge_date) { Time.zone.today - 3.days }

      it do
        expect(plan.charge_and_status_update_by_credit).to be_nil
        expect(plan.charge_and_status_update_by_credit(Time.zone.now - 4.days)).to be_nil
      end
    end

    shared_examples 'statusごとの確認' do
      let(:execute_day) { execute_time.to_date }

      context 'waitingの時' do
        let(:status) { :waiting }

        it do
          expect(subject).to eq price
          expect(plan.reload.status).to eq 'ongoing'
          expect(plan.reload.next_charge_date).to eq execute_day.next_month
          expect(plan.reload.last_charge_date).to eq execute_day
        end
      end

      context 'ongoingの時' do
        let(:status) { :ongoing }

        context 'end_atが過ぎているの時' do
          let(:end_at) { execute_time - 1.minutes }

          it do
            expect(subject).to eq 0
            expect(plan.status).to eq 'stopped'
            expect(plan.next_charge_date).to be_nil
          end
        end

        context 'end_atが過ぎていないの時' do
          let(:end_at) { execute_time + 4.months }

          it do
            expect(subject).to eq price
            expect(plan.reload.status).to eq 'ongoing'
            expect(plan.next_charge_date).to eq execute_day.next_month
            expect(plan.last_charge_date).to eq execute_day
          end
        end

        context 'end_atがnil' do
          let(:end_at) { nil }

          it do
            expect(subject).to eq price
            expect(plan.reload.status).to eq 'ongoing'
            expect(plan.next_charge_date).to eq execute_day.next_month
            expect(plan.last_charge_date).to eq execute_day
          end
        end
      end

      context 'stoppedの時' do
        let(:status) { :stopped }
        let(:next_charge_date) { execute_day }

        context 'end_atがnil' do
          let(:end_at) { nil }

          it do
            expect(subject).to eq 0
            expect(plan.reload.status).to eq 'stopped'
            expect(plan.next_charge_date).to be_nil
            expect(plan.end_at).to eq execute_day.yesterday.end_of_day.iso8601
          end
        end

        context 'end_atがある' do
          let(:end_at) { execute_day - 4.minutes }

          it do
            expect(subject).to eq 0
            expect(plan.reload.status).to eq 'stopped'
            expect(plan.next_charge_date).to be_nil
            expect(plan.end_at).to eq end_at.iso8601
          end
        end
      end
    end

    context 'time引数なし' do
      let(:execute_time) { Time.zone.now }

      subject { plan.charge_and_status_update_by_credit }

      it_behaves_like 'statusごとの確認'
    end

    context 'time引数あり' do
      let(:next_charge_date) { Time.zone.today - 2.days }
      let(:execute_time) { Time.zone.now - 2.days }

      subject { plan.charge_and_status_update_by_credit(execute_time) }

      it_behaves_like 'statusごとの確認'
    end
  end

  describe '#stop_at_next_update_date!' do
    let(:plan) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: nil,
                                       start_at: start_at, end_at: nil, billing: user.billing) }
    let(:start_at) { Time.zone.now.last_month }

    context '引数ない時' do

      context '今日' do
        let(:charge_date) { Time.zone.today.day.to_s }

        it do
          plan.stop_at_next_update_date!
          expect(plan.reload.end_at).to eq Time.zone.today.next_month.yesterday.end_of_day.iso8601
        end
      end

      context '明日' do
        let(:charge_date) { Time.zone.tomorrow.day.to_s }

        it do
          plan.stop_at_next_update_date!
          expect(plan.reload.end_at).to eq Time.zone.today.end_of_day.iso8601
        end
      end

      context '' do
        let(:charge_date) { (Time.zone.today + 7.days).day.to_s }

        it do
          plan.stop_at_next_update_date!
          expect(plan.reload.end_at).to eq (Time.zone.today + 7.days).yesterday.end_of_day.iso8601
        end
      end

      context '' do
        let(:charge_date) { (Time.zone.today + 17.days).day.to_s }

        it do
          plan.stop_at_next_update_date!
          expect(plan.reload.end_at).to eq (Time.zone.today + 17.days).yesterday.end_of_day.iso8601
        end
      end

      context '' do
        let(:charge_date) { (Time.zone.today + 27.days).day.to_s }

        it do
          plan.stop_at_next_update_date!
          expect(plan.reload.end_at).to eq (Time.zone.today + 27.days).yesterday.end_of_day.iso8601
        end
      end
    end

    context '引数ある時' do
      context '今日' do
        let(:charge_date) { Time.zone.today.day.to_s }

        it do
          plan.stop_at_next_update_date!(Time.zone.now - 1.days)
          expect(plan.reload.end_at).to eq Time.zone.yesterday.end_of_day.iso8601
        end
      end

      context '明日' do
        let(:charge_date) { Time.zone.tomorrow.day.to_s }

        it do
          plan.stop_at_next_update_date!(Time.zone.now - 1.days)
          expect(plan.reload.end_at).to eq Time.zone.today.end_of_day.iso8601
        end
      end

      context '' do
        let(:charge_date) { (Time.zone.today + 7.days).day.to_s }

        it do
          plan.stop_at_next_update_date!(Time.zone.now - 1.days)
          expect(plan.reload.end_at).to eq (Time.zone.today + 7.days).yesterday.end_of_day.iso8601
        end

        it do
          plan.stop_at_next_update_date!(Time.zone.now + 4.days)
          expect(plan.reload.end_at).to eq (Time.zone.today + 7.days).yesterday.end_of_day.iso8601
        end
      end
    end
  end

  describe '#cal_amount' do
    let(:plan) { create(:billing_plan, price: price, tax_included: tax_included, tax_rate: tax_rate,
                                       billing: user.billing) }
    let(:price) { 4000 }
    let(:tax_rate) { 8 }

    context 'tax_includedがtrue' do
      let(:tax_included) { true }

      it { expect(plan.cal_amount).to eq price }
    end

    context 'tax_includedがfalse' do
      let(:tax_included) { false }

      it { expect(plan.cal_amount).to eq ( price + price * tax_rate * 0.01 ).floor }
    end
  end

  describe '#cal_next_charge_date' do
    context '毎月払い' do
      let(:type) { :monthly }

      context '今月' do
        context 'base 12, charge_date 13' do
          let(:charge_date) { '13' }
          let(:time) { Time.zone.parse('2023/03/12 12:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/13') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/13').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/13') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/03/12').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 4/13, charge_date 31' do
          let(:charge_date) { '31' }
          let(:time) { Time.zone.parse('2023/04/13 00:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/1') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/05/1').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/04/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 4/30, charge_date 31' do
          let(:charge_date) { '31' }
          let(:time) { Time.zone.parse('2023/04/30 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/1') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/05/1').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/04/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 5/1, charge_date 31' do
          let(:charge_date) { '31' }
          let(:time) { Time.zone.parse('2023/05/1 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/31') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/05/31').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/31') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/04/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 5/1, charge_date 31' do
          let(:charge_date) { '31' }
          let(:time) { Time.zone.parse('2023/05/1 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/31') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/05/31').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/05/31') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/05/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 2/27, charge_date 31' do
          let(:charge_date) { '31' }
          let(:time) { Time.zone.parse('2023/02/27 01:15') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/1').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 1/29, charge_date 30' do
          let(:charge_date) { '30' }
          let(:time) { Time.zone.parse('2023/01/29 00:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/01/30') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/01/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/01/30') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/01/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end
      end

      context '来月' do
        context 'base 14, charge_date 13' do
          let(:charge_date) { '13' }
          let(:time) { Time.zone.parse('2023/03/14 12:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/04/13') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/04/13').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/04/13') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/04/12').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 13, charge_date 13' do
          let(:charge_date) { '13' }
          let(:time) { Time.zone.parse('2023/03/13 00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/04/13') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/04/13').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/04/13') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/04/12').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 1/30, charge_date 30' do
          let(:charge_date) { '30' }
          let(:time) { Time.zone.parse('2023/01/30 00:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 1/31, charge_date 30' do
          let(:charge_date) { '31' }
          let(:time) { Time.zone.parse('2023/01/31 13:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/1') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end
      end
    end

    context '年間払い' do
      let(:type) { :annually }

      context '今年' do
        context 'base 1/12, charge_date 6/15' do
          let(:charge_date) { '06/15' }
          let(:time) { Time.zone.parse('2023/01/12 12:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/06/15') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/06/15').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/06/15') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/06/14').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 5/1, charge_date 12/31' do
          let(:charge_date) { '12/31' }
          let(:time) { Time.zone.parse('2023/05/01 16:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/12/31') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/12/31').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/12/31') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/12/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 12/30, charge_date 12/31' do
          let(:charge_date) { '12/31' }
          let(:time) { Time.zone.parse('2023/12/30 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/12/31') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/12/31').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/12/31') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/12/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。閏年でない年は3/1が課金日。
        context 'base 1/1, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2023/01/01 23:05:04') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。閏年でない年は3/1が課金日。
        context 'base 2/28, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2023/02/28 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。2024年は閏年。
        context 'base 2024/2/28, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2024/02/28 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/02/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。2024年は閏年。
        context 'base 2024/1/1, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2024/02/01 23:05:04') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/02/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。2024年は閏年。
        context 'base 2024/2/28, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2024/02/28 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/02/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 2024/2/29, charge_date 3/1' do
          let(:charge_date) { '03/01' }
          let(:time) { Time.zone.parse('2024/02/29 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/02/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end
      end

      context '来年' do
        context 'base 2023/10/5, charge_date 9/30' do
          let(:charge_date) { '09/30' }
          let(:time) { Time.zone.parse('2023/10/5 12:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/09/30') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/09/30').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/09/30') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/09/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 2023/4/5, charge_date 4/4' do
          let(:charge_date) { '04/04' }
          let(:time) { Time.zone.parse('2023/04/5 12:10') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/04/04') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/04/04').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/04/04') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/04/03').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 2023/4/4, charge_date 4/4' do
          let(:charge_date) { '04/04' }
          let(:time) { Time.zone.parse('2023/04/4 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/04/04') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/04/04').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/04/04') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/04/03').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 12/31, charge_date 1/1' do
          let(:charge_date) { '01/01' }
          let(:time) { Time.zone.parse('2023/12/31 23:59:59') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/01/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/01/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/01/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/12/31').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。閏年でない年は3/1が課金日。
        context 'base 3/1, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2022/03/01 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2023/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2023/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2023/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。閏年でない年は3/1が課金日。
        context 'base 3/1, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2023/03/01 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2024/02/29').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2024/02/29') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2024/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        # 2/29が課金日になっている。閏年でない年は3/1が課金日。
        context 'base 2024/2/29, charge_date 2/29' do
          let(:charge_date) { '02/29' }
          let(:time) { Time.zone.parse('2024/02/29 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2025/03/01') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2025/03/01').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2025/03/01') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2025/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end

        context 'base 2024/2/29, charge_date 2/28' do
          let(:charge_date) { '02/28' }
          let(:time) { Time.zone.parse('2024/02/29 00:00:00') }
          it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2025/02/28') }

          context 'end_atの日当日' do
            let(:end_at) { Time.zone.parse('2025/02/28').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to eq Time.zone.parse('2025/02/28') }
          end

          context 'end_atを過ぎている' do
            let(:end_at) { Time.zone.parse('2025/02/27').end_of_day }
            it { expect(plan.cal_next_charge_date(time)).to be_nil }
          end
        end
      end
    end
  end
end

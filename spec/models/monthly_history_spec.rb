require 'rails_helper'

RSpec.describe MonthlyHistory, type: :model do
  let_it_be(:user) { create(:user) }

  describe '#update_memo!' do
    subject { history.update_memo!(new_plan) }

    let!(:history) { create(:monthly_history, user: user, plan: start_plan, memo: memo) }
    let(:start_plan) { 1 }
    let(:new_plan) { 3 }

    before { Timecop.freeze }
    after  { Timecop.return }

    context 'memoがnil' do
      let(:memo) { nil }

      it do
        subject
        expect(history.reload.plan).to eq new_plan
        expect(history.reload.memo).to eq({start_plan => Time.zone.now}.to_json)
      end
    end

    context 'memoがある' do
      let(:memo) { {first_plan => first_plan_time}.to_json }
      let(:first_plan) { 100 }
      let(:first_plan_time) { Time.zone.now - 1.day }

      it do
        subject
        expect(history.reload.plan).to eq new_plan
        expect(history.reload.memo).to eq({first_plan => first_plan_time, start_plan => Time.zone.now}.to_json)
      end
    end
  end

  describe '#check' do
    subject { described_class.create(user_id: user_id, plan: plan, start_at: start_at, end_at: end_at) }
    let(:user_id) { user.id }
    let(:plan) { EasySettings.plan[:free] }
    let(:start_at) { Time.zone.now.beginning_of_month }
    let(:end_at) { Time.zone.now.end_of_month }

    context 'ユーザがいないとき' do
      let(:user_id) { 9_999_999 }
      it do
        expect(subject.errors.messages[:user]).to include('ユーザは存在しません。')
      end

      it { expect {subject}.to change(described_class, :count).by(0) }
    end

    context 'start_atよりend_atが過去の時' do
      let(:end_at) { Time.zone.now.beginning_of_month - 1.minutes }

      it do
        expect(subject.errors.messages[:end_at]).to include('終了期間は開始期間より後にしてください。')
      end

      it { expect {subject}.to change(described_class, :count).by(0) }
    end

    context '他の期間と被っている時' do
      context '開始期間に被っている' do
        before do
          create(:monthly_history, user: user, start_at: start_at - 3.days, end_at: start_at + 3.days)
        end

        it do
          expect(subject.errors.messages[:start_at]).to include('開始期間が被っています。')
        end

        it { expect {subject}.to change(described_class, :count).by(0) }
      end

      context '終了期間に被っている' do
        before do
          create(:monthly_history, user: user, start_at: end_at - 3.days, end_at: end_at + 3.days)
        end

        it do
          expect(subject.errors.messages[:end_at]).to include('終了期間が被っています。')
        end

        it { expect {subject}.to change(described_class, :count).by(0) }
      end

      context '開始日と終了日の間の期間が被っている' do
        before do
          create(:monthly_history, user: user, start_at: start_at + 3.days, end_at: end_at - 3.days)
        end

        it do
          expect(subject.errors.messages[:start_at]).to include('開始日と終了日の間の期間が被っています。')
        end

        it { expect {subject}.to change(described_class, :count).by(0) }
      end
    end

    context '他のユーザと被っている時' do
      before do
        user2 = create(:user)
        user3 = create(:user)
        user4 = create(:user)
        create(:monthly_history, user: user2, start_at: start_at + 3.days, end_at: end_at - 3.days)
        create(:monthly_history, user: user3, start_at: end_at - 3.days, end_at: end_at + 3.days)
        create(:monthly_history, user: user4, start_at: start_at - 3.days, end_at: start_at + 3.days)
      end

      it do
        expect(subject.errors.messages).to be_empty
      end

      it { expect {subject}.to change(described_class, :count).by(1) }
    end

    context 'update' do
      let!(:history) { create(:monthly_history, user: user, start_at: start_at, end_at: end_at - 3.days)  }

      it do
        history.update(end_at: end_at)
        expect(history.errors.messages).to be_empty
        expect(history.end_at).to eq end_at.iso8601
      end
    end
  end

  describe '#get' do

    context '指定時間のちょうどのhistoryがある場合' do
      let!(:history1) { create(:monthly_history, user: user, start_at: Time.zone.now - 7.days, end_at: Time.zone.now - 5.days) }
      let!(:history2) { create(:monthly_history, user: user, start_at: Time.zone.now - 4.days, end_at: Time.zone.now - 2.days) }
      let!(:history3) { create(:monthly_history, user: user, start_at: Time.zone.now - 1.days, end_at: Time.zone.now + 2.days) }
      let!(:history4) { create(:monthly_history, user: user, start_at: Time.zone.now + 3.days, end_at: Time.zone.now + 5.days) }

      it do
        expect(described_class.get(user)).to eq history3
        expect(described_class.get(user, Time.zone.now - 3.days)).to eq history2
        expect(described_class.get(user, Time.zone.now + 4.days)).to eq history4
        expect(described_class.get(user, Time.zone.now - 6.days)).to eq history1

        expect(described_class.get(user, Time.zone.now, history3.id)).to be_blank
        expect(described_class.get(user, Time.zone.now - 3.days, history2.id)).to be_blank
        expect(described_class.get(user, Time.zone.now + 4.days, history4.id)).to be_blank
        expect(described_class.get(user, Time.zone.now - 6.days, history1.id)).to be_blank
      end
    end
  end

  describe '#find_around' do

    context '指定時間のちょうどのhistoryがある場合' do
      let!(:history1) { create(:monthly_history, user: user, start_at: Time.zone.now - 7.days, end_at: Time.zone.now - 5.days) }
      let!(:history2) { create(:monthly_history, user: user, start_at: Time.zone.now - 4.days, end_at: Time.zone.now - 2.days) }
      let!(:history3) { create(:monthly_history, user: user, start_at: Time.zone.now - 1.days, end_at: Time.zone.now + 2.days) }
      let!(:history4) { create(:monthly_history, user: user, start_at: Time.zone.now + 3.days, end_at: Time.zone.now + 5.days) }

      it do
        expect(described_class.find_around(user)).to eq history3
        expect(described_class.find_around(user, Time.zone.now - 3.days)).to eq history2
        expect(described_class.find_around(user, Time.zone.now + 4.days)).to eq history4
        expect(described_class.find_around(user, Time.zone.now - 6.days)).to eq history1
      end
    end

    context '+1秒ずれている場合' do
      let!(:history1) { create(:monthly_history, user: user, start_at: Time.zone.now - 7.days, end_at: Time.zone.now.end_of_day) }
      let!(:history2) { create(:monthly_history, user: user, start_at: Time.zone.now.next_day.beginning_of_day, end_at: Time.zone.now + 7.days) }

      it do
        expect(history1.end_at).to be < Time.zone.now.end_of_day
        expect(history2.end_at).to be > Time.zone.now.end_of_day
        expect(described_class.find_around(user, Time.zone.now.end_of_day)).to eq history2
      end
    end

    context '-1秒ずれている場合' do
      let!(:history1) { create(:monthly_history, user: user, start_at: Time.zone.now - 7.days, end_at: Time.zone.now.end_of_day) }

      it do
        expect(history1.end_at).to be < Time.zone.now.end_of_day
        expect(described_class.find_around(user, Time.zone.now.end_of_day)).to eq history1
      end
    end
  end

  describe '#get_last' do
    subject { described_class.get_last(user) }

    let!(:history1) { create(:monthly_history, user: user, start_at: Time.zone.now - 7.days, end_at: Time.zone.now - 5.days) }
    let!(:history2) { create(:monthly_history, user: user, start_at: Time.zone.now - 4.days, end_at: Time.zone.now - 2.days) }
    let!(:history3) { create(:monthly_history, user: user, start_at: Time.zone.now - 1.days, end_at: Time.zone.now + 2.days) }

    it do
      expect(subject).to eq history3
    end
  end
end

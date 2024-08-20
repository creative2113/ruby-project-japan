require 'rails_helper'

RSpec.describe BanCondition, type: :model do
  describe 'find' do
    subject { described_class.find(ip: ip, mail: mail, action: action) }

    let(:ip) { '111.222.333.444' }
    let(:mail) { 'aaa@sxmaple.com' }
    let(:action) { described_class.ban_actions['user_register'] }

    describe 'by ID' do
      let!(:condition) { create(:ban_condition, ip: ip, ban_action: action) }

      it do
        expect{ described_class.find(condition.id+1) }.to raise_error(ActiveRecord::RecordNotFound)
        expect( described_class.find(condition.id)).to be_present
      end
    end

    describe 'IP' do
      let(:mail) { nil }

      context '禁止ip' do
        before { create(:ban_condition, ip: ip, ban_action: action) }
        it { expect(subject).to be_present }
      end

      context '禁止ipだけど、actionが違う' do
        before { create(:ban_condition, ip: ip, ban_action: described_class.ban_actions['inquiry']) }
        it { expect(subject).to be_nil }
      end

      context '禁止ipではない' do
        before { create(:ban_condition, ip: '111.222.333.555', ban_action: action) }
        it { expect(subject).to be_nil }
      end
    end

    describe 'mail' do
      let(:ip) { nil }

      context '禁止mail' do
        before { create(:ban_condition, mail: mail, ban_action: action) }
        it { expect(subject).to be_present }
      end

      context '禁止mailだけど、actionが違う' do
        before { create(:ban_condition, mail: mail, ban_action: described_class.ban_actions['inquiry']) }
        it { expect(subject).to be_nil }
      end

      context '禁止mailではない' do
        before { create(:ban_condition, mail: 'bbb@sxmaple.com', ban_action: action) }
        it { expect(subject).to be_nil }
      end
    end

    describe 'ipとmailの両方' do
      before do
        create(:ban_condition, ip: '111.222.333.444', ban_action: action)
        create(:ban_condition, mail: 'aaa@sxmaple.com', ban_action: action)
      end

      context '禁止ipと禁止mail' do
        it { expect(subject).to be_present }
      end

      context '禁止ipだけ' do
        let(:mail) { 'bbb@sxmaple.com' }
        it { expect(subject).to be_present }
      end

      context '禁止mailだけ' do
        let(:ip) { '111.222.333.555' }
        it { expect(subject).to be_present }
      end

      context '両方ともOK' do
        let(:ip)   { '111.222.333.555' }
        let(:mail) { 'bbb@sxmaple.com' }
        it { expect(subject).to be_nil }
      end
    end
  end

  describe 'ban?' do
    subject { described_class.ban?(ip: ip, mail: mail, action: action) }

    let(:ip) { '111.222.333.444' }
    let(:mail) { 'aaa@sxmaple.com' }
    let(:action) { described_class.ban_actions['user_register'] }

    describe 'IP' do
      let(:mail) { nil }

      context '禁止ip' do
        before { create(:ban_condition, ip: ip, ban_action: action) }
        it { expect(subject).to be_truthy }
      end

      context '禁止ipだけど、actionが違う' do
        before { create(:ban_condition, ip: ip, ban_action: described_class.ban_actions['inquiry']) }
        it { expect(subject).to be_falsey }
      end

      context '禁止ipではない' do
        before { create(:ban_condition, ip: '111.222.333.555', ban_action: action) }
        it { expect(subject).to be_falsey }
      end
    end

    describe 'mail' do
      let(:ip) { nil }

      context '禁止mail' do
        before { create(:ban_condition, mail: mail, ban_action: action) }
        it { expect(subject).to be_truthy }
      end

      context '禁止mailだけど、actionが違う' do
        before { create(:ban_condition, mail: mail, ban_action: described_class.ban_actions['inquiry']) }
        it { expect(subject).to be_falsey }
      end

      context '禁止mailではない' do
        before { create(:ban_condition, mail: 'bbb@sxmaple.com', ban_action: action) }
        it { expect(subject).to be_falsey }
      end
    end

    describe 'ipとmailの両方' do
      before do
        create(:ban_condition, ip: '111.222.333.444', ban_action: action)
        create(:ban_condition, mail: 'aaa@sxmaple.com', ban_action: action)
      end

      context '禁止ipと禁止mail' do
        it { expect(subject).to be_truthy }
      end

      context '禁止ipだけ' do
        let(:mail) { 'bbb@sxmaple.com' }
        it { expect(subject).to be_truthy }
      end

      context '禁止mailだけ' do
        let(:ip) { '111.222.333.555' }
        it { expect(subject).to be_truthy }
      end

      context '両方ともOK' do
        let(:ip)   { '111.222.333.555' }
        let(:mail) { 'bbb@sxmaple.com' }
        it { expect(subject).to be_falsey }
      end
    end
  end
end

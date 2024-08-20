require 'rails_helper'

RSpec.describe AllowIp, type: :model do
  let(:user) { create(:user) }

  before do
    Timecop.freeze(current_time)
  end

  after do
    Timecop.return
  end

  describe '#get_ips' do
    subject { allow_ip.get_ips }

    context 'ipsがnil' do
      let(:allow_ip) { create(:allow_ip, ips: nil, user: user) }

      it do
        expect(subject).to eq({})
      end
    end

    context 'ipが期限切れ' do
      let(:allow_ip) { create(:allow_ip, ips: {'1' => nil, '2' => Time.zone.now - 1.minutes, '3' => Time.zone.now + 1.minutes}.to_json, user: user) }

      it do
        expect(subject).to eq({'1' => nil, '3' => (Time.zone.now + 1.minutes).iso8601(3)})
        expect(allow_ip.reload.ips).to eq({'1' => nil, '3' => (Time.zone.now + 1.minutes).iso8601(3)}.to_json)
      end
    end

    context 'ipが全て有効' do
      let(:allow_ip) { create(:allow_ip, ips: {'1' => nil, '2' => Time.zone.now + 10.seconds, '3' => Time.zone.now + 1.minutes}.to_json, user: user) }

      it do
        expect(subject).to eq({'1' => nil, '2' => (Time.zone.now + 10.seconds).iso8601(3), '3' => (Time.zone.now + 1.minutes).iso8601(3)})
        expect(allow_ip.reload.ips).to eq({'1' => nil, '2' => (Time.zone.now + 10.seconds).iso8601(3), '3' => (Time.zone.now + 1.minutes).iso8601(3)}.to_json)
      end
    end
  end

  describe '#add!' do
    subject { allow_ip.add!(ip, exp) }
    let(:ip) { '1.22.33.444' }

    context 'expirationがnil' do
      let(:allow_ip) { create(:allow_ip, ips: ips, user: user) }
      let(:exp) { nil }

      context 'ipsがnil' do
        let(:ips) { nil }

        it do
          subject
          expect(allow_ip.ips).to eq({'1.22.33.444' => nil}.to_json)
        end
      end

      context 'ipsがある' do
        let(:ips) { {'1.22.33.555' => nil}.to_json }

        it do
          subject
          expect(allow_ip.ips).to eq({'1.22.33.555' => nil, '1.22.33.444' => nil}.to_json)
        end
      end
    end

    context 'expirationがnil' do
      let(:allow_ip) { create(:allow_ip, ips: ips, user: user) }
      let(:exp) { 5 }

      context 'ipsがnil' do
        let(:ips) { nil }

        it do
          subject
          expect(allow_ip.ips).to eq({'1.22.33.444' => (Time.zone.now + 5.hours).iso8601(3)}.to_json)
        end
      end

      context 'ipsがある' do
        let(:ips) { {'1.22.33.555' => nil}.to_json }

        it do
          subject
          expect(allow_ip.ips).to eq({'1.22.33.555' => nil, '1.22.33.444' => (Time.zone.now + 5.hours).iso8601(3)}.to_json)
        end
      end
    end
  end

  describe '#allow?' do
    subject { allow_ip.allow?(ip) }
    let(:ip) { '1.22.33.444' }

    let(:allow_ip) { create(:allow_ip, ips: ips.to_json, user: user) }

    context 'ipsがnil' do
      let(:ips) { nil }

      it do
        expect(subject).to be_falsey
      end
    end

    context 'ipsがnil' do
      let(:ips) { { ip => nil} }

      it do
        expect(subject).to be_truthy
      end
    end

    context 'ipsが期限切れ' do
      let(:ips) { { ip => Time.zone.now - 30.seconds } }

      it do
        expect(subject).to be_falsey
      end
    end

    context 'ipsが有効' do
      let(:ips) { { ip => Time.zone.now + 30.seconds } }

      it do
        expect(subject).to be_truthy
      end
    end
  end
end

require 'rails_helper'

RSpec.describe MasterBillingPlan, type: :model do
  describe 'スコープ' do

    before { Timecop.freeze }
    after  { Timecop.return }

    describe 'enabled' do
      let_it_be(:p1)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now - 3.minutes, end_at: Time.zone.now + 3.minutes) }
      let_it_be(:p2)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now - 3.minutes, end_at: nil                      ) }
      let_it_be(:p3)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now - 3.minutes, end_at: Time.zone.now - 1.minutes) }
      let_it_be(:p4)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now - 5.minutes, end_at: Time.zone.now - 3.minutes) }
      let_it_be(:p5)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now + 1.minutes, end_at: Time.zone.now + 3.minutes) }
      let_it_be(:p6)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now + 3.minutes, end_at: Time.zone.now + 5.minutes) }
      let_it_be(:p7)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now + 1.minutes, end_at: nil                      ) }
      let_it_be(:p8)  { create(:master_billing_plan, enable: true,  application_available: false, start_at: Time.zone.now + 3.minutes, end_at: nil                      ) }
      let_it_be(:p9)  { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now - 3.minutes, end_at: Time.zone.now + 3.minutes) }
      let_it_be(:p10) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now - 3.minutes, end_at: nil                      ) }
      let_it_be(:p11) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now - 3.minutes, end_at: Time.zone.now - 1.minutes) }
      let_it_be(:p12) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now - 5.minutes, end_at: Time.zone.now - 3.minutes) }
      let_it_be(:p13) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now + 1.minutes, end_at: Time.zone.now + 3.minutes) }
      let_it_be(:p14) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now + 3.minutes, end_at: Time.zone.now + 5.minutes) }
      let_it_be(:p15) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now + 1.minutes, end_at: nil                      ) }
      let_it_be(:p16) { create(:master_billing_plan, enable: false, application_available: false, start_at: Time.zone.now + 3.minutes, end_at: nil                      ) }

      it do
        expect(described_class.enabled).to match([p1, p2])
        expect(described_class.enabled(Time.zone.now - 2.minutes)).to match([p1, p2, p3])
        expect(described_class.enabled(Time.zone.now + 2.minutes)).to match([p1, p2, p5, p7])
      end
    end

    describe 'application_enabled' do
      let_it_be(:ap1)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap2)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now - 3.minutes, application_end_at: nil                      ) }
      let_it_be(:ap3)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now - 1.minutes) }
      let_it_be(:ap4)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now - 5.minutes, application_end_at: Time.zone.now - 3.minutes) }
      let_it_be(:ap5)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now + 1.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap6)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now + 3.minutes, application_end_at: Time.zone.now + 5.minutes) }
      let_it_be(:ap7)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now + 1.minutes, application_end_at: nil                      ) }
      let_it_be(:ap8)  { create(:master_billing_plan, enable: true, application_available: false, application_start_at: Time.zone.now + 3.minutes, application_end_at: nil                      ) }
      let_it_be(:ap9)  { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap10) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now - 3.minutes, application_end_at: nil                      ) }
      let_it_be(:ap11) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now - 1.minutes) }
      let_it_be(:ap12) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now - 5.minutes, application_end_at: Time.zone.now - 3.minutes) }
      let_it_be(:ap13) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now + 1.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap14) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now + 3.minutes, application_end_at: Time.zone.now + 5.minutes) }
      let_it_be(:ap15) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now + 1.minutes, application_end_at: nil                      ) }
      let_it_be(:ap16) { create(:master_billing_plan, enable: true, application_available: true,  application_start_at: Time.zone.now + 3.minutes, application_end_at: nil                      ) }

      let_it_be(:ap17) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap18) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now - 3.minutes, application_end_at: nil                      ) }
      let_it_be(:ap19) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now - 1.minutes) }
      let_it_be(:ap20) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now - 5.minutes, application_end_at: Time.zone.now - 3.minutes) }
      let_it_be(:ap21) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now + 1.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap22) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now + 3.minutes, application_end_at: Time.zone.now + 5.minutes) }
      let_it_be(:ap23) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now + 1.minutes, application_end_at: nil                      ) }
      let_it_be(:ap24) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: false, application_start_at: Time.zone.now + 3.minutes, application_end_at: nil                      ) }
      let_it_be(:ap25) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap26) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now - 3.minutes, application_end_at: nil                      ) }
      let_it_be(:ap27) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now - 3.minutes, application_end_at: Time.zone.now - 1.minutes) }
      let_it_be(:ap28) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now - 5.minutes, application_end_at: Time.zone.now - 3.minutes) }
      let_it_be(:ap29) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now + 1.minutes, application_end_at: Time.zone.now + 3.minutes) }
      let_it_be(:ap30) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now + 3.minutes, application_end_at: Time.zone.now + 5.minutes) }
      let_it_be(:ap31) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now + 1.minutes, application_end_at: nil                      ) }
      let_it_be(:ap32) { create(:master_billing_plan, enable: true, end_at: Time.zone.now - 5.minutes, application_available: true,  application_start_at: Time.zone.now + 3.minutes, application_end_at: nil                      ) }

      it do
        expect(described_class.application_enabled).to match([ap9, ap10])
        expect(described_class.application_enabled(Time.zone.now - 2.minutes)).to match([ap9, ap10, ap11])
        expect(described_class.application_enabled(Time.zone.now + 2.minutes)).to match([ap9, ap10, ap13, ap15])
      end
    end
  end
end

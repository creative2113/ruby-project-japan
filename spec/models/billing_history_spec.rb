require 'rails_helper'

RSpec.describe BillingHistory, type: :model do
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }

  let_it_be(:this_month) { Time.zone.now.beginning_of_month }
  let_it_be(:last_month) {(Time.zone.now - 1.months).beginning_of_month }
  let_it_be(:two_months_ago) { (Time.zone.now - 2.months).beginning_of_month }
  let_it_be(:three_months_ago) { (Time.zone.now - 3.months).beginning_of_month }
  let_it_be(:bh1)  { create(:billing_history, billing: user1.billing, payment_method: :invoice, billing_date: this_month + 1.days) }
  let_it_be(:bh2)  { create(:billing_history, billing: user2.billing, payment_method: :credit, billing_date: this_month + 2.days) }
  let_it_be(:bh3)  { create(:billing_history, billing: user3.billing, payment_method: :invoice, billing_date: this_month + 5.days) }
  let_it_be(:bh4)  { create(:billing_history, billing: user1.billing, payment_method: :credit, billing_date: this_month + 15.days) }
  let_it_be(:bh5)  { create(:billing_history, billing: user2.billing, payment_method: :bank_transfer, billing_date: last_month + 3.days) }
  let_it_be(:bh6)  { create(:billing_history, billing: user3.billing, payment_method: :bank_transfer, billing_date: last_month + 7.days) }
  let_it_be(:bh7)  { create(:billing_history, billing: user1.billing, payment_method: :invoice, billing_date: last_month + 17.days) }
  let_it_be(:bh8)  { create(:billing_history, billing: user2.billing, payment_method: :credit, billing_date: last_month + 27.days) }
  let_it_be(:bh9)  { create(:billing_history, billing: user3.billing, payment_method: :invoice, billing_date: two_months_ago + 4.days) }
  let_it_be(:bh10) { create(:billing_history, billing: user1.billing, payment_method: :invoice, billing_date: two_months_ago + 17.days) }
  let_it_be(:bh11) { create(:billing_history, billing: user2.billing, payment_method: :invoice, billing_date: two_months_ago + 18.days) }
  let_it_be(:bh12) { create(:billing_history, billing: user3.billing, payment_method: :credit, billing_date: two_months_ago + 27.days) }
  let_it_be(:bh13) { create(:billing_history, billing: user1.billing, payment_method: :credit, billing_date: three_months_ago + 13.days) }
  let_it_be(:bh14) { create(:billing_history, billing: user2.billing, payment_method: :invoice, billing_date: three_months_ago + 17.days) }
  let_it_be(:bh15) { create(:billing_history, billing: user3.billing, payment_method: :invoice, billing_date: three_months_ago + 20.days) }
  let_it_be(:bh16) { create(:billing_history, billing: user1.billing, payment_method: :bank_transfer, billing_date: three_months_ago + 25.days) }
  let_it_be(:bh17) { create(:billing_history, billing: user2.billing, payment_method: :invoice, billing_date: three_months_ago + 26.days) }
  
  describe 'スコープ by_month' do
    it do
      expect(described_class.by_month).to match([bh4, bh3, bh2, bh1])
      expect(described_class.by_month(last_month + 3.days) ).to match([bh8, bh7, bh6, bh5])
      expect(described_class.by_month(two_months_ago + 16.days) ).to match([bh12, bh11, bh10, bh9])
      expect(described_class.by_month(three_months_ago + 27.days) ).to match([bh17, bh16, bh15, bh14, bh13])
    end
  end

  describe 'スコープ invoices_by_month' do
    it do
      expect(described_class.invoices_by_month).to match([bh1, bh3])
      expect(described_class.invoices_by_month(last_month + 3.days) ).to match([bh7])
      expect(described_class.invoices_by_month(two_months_ago + 16.days) ).to match([bh9, bh10, bh11])
      expect(described_class.invoices_by_month(three_months_ago + 27.days) ).to match([bh14, bh15, bh17])
    end
  end
end

class BillingHistory < ApplicationRecord
  belongs_to :billing

  enum payment_method: [ :credit, :bank_transfer, :invoice ]

  scope :by_month, -> (month = Time.zone.today) do
    where(billing_date: month.beginning_of_month..month.end_of_month).order(billing_date: :desc)
  end

  scope :invoices_by_month, -> (month = Time.zone.today) do
    where(payment_method: :invoice, billing_date: month.beginning_of_month..month.end_of_month)
  end

  def payment_method_str
    case payment_method
    when 'credit'
      'クレジットカード'
    when 'bank_transfer'
      '銀行振込'
    when 'invoice'
      '請求書'
    end
  end
end

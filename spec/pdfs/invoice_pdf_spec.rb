require 'rails_helper'

RSpec.describe InvoicePdf, type: :pdf do
  let_it_be(:execute_time) { Time.zone.now }
  let_it_be(:beginning_of_month) { execute_time.beginning_of_month.to_date }
  let_it_be(:user) { create(:user, billing_attrs: { payment_method: :invoice } ) }

  let(:billing_histories) { BillingHistory.invoices_by_month(execute_time).where(billing: user.billing) }

  describe '#new' do
    subject do
      described_class.new(user.company_name, billing_histories, execute_time)
    end

    context 'billing_historyが空欄' do
      let(:billing_histories) { [] }

      it 'エラーになること' do
        expect{subject}.to raise_error(described_class::BillingHistoryBlankError)
      end
    end

    context 'billing_historyが1個' do
      let!(:bh1) { create(:billing_history, :invoice, billing_date: beginning_of_month + 7.days, billing: user.billing) }


      it '請求書が正しく作成されること' do
        Dir.mktmpdir do |dir|
          path = "#{dir}/invoice.pdf"
          IO.write(path, subject.render, mode: 'wb')

          check_invoice_pdf(path, user, execute_time)

          texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")
          expect(texts).to match(/請求書\n/)
          expect(texts).to match(/#{user.company_name} 御中\n/)
          expect(texts).to match(/お支払期限 #{execute_time.next_month.end_of_month.strftime("%Y/%-m/%-d")}\n/)
          expect(texts).to match(/#{bh1.billing_date.strftime("%Y/%-m/%-d")}/)
          expect(texts).to match(/#{bh1.item_name}/)
          expect(texts).to match(/#{bh1.price.to_s(:delimited)}/)
        end
      end
    end

    context 'billing_historyが3個' do
      let!(:bh1) { create(:billing_history, :invoice, billing_date: beginning_of_month + 3.days,  billing: user.billing) }
      let!(:bh2) { create(:billing_history, :invoice, billing_date: beginning_of_month + 14.days, billing: user.billing) }
      let!(:bh3) { create(:billing_history, :invoice, billing_date: beginning_of_month + 21.days, billing: user.billing) }

      it '請求書が正しく作成されること' do
        Dir.mktmpdir do |dir|
          path = "#{dir}/invoice.pdf"
          IO.write(path, subject.render, mode: 'wb')

          check_invoice_pdf(path, user, execute_time)

          texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")
          expect(texts).to match(/請求書\n/)
          expect(texts).to match(/#{user.company_name} 御中\n/)
          expect(texts).to match(/お支払期限 #{execute_time.next_month.end_of_month.strftime("%Y/%-m/%-d")}\n/)
          expect(texts).to match(/#{bh1.billing_date.strftime("%Y/%-m/%-d")}/)
          expect(texts).to match(/#{bh1.item_name}/)
          expect(texts).to match(/#{bh1.price.to_s(:delimited)}/)
          expect(texts).to match(/#{bh2.billing_date.strftime("%Y/%-m/%-d")}/)
          expect(texts).to match(/#{bh2.item_name}/)
          expect(texts).to match(/#{bh2.price.to_s(:delimited)}/)
        end
      end
    end

    context '請求書以外は請求書に表示されないこと' do
      let!(:bh1) { create(:billing_history, :invoice,       billing_date: beginning_of_month + 3.days,  billing: user.billing) }
      let!(:bh2) { create(:billing_history, :invoice,       billing_date: beginning_of_month + 14.days, billing: user.billing) }
      let!(:bh3) { create(:billing_history, :credit,        billing_date: beginning_of_month + 6.days,  billing: user.billing) }
      let!(:bh4) { create(:billing_history, :bank_transfer, billing_date: beginning_of_month + 9.days,  billing: user.billing) }

      it '請求書が正しく作成されること' do
        Dir.mktmpdir do |dir|
          path = "#{dir}/invoice.pdf"
          IO.write(path, subject.render, mode: 'wb')

          check_invoice_pdf(path, user, execute_time)

          texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")
          expect(texts).not_to match(/#{bh3.item_name}/)
          expect(texts).not_to match(/#{bh3.price.to_s(:delimited)}/)
          expect(texts).not_to match(/#{bh4.item_name}/)
          expect(texts).not_to match(/#{bh4.price.to_s(:delimited)}/)
        end
      end
    end

    context '日時の範囲外は請求書に表示されないこと' do
      let_it_be(:bh1) { create(:billing_history, :invoice, billing_date: beginning_of_month + 3.days,  billing: user.billing) }
      let_it_be(:bh2) { create(:billing_history, :invoice, billing_date: beginning_of_month + 14.days, billing: user.billing) }
      let_it_be(:bh3) { create(:billing_history, :invoice, billing_date: beginning_of_month.last_month + 27.days, billing: user.billing) }
      let_it_be(:bh4) { create(:billing_history, :invoice, billing_date: beginning_of_month.last_month.end_of_month, billing: user.billing) }
      let_it_be(:bh5) { create(:billing_history, :invoice, billing_date: beginning_of_month - 1.day, billing: user.billing) }
      let_it_be(:bh6) { create(:billing_history, :invoice, billing_date: beginning_of_month.next_month.beginning_of_month, billing: user.billing) }
      let_it_be(:bh7) { create(:billing_history, :invoice, billing_date: beginning_of_month.next_month, billing: user.billing) }

      context 'その１' do
        let(:execute_time) { Time.zone.now }
        it '請求書が正しく作成されること' do
          Dir.mktmpdir do |dir|
            path = "#{dir}/invoice.pdf"
            IO.write(path, subject.render, mode: 'wb')

            check_invoice_pdf(path, user, execute_time)

            texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")
            expect(texts).not_to match(/#{bh3.item_name}/)
            expect(texts).not_to match(/#{bh3.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh4.item_name}/)
            expect(texts).not_to match(/#{bh4.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh5.item_name}/)
            expect(texts).not_to match(/#{bh5.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh6.item_name}/)
            expect(texts).not_to match(/#{bh6.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh7.item_name}/)
            expect(texts).not_to match(/#{bh7.price.to_s(:delimited)}/)
          end
        end
      end

      context 'その２' do
        let(:execute_time) { Time.zone.now.last_month }

        it '請求書が正しく作成されること' do
          Dir.mktmpdir do |dir|
            path = "#{dir}/invoice.pdf"
            IO.write(path, subject.render, mode: 'wb')

            check_invoice_pdf(path, user, execute_time)

            texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")
            expect(texts).not_to match(/#{bh1.item_name}/)
            expect(texts).not_to match(/#{bh1.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh2.item_name}/)
            expect(texts).not_to match(/#{bh2.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh6.item_name}/)
            expect(texts).not_to match(/#{bh6.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh7.item_name}/)
            expect(texts).not_to match(/#{bh7.price.to_s(:delimited)}/)
          end
        end
      end

      context 'その３' do
        let(:execute_time) { Time.zone.now.next_month }

        it '請求書が正しく作成されること' do
          Dir.mktmpdir do |dir|
            path = "#{dir}/invoice.pdf"
            IO.write(path, subject.render, mode: 'wb')

            check_invoice_pdf(path, user, execute_time)

            texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")
            expect(texts).not_to match(/#{bh1.item_name}/)
            expect(texts).not_to match(/#{bh1.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh2.item_name}/)
            expect(texts).not_to match(/#{bh2.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh3.item_name}/)
            expect(texts).not_to match(/#{bh3.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh4.item_name}/)
            expect(texts).not_to match(/#{bh4.price.to_s(:delimited)}/)
            expect(texts).not_to match(/#{bh5.item_name}/)
            expect(texts).not_to match(/#{bh5.price.to_s(:delimited)}/)
          end
        end
      end
    end
  end
end

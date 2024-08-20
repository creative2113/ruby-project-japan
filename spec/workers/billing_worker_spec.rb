require 'rails_helper'

RSpec.describe BillingWorker, type: :worker do

  before do
    create_public_user
  end

  let(:public_user) { User.get_public }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }

  after { ActionMailer::Base.deliveries.clear }

  describe '#all_execute' do
    subject { described_class.all_execute }

    let(:execute_time) { Time.zone.now }

    before do
      Timecop.freeze execute_time

      allow(described_class).to receive(:upload_to_s3).and_return(true)

      allow_any_instance_of(Billing).to receive(:create_charge).and_return({ 'error' => false })
    end

    after { Timecop.return }

    let(:execute_time) { Time.zone.now }
    let(:next_charge_date) { execute_time.to_date }
    let(:charge_date) { next_charge_date.day.to_s }

    let(:u1) { create(:user, billing_attrs: { payment_method: :invoice } ) }
    let(:u2) { create(:user, billing_attrs: { payment_method: :invoice } ) }
    let(:u3) { create(:user, billing_attrs: { payment_method: :credit } ) }
    let(:u4) { create(:user, billing_attrs: { payment_method: :invoice } ) }
    let(:u5) { create(:user, billing_attrs: { payment_method: :credit } ) }
    let(:u6) { create(:user, billing_attrs: { payment_method: :invoice } ) }
    let(:u7) { create(:user, billing_attrs: { payment_method: :credit } ) }
    let(:u8) { create(:user, billing_attrs: { payment_method: :invoice } ) }

    let!(:bh1) { create(:billing_history, :invoice, billing_date: (execute_time.last_month).to_date, billing: u1.billing) }
    let!(:bh2) { create(:billing_history, :invoice, billing_date: (execute_time.last_month).to_date, billing: u2.billing) }

    let!(:p3) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 6800, billing: u3.billing) }
    let!(:p4) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 5800, billing: u4.billing) }
    let!(:p5) { create(:billing_plan, status: :ongoing, end_at: execute_time - 1.minutes, billing: u5.billing) }
    let!(:p6) { create(:billing_plan, status: :ongoing, end_at: execute_time - 1.minutes, billing: u6.billing) }
    let!(:p7) { create(:billing_plan, status: :waiting, start_at: execute_time - 1.minutes, next_charge_date: nil, billing: u7.billing) }
    let!(:p8) { create(:billing_plan, status: :waiting, start_at: execute_time - 1.minutes, next_charge_date: nil, billing: u8.billing) }

    context '1日以外の時' do
      let(:execute_time) { Time.zone.now.day == 1 ? Time.zone.now + 1.day : Time.zone.now }

      it do
        subject

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/バッチお知らせ： ビリング/)

        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{u1.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{u2.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/課金一覧/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン終了一覧/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン開始一覧/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
      end

      context '日時を指定して実行' do
        subject { described_class.all_execute(execute_time) }

        let(:base_time)    { Time.zone.now - 14.days }
        let(:execute_time) { base_time.day == 1 ? base_time + 1.day : base_time }

        it do
          subject

          expect(ActionMailer::Base.deliveries.size).to eq(1)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/バッチお知らせ： ビリング/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{u1.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{u2.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/課金一覧/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン終了一覧/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン開始一覧/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
        end
      end
    end

    context '1日の時' do
      let(:execute_time) { Time.zone.now.beginning_of_month + 4.hours }

      it do
        subject

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/バッチお知らせ： ビリング/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u1.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u2.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/課金一覧/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン終了一覧/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン開始一覧/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
      end

      context '日時を指定して実行' do
        subject { described_class.all_execute(execute_time) }

        let(:base_time)    { Time.zone.now - 54.days }
        let(:execute_time) { base_time.beginning_of_month + 8.hours }

        it do
          subject

          expect(ActionMailer::Base.deliveries.size).to eq(1)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/バッチお知らせ： ビリング/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u1.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u2.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/課金一覧/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン終了一覧/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/プラン開始一覧/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
        end
      end
    end

    context 'エラーの時' do
      let(:execute_time) { Time.zone.now.beginning_of_month + 12.hours }

      context 'issue_invoiceでエラー' do

        before do
          allow(described_class).to receive(:issue_invoice).and_raise
        end

        it do
          subject

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#all_execute/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=all_execute エラー/)

          expect(ActionMailer::Base.deliveries[1].subject).to match(/バッチお知らせ： ビリング/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ビリングワーカー エラーによる途中終了/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/請求書発行プロセス/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u1.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u2.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/課金一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/プラン終了一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/プラン開始一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
        end
      end

      context 'execute_plan_endでエラー' do

        before do
          allow(described_class).to receive(:execute_plan_end).and_raise
        end

        it do
          subject

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#all_execute/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=all_execute エラー/)

          expect(ActionMailer::Base.deliveries[1].subject).to match(/バッチお知らせ： ビリング/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ビリングワーカー エラーによる途中終了/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/請求書発行プロセス実行/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u1.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u2.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/課金一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/プラン終了一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/プラン開始一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
        end
      end

      context 'execute_plan_startでエラー' do

        before do
          allow(described_class).to receive(:execute_plan_start).and_raise
        end

        it do
          subject

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#all_execute/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=all_execute エラー/)

          expect(ActionMailer::Base.deliveries[1].subject).to match(/バッチお知らせ： ビリング/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ビリングワーカー エラーによる途中終了/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/請求書発行プロセス実行/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u1.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u2.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/課金一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/プラン終了一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/プラン開始一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
        end
      end

      context 'execute_chargeでエラー' do

        before do
          allow(described_class).to receive(:execute_charge).and_raise
        end

        it do
          subject

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#all_execute/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=all_execute エラー/)

          expect(ActionMailer::Base.deliveries[1].subject).to match(/バッチお知らせ： ビリング/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ビリングワーカー エラーによる途中終了/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/請求書発行プロセス実行/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u1.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u2.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/課金一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).not_to match(/PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/プラン終了一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u5.id}, PLAN_ID: #{p5.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u6.id}, PLAN_ID: #{p6.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/プラン開始一覧/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u7.id}, PLAN_ID: #{p7.id}/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID: #{u8.id}, PLAN_ID: #{p8.id}/)
        end
      end
    end
  end

  describe '#issue_invoice' do
    subject { described_class.issue_invoice }

    def s3_path(user, time)
      "#{Rails.application.credentials.s3_bucket[:invoices]}/#{user.id}/invoice_#{time.strftime("%Y%m")}.pdf"
    end

    context '様々なpayment_methodの確認' do
      let(:u1)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :invoice } ) }

      let!(:bh1)   { create(:billing_history, :invoice,       billing_date: Time.zone.today,           billing: u1.billing) }
      let!(:bh2)   { create(:billing_history, :credit,        billing_date: Time.zone.today,           billing: u2.billing) }
      let!(:bh3)   { create(:billing_history, :bank_transfer, billing_date: Time.zone.today,           billing: u3.billing) }
      let!(:bh4)   { create(:billing_history, :invoice,       billing_date: Time.zone.today - 1.month, billing: u4.billing) }
      let!(:bh5)   { create(:billing_history, :invoice,       billing_date: Time.zone.today + 1.month, billing: u5.billing) }
      let!(:bh6_1) { create(:billing_history, :invoice,       billing_date: Time.zone.today,           billing: u6.billing) }
      let!(:bh6_2) { create(:billing_history, :invoice,       billing_date: Time.zone.today,           billing: u6.billing) }

      it '対象の請求書が作成されること' do


        expect(subject).to eq ["USER_ID: #{u1.id}, FILE_NAME: invoice_#{Time.zone.now.strftime("%Y%m")}.pdf",
                               "USER_ID: #{u6.id}, FILE_NAME: invoice_#{Time.zone.now.strftime("%Y%m")}.pdf",]

        check_s3_uploaded(s3_path(u1, Time.zone.now))
        download_invoice_pdf_and_check(s3_path(u1, Time.zone.now), u1, Time.zone.now)

        check_s3_uploaded(s3_path(u2, Time.zone.now), false)
        check_s3_uploaded(s3_path(u3, Time.zone.now), false)
        check_s3_uploaded(s3_path(u4, Time.zone.now), false)
        check_s3_uploaded(s3_path(u5, Time.zone.now), false)

        check_s3_uploaded(s3_path(u6, Time.zone.now))
        download_invoice_pdf_and_check(s3_path(u6, Time.zone.now), u6, Time.zone.now)

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context '日時が指定されているとき' do
      subject { described_class.issue_invoice(execute_time) }

      let(:execute_time) { Time.zone.now - 6.days - 1.month }
      let(:u1)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u7)  { create(:user, billing_attrs: { payment_method: :invoice } ) }

      let!(:bh1)   { create(:billing_history, :invoice,       billing_date: execute_time,                    billing: u1.billing) }
      let!(:bh1_1) { create(:billing_history, :invoice,       billing_date: Time.zone.now,                   billing: u1.billing) }
      let!(:bh1_2) { create(:billing_history, :invoice,       billing_date: Time.zone.now - 6.days,          billing: u1.billing) }
      let!(:bh2)   { create(:billing_history, :credit,        billing_date: execute_time,                    billing: u2.billing) }
      let!(:bh3)   { create(:billing_history, :bank_transfer, billing_date: execute_time,                    billing: u3.billing) }
      let!(:bh4)   { create(:billing_history, :invoice,       billing_date: execute_time - 6.days - 1.month, billing: u4.billing) }
      let!(:bh5)   { create(:billing_history, :invoice,       billing_date: execute_time - 6.days + 1.month, billing: u5.billing) }
      let!(:bh6_1) { create(:billing_history, :invoice,       billing_date: execute_time,                    billing: u6.billing) }
      let!(:bh6_2) { create(:billing_history, :invoice,       billing_date: execute_time,                    billing: u6.billing) }
      let!(:bh7)   { create(:billing_history, :invoice,       billing_date: Time.zone.now,                   billing: u7.billing) }

      it '対象の請求書が作成されること' do


        expect(subject).to eq ["USER_ID: #{u1.id}, FILE_NAME: invoice_#{execute_time.strftime("%Y%m")}.pdf",
                               "USER_ID: #{u6.id}, FILE_NAME: invoice_#{execute_time.strftime("%Y%m")}.pdf",]

        check_s3_uploaded(s3_path(u1, execute_time))
        download_invoice_pdf_and_check(s3_path(u1, execute_time), u1, execute_time)
        check_s3_uploaded(s3_path(u1, Time.zone.now), false)
        check_s3_uploaded(s3_path(u1, Time.zone.now - 6.days ), false)

        check_s3_uploaded(s3_path(u2, execute_time), false)
        check_s3_uploaded(s3_path(u3, execute_time), false)
        check_s3_uploaded(s3_path(u4, execute_time), false)
        check_s3_uploaded(s3_path(u5, execute_time), false)

        check_s3_uploaded(s3_path(u6, execute_time))
        download_invoice_pdf_and_check(s3_path(u6, execute_time), u6, execute_time)

        check_s3_uploaded(s3_path(u7, execute_time), false)

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context 'エラーが発生するとき' do
      let(:u1) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u2) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u4) { create(:user, billing_attrs: { payment_method: :invoice } ) }

      let!(:bh1) { create(:billing_history, :invoice, billing_date: Time.zone.today, billing: u1.billing) }
      let!(:bh2) { create(:billing_history, :invoice, billing_date: Time.zone.today, billing: u2.billing) }
      let!(:bh3) { create(:billing_history, :invoice, billing_date: Time.zone.today, billing: u3.billing) }

      before do
        allow(InvoicePdf).to receive(:new).and_wrap_original do |method, *args|
          if [u2.company_name].include?(args[0])
            raise
          else
            method.call(*args)
          end
        end
      end

      it '対象の請求書が作成されること' do
        expect(subject).to eq ["USER_ID: #{u1.id}, FILE_NAME: invoice_#{Time.zone.now.strftime("%Y%m")}.pdf",
                               "USER_ID: #{u3.id}, FILE_NAME: invoice_#{Time.zone.now.strftime("%Y%m")}.pdf",]

        check_s3_uploaded(s3_path(u1, Time.zone.now))
        download_invoice_pdf_and_check(s3_path(u1, Time.zone.now), u1, Time.zone.now)

        check_s3_uploaded(s3_path(u2, Time.zone.now), false)

        check_s3_uploaded(s3_path(u3, Time.zone.now))
        download_invoice_pdf_and_check(s3_path(u3, Time.zone.now), u3, Time.zone.now)

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#issue_invoice/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/method=issue_invoice issue=issue_invoice 個別エラー user_id=#{u2.id} billing_id=#{u2.billing.id}/)
      end
    end
  end

  describe '#execute_charge' do
    subject { described_class.execute_charge }

    context '様々なpayment_methodの確認' do
      let(:next_charge_date) { Time.zone.today }
      let(:charge_date) { next_charge_date.day.to_s }
      let(:u1)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u7)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let!(:p1)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 1200, billing: u1.billing) }
      let!(:p2)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price:  800, billing: u2.billing) }
      let!(:p3)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 1800, billing: u3.billing) }
      let!(:p4)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date + 1.day, price:  2800, billing: u4.billing) }
      let!(:p5)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date - 1.day, price:  3000, billing: u5.billing) }
      let!(:p6)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date + 1.day, price:  1800, billing: u6.billing) }
      let!(:p7)  { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date - 1.day, price:  2000, billing: u7.billing) }

      before do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        res_user1 = u1.billing.create_customer(card_token)
        u1.billing.save!
      end

      after do
        u1.billing.delete_customer
      end

      it '対象が課金が実行されること' do
        p3_updated_at = p3.updated_at
        p4_updated_at = p4.updated_at
        p5_updated_at = p5.updated_at
        p6_updated_at = p6.updated_at
        p7_updated_at = p7.updated_at

        u1_bh_count = u1.billing.histories.count
        u2_bh_count = u2.billing.histories.count
        bh_count = BillingHistory.count

        expect(subject).to eq ["PLAN_ID: #{p1.id}, TYPE: #{p1.type}, CHARGE_DATE: #{p1.charge_date}, AMOUNT: #{p1.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p2.id}, TYPE: #{p2.type}, CHARGE_DATE: #{p2.charge_date}, AMOUNT: #{p2.price.to_s(:delimited)}円"]

        expect(BillingHistory.count).to eq bh_count + 2

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.next_charge_date).not_to eq Time.zone.today
        expect(p1.next_charge_date).to eq Time.zone.today.next_month
        expect(p1.last_charge_date).to eq Time.zone.today

        expect(u1.billing.histories.reload.count).to eq u1_bh_count + 1
        bh1 = u1.billing.histories.last
        expect(bh1.item_name).to eq p1.name
        expect(bh1.payment_method.to_sym).to eq :credit
        expect(bh1.price).to eq p1.price
        expect(bh1.billing_date).to eq Time.zone.today
        expect(bh1.unit_price).to eq p1.price
        expect(bh1.number).to eq 1

        # 課金
        payjp_res = u1.billing.get_charges
        expect(payjp_res.count).to eq 1
        expect(payjp_res.data[0].amount).to eq 1200
        expect(payjp_res.data[0].customer).to eq u1.billing.reload.customer_id
        expect(Time.at(payjp_res.data[0].created)).to be > Time.zone.now - 1.minute

        expect(p2.reload.status.to_sym).to eq :ongoing
        expect(p2.next_charge_date).not_to eq Time.zone.today
        expect(p2.next_charge_date).to eq Time.zone.today.next_month
        expect(p2.last_charge_date).to eq Time.zone.today

        expect(u2.billing.histories.reload.count).to eq u2_bh_count + 1
        bh2 = u2.billing.histories.last
        expect(bh2.item_name).to eq p2.name
        expect(bh2.payment_method.to_sym).to eq :invoice
        expect(bh2.price).to eq p2.price
        expect(bh2.billing_date).to eq Time.zone.today
        expect(bh2.unit_price).to eq p2.price
        expect(bh2.number).to eq 1

        expect(p3.updated_at).to eq p3_updated_at
        expect(p4.updated_at).to eq p4_updated_at
        expect(p5.updated_at).to eq p5_updated_at
        expect(p6.updated_at).to eq p6_updated_at
        expect(p7.updated_at).to eq p7_updated_at

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context 'trialの場合' do
      let(:next_charge_date) { Time.zone.today }
      let(:charge_date) { next_charge_date.day.to_s }
      let(:u1) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u3) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u4) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let!(:p1) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, trial: true,  price: 1210, billing: u1.billing) }
      let!(:p2) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, trial: false, price:  810, billing: u2.billing) }
      let!(:p3) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, trial: true,  price: 3810, billing: u3.billing) }
      let!(:p4) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, trial: false, price: 2010, billing: u4.billing) }

      before do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        res_user1 = u1.billing.create_customer(card_token)
        u1.billing.save!

        card_token = Billing.create_dummy_card_token('5555555555554444', '3', '2030', '416')
        res_user2 = u2.billing.create_customer(card_token)
        u2.billing.save!
      end

      after do
        u1.billing.delete_customer
        u2.billing.delete_customer
      end

      it 'trialがfalseになること' do
        u1_bh_count = u1.billing.histories.count
        u2_bh_count = u2.billing.histories.count
        u3_bh_count = u3.billing.histories.count
        u4_bh_count = u4.billing.histories.count
        bh_count = BillingHistory.count

        expect(subject).to eq ["PLAN_ID: #{p1.id}, TYPE: #{p1.type}, CHARGE_DATE: #{p1.charge_date}, AMOUNT: #{p1.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p2.id}, TYPE: #{p2.type}, CHARGE_DATE: #{p2.charge_date}, AMOUNT: #{p2.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円"]

        expect(BillingHistory.count).to eq bh_count + 4

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.trial).to eq false
        expect(p1.next_charge_date).not_to eq Time.zone.today
        expect(p1.next_charge_date).to eq Time.zone.today.next_month
        expect(p1.last_charge_date).to eq Time.zone.today

        expect(u1.billing.histories.reload.count).to eq u1_bh_count + 1
        bh1 = u1.billing.histories.last
        expect(bh1.item_name).to eq p1.name
        expect(bh1.payment_method.to_sym).to eq :credit
        expect(bh1.price).to eq p1.price
        expect(bh1.billing_date).to eq Time.zone.today
        expect(bh1.unit_price).to eq p1.price
        expect(bh1.number).to eq 1

        # 課金
        payjp_res = u1.billing.get_charges
        expect(payjp_res.count).to eq 1
        expect(payjp_res.data[0].amount).to eq 1210
        expect(payjp_res.data[0].customer).to eq u1.billing.reload.customer_id
        expect(Time.at(payjp_res.data[0].created)).to be > Time.zone.now - 1.minute


        expect(p2.reload.status.to_sym).to eq :ongoing
        expect(p2.trial).to eq false
        expect(p2.next_charge_date).not_to eq Time.zone.today
        expect(p2.next_charge_date).to eq Time.zone.today.next_month
        expect(p2.last_charge_date).to eq Time.zone.today

        expect(u2.billing.histories.reload.count).to eq u2_bh_count + 1
        bh2 = u2.billing.histories.last
        expect(bh2.item_name).to eq p2.name
        expect(bh2.payment_method.to_sym).to eq :credit
        expect(bh2.price).to eq p2.price
        expect(bh2.billing_date).to eq Time.zone.today
        expect(bh2.unit_price).to eq p2.price
        expect(bh2.number).to eq 1

        # 課金
        payjp_res = u2.billing.get_charges
        expect(payjp_res.count).to eq 1
        expect(payjp_res.data[0].amount).to eq 810
        expect(payjp_res.data[0].customer).to eq u2.billing.reload.customer_id
        expect(Time.at(payjp_res.data[0].created)).to be > Time.zone.now - 1.minute


        expect(p3.reload.status.to_sym).to eq :ongoing
        expect(p3.trial).to eq false
        expect(p3.next_charge_date).not_to eq Time.zone.today
        expect(p3.next_charge_date).to eq Time.zone.today.next_month
        expect(p3.last_charge_date).to eq Time.zone.today

        expect(u3.billing.histories.reload.count).to eq u3_bh_count + 1
        bh3 = u3.billing.histories.last
        expect(bh3.item_name).to eq p3.name
        expect(bh3.payment_method.to_sym).to eq :invoice
        expect(bh3.price).to eq p3.price
        expect(bh3.billing_date).to eq Time.zone.today
        expect(bh3.unit_price).to eq p3.price
        expect(bh3.number).to eq 1

        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(p4.trial).to eq false
        expect(p4.next_charge_date).not_to eq Time.zone.today
        expect(p4.next_charge_date).to eq Time.zone.today.next_month
        expect(p4.last_charge_date).to eq Time.zone.today

        expect(u4.billing.histories.reload.count).to eq u4_bh_count + 1
        bh4 = u4.billing.histories.last
        expect(bh4.item_name).to eq p4.name
        expect(bh4.payment_method.to_sym).to eq :invoice
        expect(bh4.price).to eq p4.price
        expect(bh4.billing_date).to eq Time.zone.today
        expect(bh4.unit_price).to eq p4.price
        expect(bh4.number).to eq 1

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context 'charge_and_status_update_by_creditのバリエーション' do
      let(:next_charge_date) { Time.zone.today }
      let(:charge_date) { next_charge_date.day.to_s }
      let(:p6_end_at) { Time.zone.now - 1.second }
      let(:u1) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u3) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u4) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u6) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let!(:p1) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.second, charge_date: charge_date, next_charge_date: next_charge_date, price: 1230, billing: u1.billing) }
      let!(:p2) { create(:billing_plan, status: :waiting, start_at: Time.zone.now + 1.minutes, charge_date: charge_date, next_charge_date: next_charge_date, price:  830, billing: u2.billing) }
      let!(:p3) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.second,  charge_date: charge_date, next_charge_date: next_charge_date, price: 2830, billing: u3.billing) }
      let!(:p4) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now + 1.minutes, charge_date: charge_date, next_charge_date: next_charge_date, price: 3830, billing: u4.billing) }
      let!(:p5) { create(:billing_plan, status: :stopped, start_at: Time.zone.now - 2.months, end_at: nil,       charge_date: charge_date, next_charge_date: next_charge_date, last_charge_date: Time.zone.today.last_month, price: 2030, billing: u5.billing) }
      let!(:p6) { create(:billing_plan, status: :stopped, start_at: Time.zone.now - 2.months, end_at: p6_end_at, charge_date: charge_date, next_charge_date: next_charge_date, last_charge_date: Time.zone.today.last_month, price: 2130, billing: u6.billing) }

      before do
        allow_any_instance_of(Billing).to receive(:create_charge).and_return({ 'error' => false })
      end

      it do
        p2_updated_at = p2.updated_at
        p3_updated_at = p3.updated_at

        u1_bh_count = u1.billing.histories.count
        u2_bh_count = u2.billing.histories.count
        u3_bh_count = u3.billing.histories.count
        u4_bh_count = u4.billing.histories.count
        u5_bh_count = u5.billing.histories.count
        u6_bh_count = u6.billing.histories.count
        bh_count = BillingHistory.count


        expect(subject).to eq ["PLAN_ID: #{p1.id}, TYPE: #{p1.type}, CHARGE_DATE: #{p1.charge_date}, AMOUNT: #{p1.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円"]

        expect(BillingHistory.count).to eq bh_count + 2

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.next_charge_date).not_to eq Time.zone.today
        expect(p1.next_charge_date).to eq Time.zone.today.next_month
        expect(p1.last_charge_date).to eq Time.zone.today

        expect(u1.billing.histories.reload.count).to eq u1_bh_count + 1
        bh1 = u1.billing.histories.last
        expect(bh1.item_name).to eq p1.name
        expect(bh1.payment_method.to_sym).to eq :credit
        expect(bh1.price).to eq p1.price
        expect(bh1.billing_date).to eq Time.zone.today
        expect(bh1.unit_price).to eq p1.price
        expect(bh1.number).to eq 1

        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(p4.next_charge_date).not_to eq Time.zone.today
        expect(p4.next_charge_date).to be_nil # 次回課金は発生しないのでnil
        expect(p4.last_charge_date).to eq Time.zone.today

        expect(u4.billing.histories.reload.count).to eq u4_bh_count + 1
        bh4 = u4.billing.histories.last
        expect(bh4.item_name).to eq p4.name
        expect(bh4.payment_method.to_sym).to eq :credit
        expect(bh4.price).to eq p4.price
        expect(bh4.billing_date).to eq Time.zone.today
        expect(bh4.unit_price).to eq p4.price
        expect(bh4.number).to eq 1


        expect(p5.reload.status.to_sym).to eq :stopped
        expect(p5.end_at).to eq Time.zone.today.yesterday.end_of_day.iso8601
        expect(p5.next_charge_date).to be_nil # 次回課金は発生しないのでnil
        expect(p5.last_charge_date).to eq Time.zone.today.last_month

        expect(u5.billing.histories.reload.count).to eq u5_bh_count + 0

        expect(p6.reload.status.to_sym).to eq :stopped
        expect(p6.end_at).to eq p6_end_at.iso8601
        expect(p6.next_charge_date).to be_nil # 次回課金は発生しないのでnil
        expect(p6.last_charge_date).to eq Time.zone.today.last_month

        expect(u6.billing.histories.reload.count).to eq u6_bh_count + 0


        expect(p2.updated_at).to eq p2_updated_at
        expect(u2.billing.histories.reload.count).to eq u2_bh_count + 0

        expect(p3.updated_at).to eq p3_updated_at
        expect(u3.billing.histories.reload.count).to eq u3_bh_count + 0


        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context '日時を指定するとき' do
      subject { described_class.execute_charge(execute_time) }

      let(:execute_time) { Time.zone.now - 5.days }
      let(:next_charge_date) { execute_time.to_date }
      let(:charge_date) { next_charge_date.day.to_s }
      let(:p6_end_at) { execute_time - 1.second }
      let(:u1) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u3) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u4) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u6) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let!(:p1) { create(:billing_plan, status: :waiting, start_at: execute_time - 1.second, charge_date: charge_date, next_charge_date: next_charge_date, price: 1240, billing: u1.billing) }
      let!(:p2) { create(:billing_plan, status: :waiting, start_at: execute_time + 1.minutes, charge_date: charge_date, next_charge_date: next_charge_date, price:  840, billing: u2.billing) }
      let!(:p3) { create(:billing_plan, status: :ongoing, start_at: execute_time - 2.months, end_at: execute_time - 1.second,  charge_date: charge_date, next_charge_date: next_charge_date, price: 2840, billing: u3.billing) }
      let!(:p4) { create(:billing_plan, status: :ongoing, start_at: execute_time - 2.months, end_at: execute_time + 1.minutes, charge_date: charge_date, next_charge_date: next_charge_date, price: 3840, billing: u4.billing) }
      let!(:p5) { create(:billing_plan, status: :stopped, start_at: execute_time - 2.months, end_at: nil,       charge_date: charge_date, next_charge_date: next_charge_date, last_charge_date: execute_time.last_month, price: 2040, billing: u5.billing) }
      let!(:p6) { create(:billing_plan, status: :stopped, start_at: execute_time - 2.months, end_at: p6_end_at, charge_date: charge_date, next_charge_date: next_charge_date, last_charge_date: execute_time.last_month, price: 2140, billing: u6.billing) }

      before do
        allow_any_instance_of(Billing).to receive(:create_charge).and_return({ 'error' => false })
      end

      it do
        p2_updated_at = p2.updated_at
        p3_updated_at = p3.updated_at

        u1_bh_count = u1.billing.histories.count
        u2_bh_count = u2.billing.histories.count
        u3_bh_count = u3.billing.histories.count
        u4_bh_count = u4.billing.histories.count
        u5_bh_count = u5.billing.histories.count
        u6_bh_count = u6.billing.histories.count
        bh_count = BillingHistory.count


        expect(subject).to eq ["PLAN_ID: #{p1.id}, TYPE: #{p1.type}, CHARGE_DATE: #{p1.charge_date}, AMOUNT: #{p1.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p4.id}, TYPE: #{p4.type}, CHARGE_DATE: #{p4.charge_date}, AMOUNT: #{p4.price.to_s(:delimited)}円"]

        expect(BillingHistory.count).to eq bh_count + 2

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.next_charge_date).not_to eq execute_time.to_date
        expect(p1.next_charge_date).to eq execute_time.to_date.next_month
        expect(p1.last_charge_date).to eq execute_time.to_date

        expect(u1.billing.histories.reload.count).to eq u1_bh_count + 1
        bh1 = u1.billing.histories.last
        expect(bh1.item_name).to eq p1.name
        expect(bh1.payment_method.to_sym).to eq :credit
        expect(bh1.price).to eq p1.price
        expect(bh1.billing_date).to eq execute_time.to_date
        expect(bh1.unit_price).to eq p1.price
        expect(bh1.number).to eq 1

        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(p4.next_charge_date).not_to eq execute_time.to_date
        expect(p4.next_charge_date).to be_nil # 次回課金は発生しないのでnil
        expect(p4.last_charge_date).to eq execute_time.to_date

        expect(u4.billing.histories.reload.count).to eq u4_bh_count + 1
        bh4 = u4.billing.histories.last
        expect(bh4.item_name).to eq p4.name
        expect(bh4.payment_method.to_sym).to eq :credit
        expect(bh4.price).to eq p4.price
        expect(bh4.billing_date).to eq execute_time.to_date
        expect(bh4.unit_price).to eq p4.price
        expect(bh4.number).to eq 1


        expect(p5.reload.status.to_sym).to eq :stopped
        expect(p5.end_at).to eq execute_time.to_date.yesterday.end_of_day.iso8601
        expect(p5.next_charge_date).to be_nil # 次回課金は発生しないのでnil
        expect(p5.last_charge_date).to eq execute_time.to_date.last_month

        expect(u5.billing.histories.reload.count).to eq u5_bh_count + 0

        expect(p6.reload.status.to_sym).to eq :stopped
        expect(p6.end_at).to eq p6_end_at.iso8601
        expect(p6.next_charge_date).to be_nil # 次回課金は発生しないのでnil
        expect(p6.last_charge_date).to eq execute_time.to_date.last_month

        expect(u6.billing.histories.reload.count).to eq u6_bh_count + 0


        expect(p2.updated_at).to eq p2_updated_at
        expect(u2.billing.histories.reload.count).to eq u2_bh_count + 0

        expect(p3.updated_at).to eq p3_updated_at
        expect(u3.billing.histories.reload.count).to eq u3_bh_count + 0


        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context 'エラーの場合' do
      let(:next_charge_date) { Time.zone.today }
      let(:charge_date) { next_charge_date.day.to_s }

      let(:u1) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u3) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u4) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let!(:p1) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 1220, billing: u1.billing) }
      let!(:p2) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price:  820, billing: u2.billing) }
      let!(:p3) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 3820, billing: u3.billing) }
      let!(:p4) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 4420, billing: u4.billing) }
      let!(:p5) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 2020, billing: u5.billing) }
      let!(:p6) { create(:billing_plan, status: :ongoing, charge_date: charge_date, next_charge_date: next_charge_date, price: 2020, billing: u6.billing) }

      before do
        allow_any_instance_of(Billing).to receive(:create_charge).and_wrap_original do |update_method, args|
          if [p2.billing.id].include?(update_method.receiver.id)
            raise Billing::PayJpCardChargeFailureError
          elsif [p4.billing.id].include?(update_method.receiver.id)
            raise
          else
            { 'error' => false }
          end
        end

        allow_any_instance_of(BillingPlan).to receive(:trial?).and_wrap_original do |method, args|
          if [p5.id].include?(method.receiver.id)
            raise
          else
            false
          end
        end
      end

      it '' do
        p2_updated_at = p2.updated_at
        p4_updated_at = p4.updated_at
        p5_updated_at = p5.updated_at

        u1_bh_count = u1.billing.histories.count
        u2_bh_count = u2.billing.histories.count
        u3_bh_count = u3.billing.histories.count
        u4_bh_count = u4.billing.histories.count
        u5_bh_count = u5.billing.histories.count
        u6_bh_count = u6.billing.histories.count
        bh_count = BillingHistory.count

        expect(subject).to eq ["PLAN_ID: #{p1.id}, TYPE: #{p1.type}, CHARGE_DATE: #{p1.charge_date}, AMOUNT: #{p1.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p3.id}, TYPE: #{p3.type}, CHARGE_DATE: #{p3.charge_date}, AMOUNT: #{p3.price.to_s(:delimited)}円",
                               "PLAN_ID: #{p6.id}, TYPE: #{p6.type}, CHARGE_DATE: #{p6.charge_date}, AMOUNT: #{p6.price.to_s(:delimited)}円"]

        expect(BillingHistory.count).to eq bh_count + 3

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.trial).to eq false
        expect(p1.next_charge_date).not_to eq Time.zone.today
        expect(p1.next_charge_date).to eq Time.zone.today.next_month
        expect(p1.last_charge_date).to eq Time.zone.today

        expect(u1.billing.histories.reload.count).to eq u1_bh_count + 1
        bh1 = u1.billing.histories.last
        expect(bh1.item_name).to eq p1.name
        expect(bh1.payment_method.to_sym).to eq :credit
        expect(bh1.price).to eq p1.price
        expect(bh1.billing_date).to eq Time.zone.today
        expect(bh1.unit_price).to eq p1.price
        expect(bh1.number).to eq 1


        expect(p3.reload.status.to_sym).to eq :ongoing
        expect(p3.trial).to eq false
        expect(p3.next_charge_date).not_to eq Time.zone.today
        expect(p3.next_charge_date).to eq Time.zone.today.next_month
        expect(p3.last_charge_date).to eq Time.zone.today

        expect(u3.billing.histories.reload.count).to eq u3_bh_count + 1
        bh3 = u3.billing.histories.last
        expect(bh3.item_name).to eq p3.name
        expect(bh3.payment_method.to_sym).to eq :invoice
        expect(bh3.price).to eq p3.price
        expect(bh3.billing_date).to eq Time.zone.today
        expect(bh3.unit_price).to eq p3.price
        expect(bh3.number).to eq 1

        expect(p6.reload.status.to_sym).to eq :ongoing
        expect(p6.trial).to eq false
        expect(p6.next_charge_date).not_to eq Time.zone.today
        expect(p6.next_charge_date).to eq Time.zone.today.next_month
        expect(p6.last_charge_date).to eq Time.zone.today

        expect(u6.billing.histories.reload.count).to eq u6_bh_count + 1
        bh6 = u6.billing.histories.last
        expect(bh6  .item_name).to eq p6.name
        expect(bh6.payment_method.to_sym).to eq :invoice
        expect(bh6.price).to eq p6.price
        expect(bh6.billing_date).to eq Time.zone.today
        expect(bh6.unit_price).to eq p6.price
        expect(bh6.number).to eq 1

        expect(p2.updated_at).to eq p2_updated_at
        expect(u2.billing.histories.reload.count).to eq u2_bh_count + 0

        expect(p4.updated_at).to eq p4_updated_at
        expect(u4.billing.histories.reload.count).to eq u4_bh_count + 0

        expect(p5.updated_at).to eq p5_updated_at
        expect(u5.billing.histories.reload.count).to eq u5_bh_count + 0


        expect(ActionMailer::Base.deliveries.size).to eq(6)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#try_charge/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=PAYJP Charge Failure: 課金の失敗: カード認証・支払いエラーによる失敗 user_id=#{u2.id} plan_id=#{p2.id}/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/PLAN_ID\[#{p2.id}\]: PAYJP Charge Failure: カード認証・支払いエラーによる失敗。\]/)
        expect(ActionMailer::Base.deliveries[2].subject).to match(/fatal発生　BillingWorker#try_charge/)
        expect(ActionMailer::Base.deliveries[2].body.raw_source).to match(/issue=PAYJP Charge Failure: 課金の失敗 user_id=#{u4.id} plan_id=#{p4.id}/)
        expect(ActionMailer::Base.deliveries[3].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[3].body.raw_source).to match(/PLAN_ID\[#{p4.id}\]: PAYJP Charge Failure: 課金の失敗。\]/)
        expect(ActionMailer::Base.deliveries[4].subject).to match(/fatal発生　BillingWorker#execute_charge/)
        expect(ActionMailer::Base.deliveries[4].body.raw_source).to match(/issue=execute_charge 個別エラー user_id=#{u5.id} plan_id=#{p5.id}/)
        expect(ActionMailer::Base.deliveries[5].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[5].body.raw_source).to match(/PLAN_ID\[#{p5.id}\]: BillingWorker execute_charge 個別エラー\]/)
      end
    end
  end
 
  describe '#execute_plan_end' do
    subject { described_class.execute_plan_end }

    context '様々なステータスの確認' do
      let(:u1)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u7)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let!(:p1)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u1.billing) }
      let!(:p2)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u2.billing) }
      let!(:p3)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u3.billing) }
      let!(:p4)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now + 1.minutes, billing: u4.billing) }
      let!(:p5)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now + 1.minutes, billing: u5.billing) }
      let!(:p6)  { create(:billing_plan, status: :stopped, end_at: Time.zone.now - 1.minutes, billing: u6.billing) }
      let!(:p7)  { create(:billing_plan, status: :stopped, end_at: Time.zone.now - 1.minutes, billing: u7.billing) }

      it '対象がstoppedになること' do
        p1_updated_at = p1.updated_at
        p6_updated_at = p6.updated_at
        p7_updated_at = p7.updated_at

        expect(subject).to eq ["USER_ID: #{u1.id}, PLAN_ID: #{p1.id}",
                               "USER_ID: #{u2.id}, PLAN_ID: #{p2.id}",
                               "USER_ID: #{u3.id}, PLAN_ID: #{p3.id}"]

        expect(p1.reload.status.to_sym).to eq :stopped
        # expect(p1.updated_at).not_to eq p1_updated_at
        expect(u1.billing.reload.payment_method).to be_nil
        expect(p2.reload.status.to_sym).to eq :stopped
        expect(u2.billing.reload.payment_method).to be_nil
        expect(p3.reload.status.to_sym).to eq :stopped
        expect(u3.billing.reload.payment_method).to be_nil
        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(u4.billing.reload.payment_method.to_sym).to eq :credit
        expect(p5.reload.status.to_sym).to eq :ongoing
        expect(u5.billing.reload.payment_method.to_sym).to eq :invoice
        expect(p6.reload.status.to_sym).to eq :stopped
        expect(p6.updated_at.floor(9)).to eq p6_updated_at.floor(9)
        expect(u6.billing.reload.payment_method.to_sym).to eq :credit
        expect(p7.reload.status.to_sym).to eq :stopped
        expect(p7.updated_at.floor(9)).to eq p7_updated_at.floor(9)
        expect(u7.billing.reload.payment_method.to_sym).to eq :invoice

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context '日時を指定する時' do
      subject { described_class.execute_plan_end(time) }
      let(:time) { Time.zone.now - 3.days }

      let(:u1)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u7)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let!(:p1)  { create(:billing_plan, status: :ongoing, start_at: time - 2.month, end_at: time - 1.minutes, billing: u1.billing) }
      let!(:p2)  { create(:billing_plan, status: :ongoing, start_at: time - 2.month, end_at: time - 1.minutes, billing: u2.billing) }
      let!(:p3)  { create(:billing_plan, status: :ongoing, start_at: time - 2.month, end_at: time - 1.minutes, billing: u3.billing) }
      let!(:p4)  { create(:billing_plan, status: :ongoing, start_at: time - 2.month, end_at: time + 1.minutes, billing: u4.billing) }
      let!(:p5)  { create(:billing_plan, status: :ongoing, start_at: time - 2.month, end_at: time + 1.minutes, billing: u5.billing) }
      let!(:p6)  { create(:billing_plan, status: :stopped, start_at: time - 2.month, end_at: time - 1.minutes, billing: u6.billing) }
      let!(:p7)  { create(:billing_plan, status: :stopped, start_at: time - 2.month, end_at: time - 1.minutes, billing: u7.billing) }

      it '対象がstoppedになること' do
        p1_updated_at = p1.updated_at
        p6_updated_at = p6.updated_at
        p7_updated_at = p7.updated_at

        expect(subject).to eq ["USER_ID: #{u1.id}, PLAN_ID: #{p1.id}",
                               "USER_ID: #{u2.id}, PLAN_ID: #{p2.id}",
                               "USER_ID: #{u3.id}, PLAN_ID: #{p3.id}"]

        expect(p1.reload.status.to_sym).to eq :stopped
        # expect(p1.updated_at).not_to eq p1_updated_at
        expect(u1.billing.reload.payment_method).to be_nil
        expect(p2.reload.status.to_sym).to eq :stopped
        expect(u2.billing.reload.payment_method).to be_nil
        expect(p3.reload.status.to_sym).to eq :stopped
        expect(u3.billing.reload.payment_method).to be_nil
        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(u4.billing.reload.payment_method.to_sym).to eq :credit
        expect(p5.reload.status.to_sym).to eq :ongoing
        expect(u5.billing.reload.payment_method.to_sym).to eq :invoice
        expect(p6.reload.status.to_sym).to eq :stopped
        expect(p6.updated_at.floor(9)).to eq p6_updated_at.floor(9)
        expect(u6.billing.reload.payment_method.to_sym).to eq :credit
        expect(p7.reload.status.to_sym).to eq :stopped
        expect(p7.updated_at.floor(9)).to eq p7_updated_at.floor(9)
        expect(u7.billing.reload.payment_method.to_sym).to eq :invoice

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context '一部のアップデートが失敗する場合' do
      let(:u1) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3) { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6) { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let!(:p1) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u1.billing) }
      let!(:p2) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u2.billing) }
      let!(:p3) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u3.billing) }
      let!(:p4) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u4.billing) }
      let!(:p5) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u5.billing) }
      let!(:p6) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u6.billing) }

      before do
        allow_any_instance_of(Billing).to receive(:update!).and_wrap_original do |update_method, args|
          if [p3.billing.id, p5.billing.id].include?(update_method.receiver.id)
            raise
          else
            update_method.call(payment_method: args[:payment_method])
          end
        end
      end

      it '対象がstoppedになること' do
        expect(subject).to eq ["USER_ID: #{u1.id}, PLAN_ID: #{p1.id}",
                               "USER_ID: #{u2.id}, PLAN_ID: #{p2.id}",
                               "USER_ID: #{u4.id}, PLAN_ID: #{p4.id}",
                               "USER_ID: #{u6.id}, PLAN_ID: #{p6.id}"]

        expect(p1.reload.status.to_sym).to eq :stopped
        expect(u1.billing.reload.payment_method).to be_nil
        expect(p2.reload.status.to_sym).to eq :stopped
        expect(u2.billing.reload.payment_method).to be_nil
        expect(p3.reload.status.to_sym).to eq :ongoing
        expect(u3.billing.reload.payment_method.to_sym).to eq :bank_transfer
        expect(p4.reload.status.to_sym).to eq :stopped
        expect(u4.billing.reload.payment_method).to be_nil
        expect(p5.reload.status.to_sym).to eq :ongoing
        expect(u5.billing.reload.payment_method.to_sym).to eq :invoice
        expect(p6.reload.status.to_sym).to eq :stopped
        expect(u6.billing.reload.payment_method).to be_nil


        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#execute_plan_end/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=execute_plan_end 個別エラー user_id=#{u3.id} plan_id=#{p3.id}/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/fatal発生　BillingWorker#execute_plan_end/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/issue=execute_plan_end 個別エラー user_id=#{u5.id} plan_id=#{p5.id}/)
      end
    end

    # 複数のプランを持てるときに開放する
    xcontext '複数のプランがある時' do
      let(:u8)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u9)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u10) { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u11) { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u12) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u13) { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let!(:p8)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u8.billing) }
      let!(:p9)  { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 3.minutes, billing: u8.billing) }
      let!(:p10) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u9.billing) }
      let!(:p11) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 5.minutes, billing: u9.billing) }
      let!(:p12) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u10.billing) }
      let!(:p13) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u10.billing) }
      let!(:p14) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u11.billing) }
      let!(:p15) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now + 1.minutes, billing: u11.billing) }
      let!(:p16) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u12.billing) }
      let!(:p17) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now + 1.minutes, billing: u12.billing) }
      let!(:p18) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now - 1.minutes, billing: u13.billing) }
      let!(:p19) { create(:billing_plan, status: :ongoing, end_at: Time.zone.now + 1.minutes, billing: u13.billing) }

      it '対象がstoppedになること' do
        subject
        expect(subject).to eq ["USER_ID: #{u8.id}, PLAN_ID: #{p8.id}",
                               "USER_ID: #{u8.id}, PLAN_ID: #{p9.id}",
                               "USER_ID: #{u9.id}, PLAN_ID: #{p10.id}",
                               "USER_ID: #{u9.id}, PLAN_ID: #{p11.id}",
                               "USER_ID: #{u10.id}, PLAN_ID: #{p12.id}",
                               "USER_ID: #{u10.id}, PLAN_ID: #{p13.id}",
                               "USER_ID: #{u11.id}, PLAN_ID: #{p14.id}",
                               "USER_ID: #{u12.id}, PLAN_ID: #{p16.id}",
                               "USER_ID: #{u13.id}, PLAN_ID: #{p18.id}"]

        expect(p8.reload.status.to_sym).to eq :stopped
        expect(p9.reload.status.to_sym).to eq :stopped
        expect(u8.billing.reload.payment_method).to be_nil
        expect(p10.reload.status.to_sym).to eq :stopped
        expect(p11.reload.status.to_sym).to eq :stopped
        expect(u9.billing.reload.payment_method).to be_nil
        expect(p12.reload.status.to_sym).to eq :stopped
        expect(p13.reload.status.to_sym).to eq :stopped
        expect(u10.billing.reload.payment_method).to be_nil
        expect(p14.reload.status.to_sym).to eq :stopped
        expect(p15.reload.status.to_sym).to eq :ongoing
        expect(u11.billing.reload.payment_method.to_sym).to eq :credit
        expect(p16.reload.status.to_sym).to eq :stopped
        expect(p17.reload.status.to_sym).to eq :ongoing
        expect(u12.billing.reload.payment_method.to_sym).to eq :invoice
        expect(p18.reload.status.to_sym).to eq :stopped
        expect(p19.reload.status.to_sym).to eq :ongoing
        expect(u13.billing.reload.payment_method.to_sym).to eq :bank_transfer

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end
  end

  describe '#execute_plan_start' do
    subject { described_class.execute_plan_start }

    context '様々なステータスの確認' do
      let(:u1)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u7)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u8)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u9)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u10) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u11) { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let!(:p1)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u1.billing) }
      let!(:p2)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u2.billing) }
      let!(:p3)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u3.billing) }
      let!(:p4)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: Time.zone.tomorrow, billing: u4.billing) }
      let!(:p5)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: Time.zone.tomorrow, billing: u5.billing) }
      let!(:p6)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now + 1.minutes, next_charge_date: nil, billing: u6.billing) }
      let!(:p7)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now + 1.minutes, next_charge_date: nil, billing: u7.billing) }
      let!(:p8)  { create(:billing_plan, status: :waiting, start_at: Time.zone.now + 1.minutes, next_charge_date: nil, billing: u8.billing) }
      let!(:p9)  { create(:billing_plan, status: :ongoing, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u9.billing) }
      let!(:p10) { create(:billing_plan, status: :ongoing, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u10.billing) }
      let!(:p11) { create(:billing_plan, status: :ongoing, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u11.billing) }

      it '対象がstoppedになること' do
        p6_updated_at = p6.updated_at
        p7_updated_at = p7.updated_at
        p8_updated_at = p8.updated_at
        p9_updated_at = p9.updated_at
        p10_updated_at = p10.updated_at
        p11_updated_at = p11.updated_at

        expect(subject).to eq ["USER_ID: #{u1.id}, PLAN_ID: #{p1.id}",
                               "USER_ID: #{u2.id}, PLAN_ID: #{p2.id}",
                               "USER_ID: #{u3.id}, PLAN_ID: #{p3.id}",
                               "USER_ID: #{u4.id}, PLAN_ID: #{p4.id}",
                               "USER_ID: #{u5.id}, PLAN_ID: #{p5.id}"]

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.next_charge_date).to eq Time.zone.today
        expect(p2.reload.status.to_sym).to eq :ongoing
        expect(p2.next_charge_date).to eq Time.zone.today
        expect(p3.reload.status.to_sym).to eq :ongoing
        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(p4.next_charge_date).to eq Time.zone.tomorrow
        expect(p5.reload.status.to_sym).to eq :ongoing
        expect(p5.next_charge_date).to eq Time.zone.tomorrow
        expect(p6.reload.status.to_sym).to eq :waiting
        expect(p6.updated_at.floor(9)).to eq p6_updated_at.floor(9)
        expect(p7.reload.status.to_sym).to eq :waiting
        expect(p7.updated_at.floor(9)).to eq p7_updated_at.floor(9)
        expect(p8.reload.status.to_sym).to eq :waiting
        expect(p8.updated_at.floor(9)).to eq p8_updated_at.floor(9)
        expect(p9.reload.status.to_sym).to eq :ongoing
        expect(p9.updated_at.floor(9)).to eq p9_updated_at.floor(9)
        expect(p10.reload.status.to_sym).to eq :ongoing
        expect(p10.updated_at.floor(9)).to eq p10_updated_at.floor(9)
        expect(p11.reload.status.to_sym).to eq :ongoing
        expect(p11.updated_at.floor(9)).to eq p11_updated_at.floor(9)

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end

    context '一部のアップデートが失敗する場合' do
      let(:u1)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let!(:p1) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u1.billing) }
      let!(:p2) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u2.billing) }
      let!(:p3) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u3.billing) }
      let!(:p4) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u4.billing) }
      let!(:p5) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u5.billing) }
      let!(:p6) { create(:billing_plan, status: :waiting, start_at: Time.zone.now - 1.minutes, next_charge_date: nil, billing: u6.billing) }

      before do
        allow_any_instance_of(BillingPlan).to receive(:update!).and_wrap_original do |update_method, args|
          if [p3.id, p5.id].include?(update_method.receiver.id)
            raise
          else
            update_method.call(status: args[:status])
          end
        end
      end

      it '対象がstoppedになること' do
        p3_updated_at = p3.updated_at
        p5_updated_at = p5.updated_at

        expect(subject).to eq ["USER_ID: #{u1.id}, PLAN_ID: #{p1.id}",
                               "USER_ID: #{u2.id}, PLAN_ID: #{p2.id}",
                               "USER_ID: #{u4.id}, PLAN_ID: #{p4.id}",
                               "USER_ID: #{u6.id}, PLAN_ID: #{p6.id}"]

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p2.reload.status.to_sym).to eq :ongoing
        expect(p3.reload.status.to_sym).to eq :waiting
        expect(p3.updated_at.floor(9)).to eq p3_updated_at.floor(9)
        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(p5.reload.status.to_sym).to eq :waiting
        expect(p5.updated_at.floor(9)).to eq p5_updated_at.floor(9)
        expect(p6.reload.status.to_sym).to eq :ongoing

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生　BillingWorker#execute_plan_start/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/issue=execute_plan_start 個別エラー user_id=#{u3.id} plan_id=#{p3.id}/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/fatal発生　BillingWorker#execute_plan_start/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/issue=execute_plan_start 個別エラー user_id=#{u5.id} plan_id=#{p5.id}/)
      end
    end

    context '日時指定をする時' do
      subject { described_class.execute_plan_start(time) }
      let(:time) { Time.zone.now - 3.days }

      let(:u1)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u2)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u3)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u4)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u5)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u6)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u7)  { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u8)  { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let(:u9)  { create(:user, billing_attrs: { payment_method: :credit } ) }
      let(:u10) { create(:user, billing_attrs: { payment_method: :invoice } ) }
      let(:u11) { create(:user, billing_attrs: { payment_method: :bank_transfer } ) }
      let!(:p1)  { create(:billing_plan, status: :waiting, start_at: time - 1.minutes, next_charge_date: nil, billing: u1.billing) }
      let!(:p2)  { create(:billing_plan, status: :waiting, start_at: time - 1.minutes, next_charge_date: nil, billing: u2.billing) }
      let!(:p3)  { create(:billing_plan, status: :waiting, start_at: time - 1.minutes, next_charge_date: nil, billing: u3.billing) }
      let!(:p4)  { create(:billing_plan, status: :waiting, start_at: time - 1.minutes, next_charge_date: Time.zone.tomorrow, billing: u4.billing) }
      let!(:p5)  { create(:billing_plan, status: :waiting, start_at: time - 1.minutes, next_charge_date: Time.zone.tomorrow, billing: u5.billing) }
      let!(:p6)  { create(:billing_plan, status: :waiting, start_at: time + 1.minutes, next_charge_date: nil, billing: u6.billing) }
      let!(:p7)  { create(:billing_plan, status: :waiting, start_at: time + 1.minutes, next_charge_date: nil, billing: u7.billing) }
      let!(:p8)  { create(:billing_plan, status: :waiting, start_at: time + 1.minutes, next_charge_date: nil, billing: u8.billing) }
      let!(:p9)  { create(:billing_plan, status: :ongoing, start_at: time - 1.minutes, next_charge_date: nil, billing: u9.billing) }
      let!(:p10) { create(:billing_plan, status: :ongoing, start_at: time - 1.minutes, next_charge_date: nil, billing: u10.billing) }
      let!(:p11) { create(:billing_plan, status: :ongoing, start_at: time - 1.minutes, next_charge_date: nil, billing: u11.billing) }

      it '対象がstoppedになること' do
        p6_updated_at = p6.updated_at
        p7_updated_at = p7.updated_at
        p8_updated_at = p8.updated_at
        p9_updated_at = p9.updated_at
        p10_updated_at = p10.updated_at
        p11_updated_at = p11.updated_at

        expect(subject).to eq ["USER_ID: #{u1.id}, PLAN_ID: #{p1.id}",
                               "USER_ID: #{u2.id}, PLAN_ID: #{p2.id}",
                               "USER_ID: #{u3.id}, PLAN_ID: #{p3.id}",
                               "USER_ID: #{u4.id}, PLAN_ID: #{p4.id}",
                               "USER_ID: #{u5.id}, PLAN_ID: #{p5.id}"]

        expect(p1.reload.status.to_sym).to eq :ongoing
        expect(p1.next_charge_date).to eq time.to_date
        expect(p2.reload.status.to_sym).to eq :ongoing
        expect(p2.next_charge_date).to eq time.to_date
        expect(p3.reload.status.to_sym).to eq :ongoing
        expect(p4.reload.status.to_sym).to eq :ongoing
        expect(p4.next_charge_date).to eq Time.zone.tomorrow
        expect(p5.reload.status.to_sym).to eq :ongoing
        expect(p5.next_charge_date).to eq Time.zone.tomorrow
        expect(p6.reload.status.to_sym).to eq :waiting
        expect(p6.updated_at.floor(9)).to eq p6_updated_at.floor(9)
        expect(p7.reload.status.to_sym).to eq :waiting
        expect(p7.updated_at.floor(9)).to eq p7_updated_at.floor(9)
        expect(p8.reload.status.to_sym).to eq :waiting
        expect(p8.updated_at.floor(9)).to eq p8_updated_at.floor(9)
        expect(p9.reload.status.to_sym).to eq :ongoing
        expect(p9.updated_at.floor(9)).to eq p9_updated_at.floor(9)
        expect(p10.reload.status.to_sym).to eq :ongoing
        expect(p10.updated_at.floor(9)).to eq p10_updated_at.floor(9)
        expect(p11.reload.status.to_sym).to eq :ongoing
        expect(p11.updated_at.floor(9)).to eq p11_updated_at.floor(9)

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end
  end


end

require 'rails_helper'

RSpec.describe PaymentHistoriesController, type: :controller do
  before do
    create_public_user
    allow_any_instance_of(S3Handler).to receive(:exist_object?).and_return(true)
  end

  let(:fallback_path) { 'http://test.host/' }
  let_it_be(:user) { create(:user) }

  after { ActionMailer::Base.deliveries.clear }

  describe "GET index" do
    subject { get :index }

    context 'ログインしていない' do
      it do
        subject
        expect(response.status).to eq(302)
        expect(response.location).to eq 'http://test.host/users/sign_in'
        expect(response).not_to render_template :index
      end
    end

    context 'ログインしている' do
      before do
        sign_in user
      end

      context 'billing historiesがない' do
        it do
          subject
          expect(response.status).to eq(302)
          expect(response.location).to eq fallback_path
          expect(response).not_to render_template :index

          expect(assigns(:last_month)).to be_nil
          expect(assigns(:last_month_histories)).to be_nil
          expect(assigns(:history_months)).to be_nil
          expect(assigns(:invoice_download_display)).to be_nil
        end
      end

      context 'billing historiesがある' do
        let_it_be(:last_month) { Time.zone.now.last_month.beginning_of_month }
        let_it_be(:two_month_month) { (Time.zone.now - 2.months).beginning_of_month }
        let_it_be(:three_month_month) { (Time.zone.now - 3.months).beginning_of_month }

        let_it_be(:his03) { create(:billing_history, billing_date: two_month_month + 24.day, billing: user.billing) }
        let_it_be(:his04) { create(:billing_history, billing_date: two_month_month + 11.day, billing: user.billing) }
        let_it_be(:his05) { create(:billing_history, billing_date: two_month_month + 18.day, billing: user.billing) }
        let_it_be(:his06) { create(:billing_history, billing_date: three_month_month + 3.day, billing: user.billing) }
        let_it_be(:his07) { create(:billing_history, billing_date: three_month_month + 19.day, billing: user.billing) }

        context 'invoiceがない' do
          let!(:his1) { create(:billing_history, billing_date: last_month + 7.day, billing: user.billing) }
          let!(:his2) { create(:billing_history, billing_date: last_month + 2.day, billing: user.billing) }
          let!(:his3) { create(:billing_history, billing_date: last_month + 15.day, billing: user.billing) }

          it do
            subject
            expect(response.status).to eq(200)
            expect(response).to render_template :index

            expect(assigns(:last_month)).to eq his3.billing_date.beginning_of_day
            expect(assigns(:last_month_histories)).to match [his3, his1, his2]
            expect(assigns(:history_months)).to match [last_month.strftime("%Y年%-m月"), two_month_month.strftime("%Y年%-m月"), three_month_month.strftime("%Y年%-m月")]
            expect(assigns(:invoice_download_display)).to be_falsey
          end
        end

        context 'invoiceがある' do

          let(:exec_time) { Time.zone.now }
          before { Timecop.freeze(exec_time) }
          after  { Timecop.return }

          context '月末を越えていない' do
            let(:exec_time) { Time.zone.now.last_month.end_of_month - 5.days }

            let!(:his1) { create(:billing_history, billing_date: last_month + 7.day, billing: user.billing) }
            let!(:his2) { create(:billing_history, payment_method: :invoice, billing_date: last_month + 2.day, billing: user.billing) }

            it do
              subject
              expect(response.status).to eq(200)
              expect(response).to render_template :index

              expect(assigns(:last_month)).to eq his1.billing_date.beginning_of_day
              expect(assigns(:last_month_histories)).to match [his1, his2]
              expect(assigns(:history_months)).to match [last_month.strftime("%Y年%-m月"), two_month_month.strftime("%Y年%-m月"), three_month_month.strftime("%Y年%-m月")]
              expect(assigns(:invoice_download_display)).to be_falsey
            end
          end

          context '月初の1日' do
            context '請求書ファイルがあるとき' do
              let(:exec_time) { Time.zone.now.beginning_of_month + 5.minutes }

              before { allow_any_instance_of(S3Handler).to receive(:exist_object?).and_return(true) }

              let!(:his1) { create(:billing_history, billing_date: last_month + 7.day, billing: user.billing) }
              let!(:his2) { create(:billing_history, payment_method: :invoice, billing_date: last_month + 2.day, billing: user.billing) }

              it do
                subject
                expect(response.status).to eq(200)
                expect(response).to render_template :index

                expect(assigns(:last_month)).to eq his1.billing_date.beginning_of_day
                expect(assigns(:last_month_histories)).to match [his1, his2]
                expect(assigns(:history_months)).to match [last_month.strftime("%Y年%-m月"), two_month_month.strftime("%Y年%-m月"), three_month_month.strftime("%Y年%-m月")]
                expect(assigns(:invoice_download_display)).to be_truthy
              end
            end

            context '請求書ファイルがあるとき' do
              let(:exec_time) { Time.zone.now.beginning_of_month + 5.minutes }
              before { allow_any_instance_of(S3Handler).to receive(:exist_object?).and_return(false) }

              let!(:his1) { create(:billing_history, billing_date: last_month + 7.day, billing: user.billing) }
              let!(:his2) { create(:billing_history, payment_method: :invoice, billing_date: last_month + 2.day, billing: user.billing) }

              it do
                subject
                expect(response.status).to eq(200)
                expect(response).to render_template :index

                expect(assigns(:last_month)).to eq his1.billing_date.beginning_of_day
                expect(assigns(:last_month_histories)).to match [his1, his2]
                expect(assigns(:history_months)).to match [last_month.strftime("%Y年%-m月"), two_month_month.strftime("%Y年%-m月"), three_month_month.strftime("%Y年%-m月")]
                expect(assigns(:invoice_download_display)).to be_falsey
              end
            end
          end

          context '月初の2日' do
            context '請求書ファイルがあるとき' do
              let(:exec_time) { Time.zone.now.beginning_of_month.tomorrow + 1.minutes }
              before { allow_any_instance_of(S3Handler).to receive(:exist_object?).and_return(false) }

              let!(:his1) { create(:billing_history, billing_date: last_month + 7.day, billing: user.billing) }
              let!(:his2) { create(:billing_history, payment_method: :invoice, billing_date: last_month + 2.day, billing: user.billing) }

              it do
                subject
                expect(response.status).to eq(200)
                expect(response).to render_template :index

                expect(assigns(:last_month)).to eq his1.billing_date.beginning_of_day
                expect(assigns(:last_month_histories)).to match [his1, his2]
                expect(assigns(:history_months)).to match [last_month.strftime("%Y年%-m月"), two_month_month.strftime("%Y年%-m月"), three_month_month.strftime("%Y年%-m月")]
                expect(assigns(:invoice_download_display)).to be_truthy
              end
            end
          end
        end
      end
    end
  end

  describe "GET show" do
    let(:target_month) { '202405' }
    subject { get :show, params: {month: target_month} }

    context 'ログインしていない' do
      it do
        subject
        expect(response.status).to eq(302)
        expect(response.location).to eq 'http://test.host/users/sign_in'
        expect(response).not_to render_template :index
      end
    end

    context 'ログインしている' do
      before do
        sign_in user
      end

      context '対象月のhistoriesがない' do
        it do
          subject
          expect(response.status).to eq(400)
          expect(response.location).to be_nil

          expect(response.body).to eq({ error: 'データは存在しません。' }.to_json)
        end
      end

      context '対象月のhistoriesがない' do
        let(:target_month) { Time.zone.now.strftime("%Y%m") }
        let!(:his) { create(:billing_history, payment_method: :invoice, billing_date: Time.zone.now.last_month, billing: user.billing) }

        it do
          subject
          expect(response.status).to eq(400)
          expect(response.location).to be_nil

          expect(response.body).to eq({ error: 'データは存在しません。' }.to_json)
        end
      end

      context '対象月のhistoriesがある' do
        context 'invoiceはない' do
          let(:target_time) { Time.zone.now }
          let(:target_month) { target_time.strftime("%Y%m") }
          let!(:his) { create(:billing_history, billing_date: Time.zone.now, billing: user.billing) }

          it do
            subject
            expect(response.status).to eq(200)
            expect(response.location).to be_nil

            res = JSON.parse(response.body)
            expect(res['year_month']).to eq target_month
            expect(res['end_of_month']).to eq target_time.end_of_month.strftime("%FT%T%:z")
            expect(res['invoice']).to eq false
            expect(res['title']).to eq "#{target_time.strftime("%Y年%-m月")} 課金情報"
            expect(res['invoice_file_exist']).to eq false
            expect(res['data'][0]['billing_date']).to eq target_time.strftime("%Y年%-m月%-d日")
            expect(res['data'][0]['item_name']).to eq his.item_name
            expect(res['data'][0]['payment_method']).to eq his.payment_method_str
            expect(res['data'][0]['unit_price']).to eq "#{his.unit_price&.to_s(:delimited)}円"
            expect(res['data'][0]['number']).to eq his.number&.to_s(:delimited)
            expect(res['data'][0]['price']).to eq "#{his.price&.to_s(:delimited)}円"
          end
        end

        context 'invoiceがある' do
          let(:target_time) { Time.zone.now.last_month }
          let(:target_month) { target_time.strftime("%Y%m") }
          let!(:his) { create(:billing_history, payment_method: :invoice, billing_date: target_time.end_of_month - 5.days, billing: user.billing) }

          it do
            subject
            expect(response.status).to eq(200)
            expect(response.location).to be_nil

            res = JSON.parse(response.body)
            expect(res['year_month']).to eq target_month
            expect(res['end_of_month']).to eq target_time.end_of_month.strftime("%FT%T%:z")
            expect(res['invoice']).to eq true
            expect(res['title']).to eq "#{target_time.strftime("%Y年%-m月")} 課金情報"
            expect(res['invoice_file_exist']).to eq true
            expect(res['data'][0]['billing_date']).to eq his.billing_date.strftime("%Y年%-m月%-d日")
            expect(res['data'][0]['item_name']).to eq his.item_name
            expect(res['data'][0]['payment_method']).to eq his.payment_method_str
            expect(res['data'][0]['unit_price']).to eq "#{his.unit_price&.to_s(:delimited)}円"
            expect(res['data'][0]['number']).to eq his.number&.to_s(:delimited)
            expect(res['data'][0]['price']).to eq "#{his.price&.to_s(:delimited)}円"
          end
        end

        context 'invoiceがある' do
          let(:target_time) { Time.zone.now - 2.month }
          let(:target_month) { target_time.strftime("%Y%m") }
          let!(:his) { create(:billing_history, payment_method: :invoice, billing_date: target_time.end_of_month - 5.days, billing: user.billing) }
          let!(:his2) { create(:billing_history, payment_method: :credit, billing_date: target_time.end_of_month - 10.days, billing: user.billing) }

          it do
            subject
            expect(response.status).to eq(200)
            expect(response.location).to be_nil

            res = JSON.parse(response.body)
            expect(res['year_month']).to eq target_month
            expect(res['end_of_month']).to eq target_time.end_of_month.strftime("%FT%T%:z")
            expect(res['invoice']).to eq true
            expect(res['title']).to eq "#{target_time.strftime("%Y年%-m月")} 課金情報"
            expect(res['invoice_file_exist']).to eq true
            expect(res['data'][0]['billing_date']).to eq his.billing_date.strftime("%Y年%-m月%-d日")
            expect(res['data'][0]['item_name']).to eq his.item_name
            expect(res['data'][0]['payment_method']).to eq his.payment_method_str
            expect(res['data'][0]['unit_price']).to eq "#{his.unit_price&.to_s(:delimited)}円"
            expect(res['data'][0]['number']).to eq his.number&.to_s(:delimited)
            expect(res['data'][0]['price']).to eq "#{his.price&.to_s(:delimited)}円"
            expect(res['data'][1]['billing_date']).to eq his2.billing_date.strftime("%Y年%-m月%-d日")
            expect(res['data'][1]['item_name']).to eq his2.item_name
            expect(res['data'][1]['payment_method']).to eq his2.payment_method_str
            expect(res['data'][1]['unit_price']).to eq "#{his2.unit_price&.to_s(:delimited)}円"
            expect(res['data'][1]['number']).to eq his2.number&.to_s(:delimited)
            expect(res['data'][1]['price']).to eq "#{his2.price&.to_s(:delimited)}円"
          end
        end
      end
    end
  end

  describe "GET download" do
    let(:target_month) { '202405' }
    subject { get :download, params: {month: target_month} }

    context 'ログインしていない' do
      it do
        subject
        expect(response.status).to eq(302)
        expect(response.location).to eq 'http://test.host/users/sign_in'
        expect(response).not_to render_template :index
      end
    end

    context 'ログインしている' do
      before do
        sign_in user
      end

      context '請求書は作成される日になっていない' do
        let(:target_time) { Time.zone.now }
        let(:target_month) { target_time.strftime("%Y%m") }
        it do
          subject
          expect(response.status).to eq(400)
          expect(response.location).to be_nil

          expect(response.body).to eq({ error: 'まだ請求書は作成されていません。' }.to_json)
        end
      end

      context 'S3の取得エラー' do
        before do
          class Aws::S3::Errors::NoSuchKey
            def initialize; end
          end

          allow_any_instance_of(S3Handler).to receive(:download).and_raise(Aws::S3::Errors::NoSuchKey)
        end

        context '月初の時' do
          let(:target_time)  { Time.zone.now.last_month }
          let(:target_month) { target_time.strftime("%Y%m") }

          before { Timecop.freeze(Time.zone.now.beginning_of_month) }
          after  { Timecop.return }

          it do
            subject
            expect(response.status).to eq(400)
            expect(response.location).to be_nil

            expect(response.body).to eq({ error: 'まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。' }.to_json)
          end
        end

        context '2日目の時' do
          let(:target_time)  { Time.zone.now.last_month }
          let(:target_month) { target_time.strftime("%Y%m") }

          before { Timecop.freeze(Time.zone.now.beginning_of_month.tomorrow) }
          after  { Timecop.return }

          it do
            subject
            expect(response.status).to eq(400)
            expect(response.location).to be_nil

            expect(response.body).to eq({ error: '請求書ファイルが存在しません。' }.to_json)

            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries[0].subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書ファイルが存在しません。至急、確認が必要です。/)
            expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID\[#{user.id}\]/)
          end
        end      
      end
    end
  end

  describe '#exist_invoice_file?' do
    subject { described_class.new.send(:exist_invoice_file?, month) }
    let!(:month) { Time.zone.now.last_month }
    let(:exec_time) { Time.zone.now }

    before { Timecop.freeze(exec_time) }
    after { Timecop.return }

    context '2日' do
      let(:exec_time) { Time.zone.now.beginning_of_month.tomorrow }
      it { expect(subject).to eq true }
    end

    context '1日' do
      let(:exec_time) { Time.zone.now.beginning_of_month }
      before {allow_any_instance_of(described_class).to receive(:invoice_s3_path).and_return('asds') }

      context 'S3にファイルあり' do
        before { allow_any_instance_of(S3Handler).to receive(:exist_object?).and_return(true) }

        it { expect(subject).to eq true }
      end

      context 'S3にファイルなし' do
        before { allow_any_instance_of(S3Handler).to receive(:exist_object?).and_return(false) }
        it { expect(subject).to eq false }
      end
    end

    context '月初を迎えていない' do
      let(:exec_time) { Time.zone.now.beginning_of_month - 1.minutes }
      it { expect(subject).to eq false }
    end
  end
end

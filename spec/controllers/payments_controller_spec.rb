require 'rails_helper'


RSpec.describe PaymentsController, type: :controller do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  before { create_public_user }
  let_it_be(:admin)     { create(:user, role: :administrator) }
  let_it_be(:allow_ip)  { create(:allow_ip, :admin, user: admin) }

  let(:password)        { "#{SecureRandom.alphanumeric(10)}A2" }
  let(:fallback_path)   { 'http://test.host/' }
  let(:his_plan)        { EasySettings.plan[:administrator] }
  let(:payment_method)  { nil }
  let(:email)           { Faker::Internet.email }
  let!(:monthly_history) { create(:monthly_history, user: user, plan: his_plan) }

  let(:user)            { create(:user, email: email, password: password, billing_attrs: { payment_method: payment_method,
                                                                                           customer_id: nil,
                                                                                           subscription_id: nil})
                        }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
  end

  after { ActionMailer::Base.deliveries.clear }

  describe 'GET index' do

    context '非ログインユーザの場合' do

      it '404になること' do
        get :index

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:user)).to be_nil
        expect(assigns(:finish_status)).to be_nil
      end
    end

    context '管理者ではないユーザの場合' do
      it '404になること' do
        sign_in user

        get :index

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:user)).to be_nil
        expect(assigns(:finish_status)).to be_nil
      end
    end

    context '管理者ユーザの場合' do
      # let!(:user) { create(:user, email: email, password: password, role: :administrator, billing_attrs: { payment_method: payment_method,
      #                                                                                                      customer_id: nil}) }
      # let(:plan) { EasySettings.plan[:administrator] }
      let(:check_user) { create(:user) }

      before { sign_in admin }

      context 'user_idを渡していない場合' do

        it 'index画面に遷移すること' do
          get :index

          expect(response.status).to eq 200
          expect(response).to render_template :index

          expect(assigns(:user)).to be_nil
        end
      end

      context 'user_idを渡している場合' do

        it 'index画面に遷移すること' do
          get :index, params: { user_id_or_email: check_user.id }

          expect(response.status).to eq 200
          expect(response).to render_template :index

          expect(assigns(:user)).to eq check_user
        end
      end

      context 'user_idが正しくない場合' do

        it 'index画面に遷移すること' do
          get :index, params: { user_id_or_email: check_user.id + 1 }

          expect(response.status).to eq 200
          expect(response).to render_template :index

          expect(flash[:alert]).to eq 'ユーザが存在しません。'
          expect(assigns(:user)).to be_nil
        end
      end

      context 'メールアドレスを渡している場合' do

        it 'index画面に遷移すること' do
          get :index, params: { user_id_or_email: check_user.email }

          expect(response.status).to eq 200
          expect(response).to render_template :index

          expect(assigns(:user)).to eq check_user
        end
      end

      context 'メールアドレスが正しくない場合' do
        let(:wrong_email) { 'wrong@mailaddress' }

        it 'index画面に遷移すること' do
          get :index, params: { user_id_or_email: wrong_email }

          expect(response.status).to eq 200
          expect(response).to render_template :index

          expect(flash[:alert]).to eq "ユーザ(#{wrong_email})が存在しません。"
          expect(assigns(:user)).to be_nil
        end
      end
    end
  end

  xdescribe 'GET modify' do
    let(:check_str) { 'gg' }
    let(:new_plan)  { EasySettings.payjp_plan_id[:test_light] }
    let(:commit)    { '変更' }
    let(:user_id)   { user.id }
    let(:to_do)     { nil }
    let(:params)    { {check: check_str, new_plan: new_plan, commit: commit, user_id: user_id, to_do: to_do} }

    context '非ログインユーザの場合' do

      it '404になること' do
        put :modify, params: params

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context '管理者ではないユーザの場合' do

      it '404になること' do
        sign_in user

        put :modify, params: params

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context '管理者ユーザの場合' do
      let(:plan)        { EasySettings.plan[:administrator] }

      context 'チェック文字列が間違っている場合' do
        context 'チェック文字列がゾロ目でない場合' do
          let(:check_str) { 'gr' }

          it 'リダイレクトされること' do
            sign_in user

            put :modify, params: params

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq 'チェック文字がおかしいです。'
            expect(assigns(:finish_status)).to eq :wrong_check_character
          end
        end

        context 'チェック文字列が2文字でない場合' do
          let(:check_str) { 'gg3' }

          it 'リダイレクトされること' do
            sign_in user

            put :modify, params: params

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq 'チェック文字がおかしいです。'
            expect(assigns(:finish_status)).to eq :wrong_check_character
          end
        end
      end

      context 'プランが間違っている場合' do
        context 'プラン番号が間違っている場合' do
          let(:new_plan)  { 1000 }

          it 'リダイレクトされること' do
            sign_in user

            put :modify, params: params

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(assigns(:finish_status)).to eq :wrong_plan
          end
        end

        context '変更ボタンが押されなかった場合' do
          let(:commit)  { 'aa' }

          it 'リダイレクトされること' do
            sign_in user

            put :modify, params: params

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(assigns(:finish_status)).to eq :wrong_plan
          end
        end
      end

      context '指定したユーザが存在しない場合' do
        let(:user_id)  { User.last.id + 1 }

        it 'リダイレクトされること' do
          sign_in user

          put :modify, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "ユーザ(#{user_id})が存在しません。"
          expect(assigns(:finish_status)).to eq :user_does_not_exist
        end
      end

      context '管理者を変更しようとした場合' do
        let(:user_id)  { user.id }

        it 'リダイレクトされること' do
          sign_in user

          put :modify, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "このユーザは変更できません。"
          expect(assigns(:finish_status)).to eq :can_not_change
        end
      end

      context 'パブリックユーザを変更しようとした場合' do
        let(:user_id)  { User.public_id }

        it 'リダイレクトされること' do
          sign_in user

          put :modify, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "このユーザは変更できません。"
          expect(assigns(:finish_status)).to eq :can_not_change
        end
      end

      context 'Billingを操作する場合' do
        let(:payment_method)  { Billing.payment_methods[:credit] }
        let(:ope_user)        { create(:user, billing_attrs: { payment_method: payment_method,
                                                               customer_id: nil,
                                                               subscription_id: nil})
                              }
        let!(:plan) { create(:billing_plan, name: master_test_light_plan.name, billing: ope_user.billing) }

        context 'createの場合' do
          let(:to_do)           { 'create' }
          let(:user_id)         { ope_user.id }
          let!(:plan)           { nil }
          let(:payment_method)  { nil }

          context 'ユーザがPAYJPに存在しない場合' do
            it '存在しないとメッセージが返ること' do

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由: PAYJPでユーザが見つかりません。/)
              expect(assigns(:finish_status)).to eq :normal_finish
            end
          end

          context 'ユーザがPAYJPに存在するが、billing保存に失敗した場合' do
            it '存在しないとメッセージが返ること' do
              card_token = Billing.create_dummy_card_token

              res = ope_user.billing.create_customer(card_token.id)
              ope_user.billing.create_subscription(EasySettings.payjp_plan_id[:test_light])

              allow_any_instance_of(Billing).to receive(:save).and_return( false )

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由:/)
              expect(flash[:alert]).not_to match(/PAYJPでユーザが見つかりません。/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:public]
              expect(ope_user.billing.status).to eq 'unpaid'
              expect(ope_user.billing.payment_method).to be_nil
              expect(ope_user.billing.customer_id).to be_nil
              expect(ope_user.billing.subscription_id).to be_nil
              expect(ope_user.billing.first_paid_at).to be_nil
              expect(ope_user.billing.expiration_date).to be_nil

              Payjp::Customer.retrieve(res.id).delete
            end
          end

          context '正常終了の場合' do
            let(:first_paid_at) { current_time }

            it '成功のメッセージが返ること' do

              card_token = Billing.create_dummy_card_token

              res = ope_user.billing.create_customer(card_token.id)
              res = ope_user.billing.create_subscription(EasySettings.payjp_plan_id[:test_light])

              Timecop.freeze(current_time)

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/変更に成功しました/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_light]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.payment_method).to eq 'credit'
              expect(ope_user.billing.customer_id).to eq res.customer
              expect(ope_user.billing.subscription_id).to eq res.id
              expect(ope_user.billing.first_paid_at).to eq current_time
              expect(ope_user.billing.expiration_date).to eq Time.zone.at(res.current_period_end)

              ope_user.billing.delete_customer

              Timecop.return
            end
          end
        end

        context 'upgradeの場合' do
          let(:to_do)     { 'upgrade' }
          let(:user_id)   { ope_user.id }

          context 'billing保存に失敗した場合' do
            it '変更失敗のメッセージが返ること' do
              allow_any_instance_of(Billing).to receive(:save).and_return( false )

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由:/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_light]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.last_plan).to be_nil
              expect(ope_user.billing.next_plan).to eq next_plan
              expect(ope_user.billing.last_paid_at).to eq last_paid_at
            end
          end

          context '正常終了の場合' do
            it '成功のメッセージが返ること' do
              Timecop.freeze(current_time)

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/変更に成功しました/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.last_plan).to eq EasySettings.plan[:test_light]
              expect(ope_user.billing.next_plan).to be_nil
              expect(ope_user.billing.last_paid_at).to eq current_time

              Timecop.return
            end
          end
        end

        context 'downgradeの場合' do
          let(:to_do)         { 'downgrade' }
          let(:user_id)       { ope_user.id }
          let(:ope_user_plan) { EasySettings.plan[:test_standard] }

          context 'billing保存に失敗した場合' do
            it '変更失敗のメッセージが返ること' do
              allow_any_instance_of(Billing).to receive(:save).and_return( false )

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由:/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.next_plan).to be_nil
            end
          end

          context '正常終了の場合' do
            it '成功のメッセージが返ること' do
              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/変更に成功しました/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.next_plan).to eq EasySettings.plan[:test_light]
            end
          end
        end

        context 'downgrade_nowの場合' do
          let(:to_do)           { 'downgrade_now' }
          let(:user_id)         { ope_user.id }
          let(:ope_user_plan)   { EasySettings.plan[:test_standard] }

          context 'billing保存に失敗した場合' do
            it '変更失敗のメッセージが返ること' do

              sign_in user

              meaningless = ope_user # 下記のスタブが入る前に作っておく

              allow_any_instance_of(Billing).to receive(:save!).and_return( false )

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由:/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.last_plan).to be_nil
              expect(ope_user.billing.next_plan).to eq EasySettings.plan[:test_light]
              expect(ope_user.billing.last_paid_at).to eq last_paid_at
            end
          end

          context 'next_planがnilの場合' do

            it '変更失敗のメッセージが返ること' do

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由:/)
              expect(flash[:alert]).to match(/次のプランが未定なので、即時ダウングレードできません。/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.last_plan).to be_nil
              expect(ope_user.billing.next_plan).to be_nil
              expect(ope_user.billing.last_paid_at).to eq last_paid_at
            end
          end

          context '正常終了の場合' do
            it '成功のメッセージが返ること' do
              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/変更に成功しました/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_light]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.last_plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.next_plan).to be_nil
              expect(ope_user.billing.last_paid_at).to eq expiration_date
            end
          end
        end

        context 'stopの場合' do
          let(:to_do)           { 'stop' }
          let(:user_id)         { ope_user.id }
          let(:ope_user_plan)   { EasySettings.plan[:test_standard] }
          let(:last_plan)       { nil }
          let(:next_plan)       { EasySettings.payjp_plan_id[:test_light] }
          let(:customer_id)     { 'cus_1111' }
          let(:subscription_id) { 'sub_1111' }
          let(:expiration_date) { Time.zone.now }

          context 'billingの保存に失敗した場合' do
            it '変更失敗のメッセージが返ること' do
              Timecop.freeze(current_time)

              create(:monthly_history, user: ope_user, plan: ope_user.billing.plan, search_count: 8, request_count: 5)

              allow_any_instance_of(Billing).to receive(:save).and_return( false )

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:alert]).to match(/変更に失敗しました。エラー理由:/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'paid'
              expect(ope_user.billing.payment_method).to eq 'credit'
              expect(ope_user.billing.last_plan).to be_nil
              expect(ope_user.billing.next_plan).to eq EasySettings.plan[:test_light]
              expect(ope_user.billing.customer_id).to eq 'cus_1111'
              expect(ope_user.billing.subscription_id).to eq 'sub_1111'
              expect(ope_user.billing.subscription_id).to eq 'sub_1111'
              expect(ope_user.billing.expiration_date).to eq Time.zone.now
              expect(MonthlyHistory.find_around(ope_user).reload.request_count).to eq 5
              expect(MonthlyHistory.find_around(ope_user).reload.search_count).to eq 8

              Timecop.return
            end
          end

          context '正常終了の場合' do
            it '成功のメッセージが返ること' do
              Timecop.freeze(current_time)

              create(:monthly_history, user: ope_user, plan: ope_user.billing.plan, search_count: 8, request_count: 5)

              sign_in user

              put :modify, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/変更に成功しました/)
              expect(assigns(:finish_status)).to eq :normal_finish

              # この手順が必要
              ope_user_id = ope_user.id
              ope_user    = User.find(ope_user_id)

              expect(ope_user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(ope_user.billing.status).to eq 'stop'
              expect(ope_user.billing.payment_method).to eq 'credit'
              expect(ope_user.billing.last_plan).to be_nil
              expect(ope_user.billing.next_plan).to be_nil
              expect(ope_user.billing.customer_id).to be_nil
              expect(ope_user.billing.subscription_id).to be_nil
              expect(ope_user.billing.expiration_date.iso8601).to eq Time.zone.now.end_of_day.iso8601 # 小数点以下の秒を比較されるとズレる
              expect(MonthlyHistory.find_around(ope_user).reload.request_count).to eq 5
              expect(MonthlyHistory.find_around(ope_user).reload.search_count).to eq 8

              Timecop.return
            end
          end
        end
      end
    end
  end

  describe 'PUT create_bank_transfer' do

    let(:payment_method)  { nil }
    let(:ope_user)        { create(:user, billing_attrs: { payment_method: payment_method}) }

    let(:check_str)      { 'gg' }
    let(:new_plan)       { EasySettings.plan[:test_light] }
    let(:target_email)   { ope_user.email }
    let(:date)           { (Time.zone.now + 2.months).strftime("%Y/%m/%d") }
    let(:payment_date)   { (Time.zone.now + 2.months).strftime("%Y/%m/%d") }
    let(:payment_amount) { 3_000 }
    let(:comment)        { '5ヶ月分' }
    let(:params)         { {str_check: check_str, new_plan: new_plan, email: target_email, expiration_date: date, additional_comment: comment} }
    let(:params_with_payment) { {str_check: check_str, new_plan: new_plan, email: target_email, expiration_date: date,
                                 payment_date: payment_date, payment_amount: payment_amount, additional_comment: comment} }

    before { Timecop.freeze(current_time) }

    after { Timecop.return }

    context '非ログインユーザの場合' do

      it '404になること' do
        put :create_bank_transfer, params: params

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context '管理者ではないユーザの場合' do
      let(:his_plan) { EasySettings.plan[:free] }

      it '404になること' do
        sign_in user

        put :create_bank_transfer, params: params

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context '管理者ユーザの場合' do
      let(:plan) { EasySettings.plan[:administrator] }

      context 'チェック文字列が間違っている場合' do
        context 'チェック文字列がゾロ目でない場合' do
          let(:check_str) { 'gr' }

          it 'リダイレクトされること' do
            sign_in admin

            put :create_bank_transfer, params: params

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq 'チェック文字がおかしいです。'
            expect(assigns(:finish_status)).to eq :wrong_check_character
          end
        end

        context 'チェック文字列が2文字でない場合' do
          let(:check_str) { 'gg3' }

          it 'リダイレクトされること' do
            sign_in admin

            put :create_bank_transfer, params: params

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq 'チェック文字がおかしいです。'
            expect(assigns(:finish_status)).to eq :wrong_check_character
          end
        end
      end

      context 'プランが間違っている場合' do
        let(:new_plan)  { 1000 }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(assigns(:finish_status)).to eq :wrong_plan
        end
      end

      context '指定したユーザが存在しない場合' do
        let(:target_email) { 'unexist@user.com' }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "ユーザ(#{target_email})が存在しません。"
          expect(assigns(:finish_status)).to eq :user_does_not_exist
        end
      end

      context '管理者を銀行振込対象にしようとした場合' do
        let(:target_email) { admin.email }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "このユーザは変更できません。"
          expect(assigns(:finish_status)).to eq :can_not_change
        end
      end

      context 'パブリックユーザを変更しようとした場合' do
        let(:target_email) { User.get_public.email }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "このユーザは変更できません。"
          expect(assigns(:finish_status)).to eq :can_not_change
        end
      end

      context '期限日の日付がおかしい場合' do
        let(:date)  { '203005' }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "有効期限がおかしいです。"
          expect(assigns(:finish_status)).to eq :strange_expiration_date
        end
      end

      context '入金日と入金金額のどちらかが空' do
        before do
          sign_in admin
          put :create_bank_transfer, params: params_with_payment
        end

        context '入金日が空' do
          let(:payment_date)  { nil }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path
            expect(flash[:alert]).to eq "入金日と入金金額は両方入力してください。もしくは、両方空欄にしてください。"
          end
        end

        context '入金金額が空' do
          let(:payment_amount)  { nil }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path
            expect(flash[:alert]).to eq "入金日と入金金額は両方入力してください。もしくは、両方空欄にしてください。"
          end
        end
      end

      context '入金日の日付がおかしい場合' do
        let(:payment_date)  { '203005' }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params_with_payment

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "入金日がおかしいです。"
        end
      end

      context '入金金額がおかしい場合' do
        let(:payment_amount)  { 'fgh' }

        it 'リダイレクトされること' do
          sign_in admin

          put :create_bank_transfer, params: params_with_payment

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to eq "入金金額は数値を入力してください。"
        end
      end

      describe 'set_bank_transfer_plan' do
        context '正常な場合' do
          context '入金日なし' do
            it '銀行振込ユーザになること' do
              sign_in admin

              plan_cnt = BillingPlan.count
              history_cnt = BillingHistory.count
              expect(ope_user.billing.plans).to be_blank

              put :create_bank_transfer, params: params

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/銀行振込ユーザを作成しました。/)

              ope_user.reload

              expect(ope_user.billing.payment_method).to eq 'bank_transfer'
              expect(ope_user.billing.customer_id).to be_nil
              expect(ope_user.billing.subscription_id).to be_nil

              expect(BillingPlan.count).to eq plan_cnt + 1
              expect(ope_user.billing.plans.size).to eq 1

              plan = ope_user.billing.plans[0]
              expect(plan.name).to eq master_test_light_plan.name
              expect(plan.status).to eq 'ongoing'
              expect(plan.price).to eq master_test_light_plan.price
              expect(plan.tax_included).to eq master_test_light_plan.tax_included
              expect(plan.type).to eq master_test_light_plan.type
              expect(plan.charge_date).to eq Time.zone.now.day.to_s
              expect(plan.start_at).to eq Time.zone.now.iso8601
              expect(plan.end_at).to eq Time.zone.parse(date).end_of_day.iso8601
              expect(plan.trial).to be_falsey
              expect(plan.next_charge_date).to eq Time.zone.today

              expect(BillingHistory.count).to eq history_cnt
              expect(ope_user.billing.histories.size).to eq 0
            end
          end

          context '入金日あり。コメントなし。' do
            let(:comment) { nil }

            it '銀行振込ユーザになること' do
              sign_in admin

              plan_cnt = BillingPlan.count
              history_cnt = BillingHistory.count
              expect(ope_user.billing.plans).to be_blank

              put :create_bank_transfer, params: params_with_payment

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/銀行振込ユーザを作成しました。/)

              ope_user.reload

              expect(ope_user.billing.payment_method).to eq 'bank_transfer'
              expect(ope_user.billing.customer_id).to be_nil
              expect(ope_user.billing.subscription_id).to be_nil

              expect(BillingPlan.count).to eq plan_cnt + 1
              expect(ope_user.billing.plans.size).to eq 1

              plan = ope_user.billing.plans[0]
              expect(plan.name).to eq master_test_light_plan.name
              expect(plan.status).to eq 'ongoing'
              expect(plan.price).to eq master_test_light_plan.price
              expect(plan.tax_included).to eq master_test_light_plan.tax_included
              expect(plan.type).to eq master_test_light_plan.type
              expect(plan.charge_date).to eq Time.zone.now.day.to_s
              expect(plan.start_at).to eq Time.zone.now.iso8601
              expect(plan.end_at).to eq Time.zone.parse(date).end_of_day.iso8601
              expect(plan.trial).to be_falsey
              expect(plan.next_charge_date).to eq Time.zone.today

              expect(BillingHistory.count).to eq history_cnt + 1
              expect(ope_user.billing.histories.size).to eq 1

              history = ope_user.billing.histories[0]
              expect(history.item_name).to eq plan.name
              expect(history.payment_method).to eq 'bank_transfer'
              expect(history.price).to eq payment_amount
              expect(history.billing_date).to eq Time.zone.parse(payment_date).to_date
              expect(history.unit_price).to eq payment_amount
              expect(history.number).to eq 1
            end
          end

          context '入金日あり。コメントあり。' do
            it '銀行振込ユーザになること' do
              sign_in admin

              plan_cnt = BillingPlan.count
              history_cnt = BillingHistory.count
              expect(ope_user.billing.plans).to be_blank

              put :create_bank_transfer, params: params_with_payment

              expect(response.status).to eq 302
              expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

              expect(flash[:notice]).to match(/銀行振込ユーザを作成しました。/)

              ope_user.reload

              expect(ope_user.billing.payment_method).to eq 'bank_transfer'
              expect(ope_user.billing.customer_id).to be_nil
              expect(ope_user.billing.subscription_id).to be_nil

              expect(BillingPlan.count).to eq plan_cnt + 1
              expect(ope_user.billing.plans.size).to eq 1

              plan = ope_user.billing.plans[0]
              expect(plan.name).to eq master_test_light_plan.name
              expect(plan.status).to eq 'ongoing'
              expect(plan.price).to eq master_test_light_plan.price
              expect(plan.tax_included).to eq master_test_light_plan.tax_included
              expect(plan.type).to eq master_test_light_plan.type
              expect(plan.charge_date).to eq Time.zone.now.day.to_s
              expect(plan.start_at).to eq Time.zone.now.iso8601
              expect(plan.end_at).to eq Time.zone.parse(date).end_of_day.iso8601
              expect(plan.trial).to be_falsey
              expect(plan.next_charge_date).to eq Time.zone.today

              expect(BillingHistory.count).to eq history_cnt + 1
              expect(ope_user.billing.histories.size).to eq 1

              history = ope_user.billing.histories[0]
              expect(history.item_name).to eq "#{plan.name} #{comment}"
              expect(history.payment_method).to eq 'bank_transfer'
              expect(history.price).to eq payment_amount
              expect(history.billing_date).to eq Time.zone.parse(payment_date).to_date
              expect(history.unit_price).to eq payment_amount
              expect(history.number).to eq 1
            end
          end
        end

        context '保存に失敗した場合' do
          context '入金日なし' do
            it '変更失敗のメッセージが返ること' do
              sign_in admin

              allow_any_instance_of(Billing).to receive(:update!).and_raise

              plan_cnt = BillingPlan.count
              history_cnt = BillingHistory.count
              expect(ope_user.billing.plans).to be_blank

              put :create_bank_transfer, params: params

              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path

              expect(flash[:alert]).to match(/エラーが発生しました。/)

              ope_user.reload

              expect(ope_user.billing.payment_method).to be_nil

              expect(BillingPlan.count).to eq plan_cnt
              expect(ope_user.billing.plans.size).to eq 0

              expect(BillingHistory.count).to eq history_cnt
              expect(ope_user.billing.histories.size).to eq 0
            end
          end

          context '入金日あり' do
            it '変更失敗のメッセージが返ること' do
              sign_in admin

              allow(BillingHistory).to receive(:create!).and_raise

              plan_cnt = BillingPlan.count
              history_cnt = BillingHistory.count
              expect(ope_user.billing.plans).to be_blank

              put :create_bank_transfer, params: params_with_payment

              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path

              expect(flash[:alert]).to match(/エラーが発生しました。/)

              ope_user.reload

              expect(ope_user.billing.payment_method).to be_nil

              expect(BillingPlan.count).to eq plan_cnt
              expect(ope_user.billing.plans.size).to eq 0

              expect(BillingHistory.count).to eq history_cnt
              expect(ope_user.billing.histories.size).to eq 0
            end
          end
        end
      end
    end
  end

  describe 'PUT continue_bank_transfer' do
    subject { put :continue_bank_transfer, params: params }

    let(:payment_method)  { :bank_transfer }
    let(:ope_user)        { create(:user, billing_attrs: { payment_method: payment_method}) }

    let(:check_str)      { '55' }
    let(:target_email)   { ope_user.email }
    let(:exp_date)       { Time.zone.now + 2.months }
    let(:exp_date_str)   { exp_date.strftime("%Y/%m/%d") }
    let(:payment_date)   { (Time.zone.now + 2.months).strftime("%Y/%m/%d") }
    let(:payment_amount) { 3_000 }
    let(:comment)        { '5ヶ月分' }
    let(:params) { params_without_payment }
    let(:params_without_payment) { {str_check: check_str, email: target_email, expiration_date: exp_date_str, additional_comment: comment} }
    let(:params_with_payment)    { {str_check: check_str, email: target_email, expiration_date: exp_date_str,
                                    payment_date: payment_date, payment_amount: payment_amount, additional_comment: comment} }
    let!(:plan) { create(:billing_plan, status: plan_status, start_at: start_at, end_at: end_at, billing: ope_user.billing) }
    let(:plan_status) { :ongoing }
    let(:start_at) { Time.zone.now - 2.month }
    let(:end_at)   { Time.zone.now + 1.month }

    context '非ログインユーザの場合' do

      it '404になること' do
        subject

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context 'ログインする場合' do
      context '管理者ではないユーザの場合' do
        let(:his_plan) { EasySettings.plan[:free] }

        it '404になること' do
          sign_in user
          subject

          expect(response.status).to eq 404
          expect(response).to render_template 'errors/error_404'

          expect(assigns(:finish_status)).to be_nil
        end
      end

      context '管理者ユーザの場合' do
        before do
          sign_in admin
          subject
        end

        context 'チェック文字列が間違っている場合' do
          context 'チェック文字列がゾロ目でない場合' do
            let(:check_str) { 'gr' }

            it 'リダイレクトされること' do
              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path

              expect(flash[:alert]).to eq 'チェック文字がおかしいです。'
              expect(assigns(:finish_status)).to eq :wrong_check_character
            end
          end

          context 'チェック文字列が2文字でない場合' do
            let(:check_str) { 'gg3' }

            it 'リダイレクトされること' do
              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path

              expect(flash[:alert]).to eq 'チェック文字がおかしいです。'
              expect(assigns(:finish_status)).to eq :wrong_check_character
            end
          end
        end

        context '指定したユーザが存在しない場合' do
          let(:target_email) { 'unexist@user.com' }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "ユーザ(#{target_email})が存在しません。"
            expect(assigns(:finish_status)).to eq :user_does_not_exist
          end
        end

        context '管理者を銀行振込対象にしようとした場合' do
          let(:target_email) { admin.email }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザは変更できません。"
            expect(assigns(:finish_status)).to eq :can_not_change
          end
        end

        context 'パブリックユーザを変更しようとした場合' do
          let(:target_email) { User.get_public.email }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザは変更できません。"
            expect(assigns(:finish_status)).to eq :can_not_change
          end
        end

        context '銀行振込ユーザではない時' do
          let(:payment_method)  { :credit }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザは銀行振込ユーザではありません。"
          end
        end

        context '銀行振込ユーザではない時' do
          let(:payment_method)  { :credit }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザは銀行振込ユーザではありません。"
          end
        end

        context 'ステータスが有効ではない時' do
          context 'ステータスがsoppedの時' do
            let(:plan_status) { :stopped }

            it 'リダイレクトされること' do
              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path

              expect(flash[:alert]).to eq "このユーザの銀行振込プランの有効期限は切れているか、ステータスが有効ではありません。"
            end
          end

          context 'ステータスがwaitingの時' do
            let(:plan_status) { :waiting }

            it 'リダイレクトされること' do
              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path

              expect(flash[:alert]).to eq "このユーザの銀行振込プランの有効期限は切れているか、ステータスが有効ではありません。"
            end
          end
        end

        context '期限が切れている時' do
          let(:end_at) { Time.zone.now - 1.minutes  }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザの銀行振込プランの有効期限は切れているか、ステータスが有効ではありません。"
          end
        end

        context '期限日の日付がおかしい場合' do
          let(:exp_date_str)  { '203005' }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "有効期限がおかしいです。"
            expect(assigns(:finish_status)).to eq :strange_expiration_date
          end
        end

        context '新しい有効期限が現在の有効期限より過去の時' do
          let(:exp_date) { Time.zone.now + 29.days }
          let(:end_at)   { Time.zone.now + 30.days  }

          it 'リダイレクトされること' do
            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "新しい有効期限が現在の有効期限より過去になっています。"
          end
        end

        context '入金日あり' do
          let(:params) { params_with_payment }

          context '入金日と入金金額のどちらかが空' do
            context '入金日が空' do
              let(:payment_date) { nil }

              it 'リダイレクトされること' do
                expect(response.status).to eq 302
                expect(response.location).to eq fallback_path
                expect(flash[:alert]).to eq "入金日と入金金額は両方入力してください。もしくは、両方空欄にしてください。"
              end
            end

            context '入金金額が空' do
              let(:payment_amount) { nil }

              it 'リダイレクトされること' do
                expect(response.status).to eq 302
                expect(response.location).to eq fallback_path
                expect(flash[:alert]).to eq "入金日と入金金額は両方入力してください。もしくは、両方空欄にしてください。"
              end
            end
          end

          context '入金日の日付がおかしい場合' do
            let(:payment_date) { '203005' }

            it 'リダイレクトされること' do
              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path
              expect(flash[:alert]).to eq "入金日がおかしいです。"
            end
          end

          context '入金金額がおかしい場合' do
            let(:payment_amount)  { 'fgh' }

            it 'リダイレクトされること' do
              expect(response.status).to eq 302
              expect(response.location).to eq fallback_path
              expect(flash[:alert]).to eq "入金金額は数値を入力してください。"
            end
          end
        end
      end
    end

    context '正常な場合' do
      before { sign_in admin }

      context '入金日なし' do
        it '銀行振込ユーザのend_atが延長されること' do

          plan_cnt = BillingPlan.count
          history_cnt = BillingHistory.count
          expect(ope_user.billing.plans).to be_present
          before_plan = ope_user.billing.plans[0].dup

          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

          expect(flash[:notice]).to eq '銀行振込を継続しました。'

          ope_user.reload

          expect(ope_user.billing.reload.payment_method).to eq 'bank_transfer'
          expect(ope_user.billing.customer_id).to be_nil
          expect(ope_user.billing.subscription_id).to be_nil

          expect(BillingPlan.count).to eq plan_cnt + 0
          expect(ope_user.billing.plans.reload.size).to eq 1

          plan = ope_user.billing.plans[0]
          expect(plan.name).to eq before_plan.name
          expect(plan.status).to eq 'ongoing'
          expect(plan.price).to eq before_plan.price
          expect(plan.tax_included).to eq before_plan.tax_included
          expect(plan.type).to eq before_plan.type
          expect(plan.charge_date).to eq before_plan.charge_date
          expect(plan.start_at).to eq before_plan.start_at
          expect(plan.end_at).not_to eq before_plan.end_at
          expect(plan.end_at).to eq exp_date.end_of_day.iso8601
          expect(plan.trial).to eq before_plan.trial
          expect(plan.next_charge_date).to eq before_plan.next_charge_date

          expect(BillingHistory.count).to eq history_cnt
          expect(ope_user.billing.histories.size).to eq 0
        end
      end

      context '入金日あり。コメントなし。' do
        let(:params) { params_with_payment }
        let(:comment) { nil }

        it '銀行振込ユーザのend_atが延長されること' do
          plan_cnt = BillingPlan.count
          history_cnt = BillingHistory.count
          expect(ope_user.billing.plans).to be_present
          before_plan = ope_user.billing.plans[0].dup

          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

          expect(flash[:notice]).to eq '銀行振込を継続しました。'

          ope_user.reload

          expect(ope_user.billing.reload.payment_method).to eq 'bank_transfer'
          expect(ope_user.billing.customer_id).to be_nil
          expect(ope_user.billing.subscription_id).to be_nil

          expect(BillingPlan.count).to eq plan_cnt + 0
          expect(ope_user.billing.plans.reload.size).to eq 1

          plan = ope_user.billing.plans[0]
          expect(plan.name).to eq before_plan.name
          expect(plan.status).to eq 'ongoing'
          expect(plan.price).to eq before_plan.price
          expect(plan.tax_included).to eq before_plan.tax_included
          expect(plan.type).to eq before_plan.type
          expect(plan.charge_date).to eq before_plan.charge_date
          expect(plan.start_at).to eq before_plan.start_at
          expect(plan.end_at).not_to eq before_plan.end_at
          expect(plan.end_at).to eq exp_date.end_of_day.iso8601
          expect(plan.trial).to eq before_plan.trial
          expect(plan.next_charge_date).to eq before_plan.next_charge_date

          expect(BillingHistory.count).to eq history_cnt + 1
          expect(ope_user.billing.histories.reload.size).to eq 1

          history = ope_user.billing.histories.reload[0]
          expect(history.item_name).to eq plan.name
          expect(history.payment_method).to eq 'bank_transfer'
          expect(history.price).to eq payment_amount
          expect(history.billing_date).to eq Time.zone.parse(payment_date).to_date
          expect(history.unit_price).to eq payment_amount
          expect(history.number).to eq 1
        end
      end

      context '入金日あり。コメントあり。' do
        let(:params) { params_with_payment }

        it '銀行振込ユーザのend_atが延長されること' do
          plan_cnt = BillingPlan.count
          history_cnt = BillingHistory.count
          expect(ope_user.billing.plans).to be_present
          before_plan = ope_user.billing.plans[0].dup

          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

          expect(flash[:notice]).to eq '銀行振込を継続しました。'

          ope_user.reload

          expect(ope_user.billing.reload.payment_method).to eq 'bank_transfer'
          expect(ope_user.billing.customer_id).to be_nil
          expect(ope_user.billing.subscription_id).to be_nil

          expect(BillingPlan.count).to eq plan_cnt + 0
          expect(ope_user.billing.plans.reload.size).to eq 1

          plan = ope_user.billing.plans[0]
          expect(plan.name).to eq before_plan.name
          expect(plan.status).to eq 'ongoing'
          expect(plan.price).to eq before_plan.price
          expect(plan.tax_included).to eq before_plan.tax_included
          expect(plan.type).to eq before_plan.type
          expect(plan.charge_date).to eq before_plan.charge_date
          expect(plan.start_at).to eq before_plan.start_at
          expect(plan.end_at).not_to eq before_plan.end_at
          expect(plan.end_at).to eq exp_date.end_of_day.iso8601
          expect(plan.trial).to eq before_plan.trial
          expect(plan.next_charge_date).to eq before_plan.next_charge_date

          expect(BillingHistory.count).to eq history_cnt + 1
          expect(ope_user.billing.histories.size).to eq 1

          history = ope_user.billing.histories.reload[0]
          expect(history.item_name).to eq "#{plan.name} #{comment}"
          expect(history.payment_method).to eq 'bank_transfer'
          expect(history.price).to eq payment_amount
          expect(history.billing_date).to eq Time.zone.parse(payment_date).to_date
          expect(history.unit_price).to eq payment_amount
          expect(history.number).to eq 1
        end
      end
    end

    context '保存に失敗した場合' do
      before { sign_in admin }

      context '入金日なし' do
        it '変更失敗のメッセージが返ること' do
          allow_any_instance_of(BillingPlan).to receive(:update!).and_raise

          plan_cnt = BillingPlan.count
          history_cnt = BillingHistory.count
          expect(ope_user.billing.plans).to be_present
          before_plan = ope_user.billing.plans[0].dup
          before_plan_updated_at = ope_user.billing.plans[0].updated_at.dup

          subject

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to match(/エラーが発生しました。/)

          ope_user.reload

          expect(ope_user.billing.payment_method).to eq 'bank_transfer'

          plan = ope_user.billing.plans.reload[0]
          expect(plan.name).to eq before_plan.name
          expect(plan.status).to eq 'ongoing'
          expect(plan.end_at).to eq before_plan.end_at
          expect(plan.updated_at).to eq before_plan_updated_at

          expect(BillingPlan.count).to eq plan_cnt
          expect(ope_user.billing.plans.size).to eq 1

          expect(BillingHistory.count).to eq history_cnt
          expect(ope_user.billing.histories.size).to eq 0
        end
      end

      context '入金日あり' do
        let(:params) { params_with_payment }

        it '変更失敗のメッセージが返ること' do
          allow(BillingHistory).to receive(:create!).and_raise

          plan_cnt = BillingPlan.count
          history_cnt = BillingHistory.count
          expect(ope_user.billing.plans).to be_present
          before_plan = ope_user.billing.plans[0].dup
          before_plan_updated_at = ope_user.billing.plans[0].updated_at.dup

          subject

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(flash[:alert]).to match(/エラーが発生しました。/)

          ope_user.reload

          expect(ope_user.billing.payment_method).to eq 'bank_transfer'

          plan = ope_user.billing.plans.reload[0]
          expect(plan.name).to eq before_plan.name
          expect(plan.status).to eq 'ongoing'
          expect(plan.end_at).to eq before_plan.end_at
          expect(plan.updated_at).to eq before_plan_updated_at

          expect(BillingPlan.count).to eq plan_cnt
          expect(ope_user.billing.plans.size).to eq 1

          expect(BillingHistory.count).to eq history_cnt
          expect(ope_user.billing.histories.size).to eq 0
        end
      end
    end
  end

  describe 'PUT create_invoice' do
    subject { put :create_invoice, params: params }

    let(:payment_method) { nil }
    let(:ope_user)       { create(:user, billing_attrs: { payment_method: payment_method}) }

    let(:new_plan)       { EasySettings.plan[:test_light] }
    let(:target_email)   { ope_user.email }
    let(:start_date)     { Time.zone.now + 5.days }
    let(:start_date_str) { start_date.strftime("%Y/%m/%d") }
    let(:params)         { {new_plan_for_invoice: new_plan, email_for_invoice: target_email, start_date_for_invoice: start_date_str} }

    context '非ログインユーザの場合' do

      it '404になること' do
        subject

        expect(response.status).to eq 404
        expect(response).to render_template 'errors/error_404'

        expect(assigns(:finish_status)).to be_nil
      end
    end

    context 'ログインする場合' do
      context '管理者ではないユーザの場合' do
        let(:his_plan) { EasySettings.plan[:free] }

        it '404になること' do
          sign_in user
          subject

          expect(response.status).to eq 404
          expect(response).to render_template 'errors/error_404'

          expect(assigns(:finish_status)).to be_nil
        end
      end

      context '管理者ユーザの場合' do
        before { sign_in admin }
        let(:plan) { EasySettings.plan[:administrator] }

        context 'プランが間違っている場合' do
          let(:new_plan) { 1000 }

          it 'リダイレクトされること' do
            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(assigns(:finish_status)).to eq :wrong_plan
          end
        end

        context '指定したユーザが存在しない場合' do
          let(:target_email) { 'unexist@user.com' }

          it 'リダイレクトされること' do
            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "ユーザ(#{target_email})が存在しません。"
            expect(assigns(:finish_status)).to eq :user_does_not_exist
          end
        end

        context '管理者を銀行振込対象にしようとした場合' do
          let(:target_email) { admin.email }

          it 'リダイレクトされること' do
            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザは変更できません。"
            expect(assigns(:finish_status)).to eq :can_not_change
          end
        end

        context 'パブリックユーザを変更しようとした場合' do
          let(:target_email) { User.get_public.email }

          it 'リダイレクトされること' do
            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "このユーザは変更できません。"
            expect(assigns(:finish_status)).to eq :can_not_change
          end
        end

        context '開始日の日付がおかしい場合' do
          let(:start_date_str) { '203005' }

          it 'リダイレクトされること' do
            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "開始日がおかしいです。"
            expect(assigns(:finish_status)).to eq :strange_start_date
          end
        end

        context '開始日が空の場合' do
          let(:start_date_str) { nil }

          it 'リダイレクトされること' do
            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to eq "開始日がおかしいです。"
            expect(assigns(:finish_status)).to eq :strange_start_date
          end
        end
      end

      context '正常な場合' do
        context '開始日が未来' do
          it '請求書払いユーザになること' do
            sign_in admin

            plan_cnt = BillingPlan.count
            history_cnt = BillingHistory.count
            expect(ope_user.billing.plans).to be_blank

            subject

            expect(response.status).to eq 302
            expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

            expect(flash[:notice]).to eq '請求書払いユーザを作成しました。'

            ope_user.reload

            expect(ope_user.billing.reload.payment_method).to eq 'invoice'
            expect(ope_user.billing.customer_id).to be_nil
            expect(ope_user.billing.subscription_id).to be_nil

            expect(BillingPlan.count).to eq plan_cnt + 1
            expect(ope_user.billing.plans.reload.size).to eq 1

            plan = ope_user.billing.plans[0]
            expect(plan.name).to eq master_test_light_plan.name
            expect(plan.status).to eq 'waiting'
            expect(plan.price).to eq master_test_light_plan.price
            expect(plan.tax_included).to eq master_test_light_plan.tax_included
            expect(plan.type).to eq master_test_light_plan.type
            expect(plan.charge_date).to eq start_date.day.to_s
            expect(plan.start_at).to eq start_date.beginning_of_day.iso8601
            expect(plan.end_at).to be_nil
            expect(plan.trial).to be_falsey
            expect(plan.next_charge_date).to eq start_date.to_date

            expect(BillingHistory.count).to eq history_cnt
            expect(ope_user.billing.histories.size).to eq 0
          end
        end

        context '開始日が過去' do
          let(:start_date) { Time.zone.now - 5.days }

          it '請求書払いユーザになること' do
            sign_in admin

            plan_cnt = BillingPlan.count
            history_cnt = BillingHistory.count
            expect(ope_user.billing.plans).to be_blank

            subject

            expect(response.status).to eq 302
            expect(response.location).to redirect_to admin_page_payments_path(user_id_or_email: ope_user.id)

            expect(flash[:notice]).to eq '請求書払いユーザを作成しました。'

            ope_user.reload

            expect(ope_user.billing.reload.payment_method).to eq 'invoice'
            expect(ope_user.billing.customer_id).to be_nil
            expect(ope_user.billing.subscription_id).to be_nil

            expect(BillingPlan.count).to eq plan_cnt + 1
            expect(ope_user.billing.plans.reload.size).to eq 1

            plan = ope_user.billing.plans[0]
            expect(plan.name).to eq master_test_light_plan.name
            expect(plan.status).to eq 'ongoing'
            expect(plan.price).to eq master_test_light_plan.price
            expect(plan.tax_included).to eq master_test_light_plan.tax_included
            expect(plan.type).to eq master_test_light_plan.type
            expect(plan.charge_date).to eq start_date.day.to_s
            expect(plan.start_at).to eq start_date.beginning_of_day.iso8601
            expect(plan.end_at).to be_nil
            expect(plan.trial).to be_falsey
            expect(plan.next_charge_date).to eq (start_date + 1.month).to_date

            # ヒストリーは作られない
            expect(BillingHistory.count).to eq history_cnt
            expect(ope_user.billing.histories.size).to eq 0
          end
        end
      end

      context '保存に失敗した場合' do
        context 'BillingPlanの保存で失敗' do
          it '変更失敗のメッセージが返ること' do
            sign_in admin

            allow_any_instance_of(BillingPlan).to receive(:save!).and_raise

            plan_cnt = BillingPlan.count
            history_cnt = BillingHistory.count
            expect(ope_user.billing.plans).to be_blank

            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to match(/エラーが発生しました。/)

            ope_user.reload

            expect(ope_user.billing.payment_method).to be_nil

            expect(BillingPlan.count).to eq plan_cnt
            expect(ope_user.billing.plans.size).to eq 0

            expect(BillingHistory.count).to eq history_cnt
            expect(ope_user.billing.histories.size).to eq 0
          end
        end

        context 'BillingPlanのupdateで失敗' do
          it '変更失敗のメッセージが返ること' do
            sign_in admin

            allow_any_instance_of(Billing).to receive(:update!).and_raise

            plan_cnt = BillingPlan.count
            history_cnt = BillingHistory.count
            expect(ope_user.billing.plans).to be_blank

            subject

            expect(response.status).to eq 302
            expect(response.location).to eq fallback_path

            expect(flash[:alert]).to match(/エラーが発生しました。/)

            ope_user.reload

            expect(ope_user.billing.payment_method).to be_nil

            expect(BillingPlan.count).to eq plan_cnt
            expect(ope_user.billing.plans.size).to eq 0

            expect(BillingHistory.count).to eq history_cnt
            expect(ope_user.billing.histories.size).to eq 0
          end
        end
      end
    end
  end

  describe 'GET edit' do
    subject { get :edit }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        subject
        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
      end
    end

    context '課金プランではないユーザの場合' do

      it 'リダイレクトされること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :not_trial_nor_paid_user
      end
    end

    context '課金プランではないユーザの場合' do
      let!(:plan) { create(:billing_plan, status: plan_status, start_at: start_at, end_at: end_at, billing: user.billing) }
      let(:plan_status) { :waiting }
      let(:start_at) { Time.zone.now.tomorrow }
      let(:end_at)   { Time.zone.now + 1.month }

      it 'リダイレクトされること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :not_trial_nor_paid_user
      end
    end

    context '課金ユーザの場合' do
      let!(:plan) { create(:billing_plan, status: plan_status, start_at: start_at, end_at: end_at, billing: user.billing) }
      let(:plan_status) { :ongoing }
      let(:start_at) { Time.zone.now - 2.month }
      let(:end_at)   { Time.zone.now + 1.month }

      after { user.billing.delete_customer }

      it 'リダイレクトされること' do
        register_card(user)

        sign_in user

        subject

        expect(response.status).to eq 200
        expect(response).to render_template :edit

        expect(assigns(:card)).to eq({ brand: 'Visa', last4: '4242' })
      end
    end

    context '紹介者トライアルユーザの場合' do
      let!(:plan) { create(:billing_plan, status: plan_status, start_at: start_at, end_at: end_at, billing: user.billing, trial: true) }
      let(:plan_status) { :ongoing }
      let(:start_at) { Time.zone.now - 2.month }
      let(:end_at)   { nil }

      after { user.billing.delete_customer }

      it 'リダイレクトされること' do
        register_card(user)

        sign_in user

        subject

        expect(response.status).to eq 200
        expect(response).to render_template :edit

        expect(assigns(:card)).to eq({ brand: 'Visa', last4: '4242' })
      end
    end
  end

  describe 'POST create_credit_subscription' do
    subject { post :create_credit_subscription, params: params }

    let(:email)          { "#{described_class.to_s.downcase}_#{Faker::Internet.email}" }
    let(:plan)           { EasySettings.plan[:free] }
    let(:plan2)          { EasySettings.plan[:test_light] }
    let(:password_param) { password }
    let(:status)         { Billing.statuses[:unpaid] }
    let(:token)          { Billing.create_dummy_card_token.id }
    let(:params)         { { plan: plan2, password_for_plan_registration: password_param, 'payjp-token' => token } }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        subject

        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
      end
    end

    context '指定したプランが間違っている場合' do
      let(:plan2) { 8888 }

      it 'リダイレクトされること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :wrong_plan
      end
    end

    context 'パスワードが間違っている場合' do
      let(:password_param) { 'fdafd129gds' }

      it 'リダイレクトされること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :wrong_password
      end
    end

    context 'PAYJPの顧客登録に失敗した場合' do
      after { user.billing.clean_customer_by_email }

      it 'エラーが返ってきた場合は、リダイレクトされること' do
        allow_any_instance_of(Billing).to receive(:create_customer).and_return( {'error' => {'status' => 402} } )

        sign_in user

        count = BillingPlan.count

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_customer_error

        expect(user.billing.reload.customer_id).to be_nil
        expect(user.billing.payment_method).to be_nil
        expect(user.billing.current_plans).to be_blank
        expect(user.expiration_date).to be_nil
        expect(BillingPlan.count).to eq count + 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:create_credit_subscription: PAYJP Make Customer Failure\]/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID\[#{user.id}\]/)
      end

      it 'エラーが発生した場合は、リダイレクトされること' do
        allow_any_instance_of(Billing).to receive(:create_customer).and_raise('Dummy Error')

        sign_in user

        count = BillingPlan.count

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_customer_error

        expect(user.billing.reload.customer_id).to be_nil
        expect(user.billing.payment_method).to be_nil
        expect(user.billing.current_plans).to be_blank
        expect(user.expiration_date).to be_nil
        expect(BillingPlan.count).to eq count + 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:create_credit_subscription: PAYJP Make Customer Failure\]/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID\[#{user.id}\]/)
      end
    end

    context 'プランレコード作成に失敗した場合' do
      after { user.billing.clean_customer_by_email }

      it 'リダイレクトされること。DBレコードは作成されない。' do
        allow_any_instance_of(Billing).to receive(:create_plan!).and_raise

        sign_in user

        count = BillingPlan.count

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_plan_error

        expect(user.billing.reload.customer_id).to be_nil
        expect(user.billing.payment_method).to be_nil
        expect(user.billing.current_plans).to be_blank
        expect(user.expiration_date).to be_nil
        expect(BillingPlan.count).to eq count + 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:create_credit_subscription: PAYJP Make Subscription Failure: Should Delete Customer、数日中にPAY.JPのカスタマーを削除してください。\]/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/USER_ID\[#{user.id}\]/)
      end

      it 'エラーが発生した場合は、リダイレクトされること。DBレコードは作成されない。' do
        allow_any_instance_of(Billing).to receive(:create_plan!).and_raise('Dummy Error')

        sign_in user

        count = BillingPlan.count

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_plan_error

        expect(user.billing.reload.customer_id).to be_nil
        expect(user.billing.payment_method).to be_nil
        expect(user.billing.current_plans).to be_blank
        expect(user.expiration_date).to be_nil
        expect(BillingPlan.count).to eq count + 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:create_credit_subscription: PAYJP Make Subscription Failure: Should Delete Customer、数日中にPAY.JPのカスタマーを削除してください。\]/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID\[#{user.id}\]/)
      end
    end

    context '課金に失敗した場合' do

      after { user.billing.clean_customer_by_email }

      it 'リダイレクトされること。DBレコードは作成されない。' do
        allow(Payjp::Charge).to receive(:create).and_return( {'error' => {'status' => 402} } )

        sign_in user

        count = BillingPlan.count

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_charge_error

        expect(user.billing.reload.customer_id).to be_nil
        expect(user.billing.payment_method).to be_nil
        expect(user.billing.current_plans).to be_blank
        expect(user.expiration_date).to be_nil
        expect(BillingPlan.count).to eq count + 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:create_credit_subscription: PAYJP Make Subscription Failure: Should Delete Customer、数日中にPAY.JPのカスタマーを削除してください。\]/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/USER_ID\[#{user.id}\]/)
      end
    end

    context '正常終了の場合' do
      after { user.billing.clean_customer_by_email }

      it 'billingに保存されること' do
        Timecop.freeze(current_time)

        sign_in user

        count = BillingPlan.count

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :normal_finish

        cus_info_res = user.billing.reload.get_customer_info

        expect(user.id.to_s).to eq cus_info_res.metadata.user_id
        expect(user.billing.customer_id).to be_present
        expect(user.billing.customer_id).to eq cus_info_res.id
        expect(user.email).to eq cus_info_res.email
        expect(user.company_name).to eq cus_info_res.metadata.company_name

        expect(user.billing.payment_method).to eq 'credit'

        plans = user.billing.current_plans
        expect(plans.size).to eq 1
        expect(plans[0].name).to eq master_test_light_plan.name
        expect(plans[0].status).to eq 'ongoing'
        expect(plans[0].price).to eq master_test_light_plan.price
        expect(plans[0].tax_included).to eq master_test_light_plan.tax_included
        expect(plans[0].tax_rate).to eq master_test_light_plan.tax_rate
        expect(plans[0].type).to eq master_test_light_plan.type
        expect(plans[0].charge_date).to eq Time.zone.now.day.to_s
        expect(plans[0].start_at).to eq Time.zone.now
        expect(plans[0].end_at).to be_nil
        expect(plans[0].trial).to be_falsey
        expect(plans[0].next_charge_date).to eq Time.zone.today.next_month
        expect(plans[0].last_charge_date).to eq Time.zone.today

        expect(BillingPlan.count).to eq count + 1

        expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day
        expect(user.expiration_date).to eq Time.zone.today.next_month.yesterday.end_of_day

        # 売上確認
        ch_info_res = user.billing.get_charges
        expect(ch_info_res['count']).to eq 1
        expect(ch_info_res['data'][0]['customer']).to eq user.billing.customer_id
        expect(ch_info_res['data'][0]['amount']).to eq master_test_light_plan.price
        expect(ch_info_res['data'][0]['object']).to eq 'charge'
        expect(ch_info_res['data'][0]['card']['id']).to eq user.billing.get_card_info['id']

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries.last.subject).to match(/有料プランへの登録が完了致しました。/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン登録が完了しました。/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン名: Rspecテスト ライトプラン/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/料金: 1,000円/)

        Timecop.return
      end
    end
  end

  xdescribe 'GET get_payment_info' do
    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        get :get_payment_info

        expect(response.status).to eq 200
        expect(response.body).to eq({ status: 400, reason: 'unlogin_user' }.to_json)
      end
    end

    context '課金ではないユーザの場合' do

      it 'リダイレクトされること' do
        sign_in user

        get :get_payment_info

        expect(response.status).to eq 200
        expect(response.body).to eq({ status: 400, reason: 'not trial_or_paid_user' }.to_json)
      end
    end

    context '課金ユーザの場合' do
      let(:plan)     { EasySettings.plan[:standard] }
      let(:status)   { Billing.statuses[:paid] }
      let(:new_plan) { EasySettings.plan[:standard] }
      let(:params)   { {plan: new_plan} }

      context '指定したプランが間違っている場合' do
        let(:new_plan)   { 8888 }

        it 'リダイレクトされること' do
          sign_in user

          post :get_payment_info

          expect(response.status).to eq 200
          expect(response.body).to eq({ status: 400, reason: 'wrong_plan' }.to_json)
        end
      end

      context 'プランをアップグレードする場合' do
        let(:diff_days)       { 5 }
        let(:expiration_date) { Time.zone.now + diff_days.days }
        let(:plan_name)       { :test_light }
        let(:plan)            { EasySettings.plan[plan_name] }
        let(:new_plan_name)   { :test_standard}
        let(:new_plan)        { EasySettings.plan[new_plan_name] }

        context '差額がある場合' do
          let(:diff_days) { 5 }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: price, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: diff_days}.to_json)
          end
        end

        context '差額がある場合' do
          let(:diff_days) { 31 }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: price, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: diff_days}.to_json)
          end
        end

        context '差額がある場合' do
          let(:diff_days) { 28 }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: price, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: diff_days}.to_json)
          end
        end

        context '差額がない場合' do
          let(:expiration_date) { Time.zone.now + 3.minutes }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: 0, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: 0}.to_json)
          end
        end
      end

      context 'プランをダウングレードする場合' do
        let(:diff_days)       { 3 }
        let(:expiration_date) { Time.zone.now + diff_days.days }
        let(:plan_name)       { :test_standard }
        let(:plan)            { EasySettings.plan[plan_name] }
        let(:new_plan_name)   { :test_light}
        let(:new_plan)        { EasySettings.plan[new_plan_name] }

        it '正しく値が戻ること' do
          sign_in user

          post :get_payment_info, params: params

          expect(response.status).to eq 200
          expect(response.body).to eq({ price: 0, new_price: EasySettings.amount[new_plan_name], diff_price: 0, reset_days: diff_days}.to_json)
        end
      end

      context 'プランが変わらない場合' do
        let(:plan_name)       { :test_light }
        let(:plan)            { EasySettings.plan[plan_name] }
        let(:new_plan_name)   { :test_light}
        let(:new_plan)        { EasySettings.plan[new_plan_name] }

        it '正しく値が戻ること' do
          sign_in user

          post :get_payment_info, params: params

          expect(response.status).to eq 200
          expect(response.body).to eq({ status: 400, reason: 'not_change' }.to_json)
        end
      end
    end

    context '紹介者トライアルユーザの場合' do
      let(:plan)     { EasySettings.plan[:standard] }
      let(:status)   { Billing.statuses[:trial] }
      let(:payment_method) { Billing.payment_methods[:credit] }
      let(:new_plan) { EasySettings.plan[:standard] }
      let(:first_paid_at)  { nil }
      let(:last_paid_at)   { nil }
      let(:params)   { {plan: new_plan} }

      context '指定したプランが間違っている場合' do
        let(:new_plan)   { 8888 }

        it 'リダイレクトされること' do
          sign_in user

          post :get_payment_info

          expect(response.status).to eq 200
          expect(response.body).to eq({ status: 400, reason: 'wrong_plan' }.to_json)
        end
      end

      context 'プランをアップグレードする場合' do
        let(:diff_days)       { 5 }
        let(:expiration_date) { Time.zone.now + diff_days.days }
        let(:plan_name)       { :test_light }
        let(:plan)            { EasySettings.plan[plan_name] }
        let(:new_plan_name)   { :test_standard}
        let(:new_plan)        { EasySettings.plan[new_plan_name] }

        context '差額がある場合' do
          let(:diff_days) { 5 }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: price, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: diff_days}.to_json)
          end
        end

        context '差額がある場合' do
          let(:diff_days) { 31 }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: price, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: diff_days}.to_json)
          end
        end

        context '差額がある場合' do
          let(:diff_days) { 28 }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: price, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: diff_days}.to_json)
          end
        end

        context '差額がない場合' do
          let(:expiration_date) { Time.zone.now + 3.minutes }
          it '正しく値が戻ること' do
            sign_in user

            post :get_payment_info, params: params

            expect(response.status).to eq 200
            diff_price = EasySettings.amount[new_plan_name]
            price      = ( diff_price / 31 ) * diff_days.floor
            expect(response.body).to eq({ price: 0, new_price: EasySettings.amount[new_plan_name], diff_price: diff_price, reset_days: 0}.to_json)
          end
        end
      end

      context 'プランをダウングレードする場合' do
        let(:diff_days)       { 3 }
        let(:expiration_date) { Time.zone.now + diff_days.days }
        let(:plan_name)       { :test_standard }
        let(:plan)            { EasySettings.plan[plan_name] }
        let(:new_plan_name)   { :test_light}
        let(:new_plan)        { EasySettings.plan[new_plan_name] }

        it '正しく値が戻ること' do
          sign_in user

          post :get_payment_info, params: params

          expect(response.status).to eq 200
          expect(response.body).to eq({ price: 0, new_price: EasySettings.amount[new_plan_name], diff_price: 0, reset_days: diff_days}.to_json)
        end
      end

      context 'プランが変わらない場合' do
        let(:plan_name)       { :test_light }
        let(:plan)            { EasySettings.plan[plan_name] }
        let(:new_plan_name)   { :test_light}
        let(:new_plan)        { EasySettings.plan[new_plan_name] }

        it '正しく値が戻ること' do
          sign_in user

          post :get_payment_info, params: params

          expect(response.status).to eq 200
          expect(response.body).to eq({ status: 400, reason: 'not_change' }.to_json)
        end
      end
    end
  end

  describe 'DELETE stop_credit_subscription' do
    subject { delete :stop_credit_subscription, params: params }

    let(:email)    { "#{described_class.to_s.downcase}_#{Faker::Internet.email}" }
    let(:password) { "#{SecureRandom.alphanumeric(10)}A2" }
    let!(:user) { create(:user, email: email, password: password, billing_attrs: { payment_method: payment_method, customer_id: nil, subscription_id: nil }) }

    let(:password_param)   { password }
    let(:params)           { {password_for_plan_stop: password_param} }
    let(:payment_method)   { :credit }
    let!(:monthly_history) { create(:monthly_history, user: user, plan: his_plan, start_at: Time.zone.now - 15.days, end_at: Time.zone.now + 15.days) }

    let!(:plan) { create(:billing_plan, name: master_test_standard_plan.name, status: plan_status, charge_date: next_charge_date.day.to_s, start_at: start_at, end_at: end_at, next_charge_date: next_charge_date, trial: trial, billing: user.billing) }
    let(:plan_status) { :ongoing }
    let(:start_at) { Time.zone.now - 2.month }
    let(:end_at)   { nil }
    let(:next_charge_date) { Time.zone.tomorrow }
    let(:trial) { false }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        subject

        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
      end
    end

    context '課金ではないユーザの場合' do
      let!(:plan) { nil }

      it 'リダイレクトされること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :not_trial_nor_paid_user
      end
    end

    context '課金ユーザの場合' do

      before do
        register_card(user)
      end

      after { user.billing.clean_customer_by_email }

      context 'パスワードが間違っている場合' do
        let(:password_param) { 'abcdefg' }

        it 'リダイレクトされること' do
          sign_in user

          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          subject

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_password
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          # 顧客レコードが残っていること
          cus_info_res = user.billing.get_customer_info
          expect(cus_info_res.id).to eq user.billing.customer_id
          expect(cus_info_res.email).to eq user.email
          expect(cus_info_res.metadata.user_id).to eq user.id.to_s
          expect(cus_info_res.metadata.company_name).to eq user.company_name

          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

          expect(ActionMailer::Base.deliveries.size).to eq(0)
        end
      end

      context '課金の更新日の当日の場合' do
        before { user.billing.current_plans[0].update!(next_charge_date: Time.zone.today) }

        it 'リダイレクトされること' do
          sign_in user

          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          subject

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :unstoppable
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})
          expect(flash[:alert]).to eq '課金の更新日が過ぎているため、今の時間は停止できません。申し訳ありませんが、課金の更新処理が完了するまでお待ちください。更新処理は1日以内に完了する予定です。'

          # 顧客レコードが残っていること
          cus_info_res = user.billing.get_customer_info
          expect(cus_info_res.id).to eq user.billing.customer_id
          expect(cus_info_res.email).to eq user.email
          expect(cus_info_res.metadata.user_id).to eq user.id.to_s
          expect(cus_info_res.metadata.company_name).to eq user.company_name

          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

          expect(ActionMailer::Base.deliveries.size).to eq(0)
        end
      end

      context 'PAYJPの顧客削除に失敗した場合' do
        context 'payjpからエラーが返って来た時' do
          before { allow_any_instance_of(Payjp::Customer).to receive(:delete).and_return( {'error' => true} ) }

          it 'DBは更新されないこと。' do
            sign_in user

            monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
            monthly_history_end_at = MonthlyHistory.get_last(user).end_at

            subject
            allow_any_instance_of(Payjp::Customer).to receive(:delete).and_call_original # すぐに戻す

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :delete_customer_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})
            expect(flash[:alert]).to match(/課金停止に失敗しました。お手数ですが、お問い合わせよりお問い合わせお願い致します。/)

            # 顧客レコードが残っていること
            cus_info_res = user.billing.get_customer_info
            expect(cus_info_res.id).to eq user.billing.customer_id
            expect(cus_info_res.email).to eq user.email
            expect(cus_info_res.metadata.user_id).to eq user.id.to_s
            expect(cus_info_res.metadata.company_name).to eq user.company_name

            expect(user.billing.reload.customer_id).to be_present
            expect(user.billing.current_plans[0].end_at).to be_nil
            expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
            expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要緊急対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:stop_credit_subscription: PAYJP Delete Customer Failure 即時に調査と対応をしてください。\]/)
          end
        end

        context 'エラーが発生した時' do
          before { allow_any_instance_of(Payjp::Customer).to receive(:delete).and_raise('Dummy Error') }

          it 'DBは更新されないこと。' do
            sign_in user

            monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
            monthly_history_end_at = MonthlyHistory.get_last(user).end_at

            subject
            allow_any_instance_of(Payjp::Customer).to receive(:delete).and_call_original # すぐに戻す

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :delete_customer_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            expect(flash[:alert]).to match(/課金停止に失敗しました。お手数ですが、お問い合わせよりお問い合わせお願い致します。/)

            # 顧客レコードが残っていること
            cus_info_res = user.billing.get_customer_info
            expect(cus_info_res.id).to eq user.billing.customer_id
            expect(cus_info_res.email).to eq user.email
            expect(cus_info_res.metadata.user_id).to eq user.id.to_s
            expect(cus_info_res.metadata.company_name).to eq user.company_name

            expect(user.billing.reload.customer_id).to be_present
            expect(user.billing.current_plans[0].end_at).to be_nil
            expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
            expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要緊急対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:stop_credit_subscription: PAYJP Delete Customer Failure 即時に調査と対応をしてください。\]/)
          end
        end
      end

      context 'billingの保存に失敗した場合' do
        before { allow_any_instance_of(MonthlyHistory).to receive(:update!).and_raise('Dummy Error' ) }

        it 'billingに保存されていないこと' do
          sign_in user

          customer_id = user.billing.customer_id
          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          expect(user.reload.billing.current_plans[0].end_at).to be_nil
          expect(user.expiration_date).to eq user.billing.current_plans[0].next_charge_date.yesterday.end_of_day

          subject

          expect(response.status).to eq 302
          # expect(response.location).to render_template :edit
          expect(response).to redirect_to('http://test.host/users/edit')
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})
          expect(assigns(:finish_status)).to eq :normal_finish
          expect(flash[:notice]).to eq Message.const[:subscription_stop_done]

          user.reload

          # 顧客のレコードが残っていないこと
          cus_info_res = nil
          begin
            10.times do |i|
              sleep 1
              cus_info_res = Billing.get_customer_info(customer_id)
              break if cus_info_res.include?('No such customer')
            end
          rescue => e
            cus_info_res = e.message
          end

          expect(cus_info_res).to eq "No such customer: #{customer_id}"

          # レコードが変わっていないこと
          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at
          expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day

          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:stop_credit_subscription: Billing Save Failure 2,3日の間に調査と対応をしてください。\]/)

          expect(ActionMailer::Base.deliveries.last.subject).to match(/有料プランの定期更新を停止致しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン名: Rspecテスト スタンダードプラン/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/有効期限: #{user.expiration_date&.strftime("%Y年%-m月%-d日")}/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)
        end
      end

      context '正常終了の場合' do
        context '有効期限が本日の時' do
          let(:next_charge_date) { Time.zone.tomorrow }

          it 'PAYJPから削除されていること。保存されていること' do
            Timecop.freeze(current_time)

            sign_in user

            customer_id = user.billing.customer_id

            monthly_history_end_at = MonthlyHistory.get_last(user).end_at.dup

            expect(user.reload.billing.current_plans[0].end_at).to be_nil
            expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day

            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to('http://test.host/users/edit')
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(flash[:notice]).to eq Message.const[:subscription_stop_done]

            expect(user.billing.reload.customer_id).to be_nil
            expect(user.reload.billing.current_plans[0].end_at).to be_present
            expect(MonthlyHistory.find_around(user).end_at).to eq user.billing.current_plans[0].end_at
            expect(MonthlyHistory.find_around(user).end_at).not_to eq monthly_history_end_at
            expect(user.expiration_date.iso8601).to eq user.billing.current_plans[0].end_at.iso8601

            expect(user.billing.reload.payment_method).to eq 'credit'

            # 顧客のレコードが残っていないこと
            cus_info_res = nil
            begin
              10.times do |i|
                sleep 1
                cus_info_res = Billing.get_customer_info(customer_id)
                break if cus_info_res.include?('No such customer')
              end
            rescue => e
              cus_info_res = e.message
            end

            expect(cus_info_res).to eq "No such customer: #{customer_id}"

            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランの定期更新を停止致しました。/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限: #{user.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)

            Timecop.return
          end
        end

        context '有効期限が2週間後の時' do
          let(:next_charge_date) { Time.zone.today + 14.days }

          it 'PAYJPから削除されていること。保存されていること' do
            Timecop.freeze(current_time)

            sign_in user

            customer_id = user.billing.customer_id

            monthly_history_end_at = MonthlyHistory.get_last(user).end_at.dup

            expect(user.reload.billing.current_plans[0].end_at).to be_nil
            expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day

            subject

            expect(response.status).to eq 302
            expect(response).to redirect_to('http://test.host/users/edit')
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(flash[:notice]).to eq Message.const[:subscription_stop_done]

            expect(user.billing.reload.customer_id).to be_nil
            expect(user.reload.billing.current_plans[0].end_at).to be_present
            expect(MonthlyHistory.find_around(user).end_at).to eq user.billing.current_plans[0].end_at
            expect(MonthlyHistory.find_around(user).end_at).not_to eq monthly_history_end_at
            expect(user.expiration_date.iso8601).to eq user.billing.current_plans[0].end_at.iso8601

            expect(user.billing.reload.payment_method).to eq 'credit'

            # 顧客のレコードが残っていないこと
            cus_info_res = nil
            begin
              10.times do |i|
                sleep 1
                cus_info_res = Billing.get_customer_info(customer_id)
                break if cus_info_res.include?('No such customer')
              end
            rescue => e
              cus_info_res = e.message
            end

            expect(cus_info_res).to eq "No such customer: #{customer_id}"

            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランの定期更新を停止致しました。/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限: #{user.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
            expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)

            Timecop.return
          end
        end
      end
    end

    context '紹介者トライアルユーザの場合' do
      let(:trial) { true }

      context 'パスワードが間違っている場合' do
        let(:password_param) { 'abcdefg' }

        it 'リダイレクトされること' do
          register_card(user)

          sign_in user

          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          subject

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_password
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          # 顧客レコードが残っていること
          cus_info_res = user.billing.get_customer_info
          expect(cus_info_res.id).to eq user.billing.customer_id
          expect(cus_info_res.email).to eq user.email
          expect(cus_info_res.metadata.user_id).to eq user.id.to_s
          expect(cus_info_res.metadata.company_name).to eq user.company_name

          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

          expect(ActionMailer::Base.deliveries.size).to eq(0)
        end
      end

      context 'PAYJPの顧客削除に失敗した場合' do
        let(:plan_name) { :test_standard }

        it 'エラーが返ってきた場合は、リダイレクトされること' do
          register_card(user)

          allow_any_instance_of(Payjp::Customer).to receive(:delete).and_return( {'error' => true} )

          sign_in user

          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          subject

          expect(response.status).to eq 500
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :delete_customer_failure
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          cus_info_res = user.billing.get_customer_info

          expect(cus_info_res.id).to eq user.billing.customer_id
          expect(cus_info_res.email).to eq user.email
          expect(cus_info_res.metadata.user_id).to eq user.id.to_s
          expect(cus_info_res.metadata.company_name).to eq user.company_name

          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要緊急対応/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:stop_credit_subscription: PAYJP Delete Customer Failure 即時に調査と対応をしてください。\]/)

          user.billing.delete_customer
        end

        it 'エラーが発生した場合は、リダイレクトされること' do
          register_card(user)
          register_subscription(user, plan_name)

          allow_any_instance_of(Payjp::Customer).to receive(:delete).and_raise('Dummy Error')

          sign_in user

          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          subject

          expect(response.status).to eq 500
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :delete_customer_failure
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          cus_info_res = user.billing.get_customer_info

          expect(cus_info_res.id).to eq user.billing.customer_id
          expect(cus_info_res.email).to eq user.email
          expect(cus_info_res.metadata.user_id).to eq user.id.to_s
          expect(cus_info_res.metadata.company_name).to eq user.company_name

          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要緊急対応/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:stop_credit_subscription: PAYJP Delete Customer Failure 即時に調査と対応をしてください。\]/)

          allow_any_instance_of(Payjp::Customer).to receive(:delete).and_call_original

          user.billing.delete_customer
        end
      end

      context 'billingの保存に失敗した場合' do
        let(:plan_name) { :test_standard }

        before { allow_any_instance_of(MonthlyHistory).to receive(:update!).and_raise('Dummy Error' ) }

        it 'billingに保存されていないこと' do
          Timecop.freeze(current_time)

          register_card(user)

          sign_in user

          customer_id = user.billing.customer_id
          monthly_history_updated_at = MonthlyHistory.get_last(user).updated_at
          monthly_history_end_at = MonthlyHistory.get_last(user).end_at

          expect(user.reload.billing.current_plans[0].end_at).to be_nil
          expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day

          subject

          expect(response.status).to eq 302
          # expect(response.location).to render_template :edit
          expect(response).to redirect_to('http://test.host/users/edit')
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})
          expect(assigns(:finish_status)).to eq :normal_finish
          expect(flash[:notice]).to eq Message.const[:subscription_stop_done]

          user.reload

          # 顧客のレコードが残っていないこと
          cus_info_res = nil
          begin
            10.times do |i|
              sleep 1
              cus_info_res = Billing.get_customer_info(customer_id)
              break if cus_info_res.include?('No such customer')
            end
          rescue => e
            cus_info_res = e.message
          end

          expect(cus_info_res).to eq "No such customer: #{customer_id}"

          # レコードが変わっていないこと
          expect(user.billing.reload.payment_method).to eq 'credit'
          expect(user.billing.reload.customer_id).to be_present
          expect(user.billing.current_plans[0].end_at).to be_nil
          expect(MonthlyHistory.get_last(user).end_at).to eq monthly_history_end_at
          expect(MonthlyHistory.get_last(user).updated_at).to eq monthly_history_updated_at
          expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day

          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:stop_credit_subscription: Billing Save Failure 2,3日の間に調査と対応をしてください。\]/)

          expect(ActionMailer::Base.deliveries.last.subject).to match(/有料プランの定期更新を停止致しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン名: Rspecテスト スタンダードプラン/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/有効期限: #{user.reload.expiration_date&.strftime("%Y年%-m月%-d日")}/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)

          Timecop.return
        end
      end

      context '正常終了の場合' do
        let(:plan_name) { :test_standard }

        it 'PAYJPから削除されていること。保存されていること' do
          Timecop.freeze(current_time)

          register_card(user)

          sign_in user

          customer_id = user.billing.customer_id

          monthly_history_end_at = MonthlyHistory.get_last(user).end_at.dup

          expect(user.reload.billing.current_plans[0].end_at).to be_nil
          expect(user.expiration_date).to eq user.reload.billing.current_plans[0].next_charge_date.yesterday.end_of_day

          subject

          expect(response.status).to eq 302
          expect(response).to redirect_to('http://test.host/users/edit')
          expect(assigns(:finish_status)).to eq :normal_finish
          expect(flash[:notice]).to eq Message.const[:subscription_stop_done]

          expect(user.billing.reload.customer_id).to be_nil
          expect(user.reload.billing.current_plans[0].end_at).to be_present
          expect(MonthlyHistory.find_around(user).end_at).to eq user.billing.current_plans[0].end_at
          expect(MonthlyHistory.find_around(user).end_at).not_to eq monthly_history_end_at
          expect(user.expiration_date.iso8601).to eq user.billing.current_plans[0].end_at.iso8601

          expect(user.billing.reload.payment_method).to eq 'credit'

          # 顧客のレコードが残っていないこと
          cus_info_res = nil
          begin
            10.times do |i|
              sleep 1
              cus_info_res = Billing.get_customer_info(customer_id)
              break if cus_info_res.include?('No such customer')
            end
          rescue => e
            cus_info_res = e.message
          end

          expect(cus_info_res).to eq "No such customer: #{customer_id}"

          expect(ActionMailer::Base.deliveries.size).to eq(1)
          expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランの定期更新を停止致しました。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト スタンダードプラン/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限: #{user.expiration_date&.strftime("%Y年%-m月%-d日")}/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)

          Timecop.return
        end
      end
    end
  end

  describe 'PUT update_card' do
    subject { put :update_card, params: params }

    let!(:user) { create(:user, email: email, password: password, role: :general_user, billing_attrs: { payment_method: :credit,
                                                                                                        customer_id: nil,
                                                                                                        subscription_id: nil})
                }

    let(:email)            { "#{described_class.to_s.downcase}_#{Faker::Internet.email}" }
    let(:password_param)   { password }
    let!(:monthly_history) { create(:monthly_history, user: user, plan: his_plan, start_at: Time.zone.now - 15.days, end_at: Time.zone.now + 15.days) }

    let!(:plan) { create(:billing_plan, name: master_test_standard_plan.name, status: plan_status, charge_date: next_charge_date.day.to_s, start_at: start_at, end_at: end_at, next_charge_date: next_charge_date, trial: trial, billing: user.billing) }
    let(:plan_status) { :ongoing }
    let(:start_at) { Time.zone.now - 2.month }
    let(:end_at)   { nil }
    let(:next_charge_date) { Time.zone.tomorrow }
    let(:trial) { false }

    after { user.billing.clean_customer_by_email }

    let(:token)  { Billing.create_dummy_card_token('5555555555554444').id }
      let(:params) { {password_for_card_change: password_param, 'payjp-token' => token } }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        subject

        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
        # expect(response.location).to eq fallback_path

        # expect(assigns(:finish_status)).to eq :unlogin_user
      end
    end

    context '課金ではないユーザの場合' do
      let!(:plan) { nil }

      it 'リダイレクトされること' do
        sign_in user

        subject

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :not_trial_nor_paid_user
      end
    end

    context '課金ユーザの場合' do
      context 'パスワードが間違っている場合' do
        let(:password_param) { 'abcdefg' }

        it 'リダイレクトされること' do
          before_card = register_card(user)

          sign_in user

          subject

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_password
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          # カードが変更されていないこと
          card = user.billing.get_card_info
          expect(card.last4).to eq '4242'
          expect(card.id).to eq before_card.card.id
        end
      end

      context 'PAYJPのカード情報取得に失敗した場合' do
        let(:params) { {password_for_card_change: password_param } }

        it 'エラーが返ってきた場合は、リダイレクトされること' do
          before_card = register_card(user)

          allow_any_instance_of(Payjp::ListObject).to receive(:retrieve).and_return( {'error' => true} )

          sign_in user

          subject

          expect(response.status).to eq 500
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :get_card_info_failure

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update_card: Get Card Info Failure\]/)

          allow_any_instance_of(Payjp::ListObject).to receive(:retrieve).and_call_original

          # カードが変更されていないこと
          card = user.billing.get_card_info
          expect(card.last4).to eq '4242'
          expect(card.id).to eq before_card.card.id
        end

        it 'エラーが発生した場合は、リダイレクトされること' do
          before_card = register_card(user)

          allow_any_instance_of(Payjp::ListObject).to receive(:retrieve).and_raise('Dummy Error')
          allow_any_instance_of(PaymentsController).to receive(:get_card_info).and_return( nil )

          sign_in user

          subject

          expect(response.status).to eq 500
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :get_card_info_failure

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update_card: Get Card Info Failure\]/)
        
          allow_any_instance_of(Payjp::ListObject).to receive(:retrieve).and_call_original

          # カードが変更されていないこと
          card = user.billing.get_card_info
          expect(card.last4).to eq '4242'
          expect(card.id).to eq before_card.card.id
        end
      end

      context 'PAYJPのカード作成に失敗した場合' do

        it 'エラーが返ってきた場合は、リダイレクトされること' do
          before_card = register_card(user)

          allow_any_instance_of(Payjp::ListObject).to receive(:create).and_return( {'error' => true} )

          sign_in user

          subject

          expect(response.status).to eq 500
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :create_card_failure
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          allow_any_instance_of(Payjp::ListObject).to receive(:retrieve).and_call_original

          expect(user.billing.get_card_count).to eq 1
          card = user.billing.get_card_info
          expect(card['last4']).to eq '4242'
          expect(card['brand']).to eq 'Visa'

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update_card: Create Card Failure\]/)
        end

        it 'エラーが発生した場合は、リダイレクトされること' do
          before_card = register_card(user)

          allow_any_instance_of(Payjp::ListObject).to receive(:create).and_raise('Dummy Error')

          sign_in user

          subject

          expect(response.status).to eq 500
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :create_card_failure
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          allow_any_instance_of(Payjp::ListObject).to receive(:retrieve).and_call_original

          expect(user.billing.get_card_count).to eq 1
          card = user.billing.get_card_info
          expect(card['last4']).to eq '4242'
          expect(card['brand']).to eq 'Visa'

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update_card: Create Card Failure\]/)
        end
      end

      context 'PAYJPのカード削除に失敗した場合' do

        it 'エラーが返ってきた場合は、リダイレクトされること' do
          register_card(user)

          allow_any_instance_of(Payjp::Card).to receive(:delete).and_return( {'error' => true} )

          sign_in user

          subject

          expect(response.status).to eq 200
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :normal_finish
          expect(assigns(:card)).to eq({brand: 'MasterCard', last4: '4444'})

          expect(user.billing.get_card_count).to eq 2
          card = user.billing.get_card_info
          expect(card['last4']).to eq '4444'
          expect(card['brand']).to eq 'MasterCard'
          card = user.billing.get_card_info(2)
          expect(card['last4']).to eq '4242'
          expect(card['brand']).to eq 'Visa'

          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update_card: Delete Card Failure\]/)

          expect(ActionMailer::Base.deliveries.last.subject).to match(/クレジットカード情報を変更しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/クレジットカード情報を更新致しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/カードブランド: MasterCard/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/カード番号下４桁: 4444/)
        end

        it 'エラーが発生した場合は、リダイレクトされること' do
          register_card(user)

          allow_any_instance_of(Payjp::Card).to receive(:delete).and_raise('Dummy Error')

          sign_in user

          subject

          expect(response.status).to eq 200
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :normal_finish
          expect(assigns(:card)).to eq({brand: 'MasterCard', last4: '4444'})

          expect(user.billing.get_card_count).to eq 2
          card = user.billing.get_card_info
          expect(card['last4']).to eq '4444'
          expect(card['brand']).to eq 'MasterCard'
          card = user.billing.get_card_info(2)
          expect(card['last4']).to eq '4242'
          expect(card['brand']).to eq 'Visa'

          expect(ActionMailer::Base.deliveries.size).to eq(3)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update_card: Delete Card Failure\]/)

          expect(ActionMailer::Base.deliveries.last.subject).to match(/クレジットカード情報を変更しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/クレジットカード情報を更新致しました。/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/カードブランド: MasterCard/)
          expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/カード番号下４桁: 4444/)
        end
      end

      context '正常終了の場合' do

        it 'カードが切り替わること' do
          register_card(user)

          sign_in user

          subject

          expect(response.status).to eq 200
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :normal_finish
          expect(assigns(:card)).to eq({brand: 'MasterCard', last4: '4444'})

          expect(user.billing.get_card_count).to eq 1
          card = user.billing.get_card_info
          expect(card['last4']).to eq '4444'
          expect(card['brand']).to eq 'MasterCard'

          expect(ActionMailer::Base.deliveries.size).to eq(1)
          expect(ActionMailer::Base.deliveries.first.subject).to match(/クレジットカード情報を変更しました。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/クレジットカード情報を更新致しました。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カードブランド: MasterCard/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カード番号下４桁: 4444/)
        end
      end
    end

    context '紹介者トライアルユーザの場合' do
      let(:trial) { true }

      context '正常終了の場合' do

        it 'カードが切り替わること' do
          register_card(user)

          sign_in user

          subject

          expect(response.status).to eq 200
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :normal_finish
          expect(assigns(:card)).to eq({brand: 'MasterCard', last4: '4444'})
          expect(flash[:notice]).to eq Message.const[:card_update_success]

          expect(user.billing.current_plans.reload[0].trial).to eq true

          expect(user.billing.get_card_count).to eq 1
          card = user.billing.get_card_info
          expect(card['last4']).to eq '4444'
          expect(card['brand']).to eq 'MasterCard'

          expect(ActionMailer::Base.deliveries.size).to eq(1)
          expect(ActionMailer::Base.deliveries.first.subject).to match(/クレジットカード情報を変更しました。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/クレジットカード情報を更新致しました。/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カードブランド: MasterCard/)
          expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カード番号下４桁: 4444/)
        end
      end
    end
  end
end

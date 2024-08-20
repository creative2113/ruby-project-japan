require 'rails_helper'

RSpec.describe PaymentsController, type: :controller do
  before { create_public_user }
  let(:password)        { "#{SecureRandom.alphanumeric(10)}A2" }
  let(:fallback_path)   { 'http://test.host/' }
  let(:plan)            { EasySettings.plan[:public] }
  let(:status)          { Billing.statuses[:unpaid] }
  let(:payment_method)  { nil }
  let(:last_plan)       { nil }
  let(:next_plan)       { nil }
  let(:last_paid_at)    { Time.zone.now }
  let(:expiration_date) { Time.zone.now + 1.month }
  let(:first_paid_at)   { Time.zone.now }
  let(:user)            { create(:user, password: password, billing_attrs: { plan: plan,
                                                                             status: status,
                                                                             payment_method: payment_method,
                                                                             last_plan: last_plan,
                                                                             next_plan: next_plan,
                                                                             last_paid_at: last_paid_at,
                                                                             first_paid_at: first_paid_at,
                                                                             expiration_date: expiration_date })
                        }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
    create(:allow_ip, :admin, user: user)
  end

  after { ActionMailer::Base.deliveries.clear }

  xdescribe 'PUT update' do
    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        put :update

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :unlogin_user
      end
    end

    context '課金ではないユーザの場合' do

      it 'リダイレクトされること' do
        sign_in user

        put :update

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :not_trial_nor_paid_user
      end
    end

    context '課金ユーザの場合' do
      let(:password_param) { password }
      let(:plan)           { EasySettings.plan[:test_light] }
      let(:status)         { Billing.statuses[:paid] }
      let(:payment_method) { Billing.payment_methods[:credit] }
      let(:new_plan)       { EasySettings.plan[:test_standard] }
      let(:params)         { { plan: new_plan, password_for_plan_change: password_param } }

      context '指定したプランが間違っている場合' do
        let(:new_plan)   { 8888 }

        it 'リダイレクトされること' do
          register_card(user)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_plan
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          user.billing.delete_customer
        end
      end

      context 'パスワードが間違っている場合' do
        let(:password_param) { 'fdafd129gds' }

        it 'リダイレクトされること' do
          register_card(user)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_password
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          user.billing.delete_customer
        end
      end

      describe 'プランのアップグレードに関して' do
        let(:plan_name)     { :test_light }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_standard }
        let(:new_plan)      { EasySettings.plan[new_plan_name] }

        context 'PAYJPの定期課金のプランの変更に失敗した場合' do

          it 'エラーが返ってきた場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_return( {'error' => true} )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :upgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Upgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end

          it 'エラーが発生した場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_raise('Dummy Error')

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :upgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Upgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end
        end

        context '次回課金更新日と本日の日差分がない場合' do
          let(:last_plan)    { 2 }
          let(:last_paid_at) { fix_time(Time.zone.now - 10.day) }
          it 'billingアップデートが失敗した場合、billingが変更されていないこと、メールが飛ぶこと' do
            Timecop.freeze(current_time)

            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Billing).to receive(:save).and_return( false )
            allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( 0 )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 200
            expect(response.location).to render_template :edit
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            # この手順が必要
            user_id = user.id
            user    = User.find(user_id)

            expect(user.billing.plan).to eq EasySettings.plan[:test_light]
            expect(user.billing.last_plan).to eq 2
            expect(user.billing.next_plan).to be_nil
            expect(user.billing.last_paid_at).to eq last_paid_at

            expect(user.billing.status).to eq 'paid'
            expect(user.billing.customer_id).to eq sub_create_res.customer
            expect(user.billing.subscription_id).to eq sub_create_res.id
            expect(user.billing.first_paid_at).to eq current_time
            expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

            expect(ActionMailer::Base.deliveries.size).to eq(3)
            expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要緊急対応/)
            expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥0: New plan: #{new_plan}\]/)

            expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金:/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

            user.billing.delete_customer

            Timecop.return
          end
        end

        context '次回課金更新日と本日の日差分がある場合' do
          let(:last_plan)    { 2 }
          let(:last_paid_at) { fix_time(Time.zone.now - 10.day) }

          context 'PAYJPのプラン差額の課金に失敗した場合' do
            let(:diff_days)    { 5 }
            let(:diff_amount)  { ( (EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]) / 31 ) * diff_days.floor }

            context 'Billingアップデートが失敗した場合' do

              it 'エラーが返ってきて、billingが変更されていないこと、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:save).and_return( false )
                allow_any_instance_of(Billing).to receive(:create_charge).and_return( {'error' => true} )
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.last_plan).to eq 2
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq last_paid_at

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

                expect(ActionMailer::Base.deliveries.size).to eq(5)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries[3].subject).to match(/エラー発生　要緊急対応/)
                expect(ActionMailer::Base.deliveries[3].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)


                user.billing.delete_customer

                Timecop.return
              end

              it 'エラーが発生して、billingアップデートが失敗した場合、billingが変更されていないこと、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:save).and_return( false )
                allow_any_instance_of(Billing).to receive(:create_charge).and_raise('Dummy Error')
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.last_plan).to eq 2
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq last_paid_at

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


                expect(ActionMailer::Base.deliveries.size).to eq(5)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries[3].subject).to match(/エラー発生　要緊急対応/)
                expect(ActionMailer::Base.deliveries[3].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end
            end

            context 'Billingアップデートが成功した場合' do
              let(:diff_days)    { 14 }
              let(:diff_amount)  { ( (EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]) / 31 ) * diff_days.floor }

              it 'PAYJPからエラーが返ってきた場合、billingが変更されていること、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:create_charge).and_return( {'error' => true} )
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
                expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq current_time

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


                expect(ActionMailer::Base.deliveries.size).to eq(3)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end

              it 'PAYJPでエラーが発生した場合、billingが変更されていること、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:create_charge).and_raise('Dummy Error')
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
                expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq current_time

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

                expect(ActionMailer::Base.deliveries.size).to eq(3)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end
            end
          end

          context 'PAYJPのプラン差額の課金に成功した場合' do

            context 'Billingアップデートが失敗した場合' do
              let(:diff_days)    { 8 }
              let(:diff_amount)  { ( (EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]) / 31 ) * diff_days.floor }

              it 'エラーが返ってきて、billingが変更されていないこと、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:save).and_return( false )
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.last_plan).to eq 2
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq last_paid_at

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).to eq user.billing.customer_id
                expect(cha_info_res.amount).to eq diff_amount
                expect(cha_info_res.currency).to eq 'jpy'

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


                expect(ActionMailer::Base.deliveries.size).to eq(3)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要緊急対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end
            end
          end
        end

        context '正常終了の場合' do
          context '次回課金更新日と本日の日差分がない場合' do
            let(:last_plan)    { 4 }
            let(:last_paid_at) { fix_time(Time.zone.now - 10.day) }
            it '成功し、editページに遷移すること、billingが変更されていること' do
              Timecop.freeze(current_time)

              register_card(user)
              sub_create_res = register_subscription(user, plan_name)

              allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( 0 )

              sign_in user

              put :update, params: params

              expect(response.status).to eq 200
              expect(response.location).to render_template :edit
              expect(assigns(:finish_status)).to eq :normal_finish
              expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

              # この手順が必要
              user_id = user.id
              user    = User.find(user_id)

              expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
              expect(user.billing.next_plan).to be_nil
              expect(user.billing.last_paid_at).to eq current_time

              expect(user.billing.status).to eq 'paid'
              expect(user.billing.customer_id).to eq sub_create_res.customer
              expect(user.billing.subscription_id).to eq sub_create_res.id
              expect(user.billing.first_paid_at).to eq current_time
              expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

              cha_info_res = Billing.get_last_charge_data

              expect(cha_info_res.customer).not_to eq user.billing.customer_id

              sub_info_res = user.billing.get_subscription_info

              expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
              expect(sub_info_res.object).to eq 'subscription'
              expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

              expect(ActionMailer::Base.deliveries.size).to eq(1)
              expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金:/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

              user.billing.delete_customer

              Timecop.return
            end
          end

          context '次回課金更新日と本日の日差分がある場合' do
            let(:diff_days)    { 13 }
            let(:diff_amount)  { ( (EasySettings.amount[new_plan_name] - EasySettings.amount[plan_name]) / 31 ) * diff_days.floor }
            let(:last_plan)    { 10 }
            let(:last_paid_at) { fix_time(Time.zone.now - 10.day) }
            it '成功し、editページに遷移すること、billingが変更されていること' do
              Timecop.freeze(current_time)

              register_card(user)
              sub_create_res = register_subscription(user, plan_name)

              allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

              sign_in user

              put :update, params: params

              expect(response.status).to eq 200
              expect(response.location).to render_template :edit
              expect(assigns(:finish_status)).to eq :normal_finish
              expect(assigns(:price_this_time)).to eq diff_amount
              expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

              # この手順が必要
              user_id = user.id
              user    = User.find(user_id)

              expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
              expect(user.billing.next_plan).to be_nil
              expect(user.billing.last_paid_at).to eq current_time

              expect(user.billing.status).to eq 'paid'
              expect(user.billing.customer_id).to eq sub_create_res.customer
              expect(user.billing.subscription_id).to eq sub_create_res.id
              expect(user.billing.first_paid_at).to eq current_time
              expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

              cha_info_res = Billing.get_last_charge_data

              expect(cha_info_res.customer).to eq user.billing.customer_id
              expect(cha_info_res.amount).to eq diff_amount
              expect(cha_info_res.currency).to eq 'jpy'

              sub_info_res = user.billing.get_subscription_info

              expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
              expect(sub_info_res.object).to eq 'subscription'
              expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

              expect(ActionMailer::Base.deliveries.size).to eq(1)
              expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

              user.billing.delete_customer

              Timecop.return
            end
          end
        end
      end

      describe 'プランダウングレードに関して' do
        let(:plan_name)     { :test_standard }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_light}
        let(:new_plan)      { EasySettings.plan[new_plan_name] }
        let(:last_plan)     { 2 }
        let(:last_paid_at)  { fix_time(Time.zone.now - 10.day) }

        context 'PAYJPの定期課金のプランの変更に失敗した場合' do

          it 'エラーが返ってきた場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_return( {'error' => true} )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :downgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Downgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end

          it 'エラーが発生した場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_raise('Dummy Error')

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :downgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Downgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end
        end

        context '次回プランの設定に失敗した場合' do
          it 'billingが変更されていないこと、メールが飛ぶこと' do
            Timecop.freeze(current_time)

            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Billing).to receive(:save).and_return( false )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 200
            expect(response.location).to render_template :edit
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            # この手順が必要
            user_id = user.id
            user    = User.find(user_id)

            expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
            expect(user.billing.last_plan).to eq 2
            expect(user.billing.next_plan).to be_nil
            expect(user.billing.last_paid_at).to eq last_paid_at

            expect(user.billing.status).to eq 'paid'
            expect(user.billing.customer_id).to eq sub_create_res.customer
            expect(user.billing.subscription_id).to eq sub_create_res.id
            expect(user.billing.first_paid_at).to eq current_time
            expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]


            expect(ActionMailer::Base.deliveries.size).to eq(3)
            expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Downgrade Save Failure: New plan: #{new_plan}\]/)

            expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト ライトプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: 0円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 1,000円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

            user.billing.delete_customer

            Timecop.return
          end
        end

        context '正常終了の場合' do
          let(:last_plan)    { 10 }
          let(:last_paid_at) { fix_time(Time.zone.now - 10.day) }
          it '成功し、editページに遷移すること、billingが変更されていること' do
            Timecop.freeze(current_time)

            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            sign_in user

            put :update, params: params

            expect(response.status).to eq 200
            expect(response.location).to render_template :edit
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            # この手順が必要
            user_id = user.id
            user    = User.find(user_id)

            expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
            expect(user.billing.last_plan).to eq 10
            expect(user.billing.next_plan).to eq EasySettings.plan[:test_light]
            expect(user.billing.last_paid_at).to eq last_paid_at

            expect(user.billing.status).to eq 'paid'
            expect(user.billing.customer_id).to eq sub_create_res.customer
            expect(user.billing.subscription_id).to eq sub_create_res.id
            expect(user.billing.first_paid_at).to eq current_time
            expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]

            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト ライトプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: 0円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 1,000円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

            user.billing.delete_customer

            Timecop.return
          end

        end
      end # describe プランダウングレードに関して

      context '同じプランの場合' do
        let(:plan_name)     { :test_standard }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_standard}
        let(:new_plan)      { EasySettings.plan[new_plan_name] }
        let(:last_plan)     { 2 }
        let(:last_paid_at)  { fix_time(Time.zone.now - 10.day) }

        it '変更がないこと' do
          Timecop.freeze(current_time)

          register_card(user)
          sub_create_res = register_subscription(user, plan_name)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit
          expect(assigns(:finish_status)).to eq :same_plan
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          # この手順が必要
          user_id = user.id
          user    = User.find(user_id)

          expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
          expect(user.billing.last_plan).to eq 2
          expect(user.billing.next_plan).to be_nil
          expect(user.billing.last_paid_at).to eq last_paid_at

          expect(user.billing.status).to eq 'paid'
          expect(user.billing.customer_id).to eq sub_create_res.customer
          expect(user.billing.subscription_id).to eq sub_create_res.id
          expect(user.billing.first_paid_at).to eq current_time
          expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

          cha_info_res = Billing.get_last_charge_data

          expect(cha_info_res.customer).not_to eq user.billing.customer_id

          sub_info_res = user.billing.get_subscription_info

          expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
          expect(sub_info_res.object).to eq 'subscription'
          expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

          expect(ActionMailer::Base.deliveries.size).to eq(0)

          user.billing.delete_customer

          Timecop.return
        end
      end
    end

    context 'トライアルユーザの場合' do
      let(:password_param) { password }
      let(:plan)           { EasySettings.plan[:test_light] }
      let(:status)         { Billing.statuses[:trial] }
      let(:payment_method) { Billing.payment_methods[:credit] }
      let(:new_plan)       { EasySettings.plan[:test_standard] }
      let(:first_paid_at)  { nil }
      let(:last_paid_at)   { nil }
      let(:params)         { { plan: new_plan, password_for_plan_change: password_param } }

      context '指定したプランが間違っている場合' do
        let(:new_plan)   { 8888 }

        it 'リダイレクトされること' do
          register_card(user)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_plan
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          user.billing.delete_customer
        end
      end

      context 'パスワードが間違っている場合' do
        let(:password_param) { 'fdafd129gds' }

        it 'リダイレクトされること' do
          register_card(user)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :wrong_password
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          user.billing.delete_customer
        end
      end

      describe 'プランのアップグレードに関して' do
        let(:plan_name)     { :test_light }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_standard }
        let(:new_plan)      { EasySettings.plan[new_plan_name] }

        context 'PAYJPの定期課金のプランの変更に失敗した場合' do

          it 'エラーが返ってきた場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_return( {'error' => true} )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :upgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Upgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end

          it 'エラーが発生した場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_raise('Dummy Error')

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :upgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Upgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end
        end

        context '次回課金更新日と本日の日差分がない場合' do

          it 'billingアップデートが失敗した場合、billingが変更されていないこと、メールが飛ぶこと' do
            Timecop.freeze(current_time)

            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Billing).to receive(:save).and_return( false )
            allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( 0 )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 200
            expect(response.location).to render_template :edit
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            # この手順が必要
            user.reload
            user.billing.reload

            expect(user.billing.plan).to eq EasySettings.plan[:test_light]
            expect(user.billing.last_plan).to be_nil
            expect(user.billing.next_plan).to be_nil
            expect(user.billing.last_paid_at).to be_nil

            expect(user.billing.status).to eq 'trial'
            expect(user.billing.customer_id).to eq sub_create_res.customer
            expect(user.billing.subscription_id).to eq sub_create_res.id
            expect(user.billing.first_paid_at).to be_nil
            expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

            expect(ActionMailer::Base.deliveries.size).to eq(3)
            expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要緊急対応/)
            expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥0: New plan: #{new_plan}\]/)

            expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金:/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

            user.billing.delete_customer

            Timecop.return
          end
        end

        context '次回課金更新日と本日の日差分がある場合' do

          context 'PAYJPのプラン差額の課金に失敗した場合' do
            let(:diff_days)    { 5 }
            let(:diff_amount)  { ( EasySettings.amount[new_plan_name] / 31 ) * diff_days.floor }

            context 'Billingアップデートが失敗した場合' do

              it 'エラーが返ってきて、billingが変更されていないこと、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:save).and_return( false )
                allow_any_instance_of(Billing).to receive(:create_charge).and_return( {'error' => true} )
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user.reload
                user.billing.reload

                expect(user.billing.plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.last_plan).to be_nil
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to be_nil

                expect(user.billing.status).to eq 'trial'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to be_nil
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

                expect(ActionMailer::Base.deliveries.size).to eq(5)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries[3].subject).to match(/エラー発生　要緊急対応/)
                expect(ActionMailer::Base.deliveries[3].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)


                user.billing.delete_customer

                Timecop.return
              end

              it 'エラーが発生して、billingアップデートが失敗した場合、billingが変更されていないこと、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:save).and_return( false )
                allow_any_instance_of(Billing).to receive(:create_charge).and_raise('Dummy Error')
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.last_plan).to be_nil
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to be_nil

                expect(user.billing.status).to eq 'trial'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to be_nil
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


                expect(ActionMailer::Base.deliveries.size).to eq(5)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries[3].subject).to match(/エラー発生　要緊急対応/)
                expect(ActionMailer::Base.deliveries[3].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end
            end

            context 'Billingアップデートが成功した場合' do
              let(:diff_days)    { 14 }
              let(:diff_amount)  { ( EasySettings.amount[new_plan_name] / 31 ) * diff_days.floor }

              it 'PAYJPからエラーが返ってきた場合、billingが変更されていること、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:create_charge).and_return( {'error' => true} )
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
                expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq current_time

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


                expect(ActionMailer::Base.deliveries.size).to eq(3)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end

              it 'PAYJPでエラーが発生した場合、billingが変更されていること、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:create_charge).and_raise('Dummy Error')
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
                expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to eq current_time

                expect(user.billing.status).to eq 'paid'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to eq current_time
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).not_to eq user.billing.customer_id

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

                expect(ActionMailer::Base.deliveries.size).to eq(3)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Create Charge Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end
            end
          end

          context 'PAYJPのプラン差額の課金に成功した場合' do

            context 'Billingアップデートが失敗した場合' do
              let(:diff_days)    { 8 }
              let(:diff_amount)  { ( EasySettings.amount[new_plan_name] / 31 ) * diff_days.floor }

              it 'エラーが返ってきて、billingが変更されていないこと、メールが飛ぶこと' do
                Timecop.freeze(current_time)

                register_card(user)
                sub_create_res = register_subscription(user, plan_name)

                allow_any_instance_of(Billing).to receive(:save).and_return( false )
                allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

                sign_in user

                put :update, params: params

                expect(response.status).to eq 200
                expect(response.location).to render_template :edit
                expect(assigns(:finish_status)).to eq :normal_finish
                expect(assigns(:price_this_time)).to eq diff_amount
                expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

                # この手順が必要
                user_id = user.id
                user    = User.find(user_id)

                expect(user.billing.plan).to eq EasySettings.plan[:test_light]
                expect(user.billing.last_plan).to be_nil
                expect(user.billing.next_plan).to be_nil
                expect(user.billing.last_paid_at).to be_nil

                expect(user.billing.status).to eq 'trial'
                expect(user.billing.customer_id).to eq sub_create_res.customer
                expect(user.billing.subscription_id).to eq sub_create_res.id
                expect(user.billing.first_paid_at).to be_nil
                expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

                cha_info_res = Billing.get_last_charge_data

                expect(cha_info_res.customer).to eq user.billing.customer_id
                expect(cha_info_res.amount).to eq diff_amount
                expect(cha_info_res.currency).to eq 'jpy'

                sub_info_res = user.billing.get_subscription_info

                expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
                expect(sub_info_res.object).to eq 'subscription'
                expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


                expect(ActionMailer::Base.deliveries.size).to eq(3)
                expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要緊急対応/)
                expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Upgrade Save Failure: Price: ¥#{diff_amount}: New plan: #{new_plan}\]/)

                expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
                expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

                user.billing.delete_customer

                Timecop.return
              end
            end
          end
        end

        context '正常終了の場合' do
          context '次回課金更新日と本日の日差分がない場合' do

            it '成功し、editページに遷移すること、billingが変更されていること' do
              Timecop.freeze(current_time)

              register_card(user)
              sub_create_res = register_subscription(user, plan_name)

              allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( 0 )

              sign_in user

              put :update, params: params

              expect(response.status).to eq 200
              expect(response.location).to render_template :edit
              expect(assigns(:finish_status)).to eq :normal_finish
              expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

              # この手順が必要
              user_id = user.id
              user    = User.find(user_id)

              expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
              expect(user.billing.next_plan).to be_nil
              expect(user.billing.last_paid_at).to eq current_time

              expect(user.billing.status).to eq 'paid'
              expect(user.billing.customer_id).to eq sub_create_res.customer
              expect(user.billing.subscription_id).to eq sub_create_res.id
              expect(user.billing.first_paid_at).to eq current_time
              expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

              cha_info_res = Billing.get_last_charge_data

              expect(cha_info_res.customer).not_to eq user.billing.customer_id

              sub_info_res = user.billing.get_subscription_info

              expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
              expect(sub_info_res.object).to eq 'subscription'
              expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

              expect(ActionMailer::Base.deliveries.size).to eq(1)
              expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金:/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

              user.billing.delete_customer

              Timecop.return
            end
          end

          context '次回課金更新日と本日の日差分がある場合' do
            let(:diff_days)    { 13 }
            let(:diff_amount)  { ( EasySettings.amount[new_plan_name] / 31 ) * diff_days.floor }

            it '成功し、editページに遷移すること、billingが変更されていること' do
              Timecop.freeze(current_time)

              register_card(user)
              sub_create_res = register_subscription(user, plan_name)

              allow_any_instance_of(PaymentsController).to receive(:difference_of_date).and_return( diff_days )

              sign_in user

              put :update, params: params

              expect(response.status).to eq 200
              expect(response.location).to render_template :edit
              expect(assigns(:finish_status)).to eq :normal_finish
              expect(assigns(:price_this_time)).to eq diff_amount
              expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

              # この手順が必要
              user_id = user.id
              user    = User.find(user_id)

              expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
              expect(user.billing.last_plan).to eq EasySettings.plan[:test_light]
              expect(user.billing.next_plan).to be_nil
              expect(user.billing.last_paid_at).to eq current_time

              expect(user.billing.status).to eq 'paid'
              expect(user.billing.customer_id).to eq sub_create_res.customer
              expect(user.billing.subscription_id).to eq sub_create_res.id
              expect(user.billing.first_paid_at).to eq current_time
              expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

              cha_info_res = Billing.get_last_charge_data

              expect(cha_info_res.customer).to eq user.billing.customer_id
              expect(cha_info_res.amount).to eq diff_amount
              expect(cha_info_res.currency).to eq 'jpy'

              sub_info_res = user.billing.get_subscription_info

              expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
              expect(sub_info_res.object).to eq 'subscription'
              expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

              expect(ActionMailer::Base.deliveries.size).to eq(1)
              expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト ライトプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: #{diff_amount.to_s(:delimited)}円/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 3,000円/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
              expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

              user.billing.delete_customer

              Timecop.return
            end
          end
        end
      end

      describe 'プランダウングレードに関して' do
        let(:plan_name)     { :test_standard }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_light}
        let(:new_plan)      { EasySettings.plan[new_plan_name] }

        it 'トライアルユーザはダウングレードできない' do
          register_card(user)
          sub_create_res = register_subscription(user, plan_name)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit

          expect(assigns(:finish_status)).to eq :downgrade_for_trial
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})
          expect(flash[:alert]).to eq Message.const[:bad_request]

          expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
          expect(user.billing.last_plan).to be_nil
          expect(user.billing.next_plan).to be_nil
          expect(user.billing.last_paid_at).to be_nil

          expect(user.billing.status).to eq 'trial'
          expect(user.billing.customer_id).to eq sub_create_res.customer
          expect(user.billing.subscription_id).to eq sub_create_res.id
          expect(user.billing.first_paid_at).to be_nil
          expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)


          sub_info_res = user.billing.get_subscription_info

          expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
          expect(sub_info_res.object).to eq 'subscription'
          expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]


          expect(ActionMailer::Base.deliveries.size).to eq(0)

          user.billing.delete_customer
        end
      end

      xdescribe 'プランダウングレードに関して' do
        let(:plan_name)     { :test_standard }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_light}
        let(:new_plan)      { EasySettings.plan[new_plan_name] }

        context 'PAYJPの定期課金のプランの変更に失敗した場合' do

          it 'エラーが返ってきた場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_return( {'error' => true} )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :downgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Downgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end

          it 'エラーが発生した場合は、リダイレクトされること' do
            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Payjp::Subscription).to receive(:save).and_raise('Dummy Error')

            sign_in user

            put :update, params: params

            expect(response.status).to eq 500
            expect(response.location).to render_template :edit

            expect(assigns(:finish_status)).to eq :downgrade_change_subscription_failure
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: PAYJP Change Downgrade Subscription Failure: New plan: #{new_plan}\]/)

            user.billing.delete_customer
          end
        end

        context '次回プランの設定に失敗した場合' do
          it 'billingが変更されていないこと、メールが飛ぶこと' do
            Timecop.freeze(current_time)

            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            allow_any_instance_of(Billing).to receive(:save).and_return( false )

            sign_in user

            put :update, params: params

            expect(response.status).to eq 200
            expect(response.location).to render_template :edit
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            # この手順が必要
            user_id = user.id
            user    = User.find(user_id)

            expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
            expect(user.billing.last_plan).to be_nil
            expect(user.billing.next_plan).to be_nil
            expect(user.billing.last_paid_at).to be_nil

            expect(user.billing.status).to eq 'trial'
            expect(user.billing.customer_id).to eq sub_create_res.customer
            expect(user.billing.subscription_id).to eq sub_create_res.id
            expect(user.billing.first_paid_at).to be_nil
            expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]


            expect(ActionMailer::Base.deliveries.size).to eq(3)
            expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
            expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[PaymentsController:update: Downgrade Save Failure: New plan: #{new_plan}\]/)

            expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト ライトプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: 0円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 1,000円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

            user.billing.delete_customer

            Timecop.return
          end
        end

        context '正常終了の場合' do
          it '成功し、editページに遷移すること、billingが変更されていること' do
            Timecop.freeze(current_time)

            register_card(user)
            sub_create_res = register_subscription(user, plan_name)

            sign_in user

            put :update, params: params

            expect(response.status).to eq 200
            expect(response.location).to render_template :edit
            expect(assigns(:finish_status)).to eq :normal_finish
            expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

            # この手順が必要
            user_id = user.id
            user    = User.find(user_id)

            expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
            expect(user.billing.last_plan).to eq 10
            expect(user.billing.next_plan).to eq EasySettings.plan[:test_light]
            expect(user.billing.last_paid_at).to be_nil

            expect(user.billing.status).to eq 'paid'
            expect(user.billing.customer_id).to eq sub_create_res.customer
            expect(user.billing.subscription_id).to eq sub_create_res.id
            expect(user.billing.first_paid_at).to eq current_time
            expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

            cha_info_res = Billing.get_last_charge_data

            expect(cha_info_res.customer).not_to eq user.billing.customer_id

            sub_info_res = user.billing.get_subscription_info

            expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
            expect(sub_info_res.object).to eq 'subscription'
            expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]

            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries.last.subject).to match(/プランの変更が完了致しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プラン変更が完了しました。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更前プラン名: Rspecテスト スタンダードプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後プラン名: Rspecテスト ライトプラン/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/今回課金料金: 0円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/変更後料金: 1,000円/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).not_to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
            expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)

            user.billing.delete_customer

            Timecop.return
          end

        end
      end # describe プランダウングレードに関して

      context '同じプランの場合' do
        let(:plan_name)     { :test_standard }
        let(:plan)          { EasySettings.plan[plan_name] }
        let(:new_plan_name) { :test_standard}
        let(:new_plan)      { EasySettings.plan[new_plan_name] }

        it '変更がないこと' do
          Timecop.freeze(current_time)

          register_card(user)
          sub_create_res = register_subscription(user, plan_name)

          sign_in user

          put :update, params: params

          expect(response.status).to eq 400
          expect(response.location).to render_template :edit
          expect(assigns(:finish_status)).to eq :same_plan
          expect(assigns(:card)).to eq({brand: 'Visa', last4: '4242'})

          # この手順が必要
          user_id = user.id
          user    = User.find(user_id)

          expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
          expect(user.billing.last_plan).to be_nil
          expect(user.billing.next_plan).to be_nil
          expect(user.billing.last_paid_at).to be_nil

          expect(user.billing.status).to eq 'trial'
          expect(user.billing.customer_id).to eq sub_create_res.customer
          expect(user.billing.subscription_id).to eq sub_create_res.id
          expect(user.billing.first_paid_at).to be_nil
          expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

          cha_info_res = Billing.get_last_charge_data

          expect(cha_info_res.customer).not_to eq user.billing.customer_id

          sub_info_res = user.billing.get_subscription_info

          expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
          expect(sub_info_res.object).to eq 'subscription'
          expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]

          expect(ActionMailer::Base.deliveries.size).to eq(0)

          user.billing.delete_customer

          Timecop.return
        end
      end
    end
  end
end

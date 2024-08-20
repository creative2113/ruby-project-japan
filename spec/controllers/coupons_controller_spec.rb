require 'rails_helper'

RSpec.describe CouponsController, type: :controller do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_beta_standard_plan) { create(:master_billing_plan, :beta_standard) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'beta_standard'])
  end

  before { create_public_user }
  let(:password)        { "#{SecureRandom.alphanumeric(10)}A2" }
  let(:fallback_path)   { 'http://test.host/users/edit' }
  let(:payment_method)  { nil }
  let(:expiration_date) { nil }
  let(:user)            { create(:user, password: password, billing_attrs: { payment_method: payment_method }) }
  let(:coupon)          { create(:referrer_trial) }

  before do
    create(:allow_ip, :admin, user: user)
    coupon
  end

  after { ActionMailer::Base.deliveries.clear }

  describe 'GET new_trial' do
    let(:coupon_code) { '1234567890' }
    let(:referrer)    { create(:referrer, code: coupon_code) }
    let(:params)      { { coupon_code: coupon_code } }

    before { referrer }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        get :new_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
      end
    end

    context '異常ケース' do

      def check_invalid_request
        get :new_trial, params: params
        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path
      end

      before { sign_in user }

      context 'コードがない時' do
        let(:coupon_code) { '' }
        it { check_invalid_request }
      end

      context 'すでにトライアルがある時' do
        before { create(:user_coupon, user: user, coupon: coupon) }
        it { check_invalid_request }
      end

      context 'コードが間違っている時' do
        let(:params) { { coupon_code: '123123123' } }
        it { check_invalid_request }
      end

      context 'すでにクーポン由来の紹介者が紐づいているが、違う紹介者コードを入れた時' do
        let(:another_coupon_code) { '123123123' }
        let(:another_referrer)    { create(:referrer, code: another_coupon_code) }

        before do
          another_referrer
          user.update(referrer_id: another_referrer.id, referral_reason: User.referral_reasons[:coupon])
        end
        it { check_invalid_request }
      end

      context 'すでにトライアル中' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        before { user.billing.create_plan!(master_test_standard_plan.id, trial: true) }

        it { check_invalid_request }
      end

      context 'すでに課金中' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        before { user.billing.create_plan!(master_test_standard_plan.id) }

        it { check_invalid_request }
      end

      context 'ユーザ作成から33日間経過' do
        before { user.update(created_at: Time.zone.now - 33.days) }
        it { check_invalid_request }
      end
    end

    context '正常系' do

      context '紹介者が紐づいてない' do
        before { sign_in user }
        it 'トライアル申請画面に遷移すること' do
          get :new_trial, params: params

          expect(response.status).to eq 200
          expect(response).to render_template :new_trial
        end
      end

      context '同じクーポン由来の紹介者が紐づいている' do
        before do
          user.update(referrer_id: referrer.id, referral_reason: User.referral_reasons[:coupon])
          sign_in user
        end

        it 'トライアル申請画面に遷移すること' do
          get :new_trial, params: params

          expect(response.status).to eq 200
          expect(response).to render_template :new_trial
        end
      end

      context '違うURL由来の紹介者が紐づいている' do
        let(:another_coupon_code) { '123123123' }
        let(:another_referrer)    { create(:referrer, code: another_coupon_code) }

        before do
          another_referrer
          user.update(referrer_id: another_referrer.id, referral_reason: User.referral_reasons[:url])
          sign_in user
        end

        it 'トライアル申請画面に遷移すること' do
          get :new_trial, params: params

          expect(response.status).to eq 200
          expect(response).to render_template :new_trial
        end
      end
    end
  end

  describe 'POST create_trial' do
    let(:coupon_code) { '1234567890' }
    let(:referrer)    { create(:referrer, code: coupon_code) }
    let(:token)       { Billing.create_dummy_card_token.id }
    let(:params)      { { coupon_code: coupon_code, 'payjp-token' => token } }

    before { referrer }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
      end
    end

    context '異常ケース' do

      def check_invalid_request
        post :create_trial, params: params
        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path
        expect(assigns(:finish_status)).to eq :invalid_request
      end

      before { sign_in user }

      context 'コードがない時' do
        let(:coupon_code) { '' }
        it { check_invalid_request }
      end

      context 'すでにトライアルがある時' do
        before { create(:user_coupon, user: user, coupon: coupon) }
        it { check_invalid_request }
      end

      context 'コードが間違っている時' do
        let(:params) { { coupon_code: '123123123', 'payjp-token' => token } }
        it { check_invalid_request }
      end

      context 'すでにクーポン由来の紹介者が紐づいているが、違う紹介者コードを入れた時' do
        let(:another_coupon_code) { '123123123' }
        let(:another_referrer)    { create(:referrer, code: another_coupon_code) }

        before do
          another_referrer
          user.update(referrer_id: another_referrer.id, referral_reason: User.referral_reasons[:coupon])
        end
        it { check_invalid_request }
      end

      context 'すでにトライアル中' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        before { user.billing.create_plan!(master_test_standard_plan.id, trial: true) }

        it { check_invalid_request }
      end

      context 'すでに課金中' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        before { user.billing.create_plan!(master_test_standard_plan.id) }

        it { check_invalid_request }
      end

      context 'ユーザ作成から33日間経過' do
        before { user.update(created_at: Time.zone.now - 33.days) }
        it { check_invalid_request }
      end
    end

    context 'プランが存在しない場合' do
      it do
        allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])

        sign_in user

        expect(user.billing.plans.reload.size).to eq 0

        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :error_occurred
        expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

        expect(user.billing.reload.payment_method).to be_nil
        expect(user.billing.customer_id).to be_nil

        expect(user.billing.plans.reload.size).to eq 0

        expect(UserCoupon.count).to eq 0

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries.last.subject).to match(/error発生/)
        expect(ActionMailer::Base.deliveries.last.body.raw_source).to match(/「beta_standard」が存在しません。/)
      end
    end

    context 'トライアルクーポンの保存に失敗した場合' do
      it 'リダイレクトされること' do
        # allow_any_instance_of(Billing).to receive(:create_customer).and_return( {'error' => false} )
        # allow_any_instance_of(Billing).to receive(:create_subscription_with_trial).and_return( make_response(status: 'trial',
        #                                                                                                      customer: 'cus_111',
        #                                                                                                      id: 'sub_111',
        #                                                                                                      current_period_end: Time.zone.now) )
        # allow_any_instance_of(Billing).to receive(:update).and_return( false )
        allow(UserCoupon).to receive(:create!).and_raise

        sign_in user

        cnt_user_coupon = UserCoupon.count
        expect(user.user_coupons.size).to eq 0
        expect(user.billing.plans.reload.size).to eq 0

        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_trial_coupon_error
        expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

        expect(user.billing.reload.payment_method).to be_nil
        expect(user.billing.customer_id).to be_nil

        expect(UserCoupon.count).to eq cnt_user_coupon + 0
        expect(user.user_coupons.reload.size).to eq 0
        expect(user.billing.plans.reload.size).to eq 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/error発生/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/Save Failure: UserCoupon クーポン保存に失敗しました。/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[CouponsController:create_trial: UserCoupon クーポン保存に失敗しました。\]/)
      end
    end

    context 'クレジット定期課金のプラン作成に失敗した場合' do

      context 'Billingのアップデートに失敗した場合' do
        it 'リダイレクトされること' do
          allow_any_instance_of(Billing).to receive(:update!).and_raise

          sign_in user

          cnt_user_coupon = UserCoupon.count
          expect(user.user_coupons.size).to eq 0
          expect(user.billing.plans.reload.size).to eq 0

          post :create_trial, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(assigns(:finish_status)).to eq :create_trial_plan_error
          expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

          expect(user.billing.reload.payment_method).to be_nil
          expect(user.billing.customer_id).to be_nil

          expect(UserCoupon.count).to eq cnt_user_coupon + 0
          expect(user.user_coupons.reload.size).to eq 0
          expect(user.billing.plans.reload.size).to eq 0

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/error発生/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/Save Failure: トライアル課金プラン保存に失敗しました。/)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[CouponsController:create_trial: トライアル課金プラン保存に失敗しました。\]/)
        end
      end

      context 'トライアルクーポンの保存に失敗した場合' do
        it 'リダイレクトされること' do
          allow(BillingPlan).to receive(:new).and_raise

          sign_in user

          cnt_user_coupon = UserCoupon.count
          expect(user.user_coupons.size).to eq 0
          expect(user.billing.plans.reload.size).to eq 0

          post :create_trial, params: params

          expect(response.status).to eq 302
          expect(response.location).to eq fallback_path

          expect(assigns(:finish_status)).to eq :create_trial_plan_error
          expect(flash[:alert]).to eq Message.const[:error_occurred_retry_latter]

          expect(user.billing.reload.payment_method).to be_nil
          expect(user.billing.customer_id).to be_nil

          expect(UserCoupon.count).to eq cnt_user_coupon + 0
          expect(user.user_coupons.reload.size).to eq 0
          expect(user.billing.plans.reload.size).to eq 0

          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/error発生/)
          expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/Save Failure: トライアル課金プラン保存に失敗しました。/)
          expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
          expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[CouponsController:create_trial: トライアル課金プラン保存に失敗しました。\]/)
        end
      end
    end

    context 'PAYJPの顧客登録に失敗した場合' do

      it 'エラーが返ってきた場合は、リダイレクトされること' do
        allow_any_instance_of(Billing).to receive(:create_customer).and_return( {'error' => true} )

        sign_in user

        expect(user.billing.plans.reload.size).to eq 0

        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_payjp_customer_error
        expect(flash[:alert]).to eq Message.const[:card_registration_failure]

        expect(user.billing.reload.payment_method).to be_nil
        expect(user.billing.customer_id).to be_nil

        expect(user.billing.plans.reload.size).to eq 0

        expect(UserCoupon.count).to eq 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/error発生/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PAYJP Make Customer Failure: PAYJPの顧客登録に失敗しました。/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[CouponsController:create_trial: PAYJP Make Customer Failure\]/)
      end

      it 'エラーが発生した場合は、リダイレクトされること' do
        allow_any_instance_of(Billing).to receive(:create_customer).and_raise('Dummy Error')

        sign_in user

        expect(user.billing.plans.reload.size).to eq 0

        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :create_payjp_customer_error
        expect(flash[:alert]).to eq Message.const[:card_registration_failure]

        expect(user.billing.reload.payment_method).to be_nil
        expect(user.billing.customer_id).to be_nil

        expect(user.billing.plans.reload.size).to eq 0

        expect(UserCoupon.count).to eq 0

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/error発生/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PAYJP Make Customer Failure: PAYJPの顧客登録に失敗しました。/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要対応/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[CouponsController:create_trial: PAYJP Make Customer Failure\]/)
      end
    end

    context 'カスタマーIDの保存に失敗した場合' do
      after do
        user.billing.clean_customer_by_email
        Timecop.return
      end

      it '成功すること。カスタマーIDを登録するようメッセージが来ること。' do
        Timecop.freeze(current_time)

        allow_any_instance_of(Billing).to receive(:update!).and_raise
        allow_any_instance_of(Billing).to receive(:update!).with(payment_method: Billing.payment_methods[:credit]).and_call_original

        sign_in user

        cnt_user_coupon = UserCoupon.count
        expect(user.user_coupons.size).to eq 0
        expect(user.billing.plans.reload.size).to eq 0

        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to eq :save_customer_id_error
        expect(flash[:notice]).to eq Message.const[:success_trial_coupon]

        # この手順が必要
        user.reload
        user.billing.reload

        cus_info_res = user.billing.search_customer_by_email

        expect(user.id.to_s).to eq cus_info_res.metadata.user_id
        expect(user.email).to eq cus_info_res.email
        expect(user.company_name).to eq cus_info_res.metadata.company_name

        expect(user.billing.reload.payment_method).to eq 'credit'
        expect(user.billing.customer_id).to be_nil

        expect(UserCoupon.count).to eq cnt_user_coupon + 1
        expect(user.user_coupons.reload.size).to eq 1
        expect(user.billing.plans.reload.size).to eq 1

        expect(ActionMailer::Base.deliveries.size).to eq(2)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/fatal発生/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/カスタマーIDの保存に失敗しました。できるだけ早く、カスタマーIDをuser.billing.customer_idに保存してください。/)
        expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/#{cus_info_res.id}/)
        expect(ActionMailer::Base.deliveries[1].subject).to match(/エラー発生　要緊急対応/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ERROR_POINT\[CouponsController:create_trial: カスタマーIDの保存に失敗しました。できるだけ早く、カスタマーIDをuser.billing.customer_idに保存してください。\]/)
        expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/CUSTOMER_ID\[#{cus_info_res.id}\]/)
      end
    end

    context '正常終了の場合' do

      after do
        user.billing.delete_customer if user.billing.reload.customer_id.present?
        Timecop.return
      end

      it 'billingに保存されること' do
        Timecop.freeze(current_time)

        sign_in user

        cnt_user_coupon = UserCoupon.count
        expect(user.user_coupons.size).to eq 0
        expect(user.billing.plans.reload.size).to eq 0

        post :create_trial, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path

        expect(assigns(:finish_status)).to be_nil
        expect(flash[:notice]).to eq Message.const[:success_trial_coupon]

        # この手順が必要
        user.reload
        user.billing.reload

        cus_info_res = user.billing.get_customer_info

        expect(user.id.to_s).to eq cus_info_res.metadata.user_id
        expect(user.email).to eq cus_info_res.email
        expect(user.company_name).to eq cus_info_res.metadata.company_name

        expect(user.billing.customer_id).to eq cus_info_res.id
        expect(user.billing.payment_method).to eq 'credit'

        expect(UserCoupon.count).to eq cnt_user_coupon + 1
        expect(user.user_coupons.reload.size).to eq 1
        expect(user.user_coupons.first.count).to eq 1
        expect(user.user_coupons.first.coupon).to eq coupon
        expect(user.billing.plans.reload.size).to eq 1

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end
  end

  describe 'PUT add' do
    let(:coupon_code) { '1234567890' }
    let(:referrer)    { create(:referrer, code: coupon_code) }
    let(:referrer2)   { create(:referrer, code: '0000000') }
    let(:token)       { Billing.create_dummy_card_token.id }
    let(:params)      { { coupon_code: coupon_code } }

    before { referrer }

    context '非ログインユーザの場合' do

      it 'リダイレクトされること' do
        put :add, params: params

        expect(response.status).to eq 302
        expect(response.location).to eq 'http://test.host/users/sign_in'
      end
    end

    context '異常ケース' do

      def check_invalid_request(message)
        put :add, params: params
        expect(response.status).to eq 302
        expect(response.location).to eq fallback_path
        expect(flash[:alert]).to eq message
      end

      before { sign_in user }

      context 'コードがない時' do
        let(:coupon_code) { '' }
        it { check_invalid_request(Message.const[:coupon_code_is_blank]) }
      end

      context 'コードが間違っている時' do
        let(:params) { { coupon_code: '123123123' } }
        it { 
          put :add, params: params
          expect(response.status).to eq 400
          expect(response).to render_template "devise/registrations/edit"
          expect(flash[:alert]).to eq Message.const[:invalid_code]
        }
      end

      context 'すでにトライアルがある時' do
        before { create(:user_coupon, user: user, coupon: coupon) }
        it { check_invalid_request(Message.const[:used_coupon_code]) }
      end

      context 'すでにクーポン由来の紹介者が紐づいているが、違う紹介者コードを入れた時' do
        let(:another_coupon_code) { '123123123' }
        let(:another_referrer)    { create(:referrer, code: another_coupon_code) }

        before do
          another_referrer
          user.update(referrer_id: another_referrer.id, referral_reason: User.referral_reasons[:coupon])
        end
        it { check_invalid_request(Message.const[:invalid_coupon_code]) }
      end

      context 'すでにトライアル中' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        before { user.billing.create_plan!(master_test_standard_plan.id, trial: true) }

        it { check_invalid_request(Message.const[:expired_coupon_code]) }
      end

      context 'すでに課金中' do
        let(:payment_method) { Billing.payment_methods[:credit] }
        before { user.billing.create_plan!(master_test_standard_plan.id) }

        it { check_invalid_request(Message.const[:expired_coupon_code]) }
      end

      context 'ユーザ作成から33日間経過' do
        before { user.update(created_at: Time.zone.now - 33.days) }
        it { check_invalid_request(Message.const[:expired_coupon_code]) }
      end
    end

    context '正常ケース' do
      before { sign_in user }

      context '紹介者が紐付けされてない' do
        it do
          expect(user.reload.referrer).to be_nil

          put :add, params: params
          expect(response.status).to eq 302
          expect(response.location).to eq "http://test.host#{coupon_trial_path(coupon_code: coupon_code)}"

          expect(user.reload.referrer).to eq referrer
          expect(user.referral_reason).to eq 'coupon'
        end
      end

      context '紹介者が紐付けされている' do
        context '同じコード & URL由来' do
          before { user.update(referrer: referrer, referral_reason: User.referral_reasons[:url]) }

          it do
            expect(user.reload.referrer).to eq referrer

            put :add, params: params
            expect(response.status).to eq 302
            expect(response.location).to eq "http://test.host#{coupon_trial_path(coupon_code: coupon_code)}"

            expect(user.reload.referrer).to eq referrer
            expect(user.referral_reason).to eq 'coupon'
          end
        end

        context '同じコード & クーポン由来' do
          before { user.update(referrer: referrer, referral_reason: User.referral_reasons[:coupon]) }

          it do
            expect(user.reload.referrer).to eq referrer

            put :add, params: params
            expect(response.status).to eq 302
            expect(response.location).to eq "http://test.host#{coupon_trial_path(coupon_code: coupon_code)}"

            expect(user.reload.referrer).to eq referrer
            expect(user.referral_reason).to eq 'coupon'
          end
        end

        context '違うURL由来の紹介者' do
          before { user.update(referrer: referrer2, referral_reason: User.referral_reasons[:url]) }

          it do
            expect(user.reload.referrer).to eq referrer2

            put :add, params: params
            expect(response.status).to eq 302
            expect(response.location).to eq "http://test.host#{coupon_trial_path(coupon_code: coupon_code)}"

            expect(user.reload.referrer).to eq referrer
            expect(user.referral_reason).to eq 'coupon'
          end
        end
      end
    end
  end
end
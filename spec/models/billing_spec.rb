require 'rails_helper'


RSpec.describe Billing, type: :model do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
  end

  let(:card_token)     { Billing.create_dummy_card_token }
  let(:payment_method) { nil }
  let(:user)           { create(:user, billing_attrs: { payment_method: payment_method,
                                                        customer_id: nil })
                       }

  describe 'PAY.JPのシナリオテスト' do
    it 'create_customer 顧客の作成
        -> get_customer_info 顧客情報の取得
        -> create_subscription 定期課金の作成
        -> create_new_subscription 定期課金情報をテーブルに保存
        -> get_subscription_info 定期課金情報の取得
        -> change_subscription 定期課金の変更
        -> get_subscription_info 定期課金情報の取得
        -> delete_subscription 定期課金の削除
        -> get_subscription_infoでエラーが出ること
        -> delete_customer 顧客の削除
        -> get_customer_infoでエラーが出ること' do

      Timecop.freeze(current_time)
      cus_create_res = user.billing.create_customer(card_token)

      expect(user.billing.customer_id).to eq cus_create_res.id.to_s

      cus_info_res = user.billing.get_customer_info

      expect(cus_info_res.id).to eq user.billing.customer_id
      expect(cus_info_res.email).to eq user.email
      expect(cus_info_res.metadata.user_id).to eq user.id.to_s
      expect(cus_info_res.metadata.company_name).to eq user.company_name
      expect(cus_info_res.metadata.environment).to eq 'test'

      sub_create_res = user.billing.create_subscription(EasySettings.payjp_plan_id[:test_standard])

      user.billing.create_new_subscription(EasySettings.plan[:test_standard], sub_create_res)

      expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
      expect(user.billing.status).to eq 'paid'
      expect(user.billing.payment_method).to eq 'credit'
      expect(user.billing.customer_id).to eq sub_create_res.customer
      expect(user.billing.subscription_id).to eq sub_create_res.id
      expect(user.billing.first_paid_at).to eq current_time
      expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

      sub_info_res = user.billing.get_subscription_info

      expect(sub_info_res.customer).to eq user.billing.customer_id
      expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
      expect(sub_info_res.object).to eq 'subscription'
      expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]
      expect(sub_info_res.status).to eq 'active'

      sub_change_res = user.billing.change_subscription(EasySettings.payjp_plan_id[:test_light])

      sub_info_res = user.billing.get_subscription_info

      expect(sub_info_res.customer).to eq user.billing.customer_id
      expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
      expect(sub_info_res.object).to eq 'subscription'
      expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]
      expect(sub_info_res.status).to eq 'trial'

      sub_delete_res = user.billing.delete_subscription

      expect(sub_delete_res.deleted).to be_truthy
      expect(sub_delete_res.id).to eq sub_create_res.id

      sleep 2
      expect { user.billing.get_subscription_info }.to raise_error(Payjp::InvalidRequestError)

      cus_delete_res = user.billing.delete_customer

      expect(cus_delete_res.deleted).to be_truthy
      expect(cus_delete_res.id).to eq user.billing.customer_id

      sleep 2
      expect { user.billing.get_customer_info }.to raise_error(Payjp::InvalidRequestError)
      Timecop.return
    end

    it 'create_customer 顧客の作成
        -> get_customer_info 顧客情報の取得
        -> create_subscription_with_trial トライアル定期課金の作成
        -> create_new_subscription トライアル定期課金情報をテーブルに保存
        -> get_subscription_info 定期課金情報の取得
        -> change_subscription 定期課金の変更
        -> get_subscription_info 定期課金情報の取得
        -> delete_subscription 定期課金の削除
        -> get_subscription_infoでエラーが出ること
        -> delete_customer 顧客の削除
        -> get_customer_infoでエラーが出ること' do

      Timecop.freeze(current_time)
      cus_create_res = user.billing.create_customer(card_token)

      expect(user.billing.customer_id).to eq cus_create_res.id.to_s

      cus_info_res = user.billing.get_customer_info

      expect(cus_info_res.id).to eq user.billing.customer_id
      expect(cus_info_res.email).to eq user.email
      expect(cus_info_res.metadata.user_id).to eq user.id.to_s
      expect(cus_info_res.metadata.company_name).to eq user.company_name
      expect(cus_info_res.metadata.environment).to eq 'test'

      sub_create_res = user.billing.create_subscription_with_trial(EasySettings.payjp_plan_id[:test_standard], (Time.zone.now + 10.days).end_of_day)

      user.billing.create_new_subscription(EasySettings.plan[:test_standard], sub_create_res)

      expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
      expect(user.billing.status).to eq 'trial'
      expect(user.billing.payment_method).to eq 'credit'
      expect(user.billing.customer_id).to eq sub_create_res.customer
      expect(user.billing.subscription_id).to eq sub_create_res.id
      expect(user.billing.first_paid_at).to be_nil
      expect(user.billing.expiration_date).to eq Time.zone.at(sub_create_res.current_period_end)

      sub_info_res = user.billing.get_subscription_info

      expect(sub_info_res.customer).to eq user.billing.customer_id
      expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_standard]
      expect(sub_info_res.object).to eq 'subscription'
      expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_standard]
      expect(sub_info_res.status).to eq 'trial'

      sub_change_res = user.billing.change_subscription(EasySettings.payjp_plan_id[:test_light])

      sub_info_res = user.billing.get_subscription_info

      expect(sub_info_res.customer).to eq user.billing.customer_id
      expect(sub_info_res.plan.amount).to eq EasySettings.amount[:test_light]
      expect(sub_info_res.object).to eq 'subscription'
      expect(sub_info_res.plan.id).to eq EasySettings.payjp_plan_id[:test_light]
      expect(sub_info_res.status).to eq 'trial'

      sub_delete_res = user.billing.delete_subscription

      expect(sub_delete_res.deleted).to be_truthy
      expect(sub_delete_res.id).to eq sub_create_res.id

      sleep 2
      expect { user.billing.get_subscription_info }.to raise_error(Payjp::InvalidRequestError)

      cus_delete_res = user.billing.delete_customer

      expect(cus_delete_res.deleted).to be_truthy
      expect(cus_delete_res.id).to eq user.billing.customer_id

      sleep 2
      expect { user.billing.get_customer_info }.to raise_error(Payjp::InvalidRequestError)
      Timecop.return
    end

    it 'create_customer 顧客の作成
        -> create_charge 課金作成
        -> get_card_info カード情報の取得
        -> delete_card カードを削除
        -> create_card カードを作成
        -> get_card_info カード情報の取得
        -> delete_customer 顧客の削除' do

      amount = 999
      Timecop.freeze(current_time)

      card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
      cus_create_res = user.billing.create_customer(card_token)

      cha_create_res = user.billing.create_charge(amount)

      expect(cha_create_res.amount).to eq amount
      expect(cha_create_res.object).to eq 'charge'
      expect(cha_create_res.paid).to be_truthy
      expect(cha_create_res.customer).to eq user.billing.customer_id

      car_info_res = user.billing.get_card_info

      expect(car_info_res.brand).to eq 'Visa'
      expect(car_info_res.last4).to eq '4242'
      expect(car_info_res.object).to eq 'card'
      expect(car_info_res.exp_month).to eq 12
      expect(car_info_res.exp_year).to eq 2040

      car_delete_res = user.billing.delete_card(car_info_res.id)

      expect(car_delete_res.deleted).to be_truthy
      expect(car_delete_res.id).to eq car_info_res.id

      card_token = Billing.create_dummy_card_token('5555555555554444', '3', '2030', '345')
      car_create_res = user.billing.create_card(card_token)

      expect(car_create_res.brand).to eq 'MasterCard'
      expect(car_create_res.last4).to eq '4444'
      expect(car_create_res.object).to eq 'card'
      expect(car_create_res.exp_month).to eq 3
      expect(car_create_res.exp_year).to eq 2030

      car_info_res = user.billing.get_card_info

      expect(car_info_res.brand).to eq 'MasterCard'
      expect(car_info_res.last4).to eq '4444'
      expect(car_info_res.object).to eq 'card'
      expect(car_info_res.exp_month).to eq 3
      expect(car_info_res.exp_year).to eq 2030

      cus_delete_res = user.billing.delete_customer

      expect(cus_delete_res.deleted).to be_truthy
      expect(cus_delete_res.id).to eq user.billing.customer_id

      sleep 2
      expect { user.billing.get_customer_info }.to raise_error(Payjp::InvalidRequestError)
      Timecop.return
    end

    it 'search_customerでuser_idから顧客情報を取得できること' do
      # テストのために、顧客を整理する
      user.billing.clean_customer

      cus_create_res = user.billing.create_customer(card_token)

      cus_search_res = user.billing.search_customer

      expect(cus_search_res.email).to eq user.email
      expect(cus_search_res.metadata.user_id).to eq user.id.to_s
      expect(cus_search_res.metadata.company_name).to eq user.company_name

      cus_search_res = user.billing.search_customer(7, 1)

      # PAYJPに過去に登録した同じuser_idが残っていると落ちる
      expect(cus_search_res).to be_nil

      cus_delete_res = user.billing.delete_customer

      expect(cus_delete_res.deleted).to be_truthy
      expect(cus_delete_res.id).to eq user.billing.customer_id
    end
  end

  describe 'インスタンスメソッド' do
    describe '#get_charges' do

      after { user.billing.delete_customer }

      it 'カード情報が取れること、カードの数が取れること' do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        user.billing.create_customer(card_token)

        cha_create_res1 = user.billing.create_charge(1000)
        cha_create_res2 = user.billing.create_charge(2000)
        cha_create_res3 = user.billing.create_charge(3000)

        charges = user.billing.get_charges

        expect(charges.count).to eq 3

        expect(charges.data[0].id).to eq cha_create_res3.id
        expect(charges.data[0].amount).to eq cha_create_res3.amount
        expect(charges.data[1].id).to eq cha_create_res2.id
        expect(charges.data[1].amount).to eq cha_create_res2.amount
        expect(charges.data[2].id).to eq cha_create_res1.id
        expect(charges.data[2].amount).to eq cha_create_res1.amount

        cha_create_res4 = user.billing.create_charge(4000)

        charges = user.billing.get_charges(2)

        expect(charges.count).to eq 2

        expect(charges.data[0].id).to eq cha_create_res4.id
        expect(charges.data[0].amount).to eq cha_create_res4.amount
        expect(charges.data[1].id).to eq cha_create_res3.id
        expect(charges.data[1].amount).to eq cha_create_res3.amount
      end
    end

    describe '#search_customer_by_email' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }
      let(:user3) { create(:user) }

      after do
        user1.billing.delete_customer
        user2.billing.delete_customer
        user3.billing.delete_customer
      end

      it 'カード情報が取れること、カードの数が取れること' do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        res_user1 = user1.billing.create_customer(card_token)

        card_token = Billing.create_dummy_card_token('5555555555554444', '3', '2030', '416')
        res_user2 = user2.billing.create_customer(card_token)

        card_token = Billing.create_dummy_card_token('3566002020360505', '6', '2044', '452')
        res_user3 = user3.billing.create_customer(card_token)

        res_user = user1.billing.search_customer_by_email

        expect(res_user.id).to eq res_user1.id
        expect(res_user.id).to eq user1.billing.customer_id
        expect(res_user.email).to eq user1.email
        expect(res_user.metadata.company_name).to eq user1.company_name
        expect(res_user.metadata.user_id).to eq user1.id.to_s

        res_user = user2.billing.search_customer_by_email

        expect(res_user.id).to eq res_user2.id
        expect(res_user.id).to eq user2.billing.customer_id
        expect(res_user.email).to eq user2.email
        expect(res_user.metadata.company_name).to eq user2.company_name
        expect(res_user.metadata.user_id).to eq user2.id.to_s

        res_user = user3.billing.search_customer_by_email

        expect(res_user.id).to eq res_user3.id
        expect(res_user.id).to eq user3.billing.customer_id
        expect(res_user.email).to eq user3.email
        expect(res_user.metadata.company_name).to eq user3.company_name
        expect(res_user.metadata.user_id).to eq user3.id.to_s
      end
    end

    describe 'get_card_info, get_card_count' do

      it 'カード情報が取れること、カードの数が取れること' do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        user.billing.create_customer(card_token)

        card_token = Billing.create_dummy_card_token('5555555555554444', '3', '2030', '345')
        user.billing.create_card(card_token)

        card_token = Billing.create_dummy_card_token('3566002020360505', '4', '2037', '678')
        user.billing.create_card(card_token)

        expect(user.billing.get_card_count).to eq 3

        car_info_res = user.billing.get_card_info(1)

        expect(car_info_res.brand).to eq 'JCB'
        expect(car_info_res.last4).to eq '0505'
        expect(car_info_res.object).to eq 'card'
        expect(car_info_res.exp_month).to eq 4
        expect(car_info_res.exp_year).to eq 2037

        car_info_res = user.billing.get_card_info(2)

        expect(car_info_res.brand).to eq 'MasterCard'
        expect(car_info_res.last4).to eq '4444'
        expect(car_info_res.object).to eq 'card'
        expect(car_info_res.exp_month).to eq 3
        expect(car_info_res.exp_year).to eq 2030

        car_info_res = user.billing.get_card_info(3)

        expect(car_info_res.brand).to eq 'Visa'
        expect(car_info_res.last4).to eq '4242'
        expect(car_info_res.object).to eq 'card'
        expect(car_info_res.exp_month).to eq 12
        expect(car_info_res.exp_year).to eq 2040

        user.billing.delete_customer
      end
    end

    describe 'get_last_charge_data' do

      it 'カード情報が取れること、カードの数が取れること' do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        cus_create_res = user.billing.create_customer(card_token)

        user.billing.create_charge(888)
        user.billing.create_subscription(EasySettings.payjp_plan_id[:test_standard])

        cha_info_res = Billing.get_last_charge_data

        expect(cha_info_res.customer).to eq user.billing.customer_id
        expect(cha_info_res.amount).to eq 888
        expect(cha_info_res.subscription).to be_nil

        user.billing.delete_customer
      end
    end

    # xdescribe 'over_expiration_date?' do
    #   context '課金ユーザ、クレジットの場合' do
    #     let(:user) { create(:user, billing_attrs: { plan: EasySettings.plan[:light],
    #                                                 payment_method: Billing.payment_methods[:credit],
    #                                                 expiration_date: exp_date } ) }
    #     context 'expiration_dateが11分前で、PAYJPの定期課金が更新されている場合' do
    #       let(:exp_date) { Time.zone.now - 11.minutes }
    #       it 'trueが返ること' do
    #         allow_any_instance_of(Billing).to receive(:get_current_service_end).and_return( Time.zone.now.next_month )
    #         expect(user.billing.over_expiration_date?).to be_truthy
    #       end
    #     end

    #     context 'expiration_dateが11分前で、PAYJPの定期課金が更新されていないの場合' do
    #       let(:exp_date) { Time.zone.now - 11.minutes }
    #       it 'falseが返ること' do
    #         Timecop.freeze(current_time)
    #         allow_any_instance_of(Billing).to receive(:get_current_service_end).and_return( exp_date )
    #         expect(user.billing.over_expiration_date?).to be_falsey
    #         Timecop.return
    #       end
    #     end

    #     context 'expiration_dateが現在時刻の場合' do
    #       let(:exp_date) { Time.zone.now }
    #       it 'falseが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_falsey
    #       end
    #     end

    #     context 'expiration_dateがnilの場合' do
    #       let(:exp_date) { nil }
    #       it 'trueが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_truthy
    #       end
    #     end
    #   end

    #   context '課金ユーザ、銀行振込の場合' do
    #     let(:user) { create(:user, billing_attrs: { plan: EasySettings.plan[:light],
    #                                                 payment_method: Billing.payment_methods[:bank_transfer],
    #                                                 expiration_date: exp_date } ) }
    #     context 'expiration_dateが1秒前の場合' do
    #       let(:exp_date) { Time.zone.now - 1.second }
    #       it 'trueが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_truthy
    #       end
    #     end

    #     context 'expiration_dateが5秒先の場合' do
    #       let(:exp_date) { Time.zone.now + 5.second }
    #       it 'falseが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_falsey
    #       end
    #     end

    #     context 'expiration_dateがnilの場合' do
    #       let(:exp_date) { nil }
    #       it 'trueが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_truthy
    #       end
    #     end
    #   end

    #   context '無課金ユーザの場合' do
    #     let(:user) { create(:user, billing_attrs: { plan: EasySettings.plan[:public],
    #                                                 status: Billing.statuses[:unpaid],
    #                                                 expiration_date: exp_date } ) }
    #     context 'expiration_dateが1秒前の場合' do
    #       let(:exp_date) { Time.zone.now - 1.second }
    #       it 'trueが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_truthy
    #       end
    #     end

    #     context 'expiration_dateが5秒先の場合' do
    #       let(:exp_date) { Time.zone.now + 5.second }
    #       it 'falseが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_falsey
    #       end
    #     end

    #     context 'expiration_dateがnilの場合' do
    #       let(:exp_date) { nil }
    #       it 'trueが返ること' do
    #         expect(user.billing.over_expiration_date?).to be_truthy
    #       end
    #     end
    #   end
    # end

    # xdescribe 'plan_downgrading?' do
    #   let(:user) { create(:user, billing_attrs: { plan: EasySettings.plan[:gold],
    #                                               next_plan: next_plan,
    #                                               expiration_date: exp_date } ) }

    #   context '次のプランでダウングレードし、定期課金も更新されている場合' do
    #     let(:next_plan) { EasySettings.plan[:light] }
    #     let(:exp_date)  { Time.zone.now - 11.minutes }
    #     it 'falseが返ること' do
    #       allow_any_instance_of(Billing).to receive(:get_current_service_end).and_return( Time.zone.now.next_month )
    #       expect(user.billing.plan_downgrading?).to be_falsey
    #     end
    #   end

    #   context '次のプランでダウングレードし、定期課金はまだ更新されていない場合' do
    #     let(:next_plan) { EasySettings.plan[:light] }
    #     let(:exp_date)  { Time.zone.now - 11.minutes }
    #     it 'trueが返ること' do
    #       Timecop.freeze(current_time)
    #       allow_any_instance_of(Billing).to receive(:get_current_service_end).and_return( exp_date )
    #       expect(user.billing.plan_downgrading?).to be_truthy
    #       Timecop.return
    #     end
    #   end

    #   context 'next_planがnilの場合' do
    #     let(:next_plan) { nil }
    #     let(:exp_date)  { Time.zone.now - 11.minutes }
    #     it 'falseが返ること' do
    #       expect(user.billing.plan_downgrading?).to be_falsey
    #     end
    #   end

    #   context 'next_planがnilの場合' do
    #     let(:next_plan) { nil }
    #     let(:exp_date)  { Time.zone.now }
    #     it 'falseが返ること' do
    #       expect(user.billing.plan_downgrading?).to be_falsey
    #     end
    #   end

    #   context 'expiration_dateが現在時刻の場合' do
    #     let(:next_plan) { EasySettings.plan[:standard] }
    #     let(:exp_date)  { Time.zone.now }
    #     it 'trueが返ること' do
    #       expect(user.billing.plan_downgrading?).to be_truthy
    #     end
    #   end
    # end

    # xdescribe 'should_downgrade_plan_now?' do
    #   let(:user) { create(:user, billing_attrs: { plan: EasySettings.plan[:gold],
    #                                               next_plan: next_plan,
    #                                               expiration_date: exp_date } ) }
    #   context '次のプランでダウングレードし、定期課金も更新されている場合' do
    #     let(:next_plan) { EasySettings.plan[:light] }
    #     let(:exp_date)  { Time.zone.now - 11.minutes }
    #     it 'trueが返ること' do
    #       allow_any_instance_of(Billing).to receive(:get_current_service_end).and_return( Time.zone.now.next_month )
    #       expect(user.billing.should_downgrade_plan_now?).to be_truthy
    #     end
    #   end

    #   context '次のプランでダウングレードし、定期課金はまだ更新されていない場合' do
    #     let(:next_plan) { EasySettings.plan[:light] }
    #     let(:exp_date)  { Time.zone.now - 11.minutes }
    #     it 'trueが返ること' do
    #       Timecop.freeze(current_time)
    #       allow_any_instance_of(Billing).to receive(:get_current_service_end).and_return( exp_date )
    #       expect(user.billing.should_downgrade_plan_now?).to be_falsey
    #       Timecop.return
    #     end
    #   end

    #   context 'next_planがnilの場合' do
    #     let(:next_plan) { nil }
    #     let(:exp_date)  { Time.zone.now - 11.minutes }
    #     it 'falseが返ること' do
    #       expect(user.billing.should_downgrade_plan_now?).to be_falsey
    #     end
    #   end

    #   context 'next_planがnilの場合' do
    #     let(:next_plan) { nil }
    #     let(:exp_date)  { Time.zone.now }
    #     it 'falseが返ること' do
    #       expect(user.billing.should_downgrade_plan_now?).to be_falsey
    #     end
    #   end

    #   context 'expiration_dateが現在時刻の場合' do
    #     let(:next_plan) { EasySettings.plan[:standard] }
    #     let(:exp_date)  { Time.zone.now }
    #     it 'trueが返ること' do
    #       expect(user.billing.should_downgrade_plan_now?).to be_falsey
    #     end
    #   end
    # end

    def check_plan(master_plan, status, start_at, end_at, next_charge_date, trial)
      plan = user.billing.plans.reload[0]
      expect(plan.name).to eq master_plan.name
      expect(plan.status).to eq status
      expect(plan.price).to eq master_plan.price
      expect(plan.tax_included).to eq master_plan.tax_included
      expect(plan.tax_rate).to eq master_plan.tax_rate
      expect(plan.type).to eq master_plan.type
      expect(plan.charge_date).to eq start_at.day.to_s
      expect(plan.start_at).to eq start_at.iso8601
      expect(plan.end_at).to eq end_at&.iso8601
      expect(plan.next_charge_date).to eq next_charge_date
      expect(plan.trial).to eq trial
    end

    describe '#create_plan!' do
      subject { user.billing.create_plan!(master_plan.id, charge_date: charge_date, start_at: start_at, end_at: end_at, trial: trial) }
      let(:master_plan) { master_test_light_plan }
      let(:charge_date) { nil }
      let(:start_at) { Time.zone.now }
      let(:end_at) { nil }
      let(:trial) { false }

      context 'Time.zone.now < start_at' do
        let(:start_at) { Time.zone.now + 7.days }

        it do
          expect(user.billing.plans.reload.size).to eq 0
          subject
          expect(user.billing.plans.reload.size).to eq 1
          check_plan(master_plan, 'waiting', start_at, end_at, start_at.to_date, false)
        end
      end

      context 'Time.zone.now < start_at' do
        let(:start_at) { Time.zone.now + 3.minutes }
        let(:trial) { true }


        it do
          expect(user.billing.plans.reload.size).to eq 0
          subject
          expect(user.billing.plans.reload.size).to eq 1

          check_plan(master_plan, 'waiting', start_at, end_at, Time.zone.today, true)
        end
      end

      context 'start_at <= Time.zone.now' do
        let(:start_at) { Time.zone.now.beginning_of_day }

        it do
          expect(user.billing.plans.reload.size).to eq 0
          subject
          expect(user.billing.plans.reload.size).to eq 1

          check_plan(master_plan, 'ongoing', start_at, end_at, Time.zone.today, false)
        end
      end

      context 'start_at <= Time.zone.now' do
        let(:start_at) { Time.zone.now.beginning_of_day.yesterday }
        let(:end_at)   { Time.zone.now + 3.months }

        it do
          expect(user.billing.plans.reload.size).to eq 0
          subject
          expect(user.billing.plans.reload.size).to eq 1

          check_plan(master_plan, 'ongoing', start_at, end_at, start_at.next_month.to_date, false)
          plan = user.billing.plans.reload[0]
          expect(plan.next_charge_date).to be > Time.zone.now
        end
      end

      context 'end_at.present? && end_at < Time.zone.now' do
        let(:start_at) { Time.zone.now - 2.months }
        let(:end_at) { Time.zone.now.yesterday }

        it do
          expect(user.billing.plans.reload.size).to eq 0
          subject
          expect(user.billing.plans.reload.size).to eq 1

          check_plan(master_plan, 'stopped', start_at, end_at, nil, false)
        end
      end

      context 'start_atがnil' do
        let(:start_at) { nil }

        it do
          expect(user.billing.plans.reload.size).to eq 0
          expect { subject }.to raise_error(Billing::StrangeParametersError, 'start_atがnil。')
          expect(user.billing.plans.reload.size).to eq 0
        end
      end

      context 'start_atがnil' do
        let(:start_at) { Time.zone.now }
        let(:end_at) { Time.zone.now.yesterday }

        it do
          expect(user.billing.plans.reload.size).to eq 0
          expect { subject }.to raise_error(Billing::StrangeParametersError, 'start_atとend_atが間違っている可能性がある。')
          expect(user.billing.plans.reload.size).to eq 0
        end
      end
    end

    describe '#set_bank_transfer_plan' do
      let(:date) { (Time.zone.now + 3.months).to_time.end_of_day }
      let(:user) { create(:user, billing_attrs: { payment_method: nil,
                                                  customer_id: 'aa'} ) }

      before { Timecop.freeze }
      after { Timecop.return }

      it '値が変更されること' do
        expect(user.billing.plans.size).to eq 0
        expect(user.billing.set_bank_transfer_plan(master_test_standard_plan.id, date)).to be_truthy
        expect(user.billing.payment_method).to eq 'bank_transfer'
        expect(user.billing.customer_id).to be_nil
        expect(user.billing.subscription_id).to be_nil

        expect(user.billing.plans.reload.size).to eq 1
        check_plan(master_test_standard_plan, 'ongoing', Time.zone.now, date, Time.zone.today, false)
      end
    end

    describe '#set_invoice_plan' do
      let(:user) { create(:user, billing_attrs: { payment_method: nil,
                                                  customer_id: 'aa'} ) }

      before { Timecop.freeze }
      after  { Timecop.return }

      context 'start_dateが未来' do
        let(:start_date) { Time.zone.now + 2.days }

        it do
          expect(user.billing.plans.size).to eq 0
          expect(user.billing.set_invoice_plan(master_test_standard_plan.id, start_date)).to be_truthy
          expect(user.billing.payment_method).to eq 'invoice'
          expect(user.billing.customer_id).to be_nil
          expect(user.billing.subscription_id).to be_nil

          expect(user.billing.plans.reload.size).to eq 1
          check_plan(master_test_standard_plan, 'waiting', start_date, nil, start_date.to_date, false)
        end
      end

      context 'start_dateが過去' do
        let(:start_date) { Time.zone.now - 4.days }

        it do
          expect(user.billing.plans.size).to eq 0
          expect(user.billing.set_invoice_plan(master_test_standard_plan.id, start_date)).to be_truthy
          expect(user.billing.payment_method).to eq 'invoice'
          expect(user.billing.customer_id).to be_nil
          expect(user.billing.subscription_id).to be_nil

          expect(user.billing.plans.reload.size).to eq 1
          check_plan(master_test_standard_plan, 'ongoing', start_date, nil, start_date.next_month.to_date, false)
        end
      end
    end
  end

  describe 'クラスメソッド' do
    describe '#try_connection' do
      context 'ManyRetryError' do
        it do
          count = 0
          expect {
            described_class.try_connection(0.1, 20) do |i|
              count = i
              { 'error' => { 'status' => 429 } }
            end
          }.to raise_error(Billing::ManyRetryError, 'Error try many times but fail.')
          expect(count).to eq 16
        end
      end

      context 'Success' do
        it do
          count = 0
          expect {
            described_class.try_connection(0.1, 20) do |i|
              count = i
              if i > 8
                { 'success' => true }
              else
                { 'error' => { 'status' => 429 } }
              end
            end
          }.not_to raise_error
          expect(count).to eq 9
        end
      end

      context 'PayJpCardChargeFailureError' do
        it do
          expect {
            described_class.try_connection(0.1, 20) do
              { 'error' => { 'status' => 402 } }
            end
          }.to raise_error(Billing::PayJpCardChargeFailureError, 'カード認証・支払いエラー')
        end
      end

      context 'RetryError' do
        it do
          expect {
            described_class.try_connection(0.1, 20) do
              { 'error' => 'ok' }
            end
          }.to raise_error(Billing::RetryError, 'Error Response Return')
        end
      end
    end

    describe '#get_charges' do
      let(:user)   { create(:user, billing_attrs: { payment_method: nil,
                                                    customer_id: nil })
                   }
       let(:user2) { create(:user, billing_attrs: { payment_method: nil,
                                                    customer_id: nil })
                   }

      after do
        user.billing.delete_customer
        user2.billing.delete_customer
      end

      it do
        card_token = Billing.create_dummy_card_token('4242424242424242', '12', '2040', '123')
        user.billing.create_customer(card_token)

        cha_create_res1 = user.billing.create_charge(1000)
        cha_create_res2 = user.billing.create_charge(2000)
        cha_create_res3 = user.billing.create_charge(3000)

        card_token = Billing.create_dummy_card_token('4242424242424242', '5', '2043', '531')
        user2.billing.create_customer(card_token)

        cha_create_res2_1 = user2.billing.create_charge(1111)
        cha_create_res2_2 = user2.billing.create_charge(2222)
        cha_create_res2_3 = user2.billing.create_charge(3333)

        charges = described_class.get_charges(user.billing.customer_id)

        expect(charges.count).to eq 3

        expect(charges.data[0].id).to eq cha_create_res3.id
        expect(charges.data[0].amount).to eq cha_create_res3.amount
        expect(charges.data[1].id).to eq cha_create_res2.id
        expect(charges.data[1].amount).to eq cha_create_res2.amount
        expect(charges.data[2].id).to eq cha_create_res1.id
        expect(charges.data[2].amount).to eq cha_create_res1.amount

        cha_create_res4 = user.billing.create_charge(4000)

        charges = described_class.get_charges(user.billing.customer_id, 2)

        expect(charges.count).to eq 2

        expect(charges.data[0].id).to eq cha_create_res4.id
        expect(charges.data[0].amount).to eq cha_create_res4.amount
        expect(charges.data[1].id).to eq cha_create_res3.id
        expect(charges.data[1].amount).to eq cha_create_res3.amount

        charges = described_class.get_charges(user2.billing.customer_id, 2)

        expect(charges.count).to eq 2

        expect(charges.data[0].id).to eq cha_create_res2_3.id
        expect(charges.data[0].amount).to eq cha_create_res2_3.amount
        expect(charges.data[1].id).to eq cha_create_res2_2.id
        expect(charges.data[1].amount).to eq cha_create_res2_2.amount
      end
    end
  end
end

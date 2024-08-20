require 'rails_helper'
require 'features/billing/payment_histories_utils'

RSpec.feature "課金 銀行振込", type: :feature do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  let(:mail_address) { 'test@request.com' }
  let(:company_name) { '朝日株式会社' }
  let(:password)     { 'asdf1234' }
  let(:after_months) { rand(36) + 3 }
  let(:exp_day)      { Time.zone.now + after_months.months }
  let(:pay_day)      { Time.zone.now - 1.day }
  let(:comment)      { "#{after_months}ヶ月分" }
  let(:pay_amount)   { 3_000 }

  let!(:user) { create(:user, id: Random.rand(999999), email: mail_address, company_name: company_name, password: password, billing: :free ) }
  let!(:admin_user) { create(:admin_user) }
  let!(:allow_ip) { create(:allow_ip, :admin) }

  before do
    Timecop.freeze(current_time)
    create_public_user
    sign_in admin_user
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
  end

  after do
    ActionMailer::Base.deliveries.clear
    Timecop.return
  end

  scenario '銀行振込 -> 期限がきて -> 銀行振込停止', js: true do
    real_time_now = Time.zone.now
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    expect(user.reload.monthly_histories.size).to eq 0
    sign_in user

    visit root_path
    expect(user.reload.monthly_histories.size).to eq 1

    sign_in admin_user

    #--------------------
    # 
    #  ０ヶ月後
    #  1. 課金を開始する
    # 
    #--------------------
    puts "現在日時: #{Time.zone.now}"

    visit root_path
    click_link '管理者'

    fill_in 'user_id_or_email', with: mail_address
    find('button', text: '送信').click

    fill_in 'expiration_date', with: exp_day.strftime("%Y/%-m/%-d")
    fill_in 'payment_date', with: pay_day.strftime("%Y/%-m/%-d")
    fill_in 'payment_amount', with: pay_amount.to_s
    fill_in 'additional_comment', with: comment
    fill_in 'str_check', with: 'DD'

    find('button', text: '銀行振込 作成').click

    expect(page.driver.browser.switch_to.alert.text).to eq "銀行振込でよろしいですか？"
    page.driver.browser.switch_to.alert.accept # 2回表示されるので
    page.driver.browser.switch_to.alert.accept # 2回表示されるので

    expect(page).to have_content '銀行振込ユーザを作成しました。'

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'
    expect(user.billing.customer_id).to be_nil
    billing_updated_at = user.billing.updated_at

    # current_planの作成チェック
    expect(user.billing.current_plans).to be_present
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'Rspecテスト ライトプラン'
    expect(plan.price).to eq 1000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq Time.zone.now.day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq Time.zone.now.iso8601
    expect(plan.end_at).to eq exp_day.end_of_day.iso8601
    plan_updated_at = plan.updated_at

    expect(user.monthly_histories.reload.size).to eq 1

    # billing_history
    expect(user.billing.histories.size).to eq 1
    history = user.billing.histories[0]
    expect(history.item_name).to eq "#{plan.name} #{comment}"
    expect(history.payment_method).to eq 'bank_transfer'
    expect(history.price).to eq pay_amount
    expect(history.billing_date).to eq pay_day.to_date
    expect(history.unit_price).to eq pay_amount
    expect(history.number).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to eq plan.end_at
    expiration_date = user.reload.expiration_date.dup


    #-----------------
    #  画面の確認
    #-----------------
    expect(page).to have_content company_name
    expect(page).to have_content "#{user.family_name} #{user.given_name}"
    expect(page).to have_content mail_address
    expect(page).to have_content user.department
    expect(page).to have_content I18n.t("enum.user.position.#{user.position}")
    expect(page).to have_content user.tel

    within '#subscription_table' do
      expect(page).to have_content 'bank_transfer'
      expect(page).to have_content user.reload.expiration_date.strftime("%Y年%-m月%-d日 %H:%M:%S")
    end

    plan = user.billing.current_plans[0]
    within '#plans_table' do
      expect(page).to have_content '現在'
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000'
      expect(page).to have_content 'monthly'
      expect(page).to have_content plan.start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")
      expect(page).to have_content plan.end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")
    end

    expect(user.monthly_histories.reload.size).to eq 1


    sign_in user

    visit root_path

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq user.billing.current_plans[0].start_at
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.expiration_date
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at

    Timecop.travel(Time.zone.now + 3.days)

    click_link '設定'

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 2
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    expect(page).to have_selector('h1', text: 'アカウント設定')


    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')

      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).to have_content '今月の課金金額'
      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{Time.zone.now.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '3,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    #--------------------
    # 
    #  １ヶ月後
    #  更新の前日に移動
    #  2. 更新(1)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 2
    expect(his.end_at).to eq Time.zone.now.end_of_day.iso8601
    expect(his.updated_at).to eq last_his_updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    visit root_path


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil


    #--------------------
    # 
    #  １ヶ月後
    #  更新日に移動
    #  2. 更新(1)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 3
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.expiration_date
    expect(user.monthly_histories.first.updated_at).to eq last_his_updated_at
    last_his_updated_at = his.updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil


    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')

      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).not_to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).not_to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 1.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '3,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ２ヶ月後
    #  更新の前日に移動
    #  3. 更新(2)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 3
    expect(his.end_at).to eq Time.zone.now.end_of_day.iso8601
    expect(his.updated_at).to eq last_his_updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil


    #--------------------
    # 
    #  ２ヶ月後
    #  更新日に移動
    #  3. 更新(2)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 4
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.expiration_date
    expect(user.monthly_histories[-2].updated_at).to eq last_his_updated_at
    last_his_updated_at = his.updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil


    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')

      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).not_to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).not_to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '3,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    #--------------------
    # 
    #  有効期限の当日に移動
    #  3. 期限切れ
    # 
    #--------------------
    Timecop.travel(user.expiration_date - 10.minutes)
    Timecop.freeze
    puts "Xヶ月後: #{Time.zone.now} 有効期限の当日に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 5
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq user.monthly_histories[-2].end_at + 1.second
    expect(his.end_at).to eq user.expiration_date
    expect(user.monthly_histories[-2].updated_at).to eq last_his_updated_at
    last_his_updated_at = his.updated_at

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil

    expect(page).to have_selector('h1', text: 'アカウント設定')


    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')

      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{Time.zone.now.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).not_to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  有効期限切れに移動
    #  3. 期限切れ
    # 
    #--------------------
    Timecop.travel(user.expiration_date + 5.minutes)
    Timecop.freeze
    puts "Xヶ月後: #{Time.zone.now} 有効期限切れに移動"

    click_link '設定'

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 6
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day.iso8601
    expect(his.start_at).to eq user.monthly_histories[-2].end_at + 1.second
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    last_his_updated_at = his.updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at
    expect(user.billing.plans.last.status).to eq 'ongoing'

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.updated_at).to eq billing_updated_at


    expect(page).to have_selector('h1', text: 'アカウント設定')

    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'ご登録誠にありがとうございます。'

      expect(page).to have_content 'プラン選択'

      MasterBillingPlan.application_enabled.each do |plan|
        expect(page).to have_content plan.name
        expect(page).to have_content "料金: #{plan.price.to_s(:delimited)}円/月"
      end

      expect(page).to have_content '銀行振込'
      expect(page).to have_content '請求書払い'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content '無料プラン'
      expect(page).not_to have_content 'Rspecテスト ライトプラン'

      expect(page).not_to have_content '課金状況'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限" # 課金ワーカーが走って、課金ステータスが更新されるまでは表示されるが、許容

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).not_to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプランが更新されていること
    expect(user.billing.plans.last.reload.status).to eq 'stopped'
    plan_updated_at = user.billing.plans.last.updated_at

    # billingは更新されること
    expect(user.billing.reload.payment_method).to be_nil
    expect(user.billing.customer_id).to be_nil
    billing_updated_at = user.billing.updated_at


    expect(page).to have_selector('h1', text: 'アカウント設定')

    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'ご登録誠にありがとうございます。'

      expect(page).to have_content 'プラン選択'

      MasterBillingPlan.application_enabled.each do |plan|
        expect(page).to have_content plan.name
        expect(page).to have_content "料金: #{plan.price.to_s(:delimited)}円/月"
      end

      expect(page).to have_content '銀行振込'
      expect(page).to have_content '請求書払い'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content '無料プラン'
      expect(page).not_to have_content 'Rspecテスト ライトプラン'

      expect(page).not_to have_content '課金状況'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).not_to have_content "有効期限"

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).not_to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    #--------------------
    # 
    #  無料プラン後の次の月の前日（月末）
    #  無料プランの更新
    # 
    #--------------------
    Timecop.travel(Time.zone.now.end_of_month - 5.minutes)
    Timecop.freeze
    puts "X＋１ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.size).to eq 6
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.updated_at).to eq billing_updated_at


    #--------------------
    # 
    #  無料プラン後の次の月の月初
    #  無料プランの更新
    # 
    #--------------------
    Timecop.travel(Time.zone.now + 5.minutes)
    Timecop.freeze
    puts "X＋１ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 7
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories[-2].updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.updated_at).to eq billing_updated_at

    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 1

    expect(page).to have_selector('h1', text: 'アカウント設定')

    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'ご登録誠にありがとうございます。'

      expect(page).to have_content 'プラン選択'

      MasterBillingPlan.application_enabled.each do |plan|
        expect(page).to have_content plan.name
        expect(page).to have_content "料金: #{plan.price.to_s(:delimited)}円/月"
      end

      expect(page).to have_content '銀行振込'
      expect(page).to have_content '請求書払い'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content '無料プラン'
      expect(page).not_to have_content 'Rspecテスト ライトプラン'

      expect(page).not_to have_content '課金状況'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).not_to have_content "有効期限"

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).not_to have_content '3,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end

    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).not_to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(pay_day + 2.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(pay_day + 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{pay_day.strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(pay_day - 1.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{pay_day.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '3,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end
  end
end

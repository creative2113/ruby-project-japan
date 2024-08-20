require 'rails_helper'
require 'features/billing/payment_histories_utils'

RSpec.feature "課金 銀行振込", type: :feature do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  let(:mail_address) { 'test@request.com' }
  let(:company_name) { '朝日株式会社' }
  let(:password)     { 'asdf1234' }
  let(:after_months) { 3 }
  let(:exp_day)      { Time.zone.now + after_months.months }
  let(:pay_day)      { Time.zone.now - 1.day }
  let(:comment)      { "#{after_months}ヶ月分" }
  let(:pay_amount)   { 3_000 }

  let!(:user) { create(:user, id: Random.rand(999999), email: mail_address, company_name: company_name, password: password, billing: :free ) }
  let!(:admin_user) { create(:admin_user) }
  let!(:allow_ip) { create(:allow_ip, :admin) }

  before do
    Timecop.freeze Time.zone.now.beginning_of_month + 3.days
    create_public_user
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
  end

  after do
    ActionMailer::Base.deliveries.clear
    Timecop.return
  end

  scenario '銀行振込 -> 期限がきて -> 銀行振込停止', js: true do
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

    expect(page).to have_content '銀行振込ユーザ作成'
    expect(page).not_to have_content '銀行振込継続'

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


    expect(page).not_to have_content '銀行振込ユーザ作成'
    expect(page).to have_content '銀行振込継続'

    within '#plans_table' do
      within "tbody tr:nth-child(2)" do
        expect(page).to have_selector('td:nth-child(1)', text: '現在')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '4')
        expect(page).to have_selector('td:nth-child(6)', text: "#{Time.zone.now.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{exp_day.end_of_day.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end
    end

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

    first_start_at = plan.start_at

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
    #  ３ヶ月後
    #  有効期限の当日に移動
    #  3. 期限切れ直前に更新する
    # 
    #--------------------
    Timecop.travel(user.expiration_date - 10.minutes)
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now} 有効期限の当日に移動"
    puts "###   プランを延長する   ###"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 5
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq user.monthly_histories[-2].end_at + 1.second
    expect(his.end_at).to eq user.reload.expiration_date
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


    #-----------------
    #  管理者に切り替え
    #-----------------
    sign_in admin_user

    visit root_path
    click_link '管理者'

    fill_in 'user_id_or_email', with: mail_address
    find('button', text: '送信').click

    expect(page).not_to have_content '銀行振込ユーザ作成'
    expect(page).to have_content '銀行振込継続'

    within '#plans_table' do
      within "tbody tr:nth-child(2)" do
        expect(page).to have_selector('td:nth-child(1)', text: '現在')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '4')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.current_plans[0].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{Time.zone.now.end_of_day.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end
    end


    exp_day2 = Time.zone.now + 2.months
    pay_day2 = Time.zone.now - 2.days
    comment2 = '2ヶ月'
    pay_amount2 = 2_000


    fill_in 'additional_comment', with: comment2
    fill_in 'expiration_date', with: exp_day2.strftime("%Y/%-m/%-d")
    fill_in 'payment_date', with: pay_day2.strftime("%Y/%-m/%-d")
    fill_in 'payment_amount', with: pay_amount2.to_s
    fill_in 'str_check', with: 'DD'

    find('button', text: '銀行振込 継続').click

    expect(page.driver.browser.switch_to.alert.text).to eq "銀行振込の継続でよろしいですか？"
    page.driver.browser.switch_to.alert.accept # 2回表示されるので
    page.driver.browser.switch_to.alert.accept # 2回表示されるので


    expect(page).to have_content '銀行振込を継続しました。'


    expect(page).not_to have_content '銀行振込ユーザ作成'
    expect(page).to have_content '銀行振込継続'

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'
    expect(user.billing.customer_id).to be_nil
    expect(user.billing.updated_at).to eq billing_updated_at

    # current_planの作成チェック
    expect(user.billing.plans.size).to eq 1
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'Rspecテスト ライトプラン'
    expect(plan.price).to eq 1000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq Time.zone.now.day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq first_start_at.iso8601
    expect(plan.end_at).to eq exp_day2.end_of_day.iso8601
    plan_updated_at = plan.updated_at

    expect(user.monthly_histories.reload.size).to eq 5

    # billing_history
    expect(user.billing.histories.size).to eq 2
    history = user.billing.histories[1]
    expect(history.item_name).to eq "#{plan.name} #{comment2}"
    expect(history.payment_method).to eq 'bank_transfer'
    expect(history.price).to eq pay_amount2
    expect(history.billing_date).to eq pay_day2.to_date
    expect(history.unit_price).to eq pay_amount2
    expect(history.number).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to eq plan.end_at
    expiration_date2 = user.reload.expiration_date.dup


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
      expect(page).to have_content '4'
      expect(page).to have_content plan.start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")
      expect(page).to have_content exp_day2.end_of_day.strftime("%Y年%-m月%-d日 %H:%M:%S")
    end


    #-----------------
    #  ユーザに切り替え
    #-----------------
    sign_in user

    visit root_path
    click_link '設定'

    # monthly_history 変化ないこと
    expect(user.monthly_histories.reload.size).to eq 5


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
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day2.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).to have_content '2,000円'
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
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end


    #--------------------
    # 
    #  ３ヶ月後
    #  期限切れだったはずの当日に移動
    # 
    #--------------------
    Timecop.travel(Time.zone.now + 20.minutes)
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 6
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq user.monthly_histories[-2].end_at + 1.second
    expect(his.start_at).to eq Time.zone.now.beginning_of_day.iso8601
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.reload.expiration_date
    expect(user.monthly_histories[-2].updated_at).to eq last_his_updated_at
    last_his_updated_at = his.updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    visit root_path
    click_link '設定'

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date2
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{exp_day2.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).to have_content '2,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end


    #--------------------
    # 
    #  ４ヶ月後
    #  更新の前日に移動
    #  4. 更新(3)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "４ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 6
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
    expect(user.reload.expiration_date).to eq expiration_date2
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day2.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).not_to have_content '2,000円'
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
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end


    #--------------------
    # 
    #  ４ヶ月後
    #  更新日に移動
    #  4. 更新(3)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "４ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 7
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to eq user.reload.expiration_date
    expect(his.end_at).to eq expiration_date2
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
    expect(user.monthly_histories.reload.size).to eq 7
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 2

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date2
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day2.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  ５ヶ月後
    #  更新の前日に移動
    #  5. 更新(4)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "５ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 7
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
    expect(user.reload.expiration_date).to eq expiration_date2
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day2.strftime("%Y年%-m月%-d日")}"
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
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  ５ヶ月後
    #  有効期限切れに移動
    #  6. 期限切れ
    # 
    #--------------------
    Timecop.travel(user.expiration_date + 5.minutes)
    Timecop.freeze
    puts "５ヶ月後: #{Time.zone.now} 有効期限切れに移動"
    puts "###   プランを延長する   ###"

    click_link '設定'

    # monthly_historyのチェック Freeのmonthly_historyが作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 8
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
      expect(page).not_to have_content '000円'
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
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 5.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '3,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #-----------------
    #  管理者に切り替え
    #-----------------
    sign_in admin_user

    visit root_path
    click_link '管理者'

    fill_in 'user_id_or_email', with: mail_address
    find('button', text: '送信').click

    expect(page).to have_content '銀行振込ユーザ作成'
    expect(page).not_to have_content '銀行振込継続'

    within '#plans_table' do
      within "tbody tr:nth-child(2)" do
        expect(page).to have_selector('td:nth-child(1)', text: '')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '4')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.plans[0].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{user.billing.plans[0].end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end
    end


    exp_day3 = Time.zone.now + 2.months + 2.days
    pay_day3 = Time.zone.now - 2.days
    comment3 = '2ヶ月 - 1'
    pay_amount3 = 2_000


    fill_in 'expiration_date', with: exp_day3.strftime("%Y/%-m/%-d")
    fill_in 'payment_date', with: pay_day3.strftime("%Y/%-m/%-d")
    fill_in 'payment_amount', with: pay_amount3.to_s
    fill_in 'additional_comment', with: comment3
    fill_in 'str_check', with: 'jj'

    find('button', text: '銀行振込 作成').click

    expect(page.driver.browser.switch_to.alert.text).to eq "銀行振込でよろしいですか？"
    page.driver.browser.switch_to.alert.accept # 2回表示されるので
    page.driver.browser.switch_to.alert.accept # 2回表示されるので

    expect(page).to have_content '銀行振込ユーザを作成しました。'


    expect(page).not_to have_content '銀行振込ユーザ作成'
    expect(page).to have_content '銀行振込継続'


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

    within '#plans_table' do
      within "tbody tr:nth-child(2)" do
        expect(page).to have_selector('td:nth-child(1)', text: '現在')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '5')
        expect(page).to have_selector('td:nth-child(6)', text: "#{Time.zone.now.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{exp_day3.end_of_day.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end

      within "tbody tr:nth-child(3)" do
        expect(page).to have_selector('td:nth-child(1)', text: '')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '4')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.plans[0].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{user.billing.plans[0].end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end
    end

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'
    expect(user.billing.customer_id).to be_nil
    expect(user.billing.updated_at).to eq billing_updated_at

    # current_planの作成チェック
    expect(user.billing.plans.size).to eq 2
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'Rspecテスト ライトプラン'
    expect(plan.price).to eq 1000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq Time.zone.now.day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq Time.zone.now.iso8601
    expect(plan.end_at).to eq exp_day3.end_of_day.iso8601
    plan_updated_at = plan.updated_at

    expect(user.monthly_histories.reload.size).to eq 8
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    # billing_history
    expect(user.billing.histories.size).to eq 3
    history = user.billing.histories[2]
    expect(history.item_name).to eq "#{plan.name} #{comment3}"
    expect(history.payment_method).to eq 'bank_transfer'
    expect(history.price).to eq pay_amount3
    expect(history.billing_date).to eq pay_day3.to_date
    expect(history.unit_price).to eq pay_amount3
    expect(history.number).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to eq plan.end_at
    expiration_date3 = user.reload.expiration_date.dup

    #-----------------
    #  ユーザに切り替え
    #-----------------
    sign_in user

    visit root_path
    click_link '設定'

    # monthly_history 新プランのmonthly_historyが作成されていること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 9
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.iso8601
    expect(his.start_at).to eq user.monthly_histories.reload[-2].end_at + 1.second
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.reload.expiration_date
    expect(his.end_at).to be < exp_day3
    expect(user.monthly_histories[-2].end_at).to eq (Time.zone.now - 1.second).iso8601
    last_his_updated_at = his.updated_at


    expect(user.billing.plans.reload[-2].status).to eq 'ongoing'
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # current_planの作成チェック
    expect(user.billing.plans.reload.size).to eq 2
    plan = user.billing.current_plans[0]
    expect(user.billing.current_plans[0].updated_at).to eq plan_updated_at
    expect(user.billing.plans[-2].status).to eq 'stopped'

    # payment_methodはbank_transferのままであること
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'

    #-----------------
    #  画面の確認
    #-----------------
    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')

      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day3.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).to have_content '2,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    #--------------------
    # 
    #  ６ヶ月後
    #  MonthlyHistoryの更新の前日に移動
    #  7. 更新(5)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "６ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 9
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
    expect(user.reload.expiration_date).to eq expiration_date3
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day3.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).not_to have_content '2,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    #--------------------
    # 
    #  ６ヶ月後
    #  MonthlyHistoryの更新日に移動
    #  7. 更新(5)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "６ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 10
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.reload.expiration_date
    expect(his.end_at).to be < exp_day3
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
    expect(user.monthly_histories.reload.size).to eq 10
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 3

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date3
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day3.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  ７ヶ月後
    #  MonthlyHistoryの更新の前日に移動
    #  8. 更新(6)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "７ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 10
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
    expect(user.reload.expiration_date).to eq expiration_date3
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day3.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).not_to have_content '2,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 8.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    #--------------------
    # 
    #  ７ヶ月後
    #  MonthlyHistoryの更新日に移動
    #  8. 更新(6)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "７ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 11
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 2.day).end_of_day.iso8601
    expect(his.end_at).to eq user.reload.expiration_date
    expect(his.end_at).to eq exp_day3.end_of_day.iso8601
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
    expect(user.monthly_histories.reload.size).to eq 11
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 3

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date3
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day3.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end


    #--------------------
    # 
    #  ７ヶ月後
    #  期限切れ直前に移動
    #  8. 期限切れ
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "７ヶ月後: #{Time.zone.now} 期限切れ直前に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 11
    expect(his.end_at).to eq Time.zone.now.end_of_day.iso8601
    expect(his.updated_at).to eq last_his_updated_at
    last_history_end_at = his.end_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'


    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 11
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date3
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day3.strftime("%Y年%-m月%-d日")}"
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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end


    #--------------------
    # 
    #  ７ヶ月後
    #  有効期限切れに移動
    #  8. 期限切れ、ユーザがアクセスしないで、プランを作成する
    #  billingが一旦解除される
    # 
    #--------------------
    Timecop.travel(user.expiration_date + 5.minutes)
    Timecop.freeze
    puts "７ヶ月後: #{Time.zone.now} 有効期限切れに移動"

    # monthly_history 期限が切れていること。変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 11
    expect(user.monthly_histories.last.reload.end_at).to be < Time.zone.now
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at
    expect(user.billing.plans.reload.last.status).to eq 'ongoing'

    # billing まだbank_transferであること
    expect(user.billing.reload.updated_at).to eq billing_updated_at
    expect(user.billing.payment_method).to eq 'bank_transfer'


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 11
    expect(user.monthly_histories.last.reload.end_at).to be < Time.zone.now
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプラン stoppedに変わること
    expect(user.billing.plans.reload.last.status).to eq 'stopped'
    plan_updated_at = user.billing.plans.last.updated_at

    # billing payment_methodがnilに変わること
    expect(user.billing.reload.payment_method).to be_nil
    billing_updated_at = user.billing.updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil


    #--------------------
    # 
    #  ７ヶ月後
    #  有効期限切れに移動
    #  8. 期限切れ、ユーザがアクセスしないで、プランを作成する
    # 
    #--------------------
    Timecop.travel(Time.zone.now + 3.days)
    Timecop.freeze
    puts "７ヶ月後: #{Time.zone.now} 3日後に移動"
    puts "###   プランを延長する   ###"

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 11
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 11
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at
    expect(user.billing.plans.last.status).to eq 'stopped'

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.updated_at).to eq billing_updated_at


    #-----------------
    #  管理者に切り替え
    #-----------------
    sign_in admin_user

    visit root_path
    click_link '管理者'

    fill_in 'user_id_or_email', with: mail_address
    find('button', text: '送信').click

    expect(page).to have_content '銀行振込ユーザ作成'
    expect(page).not_to have_content '銀行振込継続'

    within '#plans_table' do
      within "tbody tr:nth-child(2)" do
        expect(page).to have_selector('td:nth-child(1)', text: '')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '5')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.plans[1].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{user.billing.plans[1].end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end

      within "tbody tr:nth-child(3)" do
        expect(page).to have_selector('td:nth-child(1)', text: '')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '4')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.plans[0].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{user.billing.plans[0].end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end
    end


    exp_day4 = Time.zone.now + 2.months + 4.days
    pay_day4 = Time.zone.now - 3.days
    comment4 = '2ヶ月 - 2'
    pay_amount4 = 2_000


    fill_in 'expiration_date', with: exp_day4.strftime("%Y/%-m/%-d")
    fill_in 'payment_date', with: pay_day4.strftime("%Y/%-m/%-d")
    fill_in 'payment_amount', with: pay_amount4.to_s
    fill_in 'additional_comment', with: comment4
    fill_in 'str_check', with: 'jj'

    find('button', text: '銀行振込 作成').click

    expect(page.driver.browser.switch_to.alert.text).to eq "銀行振込でよろしいですか？"
    page.driver.browser.switch_to.alert.accept # 2回表示されるので
    page.driver.browser.switch_to.alert.accept # 2回表示されるので

    expect(page).to have_content '銀行振込ユーザを作成しました。'


    expect(page).not_to have_content '銀行振込ユーザ作成'
    expect(page).to have_content '銀行振込継続'


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

    within '#plans_table' do
      within "tbody tr:nth-child(2)" do
        expect(page).to have_selector('td:nth-child(1)', text: '現在')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '11')
        expect(page).to have_selector('td:nth-child(6)', text: "#{Time.zone.now.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{exp_day4.end_of_day.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end

      within "tbody tr:nth-child(3)" do
        expect(page).to have_selector('td:nth-child(1)', text: '')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '5')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.plans[1].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{user.billing.plans[1].end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end

      within "tbody tr:nth-child(4)" do
        expect(page).to have_selector('td:nth-child(1)', text: '')
        expect(page).to have_selector('td:nth-child(2)', text: 'Rspecテスト ライトプラン')
        expect(page).to have_selector('td:nth-child(3)', text: '1,000')
        expect(page).to have_selector('td:nth-child(4)', text: 'monthly')
        expect(page).to have_selector('td:nth-child(5)', text: '4')
        expect(page).to have_selector('td:nth-child(6)', text: "#{user.billing.plans[0].start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
        expect(page).to have_selector('td:nth-child(7)', text: "#{user.billing.plans[0].end_at.strftime("%Y年%-m月%-d日 %H:%M:%S")}")
      end
    end

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'
    expect(user.billing.customer_id).to be_nil
    billing_updated_at = user.billing.updated_at

    # current_planの作成チェック
    expect(user.billing.plans.size).to eq 3
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'Rspecテスト ライトプラン'
    expect(plan.price).to eq 1000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq Time.zone.now.day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq Time.zone.now.iso8601
    expect(plan.end_at).to eq exp_day4.end_of_day.iso8601
    expect(user.billing.plans.reload[-2].end_at).to eq exp_day3.end_of_day.iso8601
    plan_updated_at = plan.updated_at

    expect(user.monthly_histories.reload.size).to eq 11
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    # billing_history
    expect(user.billing.histories.size).to eq 4
    history = user.billing.histories[3]
    expect(history.item_name).to eq "#{plan.name} #{comment4}"
    expect(history.payment_method).to eq 'bank_transfer'
    expect(history.price).to eq pay_amount4
    expect(history.billing_date).to eq pay_day4.to_date
    expect(history.unit_price).to eq pay_amount4
    expect(history.number).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to eq plan.end_at
    expiration_date4 = user.reload.expiration_date.dup

    #--------------------
    # 
    #  ７ヶ月後
    #  有効期限切れに移動
    #  8. 期限切れ、ユーザがアクセスしないで、プランを作成する
    # 
    #--------------------
    Timecop.travel(Time.zone.now + 1.days)
    Timecop.freeze
    puts "７ヶ月後: #{Time.zone.now} 初めてのユーザアクセス"

    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 11
    expect(user.monthly_histories.last.reload.updated_at).to eq last_his_updated_at
    expect(user.monthly_histories.last.plan).to eq EasySettings.plan[:test_light]

    #-----------------
    #  ユーザに切り替え
    #-----------------
    sign_in user

    visit root_path
    click_link '設定'

    # monthly_history 新プランのmonthly_historyが作成されていること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 12
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq user.billing.current_plans[0].start_at
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.reload.expiration_date
    expect(his.end_at).to be < exp_day4
    expect(user.monthly_histories[-2].end_at).to eq last_history_end_at
    last_his_updated_at = his.updated_at

    expect(user.billing.reload.payment_method).to eq 'bank_transfer'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # current_planの作成チェック
    expect(user.billing.plans.reload.size).to eq 3
    expect(user.billing.current_plans[0].updated_at).to eq plan_updated_at

    # payment_methodはbank_transferのままであること
    expect(user.billing.reload.payment_method).to eq 'bank_transfer'

    #-----------------
    #  画面の確認
    #-----------------
    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')

      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day4.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).to have_content '2,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 8.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[3])
    end

    #--------------------
    # 
    #  ８ヶ月後
    #  MonthlyHistoryの更新の前日に移動
    #  8. 更新(6)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "８ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 12
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
    expect(user.reload.expiration_date).to eq expiration_date4
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day4.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).not_to have_content '2,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 8.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 9.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[3])
    end

    #--------------------
    # 
    #  ８ヶ月後
    #  MonthlyHistoryの更新日に移動
    #  8. 更新(6)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "６ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 13
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to be < user.reload.expiration_date
    expect(his.end_at).to be < exp_day4
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
    expect(user.monthly_histories.reload.size).to eq 13
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 4

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date4
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day4.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end


    #--------------------
    # 
    #  ９ヶ月後
    #  MonthlyHistoryの更新の前日に移動
    #  9. 更新(7)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "９ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 13
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
    expect(user.reload.expiration_date).to eq expiration_date4
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{user.reload.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).to have_content "有効期限　　　　#{exp_day4.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).not_to have_content '2,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 8.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 9.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 10.month).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[3])
    end

    #--------------------
    # 
    #  ９ヶ月後
    #  MonthlyHistoryの更新日に移動
    #  9. 更新(7)
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at + 5.minutes
    Timecop.freeze
    puts "９ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 14
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 4.days).end_of_day.iso8601
    expect(his.end_at).to eq user.reload.expiration_date
    expect(his.end_at).to eq exp_day4.end_of_day.iso8601
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
    expect(user.monthly_histories.reload.size).to eq 14
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.size).to eq 4

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date4
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day4.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end


    #--------------------
    # 
    #  ９ヶ月後
    #  期限切れ直前に移動
    #  10. 期限切れ
    # 
    #--------------------
    Timecop.travel MonthlyHistory.find_around(user).reload.end_at - 1.minutes
    Timecop.freeze
    puts "９ヶ月後: #{Time.zone.now} 期限切れ直前に移動"

    click_link '設定'


    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 14
    expect(his.end_at).to eq Time.zone.now.end_of_day.iso8601
    expect(his.updated_at).to eq last_his_updated_at
    last_history_end_at = his.end_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'


    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 14
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date4
    expect(user.next_planned_expiration_date).to be_nil

    #-----------------
    #  画面の確認
    #-----------------
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
      expect(page).to have_content "有効期限　　　　#{exp_day4.strftime("%Y年%-m月%-d日")}"
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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).not_to have_content '000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  ９ヶ月後
    #  有効期限切れに移動
    #  11. 期限切れ
    #  billingが一旦解除される
    # 
    #--------------------
    Timecop.travel(user.expiration_date + 5.minutes)
    Timecop.freeze
    puts "９ヶ月後: #{Time.zone.now} 有効期限切れに移動"

    # monthly_history 期限が切れていること。変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 14
    expect(user.monthly_histories.last.reload.end_at).to be < Time.zone.now
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at
    expect(user.billing.plans.reload.last.status).to eq 'ongoing'

    # billing まだbank_transferであること
    expect(user.billing.reload.updated_at).to eq billing_updated_at
    expect(user.billing.payment_method).to eq 'bank_transfer'


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 14
    expect(user.monthly_histories.last.reload.end_at).to be < Time.zone.now
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans).to be_blank

    # ラストプラン stoppedに変わること
    expect(user.billing.plans.reload.last.status).to eq 'stopped'
    plan_updated_at = user.billing.plans.last.updated_at

    # billing payment_methodがnilに変わること
    expect(user.billing.reload.payment_method).to be_nil
    billing_updated_at = user.billing.updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    expiration_day = Time.zone.now


    #--------------------
    # 
    #  ９ヶ月後
    #  有効期限切れに移動
    #  8. 期限切れ
    # 
    #--------------------
    Timecop.travel(Time.zone.now + 4.days)
    Timecop.freeze
    puts "９ヶ月後: #{Time.zone.now} 4日後に移動"

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 14
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear


    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user)).to be_nil
    expect(user.monthly_histories.size).to eq 14
    expect(user.monthly_histories.last.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans.reload).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at
    expect(user.billing.plans.last.status).to eq 'stopped'

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.reload.updated_at).to eq billing_updated_at


    click_link '設定'

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 15
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq user.billing.plans.last.reload.end_at.tomorrow.beginning_of_day.iso8601
    expect(his.start_at).to eq user.monthly_histories[-2].end_at + 1.second
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    last_his_updated_at = his.updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans.reload).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.reload.updated_at).to eq billing_updated_at


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
      expect(page).not_to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).not_to have_content '000円'
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
    puts "１０ヶ月後: #{Time.zone.now}に移動"

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.size).to eq 15
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans.reload).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.reload.updated_at).to eq billing_updated_at


    #--------------------
    # 
    #  無料プラン後の次の月の月初
    #  無料プランの更新
    # 
    #--------------------
    Timecop.travel(Time.zone.now + 5.minutes)
    Timecop.freeze
    puts "１０ヶ月後: #{Time.zone.now}に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 16
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories[-2].updated_at).to eq last_his_updated_at

    # current_plan 存在しないこと
    expect(user.billing.current_plans.reload).to be_blank

    # ラストプラン 変化がないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil

    # billing
    expect(user.billing.reload.updated_at).to eq billing_updated_at

    # billing_histories 変化がないこと
    expect(user.billing.histories.reload.size).to eq 4

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
      expect(page).not_to have_content "Rspecテスト ライトプラン"
      expect(page).not_to have_content '000円'
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
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 6.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 8.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 9.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 10.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 11.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 3.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment4}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[3])
    end

    find("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 5.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.histories[2].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment3}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    find("input[value='#{(Time.zone.now - 7.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 7.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.histories[1].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment2}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '2,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 10.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 10.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content "Rspecテスト ライトプラン #{comment}"
      expect(page).to have_content '銀行振込'
      expect(page).to have_content '3,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end
  end
end

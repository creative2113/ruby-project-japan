require 'rails_helper'
require 'features/billing/payment_histories_utils'

RSpec.feature "課金開始から課金停止まで", type: :feature do

  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  let(:mail_address)      { 'test@request.com' }
  let(:company_name)      { 'ひまわり株式会社' }
  let(:password)          { 'asdf1234' }
  let(:card_exp_month)    { '11' }
  let(:card_exp_year)     { (Time.zone.now.year + 2).to_s }
  let(:card_exp_year_str) { card_exp_year[-2..-1] }
  let(:card_name)         { 'TANAKA TAKAHIRO' }

  let(:user) { create(:user, id: Random.rand(999999), email: mail_address, company_name: company_name, password: password, billing: :free ) }

  before do
    Timecop.freeze
    sign_in user
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])
  end

  after do
    ActionMailer::Base.deliveries.clear
    user.billing.delete_customer if user.billing.reload.customer_id.present?
    Timecop.return
  end

  def check_billing_data_row_in_configure_page(row_num, data_history = nil)
    if row_num == 1
      within 'table tbody tr:first-child' do
        expect(page).to have_content '課金日'
        expect(page).to have_content '項目名'
        expect(page).to have_content '金額'
      end
    else
      within "table tbody tr:nth-child(#{row_num})" do
        expect(page).to have_selector('td:nth-child(1)', text: data_history.billing_date.strftime("%Y年%-m月%-d日"))
        expect(page).to have_selector('td:nth-child(2)', text: data_history.item_name)
        expect(page).to have_selector('td:nth-child(3)', text: "#{data_history.price.to_s(:delimited)}円")
      end
    end
  end

  scenario '課金 -> 更新 × 3 -> 停止(ユーザからの確認)、課金登録できないこと -> 期限がきて -> freeプランになる(ユーザからの確認) -> 次の月初に更新', js: true do
    real_time_now = Time.zone.now
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    #--------------------
    # 
    #  ０ヶ月後
    #  1. 課金を開始する
    # 
    #--------------------
    puts "現在日時: #{Time.zone.now}"

    user.reload


    visit root_path
    click_link '設定'

    Timecop.travel Time.zone.now + 5.minutes
    Timecop.freeze

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 1
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_month
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601

    # current_planのチェック
    expect(user.billing.current_plans).to be_blank

    # 期限日
    expect(user.expiration_date).to be_nil


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
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content '無料プラン'

      expect(page).not_to have_content '課金状況'
      expect(page).not_to have_content '有効期限'
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    expect(page).not_to have_content '課金、請求履歴'

    expect(page).to have_selector('.card-title-band', text: 'ユーザ情報の変更')

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end

    expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')

    # クリックできないことを確認
    expect { find('#payjp_checkout_box input[type=button]').click }.to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)

    #-------------
    #  プラン登録
    #-------------
    find('span', text: I18n.t("plan.test_standard")).click

    # パスワード間違える
    fill_in 'password_for_plan_registration', with: '11asf'

    find('#payjp_checkout_box input[type=button]').click

    switch_to_frame find('#payjp-checkout-iframe')

    expect(page).to have_content '支払い情報'

    fill_in 'cardnumber', with: '4242424242424242'
    fill_in 'ccmonth', with: card_exp_month
    fill_in 'ccyear', with: card_exp_year_str
    fill_in 'cvc', with: '252'
    fill_in 'ccname', with: card_name


    find('input#payjp_cardSubmit').click

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content 'パスワードが間違っています。'

    expect(page).not_to have_content '課金、請求履歴'

    expect(ActionMailer::Base.deliveries.size).to eq(0)


    # 決済アカウント作成されていないこと確認！！

    expect(user.billing.reload.payment_method).to be_nil
    expect(user.billing.customer_id).to be_nil
    expect(user.billing.subscription_id).to be_nil
    expect(user.billing.search_customer(1, -1)).to be_nil

    # current_planのチェック
    expect(user.billing.current_plans).to be_blank

    # billing_historyのチェック
    expect(user.billing.histories).to be_blank

    # 期限日
    expect(user.expiration_date).to be_nil


    find('span', text: I18n.t("plan.test_standard")).click

    # 正しいパスワード入力
    fill_in 'password_for_plan_registration', with: password

    find('#payjp_checkout_box input[type=button]').click

    switch_to_frame find('#payjp-checkout-iframe')

    expect(page).to have_content '支払い情報'

    fill_in 'cardnumber', with: '4242424242424242'
    fill_in 'ccmonth', with: card_exp_month
    fill_in 'ccyear', with: card_exp_year_str
    fill_in 'cvc', with: '252'
    fill_in 'ccname', with: card_name

    find('input#payjp_cardSubmit').click

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content '決済が完了いたしました。ご利用誠にありがとうございます。'

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランへの登録が完了致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{user.family_name} 様/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン登録が完了しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト スタンダード/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/料金: 3,000円/)

    ActionMailer::Base.deliveries.clear


    # 決済アカウント作成されていること確認！！

    #-----------------
    #  PAYJP 登録確認
    #-----------------
    expect(user.billing.reload.customer_id).to be_present
    expect(user.billing.search_customer(1, -1)).to be_present

    payjp_res = user.billing.get_customer_info
    # カード
    expect(payjp_res.cards.count).to eq 1
    expect(payjp_res.cards.data[0].brand).to eq 'Visa'
    expect(payjp_res.cards.data[0].exp_month).to eq card_exp_month.to_i
    expect(payjp_res.cards.data[0].exp_year).to eq card_exp_year.to_i
    expect(payjp_res.cards.data[0].last4).to eq '4242'
    expect(payjp_res.cards.data[0].name).to eq card_name
    # メタデータ
    expect(payjp_res.metadata.company_name).to eq company_name
    expect(payjp_res.metadata.user_id).to eq user.id.to_s

    payjp_res = user.billing.get_charges
    # 課金
    expect(payjp_res.count).to eq 1
    expect(payjp_res.data[0].amount).to eq 3000
    expect(payjp_res.data[0].customer).to eq user.billing.reload.customer_id
    expect(Time.at(payjp_res.data[0].created)).to be > real_time_now - 2.minute

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'credit'
    expect(user.billing.customer_id).to be_present
    billing_updated_at = user.billing.updated_at

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:test_standard]
    expect(his.start_at).to eq Time.zone.now.iso8601
    expect(his.start_at).to eq user.billing.reload.current_plans[0].start_at.iso8601
    expect(his.end_at).to eq user.expiration_date.iso8601
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at

    # current_planの作成チェック
    expect(user.billing.current_plans).to be_present
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'Rspecテスト スタンダードプラン'
    expect(plan.price).to eq 3000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq Time.zone.now.day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq Time.zone.now.iso8601
    expect(plan.end_at).to be_nil
    if Time.zone.today.day == Time.zone.today.next_month.day
      expect(plan.next_charge_date).to eq Time.zone.today.next_month
    else
      expect(plan.next_charge_date).to eq Time.zone.today.next_month.tomorrow
    end
    expect(plan.last_charge_date).to eq Time.zone.today
    plan_updated_at = plan.updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 1
    b_his = user.billing.histories.last
    expect(b_his.item_name).to eq 'Rspecテスト スタンダードプラン'
    expect(b_his.payment_method).to eq 'credit'
    expect(b_his.price).to eq 3000
    expect(b_his.billing_date).to eq Time.zone.today
    expect(b_his.unit_price).to eq 3000
    expect(b_his.number).to eq 1
    last_b_his_updated_at = b_his.updated_at

    # 期限日
    if Time.zone.today.day == Time.zone.today.next_month.day
      expect(user.expiration_date).to eq Time.zone.today.next_month.yesterday.end_of_day
    else
      expect(user.expiration_date).to eq Time.zone.today.next_month.tomorrow.yesterday.end_of_day
    end

    #-----------------
    #  画面確認
    #-----------------
    within '#change_plan_card' do
      expect(page).to have_selector('.card-title-band', text: 'プラン、カード情報の変更')

      expect(page).to have_content '課金プラン、カード情報の変更はこちら'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト スタンダードプラン'

      user.billing.reload
      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '有効期限'
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/500"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/20"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).to have_content '今月の課金金額'
      check_billing_data_row_in_configure_page(1)
      check_billing_data_row_in_configure_page(2, user.billing.histories[0])
      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
    end


    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    expect(page).not_to have_selector("input[value='#{Time.zone.now.next_month.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{Time.zone.now.last_month.strftime("%Y年%-m月")}']")

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{Time.zone.now.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row_in_payment_histories_page(1)
        check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
      end
    end

    click_link '設定'

    click_link '課金プラン、カード情報の変更はこちら'


    expect(page).to have_selector('h1', text: 'プラン、カード情報変更')

    within '#change_card' do
      expect(page).to have_selector('.card-title-band', text: 'カード情報の変更')

      expect(page).to have_content '現在の登録カード'
      expect(page).to have_content 'Visa'
      expect(page).to have_content '4242'

      expect(page).to have_selector('#payjp_checkout_box input[value="カード変更"]')
    end


    within '#modify_plan' do
      expect(page).to have_selector('.card-title-band', text: 'プラン変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    within '#stop_plan' do
      expect(page).to have_selector('.card-title-band', text: '課金停止')
      expect(page).to have_content '課金を停止後、有効期限内は同プランでご使用できます。有効期限後から、無料プランユーザとなります。'
      expect(page).to have_content 'また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなります。'
      expect(page).to have_content "有効期限: #{user.expiration_date.strftime("%Y年%-m月%-d日")}"
    end

    #--------------------
    # 
    #  １ヶ月後
    #  更新の前日に移動
    #  2. 更新(1)
    # 
    #--------------------
    Timecop.travel user.expiration_date.beginning_of_day + 3.hours
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now}に移動"

    visit root_path
    click_link '設定'

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 2
    expect(his.end_at).to eq Time.zone.now.end_of_day.iso8601
    expect(his.updated_at).to eq last_his_updated_at

    # 課金に変化がないこと
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 1

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    sleep 2

    # 課金に変化がないこと
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 1

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    visit root_path

    # monthly_history 変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    # 期限日
    expect(user.expiration_date).to eq Time.zone.now.end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    #--------------------
    # 
    #  １ヶ月後
    #  更新の当日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date.tomorrow.beginning_of_day + 3.hours
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now}に移動"

    visit root_path
    click_link '設定'
    click_link '課金プラン、カード情報の変更はこちら'


    # 新しいmonthly_histryができる
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 3
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to be > Time.zone.now + 27.days
    last_his_updated_at = his.updated_at

    # current_planは変化がないこと
    expect(user.billing.current_plans[0].reload.updated_at).to eq plan_updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 1

    # 期限日
    expect(user.expiration_date).to eq Time.zone.yesterday.end_of_day
    expect(user.next_planned_expiration_date).to be > Time.zone.now + 27.days


    # 課金停止を試みる
    within '#stop_plan' do
      expect(page).to have_selector('.card-title-band', text: '課金停止')

      expect(page).to have_content '有効期限'
      expect(page).to have_content user.expiration_date.strftime("%Y年%-m月%-d日")

      fill_in 'password_for_plan_stop', with: password

      find('#stop_subscription', text: '課金停止').click

      expect(page.driver.browser.switch_to.alert.text).to eq "課金を停止してもよろしいですか？"
      page.driver.browser.switch_to.alert.accept
    end

    expect(page).to have_content '課金の更新日が過ぎているため、今の時間は停止できません。申し訳ありませんが、課金の更新処理が完了するまでお待ちください。更新処理は1日以内に完了する予定です。'



    #--------------------
    # 
    #  １ヶ月後
    #  課金バッチを回す
    # 
    #--------------------
    BillingWorker.all_execute

    plan = user.billing.current_plans[0]

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}, CHARGE_DATE: #{plan.charge_date}, AMOUNT: #{plan.price.to_s(:delimited)}円/)
    ActionMailer::Base.deliveries.clear


    # 課金されること
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 2

    expect(payjp_res.data[0].amount).to eq 3000
    expect(payjp_res.data[0].customer).to eq user.billing.reload.customer_id
    expect(Time.at(payjp_res.data[0].created)).to be > real_time_now - 2.minute
    expect(Time.at(payjp_res.data[0].created)).to be > Time.at(payjp_res.data[1].created)

    # monthly_historyには変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 3
    expect(his.updated_at).to eq last_his_updated_at

    # 期限日は1ヶ月後になっていること
    expect(user.expiration_date).to be > Time.zone.now + 27.days
    expect(user.next_planned_expiration_date).to be_nil

    # current_planは更新されていること
    plan = user.billing.current_plans[0].reload
    expect(plan.next_charge_date).to be > Time.zone.now + 27.days
    expect(plan.next_charge_date).to eq user.expiration_date.tomorrow.to_date
    expect(plan.last_charge_date).to eq Time.zone.today
    expect(plan.end_at).to be_nil
    plan_updated_at = plan.updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 2
    b_his = user.billing.histories.last
    expect(b_his.item_name).to eq 'Rspecテスト スタンダードプラン'
    expect(b_his.payment_method).to eq 'credit'
    expect(b_his.price).to eq 3000
    expect(b_his.billing_date).to eq Time.zone.today
    expect(b_his.unit_price).to eq 3000
    expect(b_his.number).to eq 1

    click_link '設定'

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).to have_content '今月の課金金額'
      check_billing_data_row_in_configure_page(1)
      check_billing_data_row_in_configure_page(2, user.billing.histories[1])
      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    #--------------------
    # 
    #  ２ヶ月後
    #  更新の前日に移動
    #  3. 更新(2)
    # 
    #--------------------
    Timecop.travel user.expiration_date.beginning_of_day + 3.hours
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now}に移動"

    visit root_path
    click_link '設定'

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 3
    expect(his.end_at).to be > Time.zone.now
    expect(his.updated_at).to eq last_his_updated_at

    plan_updated_at = user.billing.current_plans[0].updated_at

    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 2

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # 課金されていないこと 変化がないこと
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 2

    # current_planには変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # monthly_historyには変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    # 期限日は今日になっていること
    expect(user.expiration_date).to eq Time.zone.now.end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    visit root_path

    # monthly_historyには変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at


    #--------------------
    # 
    #  ２ヶ月後
    #  更新の当日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date.tomorrow.beginning_of_day + 3.hours
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now}に移動"


    # monthly_histryが終了すること
    # 新しいmonthly_histryはまだ作成されていないこと（サイトに訪れていないので）
    expect(user.monthly_histories.size).to eq 3
    expect(MonthlyHistory.get_last(user).updated_at).to eq last_his_updated_at
    expect(MonthlyHistory.find_around(user)).to be_nil

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 2

    # 期限日
    expect(user.expiration_date).to eq Time.zone.now.yesterday.end_of_day
    expect(user.next_planned_expiration_date).to be > Time.zone.now + 27.days

    click_link '設定'
    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    # 次のMonthlyHistoryが作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 4
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to be > Time.zone.now + 27.days
    last_his_updated_at = his.updated_at


    #--------------------
    # 
    #  ２ヶ月後
    #  課金バッチを回す
    # 
    #--------------------
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}, CHARGE_DATE: #{plan.charge_date}, AMOUNT: #{plan.price.to_s(:delimited)}円/)
    ActionMailer::Base.deliveries.clear

    # 課金されること
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 3

    expect(payjp_res.data[0].amount).to eq 3000
    expect(payjp_res.data[0].customer).to eq user.billing.reload.customer_id
    expect(Time.at(payjp_res.data[0].created)).to be > real_time_now - 2.minute
    expect(Time.at(payjp_res.data[0].created)).to be > Time.at(payjp_res.data[1].created)
    expect(Time.at(payjp_res.data[1].created)).to be > Time.at(payjp_res.data[2].created)

    # MonthlyHistoryの確認
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.get_last(user).updated_at).to eq last_his_updated_at

    # current_planは更新されていること
    plan = user.billing.current_plans[0].reload
    expect(plan.next_charge_date).to be > Time.zone.now + 27.days
    expect(plan.next_charge_date).to eq user.expiration_date.tomorrow.to_date
    expect(plan.last_charge_date).to eq Time.zone.today
    expect(plan.end_at).to be_nil
    plan_updated_at = plan.updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3
    b_his = user.billing.histories.last
    expect(b_his.item_name).to eq 'Rspecテスト スタンダードプラン'
    expect(b_his.payment_method).to eq 'credit'
    expect(b_his.price).to eq 3000
    expect(b_his.billing_date).to eq Time.zone.today
    expect(b_his.unit_price).to eq 3000
    expect(b_his.number).to eq 1

    # 期限日は1ヶ月後になっていること
    expect(user.expiration_date).to be > Time.zone.now + 27.days
    expect(user.next_planned_expiration_date).to be_nil

    visit root_path
    click_link '設定'

    # 次のMonthlyHistoryが作成されること
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.get_last(user).updated_at).to eq last_his_updated_at

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).to have_content '今月の課金金額'
      check_billing_data_row_in_configure_page(1)
      check_billing_data_row_in_configure_page(2, user.billing.histories[2])
      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end


    #--------------------
    # 
    #  ３ヶ月後
    #  更新の前日に移動
    #  3. 課金停止
    # 
    #--------------------
    Timecop.travel user.expiration_date.beginning_of_day + 3.hours
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now}に移動"

    visit root_path

    # monthly_historyには変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 4
    expect(his.end_at).to be > Time.zone.now
    expect(his.updated_at).to eq last_his_updated_at

    # plan_updated_at = user.billing.current_plans[0].updated_at

    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 3

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # 課金されていないこと 変化がないこと
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 3

    # current_planには変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日は当日になっていること
    expect(user.expiration_date).to eq Time.zone.now.end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    # monthly_historyには変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    visit root_path
    click_link '設定'

    # monthly_historyには変化がないこと
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end


    #--------------------
    # 
    #  ３ヶ月後
    #  更新の前日
    #  課金を停止する
    # 
    #--------------------
    click_link '課金プラン、カード情報の変更はこちら'

    within '#stop_plan' do
      expect(page).to have_selector('.card-title-band', text: '課金停止')

      expect(page).to have_content '有効期限'
      expect(page).to have_content user.expiration_date.strftime("%Y年%-m月%-d日")

      # パスワードを間違える
      fill_in 'password_for_plan_stop', with: '113121'

      find('#stop_subscription', text: '課金停止').click

      expect(page.driver.browser.switch_to.alert.text).to eq "課金を停止してもよろしいですか？"
      page.driver.browser.switch_to.alert.accept
    end

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content 'パスワードが間違っています。'

    expect(ActionMailer::Base.deliveries.size).to eq(0)

    # 停止されていないことを確認！！
    expect(user.billing.search_customer(500, -1)).to be_present
    expect(user.billing.get_customer_info).to be_present

    customer_id = user.billing.customer_id.dup # 停止後に利用する


    within '#stop_plan' do
      fill_in 'password_for_plan_stop', with: password

      find('#stop_subscription', text: '課金停止').click

      page.driver.browser.switch_to.alert.accept
    end

    sleep 3


    expect(page).to have_content '課金停止が完了しました。'

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランの定期更新を停止致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{user.family_name} 様/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト スタンダードプラン/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限: #{user.billing.reload.expiration_date&.strftime("%Y年%-m月%-d日")}/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)

    ActionMailer::Base.deliveries.clear

    # 停止されていることを確認！！
    res = user.billing.search_customer(500, -1)
    if res.present?
      sleep 3
      res = user.billing.search_customer(500, -1)
    end
    expect(res).to be_nil
    expect{ Billing.get_customer_info(customer_id) }.to raise_error(Payjp::InvalidRequestError, /No such customer:/)

    # current_planが更新されていること
    plan = user.billing.current_plans[0].reload
    expect(plan.end_at).to eq user.billing.current_plans[0].next_charge_date.yesterday.end_of_day.iso8601
    expect(plan.end_at).to eq Time.zone.now.end_of_day.iso8601
    expect(plan.end_at).to eq MonthlyHistory.find_around(user).end_at
    expect(plan.status).to eq 'ongoing'
    last_plan_updated_at = plan.updated_at

    # monthly_historyが更新されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 4
    expect(his.plan).to eq EasySettings.plan[:test_standard]
    expect(his.end_at).to eq user.billing.current_plans[0].end_at
    expect(his.end_at).to eq user.reload.expiration_date
    last_his_updated_at = his.updated_at

    # billingは更新されること
    expect(user.billing.payment_method).to eq 'credit'
    expect(user.billing.customer_id).to be_nil

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日は当日になっていること
    expect(user.expiration_date).to eq Time.zone.now.end_of_day.iso8601
    expect(user.next_planned_expiration_date).to be_nil


    expect(page).to have_selector('h1', text: 'アカウント設定')

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')
    expect(page).not_to have_selector('.card-title-band', text: '課金プラン、カード情報の変更')


    #-------------------
    #  課金停止を確認する
    #-------------------
    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　0/500"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/20"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    #-------------------
    #  有効期限切れの直前
    #-------------------
    Timecop.travel(user.expiration_date - 10.minutes)
    Timecop.freeze
    puts "有効期限切れの直前: #{Time.zone.now}に移動"

    # 課金ワーカーを実行 => 何も変化はないこと
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'


    # current_planは変わっていないこと
    expect(user.billing.current_plans[0].reload.updated_at).to eq last_plan_updated_at

    # billingの課金方法は変わっていないこと
    expect(user.billing.reload.payment_method).to eq 'credit'

    # monthly_historyは変わっていないこと
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日は当日になっていること
    expect(user.expiration_date).to eq Time.zone.now.end_of_day.iso8601
    expect(user.next_planned_expiration_date).to be_nil


    expect(page).to have_selector('h1', text: 'アカウント設定')

    # within '#plan_registration' do
      expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')
      expect(page).not_to have_content '有効期限内はプランの再登録ができません。'
    # end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　0/500"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/20"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    #-------------------
    #  有効期限が過ぎた
    #-------------------
    Timecop.travel(user.expiration_date + 1.minutes)
    Timecop.freeze
    puts "有効期限切れ: #{Time.zone.now}に移動"

    click_link '設定'

    # monthly_historyが新しく作成されていること
    expect(user.monthly_histories.size).to eq 5
    his = MonthlyHistory.find_around(user)
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    last_his_updated_at = his.updated_at

    # billingは変わっていないこと
    expect(user.billing.payment_method).to eq 'credit'
    expect(user.billing.customer_id).to be_nil

    # current_planは消えていること
    expect(user.billing.current_plans).to be_blank

    # ラストプランは更新されていないこと
    last_plan = user.billing.plans.last.reload
    expect(last_plan.status).to eq 'ongoing'
    expect(last_plan.updated_at).to eq last_plan_updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日
    expect(user.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil



    expect(page).to have_selector('h1', text: 'アカウント設定')

    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'ご登録誠にありがとうございます。'

      expect(page).to have_content 'プラン選択'

      Billing.plan_list.each do |plan|
        expect(page).to have_content I18n.t("plan.#{plan}")
        expect(page).to have_content "料金: #{EasySettings.amount[plan].to_s(:delimited)}円/月"
      end

      expect(page).to have_content '銀行振込'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content '無料プラン'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).not_to have_content '課金状況'
      expect(page).not_to have_content '有効期限'
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    # 更新前のチェック
    expect(user.billing.plans.reload.last.reload.status).to eq 'ongoing'
    expect(user.billing.reload.payment_method).to eq 'credit'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # current_planは消えていること
    expect(user.billing.current_plans).to be_blank

    # ラストプランが更新されていること
    expect(user.billing.plans.last.reload.status).to eq 'stopped'

    # billingは更新されること
    expect(user.billing.reload.payment_method).to be_nil
    expect(user.billing.customer_id).to be_nil

    # monthly_historyは変わっていないこと
    expect(user.monthly_histories.size).to eq 5
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日
    expect(user.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil


    # 実際の課金の確認
    payjp_res = Billing.get_charges(customer_id)
    expect(payjp_res.count).to eq 3

    expect(payjp_res.data[0].amount).to eq 3000
    expect(payjp_res.data[0].customer).to eq customer_id
    expect(payjp_res.data[1].amount).to eq 3000
    expect(payjp_res.data[1].customer).to eq customer_id
    expect(payjp_res.data[2].amount).to eq 3000
    expect(payjp_res.data[2].customer).to eq customer_id


    #--------------------
    # 
    #  ３ヶ月後の
    #  月末に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month - 1.minutes
    Timecop.freeze
    puts "３ヶ月後の月末: #{Time.zone.now}に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # monthly_historyは変わっていないこと
    expect(user.monthly_histories.size).to eq 5
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_planは存在しないこと
    expect(user.billing.current_plans).to be_blank

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日
    expect(user.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    # 実際の課金の確認
    payjp_res = Billing.get_charges(customer_id)
    expect(payjp_res.count).to eq 3

    click_link '設定'
    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_selector ('table')
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_selector('a', text: '過去の課金、請求履歴')
    end


    #--------------------
    # 
    #  ３ヶ月後の
    #  月初に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now + 2.minutes
    Timecop.freeze
    puts "３ヶ月後の月初: #{Time.zone.now}に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    # monthly_historyが更新されること
    expect(user.monthly_histories.size).to eq 6
    his = MonthlyHistory.find_around(user)
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories.last(2)[0].updated_at).to eq last_his_updated_at
    expect(user.monthly_histories.last(2)[0].end_at).to be < his.start_at

    # current_planは存在しないこと
    expect(user.billing.current_plans).to be_blank

    # billing_historyのチェック
    expect(user.billing.histories.size).to eq 3

    # 期限日
    expect(user.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    # 実際の課金は変化ないこと
    payjp_res = Billing.get_charges(customer_id)
    expect(payjp_res.count).to eq 3

    #---------------
    # 課金履歴の確認
    #---------------
    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    expect(page).not_to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row_in_payment_histories_page(1)
        check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
      end
    end

    find("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 3.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row_in_payment_histories_page(1)
        check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
      end
    end

    find("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 4.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row_in_payment_histories_page(1)
        check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
      end
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row_in_payment_histories_page(1)
        check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
      end
    end
  end
end

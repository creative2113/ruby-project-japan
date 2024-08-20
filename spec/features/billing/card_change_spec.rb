require 'rails_helper'


RSpec.feature "クレジット課金 カード変更", type: :feature do

  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  let(:mail_address)      { 'test@request.com' }
  let(:company_name)      { '田んぼ株式会社' }
  let(:password)          { 'asdf1234' }
  let(:card_exp_month)    { '11' }
  let(:card_exp_year)     { (Time.zone.now.year + 2).to_s }
  let(:card_exp_year_str) { card_exp_year[-2..-1] }
  let(:card_name)         { 'SUZUKI SIGERU' }

  let(:after_card_exp_month)    { '4' }
  let(:after_card_exp_year)     { (Time.zone.now.year + 3).to_s }
  let(:after_card_exp_year_str) { after_card_exp_year[-2..-1] }
  let(:after_card_name)         { 'AZUMA TAIKI' }

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

  scenario '課金 -> カード変更', js: true do
    real_time_now = Time.zone.now
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    #--------------------
    # 
    #  ０ヶ月後
    #  課金を開始する
    # 
    #--------------------
    puts "現在日時: #{Time.zone.now} 課金を開始する"

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

    expect(page).to have_selector('.card-title-band', text: 'ユーザ情報の変更')

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end

    expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')

    # # クリックできないことを確認
    # expect { find('#payjp_checkout_box input[type=button]').click }.to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)

    #-------------
    #  プラン登録
    #-------------
    find('span', text: I18n.t("plan.test_light")).click

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


    # 決済アカウント作成されていること確認！！

    #-----------------
    #  PAYJP 登録確認
    #-----------------
    expect(user.billing.reload.customer_id).to be_present
    expect(user.billing.search_customer(1, -1)).to be_present

    payjp_res = user.billing.get_customer_info
    # カード
    expect(payjp_res.cards.count).to eq 1
    card_id = payjp_res.cards.data[0].id
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
    expect(payjp_res.data[0].amount).to eq 1000
    expect(payjp_res.data[0].card.id).to eq card_id
    expect(payjp_res.data[0].customer).to eq user.billing.reload.customer_id
    expect(Time.at(payjp_res.data[0].created)).to be > real_time_now - 2.minute


    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランへの登録が完了致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{user.family_name} 様/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン登録が完了しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト ライトプラン/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/料金: 1,000円/)

    ActionMailer::Base.deliveries.clear

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'credit'
    expect(user.billing.customer_id).to be_present

    # monthly_historyのチェック
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.iso8601
    expect(his.start_at).to eq user.billing.reload.current_plans[0].start_at.iso8601
    expect(his.end_at).to eq user.expiration_date.iso8601
    expect(his.end_at).to be > Time.zone.now + 27.days
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second

    # current_planの作成チェック
    expect(user.billing.current_plans).to be_present
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'Rspecテスト ライトプラン'
    expect(plan.price).to eq 1000
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

    # 期限日
    if Time.zone.today.day == Time.zone.today.next_month.day
      expect(user.expiration_date).to eq Time.zone.today.next_month.yesterday.end_of_day
    else
      expect(user.expiration_date).to eq Time.zone.today.next_month.tomorrow.yesterday.end_of_day
    end


    within '#change_plan_card' do
      expect(page).to have_selector('.card-title-band', text: '課金プラン、カード情報の変更')

      expect(page).to have_content '課金プラン、カード情報の変更はこちら'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      user.billing.reload
      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '有効期限'
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
    end


    click_link '課金プラン、カード情報の変更はこちら'


    expect(page).to have_selector('h1', text: 'プラン、カード情報変更')


    #----------------------
    #  カード変更
    #----------------------
    within '#change_card' do
      expect(page).to have_selector('.card-title-band', text: 'カード情報の変更')

      expect(page).to have_content '現在の登録カード'
      expect(page).to have_content 'Visa'
      expect(page).to have_content '4242'

      expect(page).to have_selector('#payjp_checkout_box input[value="カード変更"]')

      # クリックできないことを確認
      expect { find('#payjp_checkout_box input[value="カード変更"]').click }.to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)

      # パスワードを間違える
      fill_in 'password_for_card_change', with: '113121'

      find('#payjp_checkout_box input[value="カード変更"]').click
    end

    switch_to_frame find('#payjp-checkout-iframe')

    expect(page).to have_content '支払い情報'

    fill_in 'cardnumber', with: '378282246310005'
    fill_in 'ccmonth', with: after_card_exp_month
    fill_in 'ccyear', with: after_card_exp_year_str
    fill_in 'cvc', with: '134'
    fill_in 'ccname', with: after_card_name

    find('input#payjp_cardSubmit').click

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content 'パスワードが間違っています。'

    expect(ActionMailer::Base.deliveries.size).to eq(0)

    payjp_res = user.billing.get_customer_info
    # カード
    expect(payjp_res.cards.count).to eq 1
    expect(payjp_res.cards.data[0].id).to eq card_id
    expect(payjp_res.cards.data[0].brand).to eq 'Visa'
    expect(payjp_res.cards.data[0].exp_month).to eq card_exp_month.to_i
    expect(payjp_res.cards.data[0].exp_year).to eq card_exp_year.to_i
    expect(payjp_res.cards.data[0].last4).to eq '4242'
    expect(payjp_res.cards.data[0].name).to eq card_name


    within '#change_card' do
      expect(page).to have_selector('.card-title-band', text: 'カード情報の変更')

      expect(page).to have_content '現在の登録カード'
      expect(page).to have_content 'Visa'
      expect(page).to have_content '4242'

      expect(page).to have_selector('#payjp_checkout_box input[value="カード変更"]')

      # 正しいパスワードを入力する
      fill_in 'password_for_card_change', with: password

      find('#payjp_checkout_box input[value="カード変更"]').click
    end

    switch_to_frame find('#payjp-checkout-iframe')

    expect(page).to have_content '支払い情報'

    fill_in 'cardnumber', with: '378282246310005'
    fill_in 'ccmonth', with: after_card_exp_month
    fill_in 'ccyear', with: after_card_exp_year_str
    fill_in 'cvc', with: '134'
    fill_in 'ccname', with: after_card_name

    find('input#payjp_cardSubmit').click


    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content 'カードの変更が完了しました。'

    within '#change_card' do
      expect(page).to have_selector('.card-title-band', text: 'カード情報の変更')

      expect(page).to have_content '現在の登録カード'
      expect(page).to have_content 'American Express'
      expect(page).to have_content '0005'

      expect(page).to have_selector('#payjp_checkout_box input[value="カード変更"]')
    end


    #-----------------
    #  PAYJP 登録確認
    #-----------------

    payjp_res = user.billing.get_customer_info
    # カード
    expect(payjp_res.cards.count).to eq 1
    expect(payjp_res.cards.data[0].id).not_to eq card_id
    card_id = payjp_res.cards.data[0].id
    expect(payjp_res.cards.data[0].brand).to eq 'American Express'
    expect(payjp_res.cards.data[0].exp_month).to eq after_card_exp_month.to_i
    expect(payjp_res.cards.data[0].exp_year).to eq after_card_exp_year.to_i
    expect(payjp_res.cards.data[0].last4).to eq '0005'
    expect(payjp_res.cards.data[0].name).to eq after_card_name
    # メタデータ
    expect(payjp_res.metadata.company_name).to eq company_name
    expect(payjp_res.metadata.user_id).to eq user.id.to_s

    # 売上確認
    payjp_res = user.billing.get_charges(1)
    expect(payjp_res.data[0].amount).to eq 1000
    expect(payjp_res.data[0].card.id).not_to eq card_id


    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/クレジットカード情報を変更しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{user.family_name} 様/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/クレジットカード情報を更新致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カードブランド: American Express/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カード番号下４桁: 0005/)

    ActionMailer::Base.deliveries.clear


    #--------------------
    # 
    #  １ヶ月後
    #  更新の当日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date.tomorrow.beginning_of_day + 3.hours
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now} 更新の当日に移動"

    visit root_path
    click_link '設定'
    click_link '課金プラン、カード情報の変更はこちら'


    # 新しいmonthly_histryができる
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 3
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to be > Time.zone.now + 27.days
    last_his_updated_at = his.updated_at

    # 期限日
    expect(user.expiration_date).to eq Time.zone.yesterday.end_of_day
    expect(user.next_planned_expiration_date).to be > Time.zone.now + 27.days


    before_expiration_date = user.expiration_date.dup

    # 課金停止を試みるが、失敗する
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
    #  課金バッチを回し、課金停止する
    # 
    #--------------------
    BillingWorker.all_execute

    plan = user.billing.current_plans[0]

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}, CHARGE_DATE: #{plan.charge_date}, AMOUNT: #{plan.price.to_s(:delimited)}円/)
    ActionMailer::Base.deliveries.clear


    # 新しいカードで課金されること
    payjp_res = user.billing.get_charges
    expect(payjp_res.count).to eq 2

    expect(payjp_res.data[0].amount).to eq 1000
    expect(payjp_res.data[0].customer).to eq user.billing.reload.customer_id
    expect(Time.at(payjp_res.data[0].created)).to be > real_time_now - 2.minute
    expect(Time.at(payjp_res.data[0].created)).to be > Time.at(payjp_res.data[1].created)
    expect(payjp_res.data[0].card.brand).to eq 'American Express'
    expect(payjp_res.data[0].card.exp_month).to eq after_card_exp_month.to_i
    expect(payjp_res.data[0].card.exp_year).to eq after_card_exp_year.to_i
    expect(payjp_res.data[0].card.last4).to eq '0005'
    expect(payjp_res.data[0].card.name).to eq after_card_name

    # 古い課金は古いカード
    expect(payjp_res.data[1].card.brand).to eq 'Visa'
    expect(payjp_res.data[1].card.exp_month).to eq card_exp_month.to_i
    expect(payjp_res.data[1].card.exp_year).to eq card_exp_year.to_i
    expect(payjp_res.data[1].card.last4).to eq '4242'
    expect(payjp_res.data[1].card.name).to eq card_name


    # monthly_historyには変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 3
    expect(his.updated_at).to eq last_his_updated_at

    # 期限日は1ヶ月後になっていること
    expect(user.expiration_date).to be > Time.zone.now + 27.days
    expect(user.next_planned_expiration_date).to be_nil


    click_link '設定'
    click_link '課金プラン、カード情報の変更はこちら'

    #-------------
    #  課金停止
    #-------------
    within '#stop_plan' do
      expect(page).to have_selector('.card-title-band', text: '課金停止')

      expect(page).to have_content '有効期限'
      expect(page).to have_content user.expiration_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content before_expiration_date.strftime("%Y年%-m月%-d日")

      fill_in 'password_for_plan_stop', with: password

      find('#stop_subscription', text: '課金停止').click

      expect(page.driver.browser.switch_to.alert.text).to eq "課金を停止してもよろしいですか？"
      page.driver.browser.switch_to.alert.accept
    end

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content '課金停止が完了しました。'

    # 停止されていることを確認！！
    expect(user.billing.search_customer(1, -1)).to be_nil
    expect{ user.billing.get_customer_info }.to raise_error(Payjp::InvalidRequestError, /No such customer:/)

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランの定期更新を停止致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{user.family_name} 様/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: Rspecテスト ライトプラン/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限: #{user.billing.reload.expiration_date&.strftime("%Y年%-m月%-d日")}/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)
    ActionMailer::Base.deliveries.clear

    expect(page).to have_selector('h1', text: 'アカウント設定')


    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')
    expect(page).not_to have_content '有効期限内はプランの再登録ができません。'


    #-------------------
    #  課金停止を確認する
    #-------------------
    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト ライトプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end
  end
end

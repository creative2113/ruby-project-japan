require 'rails_helper'

RSpec.feature "紹介者トライル登録 -> カード変更 -> 課金停止", type: :feature do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_beta_standard_plan) { create(:master_billing_plan, :beta_standard) }

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

  let(:coupon_code) { '1234567' }
  let!(:referrer)    { create(:referrer, code: coupon_code) }
  let!(:coupon)     { create(:referrer_trial) }

  let(:user) { create(:user, id: Random.rand(999999), email: mail_address, company_name: company_name, password: password, billing: :free ) }

  before do
    Timecop.freeze

    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'beta_standard'])

    sign_in user
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


  scenario '紹介者トライル登録 -> カード変更 -> 課金停止', js: true do
    real_time_now = Time.zone.now
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    user = User.find_by_email(mail_address)

    expect(user.reload.referrer).to be_nil
    expect(user.referral_reason).to be_nil


    visit root_path
    click_link '設定'

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

    expect(page).not_to have_content "課金、請求履歴"

    expect(page).to have_selector('.card-title-band', text: 'ユーザ情報の変更')

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end

    expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')

    #-------------------
    #  クーポンコード入力
    #-------------------
    within '#coupon' do
      expect(page).to have_selector('.card-title-band', text: 'クーポンコード入力')

      # クーポンコードを正しく入力
      fill_in 'coupon_code', with: coupon_code

      find('button', text: '送信').click
    end

    sleep 0.5

    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons).to be_blank


    expect(page).to have_selector('h1', text: I18n.t('coupon.title'))

    within '#coupon' do
      expect(page).to have_selector('.card-title-band', text: 'お試し有料プランのご利用')
      expect(page).to have_content('10日間の有料スタンダード版お試し利用が可能です。')
      expect(page).to have_content('この後、クレジットカードのご登録が必須です。')
      expect(page).to have_content('お試し期間が過ぎますと、自動的に課金され、引き続き有料プランがご利用できます。')
      expect(page).to have_content('お試し期間中に解約されますと、10日後にお試し利用が終了します。課金はされません。')
    end


    # アカウント設定に戻る
    click_link '設定'

    expect(page).to have_selector('h1', text: 'アカウント設定')


    #-------------------
    #  クーポンコード再度入力
    #-------------------
    within '#coupon' do
      expect(page).to have_selector('.card-title-band', text: 'クーポンコード入力')

      # クーポンコードを正しく入力
      fill_in 'coupon_code', with: coupon_code

      find('button', text: '送信').click
    end

    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons).to be_blank

    within '#coupon' do
      expect(page).to have_selector('.card-title-band', text: 'お試し有料プランのご利用')
      expect(page).to have_content('10日間の有料スタンダード版お試し利用が可能です。')
      expect(page).to have_content('この後、クレジットカードのご登録が必須です。')
      expect(page).to have_content('お試し期間が過ぎますと、自動的に課金され、引き続き有料プランがご利用できます。')
      expect(page).to have_content('お試し期間中に解約されますと、10日後にお試し利用が終了します。課金はされません。')

      find('#payjp_checkout_box input[value="お試し利用"]').click
    end

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

    expect(page).to have_content 'お試し利用の登録に成功しました。お試しでご利用できます。'

    #-----------------
    #  DB登録確認
    #-----------------
    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon

    expect(user.billing.payment_method).to eq 'credit'
    expect(user.expiration_date).to eq (Time.zone.now + 10.days).end_of_day
    expiration_date = user.expiration_date.dup

    # current_planの作成チェック
    expect(user.billing.current_plans).to be_present
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'β版スタンダードプラン'
    expect(plan.price).to eq 4000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq (Time.zone.now + 11.days).day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq Time.zone.now.iso8601
    expect(plan.end_at).to be_nil
    expect(plan.trial).to be_truthy
    expect(plan.next_charge_date).to eq (Time.zone.now + 11.days).to_date
    expect(plan.last_charge_date).to be_nil
    plan_updated_at = plan.updated_at
    charge_date = plan.charge_date.dup
    start_at = plan.start_at.dup

    # billing_historyのチェック
    expect(user.billing.histories.reload.size).to eq 0

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:beta_standard]
    expect(his.start_at).to eq user.referrer_trial_coupon.created_at.beginning_of_day
    expect(his.end_at).to eq user.expiration_date.iso8601
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at


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

    # 売上はないこと
    payjp_res = user.billing.get_charges(1)
    expect(payjp_res.count).to eq 0
    expect(payjp_res.data).to be_blank


    # メールが飛ばないこと
    expect(ActionMailer::Base.deliveries.size).to eq(0)
    ActionMailer::Base.deliveries.clear


    #-----------------
    #  画面の確認
    #-----------------
    within '#change_plan_card' do
      expect(page).to have_selector('.card-title-band', text: '課金プラン、カード情報の変更')

      expect(page).to have_content '課金プラン、カード情報の変更はこちら'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'β版スタンダードプラン'
      expect(page).not_to have_content 'Rspecテスト スタンダードプラン'

      user.billing.reload
      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お試し利用中'
      expect(page).not_to have_content 'お試し利用中、停止リクエスト済み'
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/30"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/3"
    end

    expect(page).not_to have_content "課金、請求履歴"

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
    end


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/#{plan.id} #{plan.type}/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 2
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.reload.size).to eq 0

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil

    his = MonthlyHistory.find_around(user)
    his.update!(request_count: 5, acquisition_count: 100)

    click_link '設定'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content "今月の実行回数　　　　　　5/30"
      expect(page).to have_content "今月の取得件数　　　　　　100/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/3"
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
    # 売上はないこと
    payjp_res = user.billing.get_charges(1)
    expect(payjp_res.count).to eq 0
    expect(payjp_res.data).to be_blank



    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/クレジットカード情報を変更しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/クレジットカード情報を更新致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カードブランド: American Express/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/カード番号下４桁: 0005/)

    ActionMailer::Base.deliveries.clear


    #-------------
    #  課金停止
    #-------------
    within '#stop_plan' do
      expect(page).to have_selector('.card-title-band', text: '課金停止（お試し利用の解約）')

      fill_in 'password_for_plan_stop', with: password

      find('#stop_subscription', text: '課金停止').click

      page.driver.browser.switch_to.alert.accept
    end

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content '課金停止が完了しました。'

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/有料プランの定期更新を停止致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有料プランの定期更新を停止致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン名: β版スタンダードプラン/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限: #{user.billing.reload.expiration_date&.strftime("%Y年%-m月%-d日")}/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/有効期限内は上記のプランで引き続きご使用できます。有効期限後から、無料プランユーザとなります。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/また、有効期限内はプラン変更、および、プラン再登録は受け付けられなくなりますので、ご了承ください。/)
    ActionMailer::Base.deliveries.clear

    sleep 1

    # 停止されていることを確認！！
    expect(user.billing.search_customer(1, -1)).to be_nil
    expect{ user.billing.get_customer_info }.to raise_error(Payjp::InvalidRequestError, /Could not determine which URL to request:/)

    # DB確認
    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon

    expect(user.billing.payment_method).to eq 'credit'

    # 期限日
    expect(user.reload.expiration_date).to eq (Time.zone.now + 10.days).end_of_day.iso8601
    expect(user.next_planned_expiration_date).to be_nil

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:beta_standard]
    expect(his.start_at).to eq (user.monthly_histories[0].end_at + 1.second).iso8601
    expect(his.end_at).to eq user.reload.expiration_date

    # current_planの作成チェック
    expect(user.billing.current_plans).to be_present
    plan = user.billing.current_plans[0]
    expect(plan.name).to eq 'β版スタンダードプラン'
    expect(plan.price).to eq 4000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq (Time.zone.now + 11.days).day.to_s
    expect(plan.status).to eq 'ongoing'
    expect(plan.start_at).to eq Time.zone.now.iso8601
    expect(plan.end_at).to eq user.expiration_date.end_of_day.iso8601
    expect(plan.trial).to be_truthy
    expect(plan.next_charge_date).to eq (Time.zone.now + 11.days).to_date
    expect(plan.last_charge_date).to be_nil
    plan_updated_at = plan.updated_at
    charge_date = plan.charge_date.dup
    start_at = plan.start_at.dup

    # billing_historyのチェック
    expect(user.billing.histories.reload.size).to eq 0


    click_link '設定'

    expect(page).to have_selector('h1', text: 'アカウント設定')

    # プラン登録も変更できない
    expect(page).not_to have_content('課金プラン、カード情報の変更')
    expect(page).not_to have_content('課金プランの変更')
    expect(page).not_to have_content('プラン登録')

    #-------------------
    #  課金停止を確認する
    #-------------------
    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'β版スタンダードプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お試し利用中、停止リクエスト済み'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　5/30"
      expect(page).to have_content "今月の取得件数　　　　　　100/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/3"
    end

    expect(page).not_to have_content "課金、請求履歴"

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    #-------------------
    #  有効期限内の当日
    #-------------------
    Timecop.travel(user.expiration_date - 10.minutes)
    Timecop.freeze

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 2
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.reload.size).to eq 0

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date.iso8601
    expect(user.next_planned_expiration_date).to be_nil


    expect(page).to have_selector('h1', text: 'アカウント設定')

    expect(page).not_to have_content('課金プラン、カード情報の変更')
    expect(page).not_to have_content('課金プランの変更')
    expect(page).not_to have_content('プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'β版スタンダードプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お試し利用中、停止リクエスト済み'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　5/30"
      expect(page).to have_content "今月の取得件数　　　　　　100/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/3"
    end

    expect(page).not_to have_content "課金、請求履歴"

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
    expect(user.monthly_histories.reload.size).to eq 2
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0].updated_at).to eq plan_updated_at
    # billing_histories 変化がないこと
    expect(user.billing.histories.reload.size).to eq 0

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date.iso8601
    expect(user.next_planned_expiration_date).to be_nil


    expect(page).to have_selector('h1', text: 'アカウント設定')

    expect(page).not_to have_content('課金プラン、カード情報の変更')
    expect(page).not_to have_content('課金プランの変更')
    expect(page).not_to have_content('プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'β版スタンダードプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お試し利用中、停止リクエスト済み'
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　5/30"
      expect(page).to have_content "今月の取得件数　　　　　　100/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/3"
    end

    expect(page).not_to have_content "課金、請求履歴"

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end


    #-------------------
    #  有効期限が過ぎた
    #-------------------
    Timecop.travel(user.expiration_date + 10.minutes)
    Timecop.freeze

    click_link '設定'

    # DB確認
    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon

    expect(user.billing.reload.payment_method).to eq 'credit'

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 3
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories.reload[-2].end_at).to eq Time.zone.now.yesterday.end_of_day.iso8601
    last_his_updated_at = his.updated_at

    # current_planのチェック
    expect(user.billing.current_plans.reload).to be_blank
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at
    expect(user.billing.plans.last.status).to eq 'ongoing'

    # billing_historyのチェック
    expect(user.billing.histories.reload.size).to eq 0

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

    expect(page).not_to have_content "課金、請求履歴"

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


    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon

    expect(user.billing.reload.payment_method).to be_nil

    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 3
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.current_plans.reload[0]).to be_blank
    expect(user.billing.plans.reload[-1].status).to eq 'stopped'
    # billing_histories 変化がないこと
    expect(user.billing.histories.reload.size).to eq 0

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

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

    expect(page).not_to have_content "課金、請求履歴"

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end
  end
end

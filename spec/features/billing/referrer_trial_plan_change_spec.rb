require 'rails_helper'

RSpec.feature "紹介者トライル登録 -> プランアップグレード -> 課金停止", type: :feature do

  let(:mail_address)      { 'test@request.com' }
  let(:company_name)      { '田んぼ株式会社' }
  let(:password)          { 'asdf1234' }
  let(:card_exp_month)    { '11' }
  let(:card_exp_year)     { (Time.zone.now.year + 2).to_s }
  let(:card_exp_year_str) { card_exp_year[-2..-1] }
  let(:card_name)         { 'SUZUKI SIGERU' }

  let(:coupon_code) { '1234567' }
  let!(:referrer)   { create(:referrer, code: coupon_code) }
  let!(:coupon)     { create(:referrer_trial) }

  let(:user) { create(:user, id: Random.rand(999999), email: mail_address, company_name: company_name, password: password, billing: :free ) }

  before do
    Timecop.freeze
    sign_in user
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'beta_standard'])
  end

  after do
    ActionMailer::Base.deliveries.clear
    user.billing.delete_customer if user.billing.reload.customer_id.present?
    Timecop.return
  end

  xscenario '紹介者トライル登録 -> プランアップグレード -> 課金停止', js: true do
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

    # DB登録確認
    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon

    expect(user.billing.reload.status).to eq 'trial'
    expect(user.billing.payment_method).to eq 'credit'
    expect(user.billing.plan).to eq EasySettings.plan[:beta_standard]
    expect(user.billing.first_paid_at).to be_nil
    expect(user.billing.expiration_date).to eq (Time.zone.now + 10.days).end_of_day.iso8601

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:beta_standard]
    expect(his.start_at).to eq user.referrer_trial_coupon.created_at.beginning_of_day
    expect(his.end_at).to eq user.billing.expiration_date.iso8601
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second


    # 決済アカウント作成されていること確認！！

    #-----------------
    #  PAYJP 登録確認
    #-----------------
    expect(user.billing.reload.customer_id).to be_present
    expect(user.billing.reload.subscription_id).to be_present
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
    # 課金
    expect(payjp_res.subscriptions.count).to eq 1
    expect(payjp_res.subscriptions.data[0].id).to eq user.billing.subscription_id
    expect(payjp_res.subscriptions.data[0].current_period_end).to eq user.billing.expiration_date.to_i
    expect(payjp_res.subscriptions.data[0].status).to eq 'trial'
    expect(payjp_res.subscriptions.data[0].trial_end).to eq user.billing.expiration_date.to_i
    expect(payjp_res.subscriptions.data[0].trial_start).to be_present
    expect(payjp_res.subscriptions.data[0].trial_start).to eq payjp_res.subscriptions.data[0].current_period_start
    # プラン
    expect(payjp_res.subscriptions.data[0].plan.id).to eq EasySettings.payjp_plan_id['beta_standard']
    expect(payjp_res.subscriptions.data[0].plan.amount).to eq EasySettings.amount['beta_standard']
    expect(payjp_res.subscriptions.data[0].plan.name).to eq 'ベータ版スタンダード'

    subscription_id = user.billing.subscription_id.dup

    # 売上はないこと
    payjp_res = user.billing.get_charges(1)
    expect(payjp_res.count).to eq 0
    expect(payjp_res.data).to be_blank


    # メールが飛ばないこと
    expect(ActionMailer::Base.deliveries.size).to eq(0)

    ActionMailer::Base.deliveries.clear


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
      expect(page).not_to have_content '次回更新日'
      expect(page).to have_content "有効期限　　　　#{user.billing.expiration_date.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/30"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/3"
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
    end



    click_link '課金プラン、カード情報の変更はこちら'


    expect(page).to have_selector('h1', text: 'プラン、カード情報変更')

    within '#change_card' do
      expect(page).to have_selector('.card-title-band', text: 'カード情報の変更')

      expect(page).to have_content '現在の登録カード'
      expect(page).to have_content 'Visa'
      expect(page).to have_content '4242'

      expect(page).to have_selector('#payjp_checkout_box input[value="カード変更"]')
    end


    price_this_time = 0
    #----------------------
    #  プラン アップグレード
    #----------------------
    Timecop.travel(Time.zone.now + 3.days)
    Timecop.freeze

    within '#modify_plan' do
      expect(page).to have_selector('.card-title-band', text: 'プラン変更')

      expect(page).to have_content '現在のプラン: β版スタンダード 料金: 1,000円/月(税込)'
      expect(page).to have_content '変更後のプラン'
      expect(page).to have_selector('form label span', text: 'Rspecテスト ライトプラン 料金: 1,000円/月(税込)')
      expect(page).to have_selector('form label span', text: 'Rspecテスト スタンダードプラン 料金: 3,000円/月(税込)')

      expect(page).to have_selector('#change_plan', text: 'プラン変更')


      # クリックできないことを確認
      expect { find('#change_plan', text: 'プラン変更').click }.to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)


      find('label span', text: I18n.t("plan.test_standard")).click

      # クリックできないことを確認
      expect { find('#change_plan', text: 'プラン変更').click }.to raise_error(Selenium::WebDriver::Error::ElementClickInterceptedError)

      within '#payment_info' do
        expect(page).to have_content '今回の課金額'
        price_this_time = find('#price_this_time').text
        expect(price_this_time).to match /円\(税込\)/
        expect(price_this_time).to match /672/
        expect(page).to have_content '次回以降の課金額'
        expect(page).to have_content '3,000円/月(税込)'
        expect(page).to have_content '次回課金日'
        expect(page).to have_content user.billing.reload.expiration_date.strftime("%Y年%-m月%-d日")
      end

      # パスワードを間違える
      fill_in 'password_for_plan_change', with: '113121'

      find('#change_plan', text: 'プラン変更').click

      expect(page.driver.browser.switch_to.alert.text).to eq "プランを変更してもよろしいですか？\nプランをアップグレードする場合、今回課金された金額は払い戻しできませんので、ご注意ください。"
      page.driver.browser.switch_to.alert.accept
    end

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content 'パスワードが間違っています。'

    expect(ActionMailer::Base.deliveries.size).to eq(0)

    payjp_res = user.billing.get_customer_info

    # メタデータ
    expect(payjp_res.metadata.company_name).to eq company_name
    expect(payjp_res.metadata.user_id).to eq user.id.to_s
    # 課金
    expect(payjp_res.subscriptions.count).to eq 1
    expect(payjp_res.subscriptions.data[0].id).to eq user.billing.subscription_id
    expect(payjp_res.subscriptions.data[0].current_period_end).to eq user.billing.expiration_date.to_i
    expect(payjp_res.subscriptions.data[0].status).to eq 'trial'
    expect(payjp_res.subscriptions.data[0].trial_end).to eq user.billing.expiration_date.to_i
    expect(payjp_res.subscriptions.data[0].trial_start).to be_present
    expect(payjp_res.subscriptions.data[0].trial_start).to eq payjp_res.subscriptions.data[0].current_period_start
    # プラン
    expect(payjp_res.subscriptions.data[0].plan.id).to eq EasySettings.payjp_plan_id['beta_standard']
    expect(payjp_res.subscriptions.data[0].plan.amount).to eq EasySettings.amount['beta_standard']
    expect(payjp_res.subscriptions.data[0].plan.name).to eq 'ベータ版スタンダード'

    subscription_id = user.billing.subscription_id.dup


    # DB確認
    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon

    expect(user.billing.reload.status).to eq 'trial'
    expect(user.billing.payment_method).to eq 'credit'
    expect(user.billing.plan).to eq EasySettings.plan[:beta_standard]
    expect(user.billing.last_plan).to be_nil
    expect(user.billing.first_paid_at).to be_nil
    expect(user.billing.expiration_date).to eq Time.zone.at(payjp_res.subscriptions.data[0].current_period_end).iso8601

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:beta_standard]
    expect(his.start_at).to eq user.referrer_trial_coupon.created_at.beginning_of_day
    expect(his.end_at).to eq user.billing.expiration_date.iso8601
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second


    within '#modify_plan' do
      expect(page).to have_selector('.card-title-band', text: 'プラン変更')

      find('label span', text: I18n.t("plan.test_standard")).click

      within '#payment_info' do
        expect(page).to have_content '今回の課金額'
        price_this_time = find('#price_this_time').text
        expect(price_this_time).to match /円\(税込\)/ 
        expect(price_this_time).to match /672/
        expect(page).to have_content '次回以降の課金額'
        expect(page).to have_content '3,000円/月(税込)'
        expect(page).to have_content '次回課金日'
        expect(page).to have_content user.billing.reload.expiration_date.strftime("%Y年%-m月%-d日")
      end

      # 正しいパスワードを入力する
      fill_in 'password_for_plan_change', with: password

      find('#change_plan', text: 'プラン変更').click

      page.driver.browser.switch_to.alert.accept
    end

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content 'プランの変更が完了いたしました。'

    payjp_res = user.billing.get_customer_info

    next_expiration_date = Time.zone.at(payjp_res.subscriptions.data[0].current_period_end).iso8601

    # メタデータ
    expect(payjp_res.metadata.company_name).to eq company_name
    expect(payjp_res.metadata.user_id).to eq user.id.to_s
    # 課金
    expect(payjp_res.subscriptions.count).to eq 1
    expect(payjp_res.subscriptions.data[0].id).to eq user.billing.subscription_id
    expect(payjp_res.subscriptions.data[0].id).to eq subscription_id
    expect(payjp_res.subscriptions.data[0].current_period_end).to eq user.billing.expiration_date.to_i
    expect(payjp_res.subscriptions.data[0].status).to eq 'trial'
    expect(payjp_res.subscriptions.data[0].trial_end).to eq user.billing.expiration_date.to_i
    expect(payjp_res.subscriptions.data[0].trial_start).to eq payjp_res.subscriptions.data[0].current_period_start

    # プラン
    expect(payjp_res.subscriptions.data[0].plan.id).to eq EasySettings.payjp_plan_id['test_standard']
    expect(payjp_res.subscriptions.data[0].plan.amount).to eq EasySettings.amount['test_standard']
    expect(payjp_res.subscriptions.data[0].plan.name).to eq 'Rspecテスト スタンダード'

    # 売上確認
    payjp_res = user.billing.get_charges(1)
    expect(payjp_res.data[0].amount).to eq price_this_time.sub('円(税込)','').sub(',','').to_i
    expect(payjp_res.data[0].card.id).to eq card_id
    expect(payjp_res.data[0].subscription).to be_nil


    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include user.email
    expect(ActionMailer::Base.deliveries.first.subject).to match(/プランの変更が完了致しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プラン変更が完了しました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/変更前プラン名: β版スタンダード/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/変更後プラン名: Rspecテスト スタンダードプラン/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/今回課金料金: #{price_this_time.sub('円(税込)','').sub(',','').to_i.to_s(:delimited)}円/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/変更後料金: 3,000円/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/次回更新日: #{user.billing.expiration_date&.strftime("%Y年%-m月%-d日")}/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/プランを上げる場合は差額分\(日割り\)を即時課金致します。決済完了後、新プランでご利用できます。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).not_to match(/プランを下げる場合は次回更新日に変更後の料金を課金致します。次回更新日に更新されるまでは現在のプランでご利用できます。/)


    # DB確認
    expect(user.reload.referrer).to eq referrer
    expect(user.referral_reason).to eq 'coupon'
    expect(user.coupons.first).to eq coupon


    expect(user.billing.reload.status).to eq 'paid'
    expect(user.billing.payment_method).to eq 'credit'
    expect(user.billing.plan).to eq EasySettings.plan[:test_standard]
    expect(user.billing.last_plan).to eq EasySettings.plan[:beta_standard]
    expect(user.billing.first_paid_at).to eq Time.zone.now.iso8601
    expect(user.billing.expiration_date).to eq next_expiration_date

    his = MonthlyHistory.find_around(user).reload
    expect(user.monthly_histories.reload.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:beta_standard]
    expect(his.start_at).to eq user.referrer_trial_coupon.created_at.beginning_of_day
    expect(his.end_at).to eq user.billing.expiration_date.iso8601
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second


    click_link '設定'

    his = MonthlyHistory.find_around(user).reload
    expect(user.monthly_histories.reload.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:test_standard]
    expect(his.memo).to match /#{EasySettings.plan[:beta_standard]}/
    expect(his.start_at).to eq user.referrer_trial_coupon.created_at.beginning_of_day
    expect(his.end_at).to eq user.billing.expiration_date.iso8601
    expect(user.monthly_histories.first.end_at).to eq his.start_at - 1.second

    within '#change_plan_card' do
      expect(page).to have_selector('.card-title-band', text: '課金プラン、カード情報の変更')

      expect(page).to have_content '課金プラン、カード情報の変更はこちら'
    end

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト スタンダードプラン'
      expect(page).not_to have_content 'β版スタンダードプラン'

      user.billing.reload
      expect(page).to have_content '課金状況'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '有効期限'
      expect(page).to have_content "次回更新日　　　#{user.billing.expiration_date.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/500"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/20"
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
    end


    click_link '課金プラン、カード情報の変更はこちら'


    within '#modify_plan' do
      expect(page).to have_selector('.card-title-band', text: 'プラン変更')

      expect(page).to have_content '現在のプラン: Rspecテスト スタンダード 料金: 3,000円/月(税込)'
      expect(page).to have_content '変更後のプラン'
      expect(page).to have_selector('form label span', text: 'Rspecテスト ライトプラン 料金: 1,000円/月(税込)')

      expect(page).to have_selector('#change_plan', text: 'プラン変更')

      find('label span', text: I18n.t("plan.test_light")).click


      within '#payment_info' do
        expect(page).to have_content '今回の課金額'
        price_this_time = find('#price_this_time').text
        expect(price_this_time).to eq '0円(税込)'
        expect(page).to have_content '次回以降の課金額'
        expect(page).to have_content '1,000円/月(税込)'
        expect(page).to have_content '次回課金日'
        expect(page).to have_content user.billing.reload.expiration_date.strftime("%Y年%-m月%-d日")
      end
    end


    #-------------
    #  課金停止
    #-------------
    Timecop.travel(Time.zone.now + 3.days)
    Timecop.freeze

    within '#stop_plan' do
      expect(page).to have_selector('.card-title-band', text: '課金停止')

      fill_in 'password_for_plan_stop', with: password

      find('#stop_subscription', text: '課金停止').click

      page.driver.browser.switch_to.alert.accept
    end

    sleep 0.5 # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"
    page.source # これがないと、エラーが発生する。Capybara::ElementNotFound: Unable to find xpath "/html"

    expect(page).to have_content '課金停止が完了しました。'

    # 停止されていることを確認！！
    expect(user.billing.search_customer(1, -1)).to be_nil
    expect{ user.billing.get_customer_info }.to raise_error(Payjp::InvalidRequestError, /No such customer:/)
    expect{ Billing.get_subscription(subscription_id) }.to raise_error(Payjp::InvalidRequestError, /No such subscription:/)


    expect(page).to have_selector('h1', text: 'アカウント設定')


    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content '有効期限内はプランの再登録ができません。'
    end

    expect(user.monthly_histories.size).to eq 2


    #-------------------
    #  課金停止を確認する
    #-------------------
    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン'
      expect(page).to have_content 'Rspecテスト スタンダードプラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content '停止中'
      expect(page).to have_content "有効期限　　　　#{user.billing.expiration_date.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content '次回更新日'

      expect(page).to have_content "今月の実行回数　　　　　　0/500"
      expect(page).to have_content "今月の取得件数　　　　　　0/5,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/20"
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end
  end
end

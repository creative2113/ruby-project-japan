require 'rails_helper'
require 'features/billing/payment_histories_utils'

RSpec.feature "課金 請求書払い", type: :feature do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  let(:mail_address)   { 'test@request.com' }
  let(:company_name)   { '朝日株式会社' }
  let(:password)       { 'asdf1234' }
  let(:start_day)      { Time.zone.now + 35.days }
  let!(:real_time_now) { Time.zone.now }

  let(:user) { create(:user, id: Random.rand(999999), email: mail_address, company_name: company_name, password: password, billing: :free ) }
  let(:admin_user) { create(:admin_user) }
  let(:allow_ip) { create(:allow_ip, :admin) }

  def s3_path(time)
    "#{Rails.application.credentials.s3_bucket[:invoices]}/#{user.id}/invoice_#{time.strftime("%Y%m")}.pdf"
  end

  before do
    Timecop.freeze(current_time)
    create_public_user
    user.confirm_billing_status
    sign_in admin_user
    allow_ip
    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard'])

    allow_any_instance_of(S3Handler).to receive(:upload).and_wrap_original do |handler, args|
      currret_dummy_time = Time.zone.now.dup
      Timecop.return

      10.times do |i|
        break if handler.call(s3_path: args[:s3_path], file_path: args[:file_path])
        raise 'S3 Upload Error' if i > 5
        sleep 2
      end

      Timecop.travel currret_dummy_time
      Timecop.freeze
    end

    allow_any_instance_of(S3Handler).to receive(:exist_object?).and_wrap_original do |handler, args|
      currret_dummy_time = Time.zone.now.dup
      Timecop.return

      res = handler.call(s3_path: args[:s3_path])

      Timecop.travel currret_dummy_time
      Timecop.freeze
      res
    end
  end

  after do
    ActionMailer::Base.deliveries.clear
    Timecop.return
  end

  scenario '請求書払い -> 2回更新 -> 期限がきて -> 請求書払い停止', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    #--------------------
    # 
    #  ０ヶ月後
    #  1. 課金の開始日を決める
    # 
    #--------------------
    puts "現在日時: #{Time.zone.now}"

    user.reload

    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 1
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_month.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    last_his_updated_at = his.updated_at

    visit root_path
    click_link '管理者'

    fill_in 'user_id_or_email', with: mail_address
    find('button', text: '送信').click

    fill_in 'start_date_for_invoice', with: start_day.strftime("%Y/%-m/%-d")

    find('button', text: '請求書払い 作成').click

    expect(page.driver.browser.switch_to.alert.text).to eq "請求書払いでよろしいですか？"
    page.driver.browser.switch_to.alert.accept # 2回表示されるので
    page.driver.browser.switch_to.alert.accept # 2回表示されるので

    expect(page).to have_content '請求書払いユーザを作成しました。'

    #-----------------
    #  DB レコード確認
    #-----------------
    # billingの更新チェック
    expect(user.billing.reload.payment_method).to eq 'invoice'
    expect(user.billing.customer_id).to be_nil
    billing_updated_at = user.billing.updated_at

    # current_planの作成チェック
    expect(user.billing.plans).to be_present
    expect(user.billing.current_plans).to be_blank
    plan = user.billing.plans[0]
    expect(plan.name).to eq 'Rspecテスト ライトプラン'
    expect(plan.price).to eq 1000
    expect(plan.type).to eq 'monthly'
    expect(plan.charge_date).to eq start_day.day.to_s
    expect(plan.status).to eq 'waiting'
    expect(plan.start_at).to eq start_day.beginning_of_day.iso8601
    expect(plan.end_at).to be_nil
    plan_updated_at = plan.updated_at

    expect(user.monthly_histories.reload.size).to eq 1

    # 期限日
    expect(user.reload.expiration_date).to be_nil


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
      expect(page).to have_content 'invoice'
    end

    within '#plans_table' do
      expect(page).to have_content '未来'
      expect(page).not_to have_content '現在'
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000'
      expect(page).to have_content 'monthly'
      expect(page).to have_content plan.start_at.strftime("%Y年%-m月%-d日 %H:%M:%S")
    end

    expect(user.monthly_histories.reload.size).to eq 1


    sign_in user

    visit root_path

    # monthly_historyのチェック
    expect(user.monthly_histories.reload.size).to eq 1
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    Timecop.travel(Time.zone.now + 3.days)

    click_link '設定'

    # monthly_historyのチェック
    expect(user.monthly_histories.reload.size).to eq 1
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    expect(page).to have_selector('h1', text: 'アカウント設定')


    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'お申し込み、誠にありがとうございます。'
      expect(page).to have_content '有料プランが有効化されるまでしばらくお待ちください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content '有効化待ち'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).to have_content '次回のプラン　　Rspecテスト ライトプラン'
      expect(page).to have_content "開始日　　　　　#{start_day.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content "有効期限"

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金、請求履歴')
    expect(page).not_to have_content '今月の課金金額'
    expect(page).not_to have_content '過去の課金、請求履歴'

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  １か月後
    #  開始月の月末に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month - 3.minutes
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now} 開始月の月末に移動"

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 1
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.reload.size).to eq 1
    expect(MonthlyHistory.find_around(user).reload.updated_at).to eq last_his_updated_at
    # current_plan 変化がないこと
    expect(user.billing.plans).to be_present
    expect(user.billing.current_plans).to be_blank
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'お申し込み、誠にありがとうございます。'
      expect(page).to have_content '有料プランが有効化されるまでしばらくお待ちください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content '有効化待ち'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).to have_content '次回のプラン　　Rspecテスト ライトプラン'
      expect(page).to have_content "開始日　　　　　#{start_day.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content "有効期限"

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金、請求履歴')
    expect(page).not_to have_content '今月の課金金額'
    expect(page).not_to have_content '過去の課金、請求履歴'

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  １か月後
    #  開始翌月の月初に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now + 10.minutes
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now} 開始翌月の月初に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.size).to eq 2
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_month.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories.first.updated_at).to eq last_his_updated_at
    last_his_updated_at = his.updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans).to be_present
    expect(user.billing.current_plans).to be_blank
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil


    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'お申し込み、誠にありがとうございます。'
      expect(page).to have_content '有料プランが有効化されるまでしばらくお待ちください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content '有効化待ち'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).to have_content '次回のプラン　　Rspecテスト ライトプラン'
      expect(page).to have_content "開始日　　　　　#{start_day.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content "有効期限"

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金、請求履歴')
    expect(page).not_to have_content '今月の課金金額'
    expect(page).not_to have_content '過去の課金、請求履歴'

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  １か月後
    #  有効化の前日に移動
    # 
    #--------------------
    Timecop.travel start_day.beginning_of_day - 3.minutes
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now} 有効化の前日に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 2
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans).to be_present
    expect(user.billing.current_plans).to be_blank
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil


    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'お申し込み、誠にありがとうございます。'
      expect(page).to have_content '有料プランが有効化されるまでしばらくお待ちください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).to have_content '有効化待ち'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).to have_content '次回のプラン　　Rspecテスト ライトプラン'
      expect(page).to have_content "開始日　　　　　#{start_day.strftime("%Y年%-m月%-d日")}"
      expect(page).not_to have_content "有効期限"

      expect(page).to have_content "今月の実行回数　　　　　　0/20"
      expect(page).to have_content "今月の取得件数　　　　　　0/200"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/1"
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金、請求履歴')
    expect(page).not_to have_content '今月の課金金額'
    expect(page).not_to have_content '過去の課金、請求履歴'

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end


    #--------------------
    # 
    #  １か月後
    #  有効化の当日に移動
    # 
    #--------------------
    Timecop.travel start_day.beginning_of_day + 3.minutes
    Timecop.freeze
    puts "１ヶ月後: #{Time.zone.now} 有効化の当日に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 3
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to eq user.next_planned_expiration_date.iso8601
    expect(user.monthly_histories[-2].end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at

    # current_plan 存在すること
    expect(user.billing.plans).to be_present
    expect(user.billing.current_plans).to be_present
    expect(user.billing.current_plans[0].status).to eq 'waiting'
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq (Time.zone.now - 1.day).end_of_day
    expect(user.next_planned_expiration_date).to be_present

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')
    expect(page).not_to have_content 'お申し込み、誠にありがとうございます。'
    expect(page).not_to have_content '有料プランが有効化されるまでしばらくお待ちください。'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

      expect(page).to have_content "今月の実行回数　　　　　　0/300"
      expect(page).to have_content "今月の取得件数　　　　　　0/2,000"
      expect(page).to have_content "今月の簡易調査依頼回数　　0/10"
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金、請求履歴')
    expect(page).not_to have_content '今月の課金金額'
    expect(page).not_to have_content '過去の課金、請求履歴'

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).not_to have_selector('button', text: '退会')
    end

    expect(user.billing.histories.size).to eq 0

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 3
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.current_plans[0].status).to eq 'ongoing'
    expect(user.billing.current_plans[0].next_charge_date).to eq (Time.zone.now + 1.month).to_date
    expect(user.billing.current_plans[0].last_charge_date).to eq Time.zone.today
    plan_updated_at = user.billing.current_plans[0].updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq (Time.zone.now + 1.month - 1.day).end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 1
    expect(user.billing.last_history.item_name).to eq user.billing.current_plans[0].name
    expect(user.billing.last_history.price).to eq user.billing.current_plans[0].price
    expect(user.billing.last_history.memo).to be_nil
    expect(user.billing.last_history.billing_date).to eq Time.zone.today
    expect(user.billing.last_history.unit_price).to eq user.billing.current_plans[0].price
    expect(user.billing.last_history.number).to eq 1

    expiration_date = user.expiration_date.dup


    click_link '設定'

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')
    expect(page).not_to have_content 'お申し込み、誠にありがとうございます。'
    expect(page).not_to have_content '有料プランが有効化されるまでしばらくお待ちください。'

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
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
      expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
    end

    #--------------------
    # 
    #  ２か月後
    #  月末に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month - 1.minutes
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now} 月末に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 3
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 1

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).to have_content '今月の課金金額'
      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end


    #--------------------
    # 
    #  ２か月後
    #  次の月の月初に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month + 1.minutes
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now} 次の月の月初に移動"

    click_link '設定'
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

      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # 請求書が作成されて、S3にアップロードされること、PDFが正しく記載されていること
    check_s3_uploaded(s3_path(Time.zone.now.last_month))
    download_invoice_pdf_and_check(s3_path(Time.zone.now.last_month), user, Time.zone.now.last_month)

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 3
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 1

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
      expect(page).to have_content '過去の課金、請求履歴'
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
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ２か月後
    #  更新日の前日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date - 3.minutes
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now} 更新日の前日に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 3
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq Time.zone.now.end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 1


    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ２か月後
    #  更新日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date + 3.minutes
    Timecop.freeze
    puts "２ヶ月後: #{Time.zone.now} 更新日に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 4
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to eq user.next_planned_expiration_date.iso8601
    expect(user.monthly_histories[-2].end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq Time.zone.now.yesterday.end_of_day
    expect(user.next_planned_expiration_date).to eq (his.start_at + 1.month - 1.day).end_of_day

    # billing_history
    expect(user.billing.histories.size).to eq 1

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{Time.zone.today.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan charge_dateが更新されること
    expect(user.billing.current_plans[0].next_charge_date).to eq (Time.zone.now + 1.month).to_date
    expect(user.billing.current_plans[0].last_charge_date).to eq Time.zone.today
    plan_updated_at = user.billing.current_plans[0].updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq (Time.zone.now + 1.month - 1.day).end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 2
    expect(user.billing.last_history.item_name).to eq user.billing.current_plans[0].name
    expect(user.billing.last_history.price).to eq user.billing.current_plans[0].price
    expect(user.billing.last_history.memo).to be_nil
    expect(user.billing.last_history.billing_date).to eq Time.zone.today
    expect(user.billing.last_history.unit_price).to eq user.billing.current_plans[0].price
    expect(user.billing.last_history.number).to eq 1

    expiration_date = user.expiration_date.dup

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{Time.zone.now.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{Time.zone.now.last_month.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{Time.zone.now.last_month.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    #--------------------
    # 
    #  ３か月後
    #  月末に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month - 1.minutes
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now} 月末に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 2

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).to have_content '今月の課金金額'
      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    #--------------------
    # 
    #  ３か月後
    #  次の月の月初に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month + 1.minutes
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now} 次の月の月初に移動"

    click_link '設定'
    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.day).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.day - 1.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.day - 2.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 1.day).strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # 請求書が作成されて、S3にアップロードされること、PDFが正しく記載されていること
    check_s3_uploaded(s3_path(Time.zone.now.last_month))
    download_invoice_pdf_and_check(s3_path(Time.zone.now.last_month), user, Time.zone.now.last_month)

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 2

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.day).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.day - 1.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.day - 2.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 1.day).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 1.day - 1.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 1.day - 1.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ３か月後
    #  更新日の前日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date - 3.minutes
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now} 更新日の前日に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 4
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq Time.zone.now.end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 2

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{(Time.zone.now + 1.day).strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.months).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.months).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    #--------------------
    # 
    #  ３か月後
    #  更新日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date + 3.minutes
    Timecop.freeze
    puts "３ヶ月後: #{Time.zone.now} 更新日に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 5
    expect(his.plan).to eq EasySettings.plan[:test_light]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq (his.start_at + 1.month - 1.day).end_of_day.iso8601
    expect(his.end_at).to eq user.next_planned_expiration_date.iso8601
    expect(user.monthly_histories[-2].end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq Time.zone.now.yesterday.end_of_day
    expect(user.next_planned_expiration_date).to eq (his.start_at + 1.month - 1.day).end_of_day

    # billing_history
    expect(user.billing.histories.size).to eq 2

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{Time.zone.today.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.months).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.months).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    click_link '設定'

    # monthly_history 変化がないこと
    expect(user.monthly_histories.size).to eq 5
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan charge_dateが更新されること
    expect(user.billing.current_plans[0].next_charge_date).to eq (Time.zone.now + 1.month).to_date
    expect(user.billing.current_plans[0].last_charge_date).to eq Time.zone.today
    plan_updated_at = user.billing.current_plans[0].updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq (Time.zone.now + 1.month - 1.day).end_of_day
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 3
    expect(user.billing.last_history.item_name).to eq user.billing.current_plans[0].name
    expect(user.billing.last_history.price).to eq user.billing.current_plans[0].price
    expect(user.billing.last_history.memo).to be_nil
    expect(user.billing.last_history.billing_date).to eq Time.zone.today
    expect(user.billing.last_history.unit_price).to eq user.billing.current_plans[0].price
    expect(user.billing.last_history.number).to eq 1

    expiration_date = user.expiration_date.dup

    within '#change_plan_box' do
      expect(page).to have_selector('.card-title-band', text: '課金プランの変更')
      expect(page).to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'
    end

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).to have_content "次回課金日　　　#{user.billing.current_plans[0].next_charge_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.months).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.months).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    find("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 1.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[1].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ３か月後
    #  次の更新前に終了予定にする
    # 
    #--------------------
    puts "次の更新前に終了予定にする"
    user.billing.current_plans[0].update!(end_at: user.billing.current_plans[0].next_charge_date.yesterday.end_of_day)

    click_link '設定'

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).not_to have_content "次回課金日"
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    within '#cancel_account_box' do
      expect(page).to have_selector('.card-title-band', text: '退会する')

      expect(page).not_to have_content I18n.t('you_can_cancel_account_after_stop_subscription')
      expect(page).to have_selector('button', text: '退会')
    end

    #--------------------
    # 
    #  ４か月後
    #  月末に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month - 1.minutes
    Timecop.freeze
    puts "４ヶ月後: #{Time.zone.now} 月末に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 5
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date.iso8601
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 3

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).not_to have_content "次回課金日"
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.months).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 3.months).strftime("%Y年%-m月")}']")
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
      expect(page).to have_content user.billing.histories[2].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    find("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 1.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[1].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ４か月後
    #  次の月の月初に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month + 1.minutes
    Timecop.freeze
    puts "４ヶ月後: #{Time.zone.now} 次の月の月初に移動"

    click_link '設定'
    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).not_to have_selector("input[value='#{Time.zone.now.strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.months).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.months).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.months).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{Time.zone.now.last_month.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # 請求書が作成されて、S3にアップロードされること、PDFが正しく記載されていること
    check_s3_uploaded(s3_path(Time.zone.now.last_month))
    download_invoice_pdf_and_check(s3_path(Time.zone.now.last_month), user, Time.zone.now.last_month)

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 5
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq expiration_date.iso8601
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 3

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).not_to have_content "次回課金日"
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now.last_month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.months).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.months).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.months).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{Time.zone.now.last_month.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.histories[2].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[1].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 3.months).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content user.billing.histories[0].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end


    #--------------------
    # 
    #  ４か月後
    #  有効期限の当日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date - 3.minutes
    Timecop.freeze
    puts "４ヶ月後: #{Time.zone.now} 有効期限の当日に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 新規作成されること
    expect(user.monthly_histories.size).to eq 5
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # billing
    expect(user.billing.reload.payment_method).to eq 'invoice'

    # current_plan 変化がないこと
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to eq Time.zone.now.end_of_day.iso8601
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 3

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')
    expect(page).not_to have_content 'お手数ですが、 お問い合わせフォーム よりお申し出ください。'

    expect(page).not_to have_selector('.card-title-band', text: 'プラン登録')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).not_to have_content '現在のプラン　　無料プラン'

      expect(page).to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).to have_content 'お支払い済み、課金停止済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).not_to have_content "次回課金日"
      expect(page).to have_content "有効期限　　　　#{user.expiration_date.strftime("%Y年%-m月%-d日")}"

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
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
    end


    #--------------------
    # 
    #  ４か月後
    #  有効期限の翌日に移動
    # 
    #--------------------
    Timecop.travel user.expiration_date + 3.minutes
    Timecop.freeze
    puts "４ヶ月後: #{Time.zone.now} 有効期限の翌日に移動"

    click_link '設定'

    # monthly_history 新規作成されること
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 6
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq  Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories[-2].end_at).to eq his.start_at - 1.second
    last_his_updated_at = his.updated_at

    # billing
    expect(user.billing.reload.payment_method).to eq 'invoice'

    # current_plan 変化がないこと
    expect(user.billing.current_plans).to be_blank
    expect(user.billing.plans[0].status).to eq 'ongoing'
    expect(user.billing.plans[0].updated_at).to eq plan_updated_at


    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 3

    within '#plan_registration' do
      expect(page).to have_selector('.card-title-band', text: 'プラン登録')

      expect(page).to have_content 'ご登録誠にありがとうございます。'

      expect(page).to have_content 'プラン選択'

      Billing.plan_list.each do |plan|
        expect(page).to have_content I18n.t("plan.#{plan}")
        expect(page).to have_content "料金: #{EasySettings.amount[plan].to_s(:delimited)}円/月"
      end

      expect(page).to have_content '銀行振込'
      expect(page).to have_content '請求書払い'
    end

    expect(page).not_to have_selector('.card-title-band', text: '課金プランの変更')

    within '#current_status' do
      expect(page).to have_selector('.card-title-band', text: '現在の利用状況')

      expect(page).not_to have_content '現在のプラン　　Rspecテスト ライトプラン'
      expect(page).to have_content '現在のプラン　　無料プラン'

      expect(page).not_to have_content '課金状況'
      expect(page).not_to have_content '有効化待ち'
      expect(page).not_to have_content 'お支払い済み'
      expect(page).not_to have_content '次回のプラン'
      expect(page).not_to have_content "開始日"
      expect(page).not_to have_content "次回課金日"

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
      expect(page).not_to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
    end


    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 変化がないこと
    expect(user.monthly_histories.size).to eq 6
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # billing payment_methodがnilになっていること
    expect(user.billing.reload.payment_method).to be_nil

    # current_planは消えていること
    expect(user.billing.current_plans).to be_blank

    # ラストプランが更新されていること
    expect(user.billing.plans.last.reload.status).to eq 'stopped'
    plan_updated_at = user.billing.plans.last.updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.size).to eq 3

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
      expect(page).to have_content '請求書払い'
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
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).not_to have_content Time.zone.now.strftime("%Y年%-m月%-d日")
      expect(page).not_to have_content 'Rspecテスト ライトプラン'
      expect(page).not_to have_content '1,000円'
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
      expect(page).to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now.last_month).strftime("%Y年%-m月")} 課金情報")

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '1,000円'
    end

    #--------------------
    # 
    #  ５か月後
    #  月末に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now.end_of_month - 3.minutes
    Timecop.freeze
    puts "５ヶ月後: #{Time.zone.now} 月末に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス不実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear


    # monthly_history 変化がないこと
    expect(user.monthly_histories.size).to eq 6
    expect(MonthlyHistory.find_around(user).updated_at).to eq last_his_updated_at

    # current_planは消えていること
    expect(user.billing.current_plans).to be_blank

    # ラストプランが更新されていないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.reload.size).to eq 3


    #--------------------
    # 
    #  ５か月後
    #  月初に移動
    # 
    #--------------------
    Timecop.travel Time.zone.now + 10.minutes
    Timecop.freeze
    puts "５ヶ月後: #{Time.zone.now} 月初に移動"

    click_link '設定'

    # 課金ワーカーを実行
    BillingWorker.all_execute
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/ビリングワーカー 完了/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/PLAN_ID: #{plan.id}, TYPE: #{plan.type}/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).to match(/請求書発行プロセス実行/)
    expect(ActionMailer::Base.deliveries[0].body.raw_source).not_to match(/USER_ID: #{user.id}, FILE_NAME: invoice_#{Time.zone.now.yesterday.strftime("%Y%m")}.pdf/)
    ActionMailer::Base.deliveries.clear

    # monthly_history 変化がないこと
    his = MonthlyHistory.find_around(user)
    expect(user.monthly_histories.reload.size).to eq 7
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_day
    expect(his.end_at).to eq  Time.zone.now.end_of_month.iso8601
    expect(user.monthly_histories[-2].end_at).to eq his.start_at - 1.second
    expect(user.monthly_histories[-2].end_at).to eq Time.zone.now.yesterday.end_of_day.iso8601

    # billing
    expect(user.billing.reload.payment_method).to be_nil

    # current_planは消えていること
    expect(user.billing.current_plans).to be_blank

    # ラストプランが更新されていないこと
    expect(user.billing.plans.last.reload.updated_at).to eq plan_updated_at

    # 期限日
    expect(user.reload.expiration_date).to be_nil
    expect(user.next_planned_expiration_date).to be_nil

    # billing_history
    expect(user.billing.histories.reload.size).to eq 3


    #--------------------
    # 
    #  課金履歴のチェック
    # 
    #--------------------

    within '#billing_history' do
      expect(page).to have_selector('.card-title-band', text: '課金、請求履歴')

      expect(page).not_to have_content '今月の課金金額'
      expect(page).not_to have_content '課金日'
      expect(page).not_to have_content '項目名'
      expect(page).not_to have_content '金額'
      expect(page).to have_content '過去の課金、請求履歴'
    end

    click_link '過去の課金、請求履歴'

    expect(page).to have_selector('h1', text: '過去の課金、請求履歴')

    within '#history_months' do
      expect(page).to have_selector('h4', text: '課金月')
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 1.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']")
      expect(page).to have_selector("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']")
      expect(page).not_to have_selector("input[value='#{(Time.zone.now - 5.month).strftime("%Y年%-m月")}']")
    end

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.last_history.billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end

    find("input[value='#{(Time.zone.now - 3.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 3.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[1])
    end

    find("input[value='#{(Time.zone.now - 4.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 4.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[0])
    end

    find("input[value='#{(Time.zone.now - 2.month).strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{(Time.zone.now - 2.month).strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
      expect(page).to have_content user.billing.histories[2].billing_date.strftime("%Y年%-m月%-d日")
      expect(page).to have_content 'Rspecテスト ライトプラン'
      expect(page).to have_content '請求書'
      expect(page).to have_content '1,000円'
      check_billing_data_row_in_payment_histories_page(1)
      check_billing_data_row_in_payment_histories_page(2, user.billing.histories[2])
    end
  end
end

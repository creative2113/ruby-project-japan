require 'rails_helper'

RSpec.feature "過去の課金、請求履歴", type: :feature do
  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }

  def check_billing_data_row(row_num, data_history = nil)
    if row_num == 1
      within 'table tbody tr:first-child' do
        expect(page).to have_content '課金日'
        expect(page).to have_content '項目名'
        expect(page).to have_content '支払方法'
        expect(page).to have_content '単価'
        expect(page).to have_content '個数'
        expect(page).to have_content '金額'
      end
    else
      within "table tbody tr:nth-child(#{row_num})" do
        expect(page).to have_selector('td:nth-child(1)', text: data_history.billing_date.strftime("%Y年%-m月%-d日"))
        expect(page).to have_selector('td:nth-child(2)', text: data_history.item_name)
        expect(page).to have_selector('td:nth-child(3)', text: data_history.payment_method_str)
        expect(page).to have_selector('td:nth-child(4)', text: "#{data_history.unit_price.to_s(:delimited)}円")
        expect(page).to have_selector('td:nth-child(5)', text: "#{data_history.number.to_s(:delimited)}")
        expect(page).to have_selector('td:nth-child(6)', text: "#{data_history.price.to_s(:delimited)}円")
      end
    end
  end

  def check_pdf_tab(month)
    # PDFの中身までは確認しない
    switch_to_window(windows.last)
    if current_url == 'about:blank'
      expect(current_url).to eq 'about:blank'
    else
      expect(current_url).to be_include("/payment_histories/#{month.strftime("%Y%m")}/download.pdf")
      expect(page.source).to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    end
    expect(page.text).to eq ''
    page.driver.browser.close
    switch_to_window(windows.first)
  end

  before do
    Timecop.freeze(current_time)
    create_public_user
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
  end

  after do
    Timecop.return
    ActionMailer::Base.deliveries.clear
    User.pluck(:id).each do |id|
      [this_month_start, last_month_start, two_month_ago_start, three_month_ago_start, four_month_ago_start].each do |month|
        S3Handler.new.delete(bucket: Rails.application.credentials.s3_bucket[:invoices], key: "#{id}/invoice_#{month.strftime("%Y%m")}.pdf")
      end
    end
  end

  let!(:user1) { create(:user, billing_attrs: { payment_method: :invoice }) }
  let!(:user2) { create(:user, billing_attrs: { payment_method: :invoice }) }

  # 過去請求終了している
  let!(:user3) { create(:user, billing_attrs: { payment_method: nil }) }

  let!(:plan1) { create(:billing_plan, billing: user1.billing, name: master_test_light_plan.name, price: master_test_light_plan.price, charge_date: 5,  start_at: Time.zone.now - 5.months, end_at: nil) }
  let!(:plan2) { create(:billing_plan, billing: user2.billing, name: master_test_standard_plan.name, price: master_test_standard_plan.price, charge_date: 18, start_at: Time.zone.now - 5.months, end_at: nil) }
  let!(:plan3) { create(:billing_plan, billing: user3.billing, name: master_test_standard_plan.name, price: master_test_standard_plan.price, charge_date: 26, start_at: Time.zone.now - 10.months, end_at: Time.zone.now - 3.months, status: :stopped) }


  let(:this_month_start) { Time.zone.now.beginning_of_month }
  let(:last_month_start) { (Time.zone.now - 1.month).beginning_of_month }
  let(:two_month_ago_start) { (Time.zone.now - 2.month).beginning_of_month }
  let(:three_month_ago_start) { (Time.zone.now - 3.month).beginning_of_month }
  let(:four_month_ago_start) { (Time.zone.now - 4.month).beginning_of_month }


  let!(:his1_3_1) { create(:billing_history, :invoice, billing: user1.billing, billing_date: three_month_ago_start + 1.days) }
  let!(:his1_3_2) { create(:billing_history, :invoice, billing: user1.billing, billing_date: three_month_ago_start + 26.days) }
  let!(:his1_3_3) { create(:billing_history, :invoice, billing: user1.billing, billing_date: three_month_ago_start + 4.days, item_name: plan1.name, price: plan1.price, number: 1, unit_price: plan1.price) }

  let!(:his1_2_1) { create(:billing_history, :invoice, billing: user1.billing, billing_date: two_month_ago_start + 3.days) }
  let!(:his1_2_2) { create(:billing_history, :invoice, billing: user1.billing, billing_date: two_month_ago_start + 3.days) }
  let!(:his1_2_3) { create(:billing_history, :invoice, billing: user1.billing, billing_date: two_month_ago_start + 10.days) }
  let!(:his1_2_4) { create(:billing_history, :invoice, billing: user1.billing, billing_date: two_month_ago_start + 12.days) }
  let!(:his1_2_5) { create(:billing_history, :invoice, billing: user1.billing, billing_date: two_month_ago_start + 4.days, item_name: plan1.name, price: plan1.price, number: 1, unit_price: plan1.price) }

  let!(:his1_1_1) { create(:billing_history, :invoice, billing: user1.billing, billing_date: last_month_start + 14.days) }
  let!(:his1_1_2) { create(:billing_history, :invoice, billing: user1.billing, billing_date: last_month_start + 25.days) }
  let!(:his1_1_3) { create(:billing_history, :invoice, billing: user1.billing, billing_date: last_month_start + 4.days, item_name: plan1.name, price: plan1.price, number: 1, unit_price: plan1.price) }

  let!(:his1_0_1) { create(:billing_history, :invoice, billing: user1.billing, billing_date: this_month_start + 30.minutes) }
  let!(:his1_0_2) { create(:billing_history, :invoice, billing: user1.billing, billing_date: this_month_start + 4.days) }
  let!(:his1_0_3) { create(:billing_history, :invoice, billing: user1.billing, billing_date: this_month_start + 4.days, item_name: plan1.name, price: plan1.price, number: 1, unit_price: plan1.price) }


  let!(:his2_2_1) { create(:billing_history, :invoice, billing: user2.billing, billing_date: two_month_ago_start + 19.days) }
  let!(:his2_2_2) { create(:billing_history, :invoice, billing: user2.billing, billing_date: two_month_ago_start + 20.days) }
  let!(:his2_2_3) { create(:billing_history, :invoice, billing: user2.billing, billing_date: two_month_ago_start + 17.days, item_name: plan2.name, price: plan2.price, number: 1, unit_price: plan2.price) }
  let!(:his2_1_1) { create(:billing_history, :invoice, billing: user2.billing, billing_date: last_month_start + 6.days) }
  let!(:his2_1_2) { create(:billing_history, :invoice, billing: user2.billing, billing_date: last_month_start + 8.days) }
  let!(:his2_1_3) { create(:billing_history, :invoice, billing: user2.billing, billing_date: last_month_start + 13.days) }
  let!(:his2_1_4) { create(:billing_history, :invoice, billing: user2.billing, billing_date: last_month_start + 20.days) }
  let!(:his2_1_5) { create(:billing_history, :invoice, billing: user2.billing, billing_date: last_month_start + 17.days, item_name: plan2.name, price: plan2.price, number: 1, unit_price: plan2.price) }
  # let!(:his2_0_1) { create(:billing_history, :invoice, billing: user2.billing, billing_date: this_month_start + 4.hours) }
  # let!(:his2_0_2) { create(:billing_history, :invoice, billing: user2.billing, billing_date: this_month_start + 6.days) }
  # let!(:his2_0_3) { create(:billing_history, :invoice, billing: user2.billing, billing_date: this_month_start + 9.days) }
  # let!(:his2_0_4) { create(:billing_history, :invoice, billing: user2.billing, billing_date: last_month_start + 17.days, item_name: plan2.name, price: plan2.price, number: 1, unit_price: plan2.price) }



  let!(:his3_4_1) { create(:billing_history, :invoice, billing: user3.billing, billing_date: four_month_ago_start + 4.days) }
  let!(:his3_4_2) { create(:billing_history, :invoice, billing: user3.billing, billing_date: four_month_ago_start + 17.days) }
  let!(:his3_4_3) { create(:billing_history, :invoice, billing: user3.billing, billing_date: four_month_ago_start + 25.days, item_name: plan3.name, price: plan3.price, number: 1, unit_price: plan3.price) }
  let!(:his3_3_1) { create(:billing_history, :invoice, billing: user3.billing, billing_date: three_month_ago_start + 1.hours) }
  let!(:his3_3_2) { create(:billing_history, :invoice, billing: user3.billing, billing_date: three_month_ago_start + 24.days) }
  let!(:his3_3_3) { create(:billing_history, :invoice, billing: user3.billing, billing_date: three_month_ago_start + 25.days) }
  let!(:his3_3_4) { create(:billing_history, :invoice, billing: user3.billing, billing_date: three_month_ago_start + 25.days, item_name: plan3.name, price: plan3.price, number: 1, unit_price: plan3.price) }
  # let!(:his3_2_1) { create(:billing_history, billing: user3.billing, billing_date: two_month_ago_start + 19.days) }
  # let!(:his3_2_2) { create(:billing_history, billing: user3.billing, billing_date: two_month_ago_start + 20.days) }
  # let!(:his3_2_3) { create(:billing_history, billing: user3.billing, billing_date: two_month_ago_start + 22.days) }
  # let!(:his3_2_4) { create(:billing_history, billing: user3.billing, billing_date: two_month_ago_start + 25.days, item_name: plan3.name, price: plan3.price, number: 1, unit_price: plan3.price) }
  let!(:his3_0_1) { create(:billing_history, :invoice, billing: user3.billing, billing_date: this_month_start + 4.hours) }

 


  scenario '過去の課金、請求履歴を確認する', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)


    #--------------------
    # 
    #  準備
    # 
    #--------------------

    BillingWorker.issue_invoice(Time.zone.now - 2.months)
    BillingWorker.issue_invoice(Time.zone.now - 3.months)


    sign_in user1
    visit root_path
    click_link '設定'
    click_link '過去の課金、請求履歴'

    expect(page).to have_selector("input[value='#{this_month_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{last_month_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{two_month_ago_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{three_month_ago_start.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{four_month_ago_start.strftime("%Y年%-m月")}']")

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{this_month_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his1_0_3)
        check_billing_data_row(3, his1_0_2)
        check_billing_data_row(4, his1_0_1)
      end
    end

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{last_month_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his1_1_2)
        check_billing_data_row(3, his1_1_1)
        check_billing_data_row(4, his1_1_3)
      end
    end

    find('a#invoice_download', text: '請求書').click

    # PDFの中身までは確認しない
    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    find("input[value='#{two_month_ago_start.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{two_month_ago_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his1_2_4)
        check_billing_data_row(3, his1_2_3)
        check_billing_data_row(4, his1_2_5)
        check_billing_data_row(5, his1_2_2)
        check_billing_data_row(6, his1_2_1)
      end
    end

    find('a#invoice_download', text: '請求書').click

    check_pdf_tab(two_month_ago_start)


    find("input[value='#{three_month_ago_start.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{three_month_ago_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his1_3_2)
        check_billing_data_row(3, his1_3_3)
        check_billing_data_row(4, his1_3_1)
      end
    end

    find('a#invoice_download', text: '請求書').click

    check_pdf_tab(three_month_ago_start)


    sign_in user2
    visit root_path
    click_link '設定'
    click_link '過去の課金、請求履歴'

    expect(page).not_to have_selector("input[value='#{this_month_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{last_month_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{two_month_ago_start.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{three_month_ago_start.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{four_month_ago_start.strftime("%Y年%-m月")}']")

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{last_month_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his2_1_4)
        check_billing_data_row(3, his2_1_5)
        check_billing_data_row(4, his2_1_3)
        check_billing_data_row(5, his2_1_2)
        check_billing_data_row(6, his2_1_1)
      end
    end

    find('a#invoice_download', text: '請求書').click

    # PDFの中身までは確認しない
    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    find("input[value='#{two_month_ago_start.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{two_month_ago_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his2_2_2)
        check_billing_data_row(3, his2_2_1)
        check_billing_data_row(4, his2_2_3)
      end
    end

    find('a#invoice_download', text: '請求書').click


    check_pdf_tab(two_month_ago_start)


    sign_in user3
    visit root_path
    click_link '設定'
    click_link '過去の課金、請求履歴'

    expect(page).to have_selector("input[value='#{this_month_start.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{last_month_start.strftime("%Y年%-m月")}']")
    expect(page).not_to have_selector("input[value='#{two_month_ago_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{three_month_ago_start.strftime("%Y年%-m月")}']")
    expect(page).to have_selector("input[value='#{four_month_ago_start.strftime("%Y年%-m月")}']")

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{this_month_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).not_to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his3_0_1)
      end
    end


    find("input[value='#{three_month_ago_start.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{three_month_ago_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his3_3_4)
        check_billing_data_row(3, his3_3_3)
        check_billing_data_row(4, his3_3_2)
        check_billing_data_row(5, his3_3_1)
      end
    end

    find('a#invoice_download', text: '請求書').click

    check_pdf_tab(three_month_ago_start)


    find("input[value='#{four_month_ago_start.strftime("%Y年%-m月")}']").click

    within '#billing_data' do
      expect(page).to have_selector('.card-title-band', text: "#{four_month_ago_start.strftime("%Y年%-m月")} 課金情報")
      expect(page).to have_selector('a#invoice_download', text: '請求書')

      within '#billing_data_table' do
        check_billing_data_row(1)
        check_billing_data_row(2, his3_4_3)
        check_billing_data_row(3, his3_4_2)
        check_billing_data_row(4, his3_4_1)
      end
    end

    ActionMailer::Base.deliveries.clear

    find('a#invoice_download', text: '請求書').click

    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{four_month_ago_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.subject).to eq 'エラー発生　要対応'
    expect(ActionMailer::Base.deliveries.first.to).to eq([Rails.application.credentials.error_email_address])
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/請求書ファイルが存在しません。至急、確認が必要です。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/USER_ID\[#{user3.id}\]/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/ERROR_POINT\[PaymentHistoriesController:download\]/)
    ActionMailer::Base.deliveries.clear

    # 請求書を作成する
    BillingWorker.issue_invoice(Time.zone.now - 4.months)

    find('a#invoice_download', text: '請求書').click
    expect(ActionMailer::Base.deliveries.size).to eq(0)
    check_pdf_tab(four_month_ago_start)
  end

  scenario 'User1 月初付近の請求書のダウンロード周りを挙動を確認する', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    allow_any_instance_of(S3Handler).to receive(:exist_object?).and_wrap_original do |handler, args|
      currret_dummy_time = Time.zone.now.dup
      Timecop.return

      res = handler.call(s3_path: args[:s3_path])
      
      Timecop.travel currret_dummy_time
      Timecop.freeze
      res
    end

    allow_any_instance_of(S3Handler).to receive(:download).and_wrap_original do |handler, args|
      currret_dummy_time = Time.zone.now.dup
      Timecop.return

      res = handler.call(s3_path: args[:s3_path], output_path: args[:output_path])
      
      Timecop.travel currret_dummy_time
      Timecop.freeze
      res
    rescue => e
      Timecop.travel currret_dummy_time
      Timecop.freeze
      raise e
    end

    sign_in user1
    visit root_path
    click_link '設定'
    click_link '過去の課金、請求履歴'

    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click

    # 現状の確認
    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month - 2.minutes
    Timecop.freeze


    visit current_path # リロード

    # 請求ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    # 請求ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    # 請求ボタンは表示される
    expect(page).to have_selector('a#invoice_download', text: '請求書')


    find('a#invoice_download', text: '請求書').click

    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month + 2.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    # 請求ボタンは表示される
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click


    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow - 1.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')
    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    # 請求ボタンは表示される
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click


    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow + 1.minutes
    Timecop.freeze

    visit current_path # リロード

    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    ActionMailer::Base.deliveries.clear

    find('a#invoice_download', text: '請求書').click


    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.subject).to eq 'エラー発生　要対応'
    expect(ActionMailer::Base.deliveries.first.to).to eq([Rails.application.credentials.error_email_address])
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/請求書ファイルが存在しません。至急、確認が必要です。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/USER_ID\[#{user1.id}\]/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/ERROR_POINT\[PaymentHistoriesController:download\]/)
    ActionMailer::Base.deliveries.clear


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow - 1.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click


    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)

    BillingWorker.issue_invoice(Time.zone.now - 1.months)


    find('a#invoice_download', text: '請求書').click

    check_pdf_tab(last_month_start)


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow + 1.minutes
    Timecop.freeze

    visit current_path # リロード
    # 請求ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    expect(page).to have_selector('a#invoice_download', text: '請求書')

    ActionMailer::Base.deliveries.clear

    find('a#invoice_download', text: '請求書').click

    expect(ActionMailer::Base.deliveries.size).to eq(0)

    check_pdf_tab(last_month_start)
  end

  scenario 'User2 月末付近の請求書のダウンロード周りを確認する & indexアクションの確認', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    allow_any_instance_of(S3Handler).to receive(:exist_object?).and_wrap_original do |handler, args|
      currret_dummy_time = Time.zone.now.dup
      Timecop.return

      res = handler.call(s3_path: args[:s3_path])
      
      Timecop.travel currret_dummy_time
      Timecop.freeze
      res
    end

    allow_any_instance_of(S3Handler).to receive(:download).and_wrap_original do |handler, args|
      currret_dummy_time = Time.zone.now.dup
      Timecop.return

      res = handler.call(s3_path: args[:s3_path], output_path: args[:output_path])
      
      Timecop.travel currret_dummy_time
      Timecop.freeze
      res
    rescue => e
      Timecop.travel currret_dummy_time
      Timecop.freeze
      raise e
    end

    sign_in user2
    visit root_path
    click_link '設定'
    click_link '過去の課金、請求履歴'

    # 先月なので、請求書ボタンは表示
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは表示される
    expect(page).to have_selector('a#invoice_download', text: '請求書')
    find('a#invoice_download', text: '請求書').click

    # 現状の確認
    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month - 2.minutes
    Timecop.freeze


    visit current_path # リロード

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは表示される
    # 通常は表示されない想定
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click

    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month + 2.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは表示される
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click


    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow - 1.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは表示される
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click

    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow + 1.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求書ボタンは表示
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは表示
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    ActionMailer::Base.deliveries.clear

    find('a#invoice_download', text: '請求書').click

    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"請求書ファイルが存在しません。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(ActionMailer::Base.deliveries.first.subject).to eq 'エラー発生　要対応'
    expect(ActionMailer::Base.deliveries.first.to).to eq([Rails.application.credentials.error_email_address])
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/請求書ファイルが存在しません。至急、確認が必要です。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/USER_ID\[#{user2.id}\]/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/ERROR_POINT\[PaymentHistoriesController:download\]/)
    ActionMailer::Base.deliveries.clear


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow - 1.minutes
    Timecop.freeze

    visit current_path # リロード

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは非表示
    expect(page).not_to have_selector('a#invoice_download', text: '請求書')

    sleep 0.5
    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    # 請求書ボタンは表示
    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find('a#invoice_download', text: '請求書').click

    switch_to_window(windows.last)
    expect(current_url).to be_include("/payment_histories/#{last_month_start.strftime("%Y%m")}/download.pdf")
    expect(page.text).to eq '{"error":"まだ請求書は作成されていません。本日中には作成される予定です。しばらく経ってから再度お試しください。"}'
    expect(page.source).not_to match(/<embed[^>]*?type=\"application\/pdf\".*?><\/body><\/html>/)
    page.driver.browser.close
    switch_to_window(windows.first)

    BillingWorker.issue_invoice(Time.zone.now - 1.months)

    find('a#invoice_download', text: '請求書').click

    check_pdf_tab(last_month_start)


    Timecop.travel last_month_start.next_month.beginning_of_month.tomorrow + 1.minutes
    Timecop.freeze

    visit current_path # リロード

    expect(page).to have_selector('a#invoice_download', text: '請求書')

    find("input[value='#{last_month_start.strftime("%Y年%-m月")}']").click

    expect(page).to have_selector('a#invoice_download', text: '請求書')

    ActionMailer::Base.deliveries.clear

    find('a#invoice_download', text: '請求書').click

    expect(ActionMailer::Base.deliveries.size).to eq(0)

    check_pdf_tab(last_month_start)

  end
end

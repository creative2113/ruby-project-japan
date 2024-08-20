require 'rails_helper'

RSpec.feature "ユーザ登録", type: :feature do

  before { create(:ban_condition, ip: ban_ip, ban_action: BanCondition.ban_actions['user_register']) }

  after { ActionMailer::Base.deliveries.clear }

  let_it_be(:public_user) { create(:user_public) }
  let(:mail_address) { 'test@request.com' }
  let(:company_name) { 'サンプル会社' }
  let(:family_name)  { '田中' }
  let(:given_name)   { '太郎' }
  let(:department)   { '管理部' }
  let(:position)     { 'general_employee' }
  let(:position_jp)  { '一般社員' }
  let(:tel)          { '03-0000-1111' }
  let(:password)     { 'asdf1234' }
  let(:ref_id)       { '1234567' }
  let(:referrer)     { create(:referrer, code: ref_id) }
  let(:ban_ip)       { '8.8.8.8' }

  scenario 'ユーザが登録できる', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    # 初めは登録されていない
    expect(User.find_by_email(mail_address)).to be_nil

    visit root_path
    click_link '無料ユーザ登録'

    expect(page).to have_content '無料ユーザ登録'
    expect(page).to have_selector('button', text: '登録')
    expect(page).to have_selector('a', text: 'ログイン')

    fill_in 'user_company_name', with: company_name
    fill_in 'user_family_name', with: family_name
    fill_in 'user_given_name', with: given_name
    fill_in 'user_department', with: department
    page.all(".input-field").each do |node|
      next unless node.text == '役職'
      node.click
      node.find('li', text: position_jp).click
    end
    fill_in 'user_tel', with: tel
    fill_in 'user_email', with: mail_address
    fill_in 'user_password', with: password
    fill_in 'user_password_confirmation', with: password
    find('#user_terms_of_service + span span').click # 利用規約に同意する

    find('button', text: '登録').click

    expect(page).to have_content '本人確認用のメールを送信しました。メール内のリンクからアカウント作成を承認してください。承認が完了するまではログインできません。しばらく経ってもメールが送られてこない場合は、お手数ですがお問合せください。'
    expect(page).to have_content 'ログイン'
    expect(page).to have_selector('button', text: 'ログイン')
    expect(page).to have_selector('a', text: '無料ユーザ登録')
    expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

    # 登録ユーザのデータ確認
    user = User.find_by_email(mail_address)
    expect(user.company_name).to eq company_name
    expect(user.family_name).to eq family_name
    expect(user.given_name).to eq given_name
    expect(user.department).to eq department
    expect(user.position).to eq position
    expect(user.tel).to eq tel
    expect(user.language).to eq '日本語'
    expect(user.terms_of_service).to eq true
    expect(user.search_count).to eq 0
    expect(user.last_search_count).to eq 0
    expect(user.latest_access_date).to be_nil
    expect(user.monthly_search_count).to eq 0
    expect(user.last_monthly_search_count).to eq 0
    expect(user.request_count).to eq 0
    expect(user.last_request_count).to eq 0
    expect(user.last_request_date).to be_nil
    expect(user.preferences).to be_present
    expect(user.billing).to be_present
    expect(user.referrer_id).to be_nil
    expect(user.referral_reason).to be_nil

    expect(user.monthly_histories.size).to eq 1
    his = MonthlyHistory.find_around(user)
    expect(his.plan).to eq EasySettings.plan[:free]
    expect(his.start_at).to eq Time.zone.now.beginning_of_month.iso8601
    expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
    expect(his.request_count).to eq 0
    expect(his.search_count).to eq 0

    # メールが飛ぶこと
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
    expect(ActionMailer::Base.deliveries.first.to).to include mail_address
    expect(ActionMailer::Base.deliveries.first.subject).to match(/アカウント作成承認のお願い/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{company_name}/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{family_name} #{given_name}様/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/企業リスト収集のプロにご登録ありがとうございます。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/アカウント作成を承認/)

    expect(ActionMailer::Base.deliveries[1].subject).to match(/ユーザが登録されました。/)
    expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ユーザが登録されました。/)
    expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/IP: 127.0.0.1/)

    token = ''
    ActionMailer::Base.deliveries.first.body.raw_source.split("\r\n").each do |t|
      token = t.split("\"")[1].split('=')[-1] if t.include?('<a href=') && t.include?('users/confirmation')
    end

    # メール認証
    visit user_confirmation_path(confirmation_token: token)

    expect(page).to have_content 'アカウントを登録しました。ログインができるようになりました。'
    expect(page).to have_content 'ログイン'
    expect(page).to have_selector('button', text: 'ログイン')
    expect(page).to have_selector('a', text: '無料ユーザ登録')
    expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

    fill_in 'user_email', with: mail_address
    fill_in 'user_password', with: password
    find('button', text: 'ログイン').click

    expect(page).to have_content 'ログインしました。'
    expect(page).to have_content '企業一覧サイトからの収集'
    expect(page).to have_content 'テストリクエスト送信'
    expect(page).to have_content '本リクエスト送信'

    within '#requests' do
      expect(page).to have_content 'リクエスト一覧'
    end

    within '#nav-mobile' do
      expect(page).to have_content mail_address
      expect(page).to have_content '設定'
      expect(page).to have_content 'ログアウト'
      expect(page).not_to have_content 'ログイン'
    end
  end

  describe 'アフィリエイトURLに関して' do
    let(:position)     { 'section_chief' }
    let(:position_jp)  { '課長/マネージャー' }
    scenario 'ユーザが登録できる。紹介者コードが登録される', js: true do
      referrer

      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      # 初めは登録されていない
      expect(User.find_by_email(mail_address)).to be_nil

      visit root_path(rfd: ref_id)

      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_company_name', with: company_name
      fill_in 'user_family_name', with: family_name
      fill_in 'user_given_name', with: given_name
      fill_in 'user_department', with: department
      page.all(".input-field").each do |node|
        next unless node.text == '役職'
        node.click
        node.find('li', text: position_jp).click
      end
      fill_in 'user_tel', with: tel
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password
      find('#user_terms_of_service + span span').click # 利用規約に同意する

      find('button', text: '登録').click

      expect(page).to have_content '本人確認用のメールを送信しました。メール内のリンクからアカウント作成を承認してください。承認が完了するまではログインできません。しばらく経ってもメールが送られてこない場合は、お手数ですがお問合せください。'
      expect(page).to have_content 'ログイン'
      expect(page).to have_selector('button', text: 'ログイン')
      expect(page).to have_selector('a', text: '無料ユーザ登録')
      expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

      # 登録ユーザのデータ確認
      user = User.find_by_email(mail_address)
      expect(user.company_name).to eq company_name
      expect(user.family_name).to eq family_name
      expect(user.given_name).to eq given_name
      expect(user.department).to eq department
      expect(user.position).to eq position
      expect(user.tel).to eq tel
      expect(user.language).to eq '日本語'
      expect(user.terms_of_service).to eq true
      expect(user.search_count).to eq 0
      expect(user.last_search_count).to eq 0
      expect(user.latest_access_date).to be_nil
      expect(user.monthly_search_count).to eq 0
      expect(user.last_monthly_search_count).to eq 0
      expect(user.request_count).to eq 0
      expect(user.last_request_count).to eq 0
      expect(user.last_request_date).to be_nil
      expect(user.preferences).to be_present
      expect(user.billing).to be_present
      expect(user.referrer).to eq referrer
      expect(user.referral_reason).to eq 'url'

      expect(user.monthly_histories.size).to eq 1
      his = MonthlyHistory.find_around(user)
      expect(his.plan).to eq EasySettings.plan[:free]
      expect(his.start_at).to eq Time.zone.now.beginning_of_month.iso8601
      expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
      expect(his.request_count).to eq 0
      expect(his.search_count).to eq 0

      # メールが飛ぶこと
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
      expect(ActionMailer::Base.deliveries.first.to).to include mail_address
      expect(ActionMailer::Base.deliveries.first.subject).to match(/アカウント作成承認のお願い/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{company_name}/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{family_name} #{given_name}様/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/企業リスト収集のプロにご登録ありがとうございます。/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/アカウント作成を承認/)

      expect(ActionMailer::Base.deliveries[1].subject).to match(/ユーザが登録されました。/)
      expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ユーザが登録されました。/)
      expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/IP: 127.0.0.1/)

      token = ''
      ActionMailer::Base.deliveries.first.body.raw_source.split("\r\n").each do |t|
        token = t.split("\"")[1].split('=')[-1] if t.include?('<a href=') && t.include?('users/confirmation')
      end

      # メール認証
      visit user_confirmation_path(confirmation_token: token)

      expect(page).to have_content 'アカウントを登録しました。ログインができるようになりました。'
      expect(page).to have_content 'ログイン'
      expect(page).to have_selector('button', text: 'ログイン')
      expect(page).to have_selector('a', text: '無料ユーザ登録')
      expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      find('button', text: 'ログイン').click

      expect(page).to have_content 'ログインしました。'
      expect(page).to have_content '企業一覧サイトからの収集'
      expect(page).to have_content 'テストリクエスト送信'
      expect(page).to have_content '本リクエスト送信'

      within '#requests' do
        expect(page).to have_content 'リクエスト一覧'
      end

      within '#nav-mobile' do
        expect(page).to have_content mail_address
        expect(page).to have_content '設定'
        expect(page).to have_content 'ログアウト'
        expect(page).not_to have_content 'ログイン'
      end
    end

    scenario 'ユーザが登録できる。間違った紹介者コードは登録されない', js: true do
      referrer

      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      # 初めは登録されていない
      expect(User.find_by_email(mail_address)).to be_nil

      visit root_path(rfd: '00123456')

      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_company_name', with: company_name
      fill_in 'user_family_name', with: family_name
      fill_in 'user_given_name', with: given_name
      fill_in 'user_department', with: department
      page.all(".input-field").each do |node|
        next unless node.text == '役職'
        node.click
        node.find('li', text: position_jp).click
      end
      fill_in 'user_tel', with: tel
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password
      find('#user_terms_of_service + span span').click # 利用規約に同意する

      find('button', text: '登録').click

      expect(page).to have_content '本人確認用のメールを送信しました。メール内のリンクからアカウント作成を承認してください。承認が完了するまではログインできません。しばらく経ってもメールが送られてこない場合は、お手数ですがお問合せください。'
      expect(page).to have_content 'ログイン'
      expect(page).to have_selector('button', text: 'ログイン')
      expect(page).to have_selector('a', text: '無料ユーザ登録')
      expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

      # 登録ユーザのデータ確認
      user = User.find_by_email(mail_address)
      expect(user.company_name).to eq company_name
      expect(user.family_name).to eq family_name
      expect(user.given_name).to eq given_name
      expect(user.department).to eq department
      expect(user.position).to eq position
      expect(user.tel).to eq tel
      expect(user.language).to eq '日本語'
      expect(user.terms_of_service).to eq true
      expect(user.search_count).to eq 0
      expect(user.last_search_count).to eq 0
      expect(user.latest_access_date).to be_nil
      expect(user.monthly_search_count).to eq 0
      expect(user.last_monthly_search_count).to eq 0
      expect(user.request_count).to eq 0
      expect(user.last_request_count).to eq 0
      expect(user.last_request_date).to be_nil
      expect(user.preferences).to be_present
      expect(user.billing).to be_present
      expect(user.referrer).to be_nil
      expect(user.referral_reason).to be_nil

      expect(user.monthly_histories.size).to eq 1
      his = MonthlyHistory.find_around(user)
      expect(his.plan).to eq EasySettings.plan[:free]
      expect(his.start_at).to eq Time.zone.now.beginning_of_month.iso8601
      expect(his.end_at).to eq Time.zone.now.end_of_month.iso8601
      expect(his.request_count).to eq 0
      expect(his.search_count).to eq 0

      # メールが飛ぶこと
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(ActionMailer::Base.deliveries.first.from).to eq ['notifications@corp-list-pro.com']
      expect(ActionMailer::Base.deliveries.first.to).to include mail_address
      expect(ActionMailer::Base.deliveries.first.subject).to match(/アカウント作成承認のお願い/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{company_name}/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{family_name} #{given_name}様/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/企業リスト収集のプロにご登録ありがとうございます。/)
      expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/アカウント作成を承認/)

      expect(ActionMailer::Base.deliveries[1].subject).to match(/ユーザが登録されました。/)
      expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/ユーザが登録されました。/)
      expect(ActionMailer::Base.deliveries[1].body.raw_source).to match(/IP: 127.0.0.1/)

      token = ''
      ActionMailer::Base.deliveries.first.body.raw_source.split("\r\n").each do |t|
        token = t.split("\"")[1].split('=')[-1] if t.include?('<a href=') && t.include?('users/confirmation')
      end

      # メール認証
      visit user_confirmation_path(confirmation_token: token)

      expect(page).to have_content 'アカウントを登録しました。ログインができるようになりました。'
      expect(page).to have_content 'ログイン'
      expect(page).to have_selector('button', text: 'ログイン')
      expect(page).to have_selector('a', text: '無料ユーザ登録')
      expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      find('button', text: 'ログイン').click

      expect(page).to have_content 'ログインしました。'
      expect(page).to have_content '企業一覧サイトからの収集'
      expect(page).to have_content 'テストリクエスト送信'
      expect(page).to have_content '本リクエスト送信'

      within '#requests' do
        expect(page).to have_content 'リクエスト一覧'
      end

      within '#nav-mobile' do
        expect(page).to have_content mail_address
        expect(page).to have_content '設定'
        expect(page).to have_content 'ログアウト'
        expect(page).not_to have_content 'ログイン'
      end
    end
  end

  context 'エラーがあるとき' do

    context 'reCAPTCHA' do
      before { Recaptcha.configuration.skip_verify_env.delete('test') }
      after  { Recaptcha.configuration.skip_verify_env.push('test') }

      scenario 'reCAPTCHAをクリックしなかった時', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        click_link '無料ユーザ登録'

        expect(page).to have_content '無料ユーザ登録'
        expect(page).to have_selector('button', text: '登録')
        expect(page).to have_selector('a', text: 'ログイン')

        switch_to_frame find('iframe[title="reCAPTCHA"]')
        expect(page).to have_content "I'm not a robot"
        expect(page).to have_content 'reCAPTCHA'
        switch_to_frame(:top)

        fill_in 'user_company_name', with: company_name
        fill_in 'user_family_name', with: family_name
        fill_in 'user_given_name', with: given_name
        fill_in 'user_department', with: department
        page.all(".input-field").each do |node|
          next unless node.text == '役職'
          node.click
          node.find('li', text: position_jp).click
        end
        fill_in 'user_tel', with: tel
        fill_in 'user_email', with: mail_address
        fill_in 'user_password', with: password
        fill_in 'user_password_confirmation', with: password

        find('button', text: '登録').click

        expect(page).to have_content 'reCAPTCHA認証に失敗しました。もう一度お試しください。'
        expect(page).to have_content '無料ユーザ登録'
        expect(page).to have_selector('button', text: '登録')
        expect(page).to have_selector('a', text: 'ログイン')

        expect(User.find_by_email(mail_address)).to be_nil

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/変な登録リクエストがありました。/)
      end
    end

    scenario '利用規約に同意していない', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_company_name', with: company_name
      fill_in 'user_family_name', with: family_name
      fill_in 'user_given_name', with: given_name
      fill_in 'user_department', with: department
      page.all(".input-field").each do |node|
        next unless node.text == '役職'
        node.click
        node.find('li', text: position_jp).click
      end
      fill_in 'user_tel', with: tel
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password

      find('button', text: '登録').click

      expect(page).to have_content 'ユーザ登録ができませんでした。'
      expect(page).to have_content 'サービス利用規約に同意してください'
      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      expect(User.find_by_email(mail_address)).to be_nil

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    scenario '会社名を記載していない', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_family_name', with: family_name
      fill_in 'user_given_name', with: given_name
      fill_in 'user_department', with: department
      page.all(".input-field").each do |node|
        next unless node.text == '役職'
        node.click
        node.find('li', text: position_jp).click
      end
      fill_in 'user_tel', with: tel
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password
      find('#user_terms_of_service + span span').click # 利用規約に同意する

      find('button', text: '登録').click

      expect(page).to have_content 'ユーザ登録ができませんでした。'
      expect(page).to have_content '企業名（正式名称・個人名や屋号）を入力してください'
      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      expect(User.find_by_email(mail_address)).to be_nil

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    scenario '名と役職を記載していない', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'

      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_company_name', with: company_name
      fill_in 'user_family_name', with: family_name
      fill_in 'user_department', with: department
      fill_in 'user_tel', with: tel
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password
      find('#user_terms_of_service + span span').click # 利用規約に同意する

      find('button', text: '登録').click

      expect(page).to have_content 'ユーザ登録ができませんでした。'
      expect(page).to have_content '名を入力してください'
      expect(page).to have_content '役職を入力してください'
      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      expect(User.find_by_email(mail_address)).to be_nil

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    scenario '部署と電話番号を記載していない', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'

      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_company_name', with: company_name
      fill_in 'user_family_name', with: family_name
      fill_in 'user_given_name', with: given_name
      page.all(".input-field").each do |node|
        next unless node.text == '役職'
        node.click
        node.find('li', text: position_jp).click
      end
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password
      find('#user_terms_of_service + span span').click # 利用規約に同意する

      find('button', text: '登録').click

      expect(page).to have_content 'ユーザ登録ができませんでした。'
      expect(page).to have_content '部署を入力してください'
      expect(page).to have_content '電話番号を入力してください'
      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      expect(User.find_by_email(mail_address)).to be_nil

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    scenario '禁止IPの時', js: true do
      Timecop.freeze
      condition = create(:ban_condition, ip: '127.0.0.1', ban_action: BanCondition.ban_actions['user_register'])

      expect(condition.reload.count).to eq(0)
      expect(condition.last_acted_at).to be_nil

      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '無料ユーザ登録'

      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_selector('button', text: '登録')
      expect(page).to have_selector('a', text: 'ログイン')

      fill_in 'user_company_name', with: company_name
      fill_in 'user_email', with: mail_address
      fill_in 'user_password', with: password
      fill_in 'user_password_confirmation', with: password
      find('#user_terms_of_service + span span').click # 利用規約に同意する

      find('button', text: '登録').click

      expect(page).to have_content '本人確認用のメールを送信しました。メール内のリンクからアカウント作成を承認してください。承認が完了するまではログインできません。しばらく経ってもメールが送られてこない場合は、お手数ですがお問合せください。'
      expect(page).to have_content 'ログイン'
      expect(page).to have_selector('button', text: 'ログイン')
      expect(page).to have_selector('a', text: '無料ユーザ登録')
      expect(page).to have_selector('a', text: 'パスワードを忘れた場合')

      expect(User.find_by_email(mail_address)).to be_nil

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.first.subject).to match(/変な登録リクエストがありました。/)

      expect(condition.reload.count).to eq(1)
      expect(condition.last_acted_at).to eq(Time.zone.now.iso8601)
      Timecop.return
    end
  end
end

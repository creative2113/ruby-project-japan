require 'rails_helper'

RSpec.feature "IP制限の確認", type: :feature do

  let_it_be(:email) { 'a1b1c1@example.com' }
  let_it_be(:pw) { 'password1234' }
  let_it_be(:public_user) { create(:user_public) }

  let_it_be(:user) { create(:user, email: email, password: pw, role: :administrator ) }
  let(:ip) { '127.0.0.1' }

  scenario '管理者画面のIP制限を確認する', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    sign_in user

    visit root_path

    click_link '管理者'

    expect(page).not_to have_content '管理者ページ'
    expect(page).not_to have_content 'ユーザ情報'
    expect(page).not_to have_content 'トラッキング情報'
    expect(page).not_to have_content '使用状況'
    expect(page).not_to have_content '課金状況'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    # nil
    allow_ip = create(:allow_ip, ips: nil, user: user)

    click_link '管理者'

    expect(page).not_to have_content '管理者ページ'
    expect(page).not_to have_content 'ユーザ情報'
    expect(page).not_to have_content 'トラッキング情報'
    expect(page).not_to have_content '使用状況'
    expect(page).not_to have_content '課金状況'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    # 期限有効
    allow_ip.update!(ips: { ip => Time.zone.now + 30.seconds }.to_json)

    click_link '管理者'

    expect(page).to have_content '管理者ページ'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'


    # 期限切れ
    allow_ip.update!(ips: { ip => Time.zone.now - 30.seconds }.to_json)

    click_link '管理者'

    expect(page).not_to have_content '管理者ページ'
    expect(page).not_to have_content 'ユーザ情報'
    expect(page).not_to have_content 'トラッキング情報'
    expect(page).not_to have_content '使用状況'
    expect(page).not_to have_content '課金状況'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    # nil
    allow_ip.update!(ips: { ip => nil }.to_json)

    click_link '管理者'

    expect(page).to have_content '管理者ページ'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'
  end

  scenario 'Admin画面のIP制限を確認する', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    sign_in user

    visit root_path

    click_link 'Admin'

    expect(page).not_to have_content 'Search Requests'
    expect(page).not_to have_content 'アプリに戻る'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'


    # nil
    allow_ip = create(:allow_ip, ips: nil, user: user)

    click_link 'Admin'

    expect(page).not_to have_content 'Search Requests'
    expect(page).not_to have_content 'アプリに戻る'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    # 期限有効
    allow_ip.update!(ips: { ip => Time.zone.now + 30.seconds }.to_json)


    click_link 'Admin'

    expect(page).to have_content 'Search Requests'
    expect(page).to have_content 'アプリに戻る'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'

    visit root_path

    # 期限切れ
    allow_ip.update!(ips: { ip => Time.zone.now - 30.seconds }.to_json)

    click_link 'Admin'

    expect(page).not_to have_content 'Search Requests'
    expect(page).not_to have_content 'アプリに戻る'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    visit root_path


    # nil
    allow_ip.update!(ips: { ip => nil }.to_json)

    click_link 'Admin'

    expect(page).to have_content 'Search Requests'
    expect(page).to have_content 'アプリに戻る'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'
  end

  scenario 'Sidekiq画面のIP制限を確認する', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    sign_in user

    visit root_path

    click_link 'Sidekiq'

    expect(page).not_to have_content 'Dashboard' # 日本語で表示されない
    expect(page).not_to have_content 'History'
    expect(page).not_to have_content 'Busy'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    # nil
    allow_ip = create(:allow_ip, ips: nil, user: user)

    click_link 'Sidekiq'

    expect(page).not_to have_content 'Dashboard'
    expect(page).not_to have_content 'History'
    expect(page).not_to have_content 'Busy'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'


    # 期限有効
    allow_ip.update!(ips: { ip => Time.zone.now + 30.seconds }.to_json)

    click_link 'Sidekiq'

    expect(page).to have_content 'Dashboard'
    expect(page).to have_content 'History'
    expect(page).to have_content 'Busy'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'

    visit root_path

    # 期限切れ
    allow_ip.update!(ips: { ip => Time.zone.now - 30.seconds }.to_json)

    click_link 'Sidekiq'

    expect(page).not_to have_content 'Dashboard'
    expect(page).not_to have_content 'History'
    expect(page).not_to have_content 'Busy'

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'


    # nil
    allow_ip.update!(ips: { ip => nil }.to_json)

    click_link 'Sidekiq'

    expect(page).to have_content 'Dashboard'
    expect(page).to have_content 'History'
    expect(page).to have_content 'Busy'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'
  end

  scenario 'ログイン画面でIP制限を確認する', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    visit root_path

    click_link 'ログイン'

    expect(page).to have_content 'ログイン'
    
    fill_in 'user[email]', with: email
    fill_in 'user[password]', with: pw

    find('button', text: 'ログイン').click

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    click_link 'ログイン'

    # nil
    allow_ip = create(:allow_ip, ips: nil, user: user)

    expect(page).to have_content 'ログイン'
    
    fill_in 'user[email]', with: email
    fill_in 'user[password]', with: pw

    find('button', text: 'ログイン').click

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    click_link 'ログイン'


    # 期限有効
    allow_ip.update!(ips: { ip => Time.zone.now + 30.seconds }.to_json)

    expect(page).to have_content 'ログイン'
    
    fill_in 'user[email]', with: email
    fill_in 'user[password]', with: pw

    find('button', text: 'ログイン').click

    expect(page).to have_content 'ログインしました'
    expect(page).to have_content '企業一覧サイトからの収集'
    expect(page).to have_content email
    expect(page).to have_content 'ログアウト'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'

    click_link 'ログアウト'
    page.driver.browser.switch_to.alert.accept


    click_link 'ログイン'


    # 期限切れ
    allow_ip.update!(ips: { ip => Time.zone.now - 30.seconds }.to_json)

    expect(page).to have_content 'ログイン'
    
    fill_in 'user[email]', with: email
    fill_in 'user[password]', with: pw

    find('button', text: 'ログイン').click

    expect(page).to have_content '404 Not Found'
    expect(page).to have_content 'このページは見つかりませんでした。'

    click_link 'ログイン'


    # nil
    allow_ip.update!(ips: { ip => nil }.to_json)

    expect(page).to have_content 'ログイン'
    
    fill_in 'user[email]', with: email
    fill_in 'user[password]', with: pw

    find('button', text: 'ログイン').click

    expect(page).to have_content 'ログインしました'
    expect(page).to have_content '企業一覧サイトからの収集'
    expect(page).to have_content email
    expect(page).to have_content 'ログアウト'

    expect(page).not_to have_content '404 Not Found'
    expect(page).not_to have_content 'このページは見つかりませんでした。'
  end
end

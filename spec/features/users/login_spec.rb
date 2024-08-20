require 'rails_helper'

RSpec.feature "ユーザログイン", type: :feature do

  after { ActionMailer::Base.deliveries.clear }

  let(:mail_address) { 'test@request.com' }
  let(:password)     { 'asdf1234' }

  before { create(:user, email: mail_address, password: password) }

  scenario 'ログインできる', js: true do
    Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

    visit root_path
    within '#nav-mobile' do
      expect(page).to have_content 'ログイン'
      expect(page).not_to have_content '設定'
      expect(page).not_to have_content 'ログアウト'
    end

    click_link 'ログイン'

    expect(page).to have_content 'ログイン'
    expect(page).to have_selector('button', text: 'ログイン')
    expect(page).to have_selector('a', text: '無料ユーザ登録')
    expect(page).to have_selector('a', text: 'パスワードを忘れた場合')


    # PWを間違える
    fill_in 'user_email', with: mail_address
    fill_in 'user_password', with: 'aaaa1111'

    find('button', text: 'ログイン').click

    expect(page).to have_content 'メールアドレス もしくはパスワードが不正です。'

    expect(page).to have_content 'ログイン'
    expect(page).to have_selector('button', text: 'ログイン')
    expect(page).to have_selector('a', text: '無料ユーザ登録')
    expect(page).to have_selector('a', text: 'パスワードを忘れた場合')
    expect(page).not_to have_content '企業一覧サイトからの収集'


    fill_in 'user_email', with: mail_address
    fill_in 'user_password', with: password

    find('button', text: 'ログイン').click

    expect(page).to have_content 'ログインしました。'
    expect(page).to have_content '企業一覧サイトからの収集'
    within '#nav-mobile' do
      expect(page).to have_content '設定'
      expect(page).to have_content 'ログアウト'
    end
  end
end

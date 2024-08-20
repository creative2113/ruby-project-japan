require 'rails_helper'

RSpec.feature "お知らせが表示されることの確認", type: :feature do

  let(:notice1) { create(:notice, subject: subject1, body: body1, display: display1, opened_at: opened_at1, top_page: top_page1) }
  let(:notice2) { create(:notice, subject: subject2, body: body2, display: display2, opened_at: opened_at2, top_page: top_page2) }
  let(:subject1) { 'お知らせのタイトル1' }
  let(:subject2) { 'お知らせのタイトル2' }
  let(:body1) { 'お知らせの本文1' }
  let(:body2) { 'お知らせの本文2' }
  let(:display1) { true }
  let(:display2) { true }
  let(:opened_at1) { Time.zone.now - 1.day }
  let(:opened_at2) { Time.zone.now - 1.day }
  let(:top_page1) { true }
  let(:top_page2) { true }

  before do
    create_public_user
    notice1
    notice2
  end

  def viewable_notice_1
    expect(page).to have_content subject1
    expect(page).to have_content body1
  end

  def not_viewable_notice_1
    expect(page).not_to have_content subject1
    expect(page).not_to have_content body1
  end

  def viewable_notice_2
    expect(page).to have_content subject2
    expect(page).to have_content body2
  end

  def not_viewable_notice_2
    expect(page).not_to have_content subject2
    expect(page).not_to have_content body2
  end

  describe 'サービス紹介画面に表示されるかどうか' do
    context 'disableがfalseの時' do
      let(:display1) { true }
      let(:display2) { false }

      scenario 'displayがfalseになっているお知らせは表示されない', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        click_link 'サービス紹介'
        expect(page).to have_content 'このサービスについて'
        expect(page).to have_content 'サービス利用規約'

        viewable_notice_1
        not_viewable_notice_2
      end
    end

    context 'open_atが未来の時' do
      let(:opened_at1) { Time.zone.now - 1.day }
      let(:opened_at2) { Time.zone.now + 1.day }

      scenario 'open_atが未来のお知らせは表示されない', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        click_link 'サービス紹介'
        expect(page).to have_content 'このサービスについて'
        expect(page).to have_content 'サービス利用規約'

        viewable_notice_1
        not_viewable_notice_2
      end
    end

    context 'top_pageがfalseの時' do
      let(:top_page1) { true }
      let(:top_page2) { false }

      scenario 'top_pageがfalseでもお知らせは表示される', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        click_link 'サービス紹介'
        expect(page).to have_content 'このサービスについて'
        expect(page).to have_content 'サービス利用規約'

        viewable_notice_1
        viewable_notice_2
      end
    end

    context '１年以上経過している時' do
      let(:opened_at1) { Time.zone.now - 1.day }
      let(:opened_at2) { Time.zone.now - 1.years - 1.day }

      scenario 'top_pageがfalseでもお知らせは表示される', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        click_link 'サービス紹介'
        expect(page).to have_content 'このサービスについて'
        expect(page).to have_content 'サービス利用規約'

        viewable_notice_1
        not_viewable_notice_2
      end
    end

    context '両方とも表示される時' do

      scenario 'top_pageがfalseでもお知らせは表示される', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        click_link 'サービス紹介'
        expect(page).to have_content 'このサービスについて'
        expect(page).to have_content 'サービス利用規約'

        viewable_notice_1
        viewable_notice_2
      end
    end
  end

  describe 'トップ画面に表示されるかどうか' do

    context '両方とも表示されない時' do
      let(:top_page1) { false }
      let(:top_page2) { false }

      scenario 'top_pageがtrueになっていないお知らせは表示されない', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        expect(page).to have_content '企業一覧サイトからの収集'
        expect(page).to have_content 'リクエスト送信'

        not_viewable_notice_1
        not_viewable_notice_2

        # click_link '単一HP情報取得'
        # expect(page).to have_content '単一企業HP情報の取得'
        # expect(page).to have_content '単一の企業情報の取得'

        # not_viewable_notice_1
        # not_viewable_notice_2

        click_link '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得リクエスト送信'

        not_viewable_notice_1
        not_viewable_notice_2
      end
    end

    context 'お知らせ1が表示される時' do
      let(:top_page1) { true }
      let(:top_page2) { false }

      scenario 'お知らせ2は表示されない', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        expect(page).to have_content '企業一覧サイトからの収集'
        expect(page).to have_content 'リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2

        # click_link '単一HP情報取得'
        # expect(page).to have_content '単一企業HP情報の取得'
        # expect(page).to have_content '単一の企業情報の取得'

        # viewable_notice_1
        # not_viewable_notice_2

        click_link '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2
      end
    end

    context '両方とも表示される時' do
      let(:top_page1) { true }
      let(:top_page2) { true }

      scenario 'お知らせは表示される', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        expect(page).to have_content '企業一覧サイトからの収集'
        expect(page).to have_content 'リクエスト送信'

        viewable_notice_1
        viewable_notice_2

        # click_link '単一HP情報取得'
        # expect(page).to have_content '単一企業HP情報の取得'
        # expect(page).to have_content '単一の企業情報の取得'

        # viewable_notice_1
        # viewable_notice_2

        click_link '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得リクエスト送信'

        viewable_notice_1
        viewable_notice_2
      end
    end

    context 'disableがfalseの時' do
      let(:display1) { true }
      let(:display2) { false }

      scenario 'displayがfalseになっているお知らせは表示されない', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        expect(page).to have_content '企業一覧サイトからの収集'
        expect(page).to have_content 'リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2

        # click_link '単一HP情報取得'
        # expect(page).to have_content '単一企業HP情報の取得'
        # expect(page).to have_content '単一の企業情報の取得'

        # viewable_notice_1
        # not_viewable_notice_2

        click_link '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2
      end
    end

    context 'open_atが未来の時' do
      let(:opened_at1) { Time.zone.now - 1.day }
      let(:opened_at2) { Time.zone.now + 1.day }

      scenario 'open_atが未来のお知らせは表示されない', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        expect(page).to have_content '企業一覧サイトからの収集'
        expect(page).to have_content 'リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2

        # click_link '単一HP情報取得'
        # expect(page).to have_content '単一企業HP情報の取得'
        # expect(page).to have_content '単一の企業情報の取得'

        # viewable_notice_1
        # not_viewable_notice_2

        click_link '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2
      end
    end

    context '１年以上経過している時' do
      let(:opened_at1) { Time.zone.now - 1.day }
      let(:opened_at2) { Time.zone.now - 1.years - 1.day }

      scenario 'top_pageがfalseでもお知らせは表示される', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit root_path
        expect(page).to have_content '企業一覧サイトからの収集'
        expect(page).to have_content 'リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2

        # click_link '単一HP情報取得'
        # expect(page).to have_content '単一企業HP情報の取得'
        # expect(page).to have_content '単一の企業情報の取得'

        # viewable_notice_1
        # not_viewable_notice_2

        click_link '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得'
        expect(page).to have_content '企業HP情報の取得リクエスト送信'

        viewable_notice_1
        not_viewable_notice_2
      end
    end
  end
end

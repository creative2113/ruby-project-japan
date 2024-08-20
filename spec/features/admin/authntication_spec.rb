require 'rails_helper'

RSpec.feature "権限確認", type: :feature do
  let_it_be(:master_standard_plan) { create(:master_billing_plan, :standard) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['standard'])
  end

  after { ActionMailer::Base.deliveries.clear }

  # before { create_public_user }
  let_it_be(:public_user) { create(:user_public) }

  let(:email) { 'a1b1c1@example.com' }
  let(:payment_method) { :credit }
  let(:user)  { create(:user, email: email, billing_attrs: { payment_method: payment_method } ) }
  let!(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

  context 'パブリックユーザ' do
    scenario 'パブリックユーザでは閲覧できない', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit admin_search_requests_path

      expect(page).to have_content '企業リスト収集のプロ'
      expect(page).to have_content '無料ユーザ登録'
      expect(page).to have_content 'ログイン'

      expect(page).to_not have_content '設定'
      expect(page).to_not have_content 'ログアウト'

      expect(page).to have_content '404 Not Found'
      expect(page).to have_content 'このページは見つかりませんでした。'
    end
  end

  context 'ログインユーザ' do
    def check_to_404
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit admin_search_requests_path

      expect(page).to have_content '企業リスト収集のプロ'
      expect(page).to have_content email
      expect(page).to have_content 'ログアウト'

      expect(page).to_not have_content '無料ユーザ登録'
      expect(page).to_not have_content 'ログイン'

      expect(page).to have_content '404 Not Found'
      expect(page).to have_content 'このページは見つかりませんでした。'
    end

    before { sign_in user }

    context 'スタンダード' do
      let(:payment_method) { :credit }
      let!(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

      scenario '管理者以外のユーザでは閲覧できない', js: true do
        check_to_404
      end
    end

    context 'free' do
      let(:payment_method) { nil }
      let!(:plan) { nil }

      scenario '管理者以外のユーザでは閲覧できない', js: true do
        check_to_404
      end
    end
  end
end

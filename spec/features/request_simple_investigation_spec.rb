require 'rails_helper'
require 'features/corporate_list_config_operation'

RSpec.feature "簡易調査と設定の依頼", type: :feature do
  let_it_be(:master_tester_a_plan) { create(:master_billing_plan, :test_testerA) }
  let_it_be(:master_tester_b_plan) { create(:master_billing_plan, :test_testerB) }
  let_it_be(:master_tester_c_plan) { create(:master_billing_plan, :test_testerC) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['testerA', 'standard'])
  end

  let_it_be(:public_user) { create(:user_public) }
  let!(:user)     { create(:user, billing: :credit ) }
  let!(:plan)     { create(:billing_plan, name: plan_name, billing: user.billing) }
  let!(:history)  { create(:monthly_history, user: user, plan: user_plan, simple_investigation_count: simple_investigation_count ) }
  let(:plan_name) { master_tester_a_plan.name }
  let(:user_plan) { plan; user.my_plan_number }

  let(:simple_investigation_count) { 6 }

  let(:accept_id) { Request.create_accept_id }
  let!(:request)   { create(:request, :corporate_site_list, user: user, accept_id: accept_id, plan: user_plan, test: test, status: EasySettings.status.completed) }
  let!(:list_url) { create(:corporate_list_requested_url_finished, :result_1, request: request, test: test, finish_status: finish_status ) }
  let(:test) { true }
  let(:finish_status) { EasySettings.finish_status.error }

  context 'パブリックユーザ：テスト実行：取得失敗' do
    let(:user) { public_user }

    scenario 'テスト実行で取得失敗し、調査依頼がないことを確認', js: true do
      visit root_path

      fill_in 'accept_id', with: accept_id
      click_button 'confirm' # 確認ボタン

      within '#confirm_request_form' do

        expect(page).to have_content 'リクエスト確認'

        within 'table:nth-child(1)' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content request.title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content request.corporate_list_site_start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
          expect(page).to have_content '結果'
          expect(page).to have_content '取得失敗'
          expect(page).to have_content '失敗理由'
          expect(page).to have_content '取得(クロール)に失敗しました。大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
        end

        expect(page).not_to have_content '情報を取得できなかったユーザ様へ'

        expect(page).not_to have_content 'ご期待に添えず大変申し訳ございません。'
        expect(page).not_to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'

        expect(page).not_to have_selector('button', text: '簡易調査と設定の申し込み')

        expect(page).not_to have_content '残りご利用可能数'
        expect(page).not_to have_content '調査対象URL'
      end
    end
  end

  context 'ログインユーザ　プラン testerA：テスト実行：取得失敗' do

    context 'リミットを超えていない' do
      let(:simple_investigation_count) { 6 }

      scenario 'テスト実行で取得失敗し、調査依頼をする → 調査依頼済みであることの確認', js: true do
        sign_in user
        visit root_path

        count = SimpleInvestigationHistory.count
        expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 0

        within "#requests" do
          within 'table tbody tr:nth-child(2)' do
            find('i', text: 'find_in_page').click # Confirm 確認ボタン
            # find('i', text: 'FIND_IN_PAGE').click # ネットが繋がらない時
          end
        end

        within 'table:nth-child(1)' do
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
          expect(page).to have_content '結果'
          expect(page).to have_content '取得失敗'
          expect(page).to have_content '失敗理由'
          expect(page).to have_content '取得(クロール)に失敗しました。大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
        end


        expect(page).not_to have_content 'ご期待に添えず大変申し訳ございません。'
        expect(page).not_to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'

        expect(page).not_to have_selector('button', text: '簡易調査と設定の申し込み')

        expect(page).not_to have_content '残りご利用可能数'
        expect(page).not_to have_content '調査対象URL'

        within "#confirm_request_form" do
          find('h4', text: '情報を取得できなかったユーザ様へ').click
        end

        within '#simple_investigation_request' do
          expect(page).to have_content 'ご期待に添えず大変申し訳ございません。'
          expect(page).to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'
          expect(page).to have_selector('button', text: '簡易調査と設定の申し込み')

          within 'table' do
            within 'tbody tr:nth-child(1)' do
              expect(page).to have_content '残りご利用可能数'
              expect(page).to have_content "#{10 - simple_investigation_count}回"
            end

            within 'tbody tr:nth-child(2)' do
              expect(page).to have_content '調査対象URL'
              expect(page).to have_content request.corporate_list_site_start_url
            end
          end

          expect(page).not_to have_content '簡易調査と簡易設定の依頼を受け付けました。'
          expect(page).not_to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
          expect(page).not_to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'

          find('button', text: '簡易調査と設定の申し込み').click

          expect(page).to have_content '簡易調査と簡易設定の依頼を受け付けました。'
          expect(page).to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
          expect(page).to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'


          expect(user.current_history.reload.simple_investigation_count).to eq simple_investigation_count + 1
          expect(SimpleInvestigationHistory.count).to eq count + 1

          history = SimpleInvestigationHistory.where(user: user, request: request).reload[0]
          expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 1
          expect(history.reload).to be_present
          expect(history.url).to eq request.corporate_list_site_start_url

          clickable = true
          begin
            find('button', text: '簡易調査と設定の申し込み').click
          rescue Selenium::WebDriver::Error::ElementClickInterceptedError => e
            clickable = false
          end

          expect(clickable).to be_falsey

        end

        within "#requests" do
          within 'table tbody tr:nth-child(2)' do
            find('i', text: 'find_in_page').click # Confirm 確認ボタン
            # find('i', text: 'FIND_IN_PAGE').click # ネットが繋がらない時
          end
        end

        expect(page).not_to have_content 'ご期待に添えず大変申し訳ございません。'
        expect(page).not_to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'

        expect(page).not_to have_selector('button', text: '既に依頼済みです')

        expect(page).not_to have_content '残りご利用可能数'
        expect(page).not_to have_content '調査対象URL'

        within "#confirm_request_form" do
          find('h4', text: '情報を取得できなかったユーザ様へ').click
        end

        within '#simple_investigation_request' do
          expect(page).to have_content 'ご期待に添えず大変申し訳ございません。'
          expect(page).to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'
          expect(page).to have_selector('button', text: '既に依頼済みです')

          within 'table' do
            within 'tbody tr:nth-child(1)' do
              expect(page).to have_content '残りご利用可能数'
              expect(page).to have_content "#{10 - simple_investigation_count - 1}回"
              expect(page).not_to have_content "#{10 - simple_investigation_count}回"
            end

            within 'tbody tr:nth-child(2)' do
              expect(page).to have_content '調査対象URL'
              expect(page).to have_content request.corporate_list_site_start_url
            end
          end

          expect(page).not_to have_content '簡易調査と簡易設定の依頼を受け付けました。'
          expect(page).not_to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
          expect(page).not_to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'

          clickable = true
          begin
            find('button', text: '既に依頼済みです').click
          rescue Selenium::WebDriver::Error::ElementClickInterceptedError => e
            clickable = false
          end

          expect(clickable).to be_falsey

          expect(user.current_history.reload.simple_investigation_count).to eq simple_investigation_count + 1
          expect(SimpleInvestigationHistory.count).to eq count + 1

        end
      end
    end

    context 'リミットを超えている' do
      let(:simple_investigation_count) { 10 }

      scenario 'テスト実行で取得失敗し、調査依頼ができない', js: true do
        sign_in user
        visit root_path

        count = SimpleInvestigationHistory.count
        expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 0

        within "#requests" do
          within 'table tbody tr:nth-child(2)' do
            find('i', text: 'find_in_page').click # Confirm 確認ボタン
          end
        end

        within 'table:nth-child(1)' do
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
          expect(page).to have_content '結果'
          expect(page).to have_content '取得失敗'
          expect(page).to have_content '失敗理由'
          expect(page).to have_content '取得(クロール)に失敗しました。大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
        end


        expect(page).not_to have_content 'ご期待に添えず大変申し訳ございません。'
        expect(page).not_to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'

        expect(page).not_to have_selector('button', text: '簡易調査と設定の申し込み')

        expect(page).not_to have_content '残りご利用可能数'
        expect(page).not_to have_content '調査対象URL'

        within "#confirm_request_form" do
          find('h4', text: '情報を取得できなかったユーザ様へ').click
        end

        within '#simple_investigation_request' do
          expect(page).to have_content 'ご期待に添えず大変申し訳ございません。'
          expect(page).to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'
          expect(page).to have_selector('button', text: '簡易調査と設定の申し込み')

          within 'table' do
            within 'tbody tr:nth-child(1)' do
              expect(page).to have_content '残りご利用可能数'
              expect(page).to have_content '0回'
              expect(page).not_to have_content '10回'
            end

            within 'tbody tr:nth-child(2)' do
              expect(page).to have_content '調査対象URL'
              expect(page).to have_content request.corporate_list_site_start_url
            end
          end

          expect(page).not_to have_content '簡易調査と簡易設定の依頼を受け付けました。'
          expect(page).not_to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
          expect(page).not_to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'

          clickable = true
          begin
            find('button', text: '簡易調査と設定の申し込み').click
          rescue Selenium::WebDriver::Error::ElementClickInterceptedError => e
            clickable = false
          end

          expect(clickable).to be_falsey

          expect(page).not_to have_content '簡易調査と簡易設定の依頼を受け付けました。'
          expect(page).not_to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
          expect(page).not_to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'

          expect(user.current_history.reload.simple_investigation_count).to eq simple_investigation_count + 0
          expect(SimpleInvestigationHistory.count).to eq count + 0
        end
      end
    end
  end

  context 'ログインユーザ　プラン testerΒ：テスト実行：成功' do
    # let(:plan) { EasySettings.plan[:testerB] }
    let(:plan_name) { master_tester_b_plan.name }
    let(:finish_status) { EasySettings.finish_status.successful }

    scenario 'テスト実行で成功する、調査依頼が表示されることを確認', js: true do
      sign_in user
      visit root_path

      count = SimpleInvestigationHistory.count
      expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 0

      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within 'table:nth-child(1)' do
        expect(page).to have_content '現在のステータス'
        expect(page).to have_content '完了'
        expect(page).not_to have_content '結果'
        expect(page).not_to have_content '取得失敗'
        expect(page).not_to have_content '失敗理由'
        expect(page).not_to have_content '取得(クロール)に失敗しました。'
      end

      expect(page).not_to have_content 'ご期待に添えず大変申し訳ございません。'
      expect(page).not_to have_content '毎月10回まで無料で簡易調査と設定を依頼できます。'

      expect(page).not_to have_selector('button', text: '簡易調査と設定の申し込み')

      expect(page).not_to have_content '残りご利用可能数'
      expect(page).not_to have_content '調査対象URL'

      within "#confirm_request_form" do
        find('h4', text: '情報を取得できなかったユーザ様へ').click
      end

      within '#simple_investigation_request' do
        expect(page).to have_content 'ご期待に添えず大変申し訳ございません。'
        expect(page).to have_content "毎月20回まで無料で簡易調査と設定を依頼できます。"
        expect(page).to have_selector('button', text: '簡易調査と設定の申し込み')

        within 'table' do
          within 'tbody tr:nth-child(1)' do
            expect(page).to have_content '残りご利用可能数'
            expect(page).to have_content "#{20 - simple_investigation_count}回"
          end

          within 'tbody tr:nth-child(2)' do
            expect(page).to have_content '調査対象URL'
            expect(page).to have_content request.corporate_list_site_start_url
          end
        end

        expect(page).not_to have_content '簡易調査と簡易設定の依頼を受け付けました。'
        expect(page).not_to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
        expect(page).not_to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'

        find('button', text: '簡易調査と設定の申し込み').click

        expect(page).to have_content '簡易調査と簡易設定の依頼を受け付けました。'
        expect(page).to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
        expect(page).to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'


        expect(user.current_history.reload.simple_investigation_count).to eq simple_investigation_count + 1
        expect(SimpleInvestigationHistory.count).to eq count + 1

        history = SimpleInvestigationHistory.where(user: user, request: request).reload[0]
        expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 1
        expect(history.reload).to be_present
        expect(history.url).to eq request.corporate_list_site_start_url
      end
    end
  end

  context 'ログインユーザ　プラン testerC：本実行：成功' do
    # let(:plan) { EasySettings.plan[:testerC] }
    let(:plan_name) { master_tester_c_plan.name }
    let(:finish_status) { EasySettings.finish_status.successful }
    let(:test) { false }

    scenario 'テスト実行で成功する、調査依頼が表示されることを確認', js: true do
      sign_in user
      visit root_path

      count = SimpleInvestigationHistory.count
      expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 0

      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within 'table:nth-child(1)' do
        expect(page).to have_content '現在のステータス'
        expect(page).to have_content '完了'
        expect(page).not_to have_content '取得失敗'
        expect(page).not_to have_content '失敗理由'
        expect(page).not_to have_content '取得(クロール)に失敗しました。'
      end

      expect(page).not_to have_content 'ご期待に添えず大変申し訳ございません。'
      expect(page).not_to have_content '毎月30回まで無料で簡易調査と設定を依頼できます。'

      expect(page).not_to have_selector('button', text: '簡易調査と設定の申し込み')

      expect(page).not_to have_content '残りご利用可能数'
      expect(page).not_to have_content '調査対象URL'

      within "#confirm_request_form" do
        find('h4', text: '情報を取得できなかったユーザ様へ').click
      end

      within '#simple_investigation_request' do
        expect(page).to have_content 'ご期待に添えず大変申し訳ございません。'
        expect(page).to have_content "毎月30回まで無料で簡易調査と設定を依頼できます。"
        expect(page).to have_selector('button', text: '簡易調査と設定の申し込み')

        within 'table' do
          within 'tbody tr:nth-child(1)' do
            expect(page).to have_content '残りご利用可能数'
            expect(page).to have_content "#{30 - simple_investigation_count}回"
          end

          within 'tbody tr:nth-child(2)' do
            expect(page).to have_content '調査対象URL'
            expect(page).to have_content request.corporate_list_site_start_url
          end
        end

        expect(page).not_to have_content '簡易調査と簡易設定の依頼を受け付けました。'
        expect(page).not_to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
        expect(page).not_to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'

        find('button', text: '簡易調査と設定の申し込み').click

        expect(page).to have_content '簡易調査と簡易設定の依頼を受け付けました。'
        expect(page).to have_content '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。'
        expect(page).to have_content '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。'


        expect(user.current_history.reload.simple_investigation_count).to eq simple_investigation_count + 1
        expect(SimpleInvestigationHistory.count).to eq count + 1

        history = SimpleInvestigationHistory.where(user: user, request: request).reload[0]
        expect(SimpleInvestigationHistory.where(user: user, request: request).count).to eq 1
        expect(history.reload).to be_present
        expect(history.url).to eq request.corporate_list_site_start_url
      end
    end
  end
end
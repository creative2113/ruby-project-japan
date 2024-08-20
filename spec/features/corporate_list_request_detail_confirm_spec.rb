require 'rails_helper'
require 'features/corporate_list_config_operation'

RSpec.feature "ホーム：企業一覧サイトからの収集のテスト：リクエスト、確認操作", type: :feature do
  before { create_public_user }
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin_user) }
  let(:user2) { create(:user) }
  let(:preferences) { create(:preference, user: user2, advanced_setting_for_crawl: true) }
  let(:agree_terms_of_service) { '本サービスを実行される場合は、 サービス利用規約 に同意したものとみなします。' }

  before { Timecop.freeze }

  after { Timecop.return }

  context 'パブリックユーザ：コンフィグなし：テスト送信' do
    let(:mail_address) { 'test@request.com' }
    let(:title) { 'bbbbbb.co.jpの検索' }
    let(:start_url) { 'https://bbbbbb.co.jp' }

    scenario '本リクエスト送信→リクエスト確認→再設定→リクエスト完了', js: true do
      visit root_path

      req_cnt = Request.count
      req_url_cnt = RequestedUrl.count

      # 最初は空
      expect(find_field('accept_id').value).to be_blank

      fill_in 'request_mail_address', with: mail_address
      fill_in 'request_corporate_list_site_start_url', with: start_url


      #------------
      #
      #   本リクエスト送信
      #
      #------------
      click_button 'request_main' # 本リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      req = Request.find_by_title(title)

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 1

      expect(find_field('accept_id').value).to eq req.accept_id

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content '受付ID'
          expect(page).to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
        end
      end

      #------------
      #
      #   リクエスト確認
      #
      #------------
      click_button 'confirm' # 確認ボタン

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(find_field('accept_id').value).to eq req.accept_id

        expect(page).not_to have_selector('h3', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within 'table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3', text: '設定')

        within 'table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使わない'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content '指定しない'
        end

        expect(page).not_to have_selector('h3', text: 'クロール詳細設定')
        expect(page).not_to have_selector('h5', text: '企業一覧ページの設定')
        expect(page).not_to have_selector('h5', text: '企業個別ページの設定')

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(page).not_to have_content 'より正確にクロールするための詳細設定'
        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content title
        expect(page).not_to have_content start_url

        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).to have_content agree_terms_of_service
        expect(page).not_to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: 'リクエスト送信')
      end

      #------------
      #
      #   再設定
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '再設定' # 再設定ボタン
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(find_field('accept_id').value).to eq req.accept_id

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使わない'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content '指定しない'
        end

        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(find_field('request_mail_address').value).to eq mail_address
        expect(page).not_to have_content '保存されているデータがあれば使う'
        expect(page).not_to have_selector('input#request_using_storage_days[type="text"]')
        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content '指定しない'
        expect(page).not_to have_content 'このページのみから収集する'
        expect(page).not_to have_content 'ページ送りのみ行う'

        expect(page).not_to have_selector('input#request_title')
        expect(page).not_to have_selector('label[for="request_title"]', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')

        expect(find_field('request_corporate_list_site_start_url').value).to eq start_url
        expect(page).to have_selector('label[for="request_corporate_list_site_start_url"]', text: '企業一覧サイトのURL')
        expect(page).not_to have_content 'より正確にクロールするための詳細設定'
        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).to have_content agree_terms_of_service

        expect(page).not_to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: 'リクエスト送信')
      end


      #------------
      #
      #   リクエスト完了
      #
      #------------
      req.update!(status: EasySettings.status[:completed])

      click_button 'confirm' # 確認ボタン

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(find_field('accept_id').value).to eq req.accept_id

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使わない'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content '指定しない'
        end

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: 'リクエスト送信')
      end

      expect(page).to have_selector('#request_form_part')
      expect(page).to have_content'リクエスト送信'
      expect(page).not_to have_content 'より正確にクロールするための詳細設定'
      expect(page).to have_content agree_terms_of_service
      expect(page).not_to have_selector('button#request_test', text: 'テストリクエスト送信')
      expect(page).to have_selector('button#request_main', text: 'リクエスト送信')
    end
  end

  context 'ログインユーザ：コンフィグなし：テスト送信' do
    let(:mail_address) { 'test@request.com' }
    let(:title) { 'リクエスト名_テストAAA 1' }
    let(:start_url) { 'https://bbbbbb.co.jp' }

    before { sign_in user }

    scenario 'テストリクエスト送信→リクエスト確認→再設定→リクエスト完了→本リクエスト送信', js: true do
      visit root_path

      req_cnt = Request.count
      req_url_cnt = RequestedUrl.count

      expect(page).not_to have_selector('input#accept_id')

      fill_in 'request_mail_address', with: mail_address
      fill_in 'request_title', with: title
      fill_in 'request_corporate_list_site_start_url', with: start_url


      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody' do
          expect(page).not_to have_content title
          expect(page).not_to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).not_to have_content 'テスト実行'
          expect(page).not_to have_content '未完了'
        end
      end


      #------------
      #
      #   テストリクエスト送信
      #
      #------------
      click_button 'request_test' # テストリクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      req = Request.find_by_title(title)

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 1

      expect(page).not_to have_selector('input#accept_id')

      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end

      #------------
      #
      #   リクエスト確認
      #
      #------------
      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'

        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within 'table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3', text: '設定')

        within 'table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使わない'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content '指定しない'
        end

        expect(page).not_to have_selector('h3', text: 'クロール詳細設定')
        expect(page).not_to have_selector('h5', text: '企業一覧ページの設定')
        expect(page).not_to have_selector('h5', text: '企業個別ページの設定')

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(page).not_to have_content 'より正確にクロールするための詳細設定'
        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content title
        expect(page).not_to have_content start_url

        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end

      #------------
      #
      #   再設定
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '再設定' # 再設定ボタン
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使わない'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content '指定しない'
        end

        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(find_field('request_mail_address').value).to eq mail_address
        expect(page).to have_content '保存されているデータがあれば使う'
        expect(page).not_to have_selector('input#request_using_storage_days[type="text"]')
        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).to have_content '指定しない'
        expect(page).to have_content 'このページのみから収集する'
        expect(page).to have_content 'ページ送りのみ行う'

        expect(find_field('request_title').value).to eq title
        expect(page).to have_selector('label[for="request_title"]', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')

        expect(find_field('request_corporate_list_site_start_url').value).to eq start_url
        expect(page).to have_selector('label[for="request_corporate_list_site_start_url"]', text: '企業一覧サイトのURL')
        expect(page).not_to have_content 'より正確にクロールするための詳細設定'
        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_content agree_terms_of_service

        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end

      confirm_storaged_data_field_operation


      #------------
      #
      #   リクエスト完了
      #
      #------------
      req.update!(status: EasySettings.status[:completed])

      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使わない'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content '指定しない'
        end

        expect(page).to have_content 'テストクロール結果'
        expect(page).to have_content '取得できませんでした。'
        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_content '大変申し訳ございませんが、このサイトには対応していない可能性があります。'
        expect(page).to have_content '設定やURLを変えて、何度かお試ししてみても取得できないようでしたら、このサイトは未対応の可能性が高いです。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).to have_selector('button', text: '本リクエスト送信')
      end

      expect(page).to have_selector('#request_form_part')
      expect(page).to have_content'リクエスト送信'
      expect(page).not_to have_content 'より正確にクロールするための詳細設定'
      expect(page).not_to have_content agree_terms_of_service
      expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
      expect(page).to have_selector('button#request_main', text: '本リクエスト送信')

      #------------
      #
      #   本リクエスト送信
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '本リクエスト送信' # 本リクエスト送信ボタン
      end

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 2

      expect(page).not_to have_selector('input#accept_id')

      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '本実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end
    end
  end



  context 'アドミンユーザ：コンフィグあり：テスト送信' do
    let(:title) { 'リクエスト名_テストAAA 2' }
    let(:start_url) { 'https://aaa2.co.jp' }
    let(:list_config_url1) { 'https://aaa2.co.jp/aaa2_list_1' }
    let(:list_config_url2) { 'https://aaa2.co.jp/aaa2_list_2' }
    let(:list_config_url3) { 'https://aaa2.co.jp/aaa2_list_3' }
    let(:list_config_url3_org1) { '株式会社AAA_url3_1' }
    let(:list_config_url3_org2) { '株式会社AAA_url3_2' }
    let(:list_config_url3_org3) { '株式会社AAA_url3_3' }
    let(:list_config_url3_org4) { '株式会社AAA_url3_4' }
    let(:list_config_url3_title1) { 'AAA2_url3_タイトル1' }
    let(:list_config_url3_text1_1) { 'AAA2_url3_テキスト1_1' }
    let(:list_config_url3_text1_2) { 'AAA2_url3_テキスト1_2' }
    let(:list_config_url3_title2) { 'AAA2_url3_タイトル2' }
    let(:list_config_url3_text2_1) { 'AAA2_url3_テキスト2_1' }
    let(:list_config_url3_text2_2) { 'AAA2_url3_テキスト2_2' }
    let(:list_config_url3_text2_3) { 'AAA2_url3_テキスト2_3' }

    let(:individual_config_url1) { 'https://aaa2.co.jp/aaa2_indiv_1' }
    let(:individual_config_url2) { 'https://aaa2.co.jp/aaa2_indiv_2' }

    scenario 'テストリクエスト送信→リクエスト確認→再設定→リクエスト完了→本リクエスト送信', js: true do
      preferences
      sign_in user2
      visit root_path

      req_cnt = Request.count
      req_url_cnt = RequestedUrl.count

      # 最初は空
      expect(page).not_to have_selector('input#accept_id')

      fill_in 'request_title', with: title
      fill_in 'request_corporate_list_site_start_url', with: start_url

      find("span", text: '保存されているデータがあれば使う').click # チェック

      find("span", text: 'このページのみから収集する', class: 'click-target-for-spec').click # チェック

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業一覧ページの設定').click # Open

      expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')

      fill_in 'request_corporate_list_1_url', with: list_config_url1

      find("#add_corporate_list_url_config", text: '追加').click

      fill_in 'request_corporate_list_2_url', with: list_config_url2

      find("#add_corporate_list_url_config", text: '追加').click

      fill_in 'request_corporate_list_3_url', with: list_config_url3

      find('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く').click # Open

      fill_in 'request_corporate_list_3_organization_name_1', with: list_config_url3_org1
      fill_in 'request_corporate_list_3_organization_name_2', with: list_config_url3_org2
      fill_in 'request_corporate_list_3_organization_name_3', with: list_config_url3_org3
      fill_in 'request_corporate_list_3_organization_name_4', with: list_config_url3_org4

      fill_in 'request_corporate_list_3_contents_1_title', with: list_config_url3_title1
      fill_in 'request_corporate_list_3_contents_1_text_1', with: list_config_url3_text1_1
      fill_in 'request_corporate_list_3_contents_1_text_2', with: list_config_url3_text1_2

      within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
        find('button.add_corporate_list_url_contents_config', text: '追加').click
      end

      fill_in 'request_corporate_list_3_contents_2_title', with: list_config_url3_title2
      fill_in 'request_corporate_list_3_contents_2_text_1', with: list_config_url3_text2_1
      fill_in 'request_corporate_list_3_contents_2_text_2', with: list_config_url3_text2_2
      fill_in 'request_corporate_list_3_contents_2_text_3', with: list_config_url3_text2_3

      find("h5", text: '企業個別ページの設定').click # Open

      fill_in 'request_corporate_individual_1_url', with: individual_config_url1

      find("#add_corporate_individual_url_config", text: '追加').click

      fill_in 'request_corporate_individual_2_url', with: individual_config_url2


      #------------
      #
      #   テストリクエスト送信
      #
      #------------
      click_button 'request_test' # テストリクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      req = Request.find_by_title(title)

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 1

      expect(req.corporate_list_config).to be_present
      expect(req.corporate_individual_config).to be_present

      expect(page).not_to have_selector('input#accept_id')

      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end

      #------------
      #
      #   リクエスト確認
      #
      #------------
      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う'
          expect(page).to have_content '期限なし'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).to have_selector('h3#confirm_request_form_crawl_config', text: 'クロール詳細設定')
        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '企業一覧ページの設定')

          expect(page).to have_selector('.row > div', text: '企業一覧ページのサンプルURL', count: 3)

          within '.row[data="1"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="3"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url3

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'

            expect(page).to have_content list_config_url3_org1
            expect(page).to have_content list_config_url3_org2
            expect(page).to have_content list_config_url3_org3
            expect(page).to have_content list_config_url3_org4


            within 'tr[data="con_1"]' do
              expect(page).to have_selector('th', text: list_config_url3_title1)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text1_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text1_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: '')
            end

            within 'tr[data="con_2"]' do
              expect(page).to have_selector('th', text: list_config_url3_title2)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text2_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text2_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: list_config_url3_text2_3)
            end
          end

          expect(page).not_to have_selector('.row[data="4"]')
        end

        within '#confirm_request_form_crawl_config_individual_area' do
          expect(page).to have_selector('h5', text: '企業個別ページの設定')

          expect(page).to have_selector('.row > div', text: '企業個別ページのサンプルURL', count: 2)

          within '.row[data="1"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.row[data="3"]')
        end

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do # フォームには記載なし
        expect(page).to have_content'リクエスト送信'
        expect(page).to have_content 'より正確にクロールするための詳細設定'

        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content title
        expect(page).not_to have_content start_url

        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_content list_config_url1
        expect(page).not_to have_content list_config_url2
        expect(page).not_to have_content individual_config_url1
        expect(page).not_to have_content individual_config_url2
        expect(page).to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end


      #------------
      #
      #   再設定
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '再設定' # 再設定ボタン
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う'
          expect(page).to have_content '期限なし'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).to have_selector('h3#confirm_request_form_crawl_config', text: 'クロール詳細設定')
        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '企業一覧ページの設定')

          expect(page).to have_selector('.row > div', text: '企業一覧ページのサンプルURL', count: 3)

          within '.row[data="1"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="3"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url3

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'

            expect(page).to have_content list_config_url3_org1
            expect(page).to have_content list_config_url3_org2
            expect(page).to have_content list_config_url3_org3
            expect(page).to have_content list_config_url3_org4


            within 'tr[data="con_1"]' do
              expect(page).to have_selector('th', text: list_config_url3_title1)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text1_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text1_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: '')
            end

            within 'tr[data="con_2"]' do
              expect(page).to have_selector('th', text: list_config_url3_title2)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text2_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text2_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: list_config_url3_text2_3)
            end
          end

          expect(page).not_to have_selector('.row[data="4"]')
        end

        within '#confirm_request_form_crawl_config_individual_area' do
          expect(page).to have_selector('h5', text: '企業個別ページの設定')

          expect(page).to have_selector('.row > div', text: '企業個別ページのサンプルURL', count: 2)

          within '.row[data="1"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.row[data="3"]')
        end

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(find_field('request_mail_address').value).to be_blank
        expect(page).to have_content '保存されているデータがあれば使う'
        expect(find_field('request_using_storage_days').value).to be_blank
        expect(page).to have_content '日前の取得データなら使う'
        expect(page).to have_content '指定しない'
        expect(page).to have_content 'このページのみから収集する'
        expect(page).to have_content 'ページ送りのみ行う'

        expect(find_field('request_title').value).to eq title
        expect(page).to have_selector('label[for="request_title"]', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')

        expect(find_field('request_corporate_list_site_start_url').value).to eq start_url
        expect(page).to have_selector('label[for="request_corporate_list_site_start_url"]', text: '企業一覧サイトのURL')

        expect(page).to have_content 'より正確にクロールするための詳細設定'
        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).to have_content '企業一覧ページの設定'

        within '#corporate_list_config' do
          within '.field_corporate_list_config[url_num="1"]' do
            expect(find_field('request_corporate_list_1_url').value).to eq list_config_url1
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.field_corporate_list_config[url_num="2"]' do
            expect(find_field('request_corporate_list_2_url').value).to eq list_config_url2
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.field_corporate_list_config[url_num="3"]' do
            expect(find_field('request_corporate_list_3_url').value).to eq list_config_url3
            expect(page).not_to have_content '詳細設定なし'
            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(find_field('request_corporate_list_3_organization_name_1').value).to eq list_config_url3_org1
            expect(find_field('request_corporate_list_3_organization_name_2').value).to eq list_config_url3_org2
            expect(find_field('request_corporate_list_3_organization_name_3').value).to eq list_config_url3_org3
            expect(find_field('request_corporate_list_3_organization_name_4').value).to eq list_config_url3_org4

            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
            expect(find_field('request_corporate_list_3_contents_1_title').value).to eq list_config_url3_title1
            expect(find_field('request_corporate_list_3_contents_1_text_1').value).to eq list_config_url3_text1_1
            expect(find_field('request_corporate_list_3_contents_1_text_2').value).to eq list_config_url3_text1_2
            expect(find_field('request_corporate_list_3_contents_1_text_3').value).to be_blank

            expect(find_field('request_corporate_list_3_contents_2_title').value).to eq list_config_url3_title2
            expect(find_field('request_corporate_list_3_contents_2_text_1').value).to eq list_config_url3_text2_1
            expect(find_field('request_corporate_list_3_contents_2_text_2').value).to eq list_config_url3_text2_2
            expect(find_field('request_corporate_list_3_contents_2_text_3').value).to eq list_config_url3_text2_3

            expect(page).not_to have_selector('#request_corporate_list_3_contents_3_title')
            expect(page).not_to have_selector('#request_corporate_list_3_contents_3_text_1')
          end
        end

        expect(page).to have_content '企業個別ページの設定'
        within '#corporate_individual_config' do
          within '.field_corporate_individual_config[url_num="1"]' do
            expect(find_field('request_corporate_individual_1_url').value).to eq individual_config_url1
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.field_corporate_individual_config[url_num="2"]' do
            expect(find_field('request_corporate_individual_2_url').value).to eq individual_config_url2
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.field_corporate_individual_config[url_num="3"]')
        end

        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end


      #------------
      #
      #   リクエスト完了
      #
      #------------
      req.update!(status: EasySettings.status[:completed])

      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う(期限なし)'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).to have_selector('h3#confirm_request_form_crawl_config', text: 'クロール詳細設定')
        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '企業一覧ページの設定')

          expect(page).to have_selector('.row > div', text: '企業一覧ページのサンプルURL', count: 3)

          within '.row[data="1"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="3"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url3

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'

            expect(page).to have_content list_config_url3_org1
            expect(page).to have_content list_config_url3_org2
            expect(page).to have_content list_config_url3_org3
            expect(page).to have_content list_config_url3_org4


            within 'tr[data="con_1"]' do
              expect(page).to have_selector('th', text: list_config_url3_title1)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text1_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text1_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: '')
            end

            within 'tr[data="con_2"]' do
              expect(page).to have_selector('th', text: list_config_url3_title2)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text2_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text2_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: list_config_url3_text2_3)
            end
          end

          expect(page).not_to have_selector('.row[data="4"]')
        end

        within '#confirm_request_form_crawl_config_individual_area' do
          expect(page).to have_selector('h5', text: '企業個別ページの設定')

          expect(page).to have_selector('.row > div', text: '企業個別ページのサンプルURL', count: 2)

          within '.row[data="1"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.row[data="3"]')
        end

        expect(page).to have_content 'テストクロール結果'
        expect(page).to have_content '取得できませんでした。'
        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_content '大変申し訳ございませんが、このサイトには対応していない可能性があります。'
        expect(page).to have_content '設定やURLを変えて、何度かお試ししてみても取得できないようでしたら、このサイトは未対応の可能性が高いです。'

        expect(page).to have_selector('button', text: '再設定')
        expect(page).to have_selector('button', text: '本リクエスト送信')
      end


      within '#request_form_part' do # フォームには記載なし
        expect(page).to have_content'リクエスト送信'
        expect(page).to have_content 'より正確にクロールするための詳細設定'

        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content title
        expect(page).not_to have_content start_url

        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_content list_config_url1
        expect(page).not_to have_content list_config_url2
        expect(page).not_to have_content individual_config_url1
        expect(page).not_to have_content individual_config_url2
        expect(page).to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).not_to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end


      #------------
      #
      #   本リクエスト送信
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '本リクエスト送信' # 本リクエスト送信ボタン
      end

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 2

      expect(page).not_to have_selector('input#accept_id')

      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '本実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end
    end
  end


  context 'アドミンユーザ：コンフィグあり：テスト送信' do
    let(:title) { 'リクエスト名_テストAAA 2' }
    let(:start_url) { 'https://aaa2.co.jp' }
    let(:list_config_url1) { 'https://aaa2.co.jp/aaa2_list_1' }
    let(:list_config_url2) { 'https://aaa2.co.jp/aaa2_list_2' }
    let(:list_config_url3) { 'https://aaa2.co.jp/aaa2_list_3' }
    let(:list_config_url3_org1) { '株式会社AAA_url3_1' }
    let(:list_config_url3_org2) { '株式会社AAA_url3_2' }
    let(:list_config_url3_org3) { '株式会社AAA_url3_3' }
    let(:list_config_url3_org4) { '株式会社AAA_url3_4' }
    let(:list_config_url3_title1) { 'AAA2_url3_タイトル1' }
    let(:list_config_url3_text1_1) { 'AAA2_url3_テキスト1_1' }
    let(:list_config_url3_text1_2) { 'AAA2_url3_テキスト1_2' }
    let(:list_config_url3_title2) { 'AAA2_url3_タイトル2' }
    let(:list_config_url3_text2_1) { 'AAA2_url3_テキスト2_1' }
    let(:list_config_url3_text2_2) { 'AAA2_url3_テキスト2_2' }
    let(:list_config_url3_text2_3) { 'AAA2_url3_テキスト2_3' }

    let(:individual_config_url1) { 'https://aaa2.co.jp/aaa2_indiv_1' }
    let(:individual_config_url2) { 'https://aaa2.co.jp/aaa2_indiv_2' }
    let(:individual_company1) { '株式会社BBB' }
    let(:individual_title1_1) { 'タイトルBB_1' }
    let(:individual_text1_1) { 'テキストBB_1' }
    let(:individual_title1_2) { 'タイトルBB_2' }
    let(:individual_text1_2) { 'テキストBB_2' }




    scenario 'テストリクエスト送信→リクエスト確認→再設定→リクエスト完了→本リクエスト送信', js: true do
      preferences
      sign_in user2
      visit root_path

      req_cnt = Request.count
      req_url_cnt = RequestedUrl.count

      expect(page).not_to have_selector('input#accept_id')

      fill_in 'request_title', with: title
      fill_in 'request_corporate_list_site_start_url', with: start_url

      find("span", text: '保存されているデータがあれば使う').click # チェック

      find("span", text: 'このページのみから収集する', class: 'click-target-for-spec').click # チェック

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業一覧ページの設定').click # Open

      expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')

      fill_in 'request_corporate_list_1_url', with: list_config_url1

      find("#add_corporate_list_url_config", text: '追加').click

      fill_in 'request_corporate_list_2_url', with: list_config_url2

      find("#add_corporate_list_url_config", text: '追加').click

      fill_in 'request_corporate_list_3_url', with: list_config_url3

      find('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く').click # Open

      fill_in 'request_corporate_list_3_organization_name_1', with: list_config_url3_org1
      fill_in 'request_corporate_list_3_organization_name_2', with: list_config_url3_org2
      fill_in 'request_corporate_list_3_organization_name_3', with: list_config_url3_org3
      fill_in 'request_corporate_list_3_organization_name_4', with: list_config_url3_org4

      fill_in 'request_corporate_list_3_contents_1_title', with: list_config_url3_title1
      fill_in 'request_corporate_list_3_contents_1_text_1', with: list_config_url3_text1_1
      fill_in 'request_corporate_list_3_contents_1_text_2', with: list_config_url3_text1_2

      within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
        find('button.add_corporate_list_url_contents_config', text: '追加').click
      end

      fill_in 'request_corporate_list_3_contents_2_title', with: list_config_url3_title2
      fill_in 'request_corporate_list_3_contents_2_text_1', with: list_config_url3_text2_1
      fill_in 'request_corporate_list_3_contents_2_text_2', with: list_config_url3_text2_2
      fill_in 'request_corporate_list_3_contents_2_text_3', with: list_config_url3_text2_3

      find("h5", text: '企業個別ページの設定').click # Open

      fill_in 'request_corporate_individual_1_url', with: individual_config_url1

      find("#add_corporate_individual_url_config", text: '追加').click

      fill_in 'request_corporate_individual_2_url', with: individual_config_url2

      find("#corporate_individual_1_details_toggle_btn", text: '詳細設定を開く').click

      fill_in 'request_corporate_individual_1_organization_name', with: individual_company1

      fill_in 'request_corporate_individual_1_contents_1_title', with: individual_title1_1
      fill_in 'request_corporate_individual_1_contents_1_text', with: individual_text1_1

      find(".add_corporate_individual_url_contents_config", text: '追加').click

      fill_in 'request_corporate_individual_1_contents_2_title', with: individual_title1_2
      fill_in 'request_corporate_individual_1_contents_2_text', with: individual_text1_2

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr' do
          expect(page).not_to have_content title
          expect(page).not_to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).not_to have_content 'テスト実行'
          expect(page).not_to have_content '未完了'
        end
      end

      #------------
      #
      #   テストリクエスト送信
      #
      #------------
      click_button 'request_test' # テストリクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      req = Request.find_by_title(title)

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 1

      expect(req.corporate_list_config).to be_present
      expect(req.corporate_individual_config).to be_present

      expect(page).not_to have_selector('input#accept_id')


      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end

      #------------
      #
      #   リクエスト確認
      #
      #------------
      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う'
          expect(page).to have_content '期限なし'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).to have_selector('h3#confirm_request_form_crawl_config', text: 'クロール詳細設定')
        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '企業一覧ページの設定')

          expect(page).to have_selector('.row > div', text: '企業一覧ページのサンプルURL', count: 3)

          within '.row[data="1"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="3"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url3

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'

            expect(page).to have_content list_config_url3_org1
            expect(page).to have_content list_config_url3_org2
            expect(page).to have_content list_config_url3_org3
            expect(page).to have_content list_config_url3_org4


            within 'tr[data="con_1"]' do
              expect(page).to have_selector('th', text: list_config_url3_title1)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text1_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text1_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: '')
            end

            within 'tr[data="con_2"]' do
              expect(page).to have_selector('th', text: list_config_url3_title2)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text2_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text2_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: list_config_url3_text2_3)
            end
          end

          expect(page).not_to have_selector('.row[data="4"]')
        end

        within '#confirm_request_form_crawl_config_individual_area' do
          expect(page).to have_selector('h5', text: '企業個別ページの設定')

          expect(page).to have_selector('.row > div', text: '企業個別ページのサンプルURL', count: 2)

          within '.row[data="1"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url1

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content individual_company1

            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
            expect(page).to have_content individual_title1_1
            expect(page).to have_content individual_text1_1
            expect(page).to have_content individual_title1_2
            expect(page).to have_content individual_text1_2
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.row[data="3"]')
        end

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do # フォームには記載なし
        expect(page).to have_content'リクエスト送信'
        expect(page).to have_content 'より正確にクロールするための詳細設定'

        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content title
        expect(page).not_to have_content start_url

        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_content list_config_url1
        expect(page).not_to have_content list_config_url2
        expect(page).not_to have_content individual_config_url1
        expect(page).not_to have_content individual_config_url2
        expect(page).to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end


      #------------
      #
      #   再設定
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '再設定' # 再設定ボタン
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う'
          expect(page).to have_content '期限なし'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).to have_selector('h3#confirm_request_form_crawl_config', text: 'クロール詳細設定')
        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '企業一覧ページの設定')

          expect(page).to have_selector('.row > div', text: '企業一覧ページのサンプルURL', count: 3)

          within '.row[data="1"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="3"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url3

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'

            expect(page).to have_content list_config_url3_org1
            expect(page).to have_content list_config_url3_org2
            expect(page).to have_content list_config_url3_org3
            expect(page).to have_content list_config_url3_org4


            within 'tr[data="con_1"]' do
              expect(page).to have_selector('th', text: list_config_url3_title1)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text1_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text1_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: '')
            end

            within 'tr[data="con_2"]' do
              expect(page).to have_selector('th', text: list_config_url3_title2)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text2_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text2_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: list_config_url3_text2_3)
            end
          end

          expect(page).not_to have_selector('.row[data="4"]')
        end

        within '#confirm_request_form_crawl_config_individual_area' do
          expect(page).to have_selector('h5', text: '企業個別ページの設定')

          expect(page).to have_selector('.row > div', text: '企業個別ページのサンプルURL', count: 2)

          within '.row[data="1"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url1

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content individual_company1

            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
            expect(page).to have_content individual_title1_1
            expect(page).to have_content individual_text1_1
            expect(page).to have_content individual_title1_2
            expect(page).to have_content individual_text1_2
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.row[data="3"]')
        end

        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_selector('button', text: '再設定')
        expect(page).not_to have_selector('button', text: '本リクエスト送信')
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(find_field('request_mail_address').value).to be_blank
        expect(page).to have_content '保存されているデータがあれば使う'
        expect(find_field('request_using_storage_days').value).to be_blank
        expect(page).to have_content '日前の取得データなら使う'
        expect(page).to have_content '指定しない'
        expect(page).to have_content 'このページのみから収集する'
        expect(page).to have_content 'ページ送りのみ行う'

        expect(find_field('request_title').value).to eq title
        expect(page).to have_selector('label[for="request_title"]', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')

        expect(find_field('request_corporate_list_site_start_url').value).to eq start_url
        expect(page).to have_selector('label[for="request_corporate_list_site_start_url"]', text: '企業一覧サイトのURL')

        expect(page).to have_content 'より正確にクロールするための詳細設定'
        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).to have_content '企業一覧ページの設定'

        within '#corporate_list_config' do
          within '.field_corporate_list_config[url_num="1"]' do
            expect(find_field('request_corporate_list_1_url').value).to eq list_config_url1
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.field_corporate_list_config[url_num="2"]' do
            expect(find_field('request_corporate_list_2_url').value).to eq list_config_url2
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.field_corporate_list_config[url_num="3"]' do
            expect(find_field('request_corporate_list_3_url').value).to eq list_config_url3
            expect(page).not_to have_content '詳細設定なし'
            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(find_field('request_corporate_list_3_organization_name_1').value).to eq list_config_url3_org1
            expect(find_field('request_corporate_list_3_organization_name_2').value).to eq list_config_url3_org2
            expect(find_field('request_corporate_list_3_organization_name_3').value).to eq list_config_url3_org3
            expect(find_field('request_corporate_list_3_organization_name_4').value).to eq list_config_url3_org4

            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
            expect(find_field('request_corporate_list_3_contents_1_title').value).to eq list_config_url3_title1
            expect(find_field('request_corporate_list_3_contents_1_text_1').value).to eq list_config_url3_text1_1
            expect(find_field('request_corporate_list_3_contents_1_text_2').value).to eq list_config_url3_text1_2
            expect(find_field('request_corporate_list_3_contents_1_text_3').value).to be_blank

            expect(find_field('request_corporate_list_3_contents_2_title').value).to eq list_config_url3_title2
            expect(find_field('request_corporate_list_3_contents_2_text_1').value).to eq list_config_url3_text2_1
            expect(find_field('request_corporate_list_3_contents_2_text_2').value).to eq list_config_url3_text2_2
            expect(find_field('request_corporate_list_3_contents_2_text_3').value).to eq list_config_url3_text2_3

            expect(page).not_to have_selector('#request_corporate_list_3_contents_3_title')
            expect(page).not_to have_selector('#request_corporate_list_3_contents_3_text_1')
          end
        end

        expect(page).to have_content '企業個別ページの設定'
        within '#corporate_individual_config' do
          within '.field_corporate_individual_config[url_num="1"]' do
            expect(find_field('request_corporate_individual_1_url').value).to eq individual_config_url1
            expect(page).not_to have_content '詳細設定なし'

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(find_field('request_corporate_individual_1_organization_name').value).to eq individual_company1

            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
            expect(find_field('request_corporate_individual_1_contents_1_title').value).to eq individual_title1_1
            expect(find_field('request_corporate_individual_1_contents_1_text').value).to eq individual_text1_1
            expect(find_field('request_corporate_individual_1_contents_2_title').value).to eq individual_title1_2
            expect(find_field('request_corporate_individual_1_contents_2_text').value).to eq individual_text1_2
          end

          within '.field_corporate_individual_config[url_num="2"]' do
            expect(find_field('request_corporate_individual_2_url').value).to eq individual_config_url2
            expect(page).to have_content '詳細設定なし'
            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.field_corporate_individual_config[url_num="3"]')
        end

        expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end

      #------------
      #
      #   リクエスト完了
      #
      #------------
      req.update!(status: EasySettings.status[:completed])

      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う(期限なし)'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).to have_selector('h3#confirm_request_form_crawl_config', text: 'クロール詳細設定')
        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '企業一覧ページの設定')

          expect(page).to have_selector('.row > div', text: '企業一覧ページのサンプルURL', count: 3)

          within '.row[data="1"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url1

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          within '.row[data="3"]' do
            expect(page).to have_content '企業一覧ページのサンプルURL'
            expect(page).to have_content list_config_url3

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'

            expect(page).to have_content list_config_url3_org1
            expect(page).to have_content list_config_url3_org2
            expect(page).to have_content list_config_url3_org3
            expect(page).to have_content list_config_url3_org4


            within 'tr[data="con_1"]' do
              expect(page).to have_selector('th', text: list_config_url3_title1)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text1_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text1_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: '')
            end

            within 'tr[data="con_2"]' do
              expect(page).to have_selector('th', text: list_config_url3_title2)
              expect(page).to have_selector('td:first-of-type', text: list_config_url3_text2_1)
              expect(page).to have_selector('td:nth-of-type(2)', text: list_config_url3_text2_2)
              expect(page).to have_selector('td:nth-of-type(3)', text: list_config_url3_text2_3)
            end
          end

          expect(page).not_to have_selector('.row[data="4"]')
        end

        within '#confirm_request_form_crawl_config_individual_area' do
          expect(page).to have_selector('h5', text: '企業個別ページの設定')

          expect(page).to have_selector('.row > div', text: '企業個別ページのサンプルURL', count: 2)

          within '.row[data="1"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url1

            expect(page).to have_content 'ページに記載されている会社名のサンプル'
            expect(page).to have_content individual_company1

            expect(page).to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
            expect(page).to have_content individual_title1_1
            expect(page).to have_content individual_text1_1
            expect(page).to have_content individual_title1_2
            expect(page).to have_content individual_text1_2
          end

          within '.row[data="2"]' do
            expect(page).to have_content '企業個別ページのサンプルURL'
            expect(page).to have_content individual_config_url2

            expect(page).not_to have_content 'ページに記載されている会社名のサンプル'
            expect(page).not_to have_content '取得したい情報の種別名とページに記載されているサンプル文字'
          end

          expect(page).not_to have_selector('.row[data="3"]')
        end

        expect(page).to have_content 'テストクロール結果'
        expect(page).to have_content '取得できませんでした。'
        expect(page).not_to have_content '取得結果をご覧になり、取得結果に問題がありましたら、設定項目を見直し、再度テストを行なってください。'
        expect(page).not_to have_content 'もし、問題ないようでしたら、本リクストを送信してください。'
        expect(page).to have_content '大変申し訳ございませんが、このサイトには対応していない可能性があります。'
        expect(page).to have_content '設定やURLを変えて、何度かお試ししてみても取得できないようでしたら、このサイトは未対応の可能性が高いです。'

        expect(page).to have_selector('button', text: '再設定')
        expect(page).to have_selector('button', text: '本リクエスト送信')
      end


      within '#request_form_part' do # フォームには記載なし
        expect(page).to have_content'リクエスト送信'
        expect(page).to have_content 'より正確にクロールするための詳細設定'

        expect(page).not_to have_content '日前の取得データなら使う'
        expect(page).not_to have_content title
        expect(page).not_to have_content start_url

        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
        expect(page).not_to have_content list_config_url1
        expect(page).not_to have_content list_config_url2
        expect(page).not_to have_content individual_config_url1
        expect(page).not_to have_content individual_config_url2
        expect(page).to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content agree_terms_of_service
        expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
        expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).not_to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end


      #------------
      #
      #   本リクエスト送信
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '本リクエスト送信' # 本リクエスト送信ボタン
      end

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 2

      expect(page).not_to have_selector('input#accept_id')

      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content '本実行'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content title
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '本実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
        end
      end
    end
  end



  context 'アドミンユーザ：コンフィグを入力するが、設定なしに変更する：テスト送信' do
    let(:title) { 'リクエスト名_テストAAA 2' }
    let(:start_url) { 'https://aaa2.co.jp' }
    let(:list_config_url1) { 'https://aaa2.co.jp/aaa2_list_1' }
    let(:list_config_url2) { 'https://aaa2.co.jp/aaa2_list_2' }
    let(:list_config_url3) { 'https://aaa2.co.jp/aaa2_list_3' }
    let(:list_config_url3_org1) { '株式会社AAA_url3_1' }
    let(:list_config_url3_org2) { '株式会社AAA_url3_2' }
    let(:list_config_url3_org3) { '株式会社AAA_url3_3' }
    let(:list_config_url3_org4) { '株式会社AAA_url3_4' }
    let(:list_config_url3_title1) { 'AAA2_url3_タイトル1' }
    let(:list_config_url3_text1_1) { 'AAA2_url3_テキスト1_1' }
    let(:list_config_url3_text1_2) { 'AAA2_url3_テキスト1_2' }
    let(:list_config_url3_title2) { 'AAA2_url3_タイトル2' }
    let(:list_config_url3_text2_1) { 'AAA2_url3_テキスト2_1' }
    let(:list_config_url3_text2_2) { 'AAA2_url3_テキスト2_2' }
    let(:list_config_url3_text2_3) { 'AAA2_url3_テキスト2_3' }

    let(:individual_config_url1) { 'https://aaa2.co.jp/aaa2_indiv_1' }
    let(:individual_config_url2) { 'https://aaa2.co.jp/aaa2_indiv_2' }

    scenario 'テストリクエスト送信→リクエスト確認→再設定→リクエスト完了→本リクエスト送信', js: true do
      preferences
      sign_in user2
      visit root_path

      req_cnt = Request.count
      req_url_cnt = RequestedUrl.count

      expect(page).not_to have_selector('input#accept_id')

      fill_in 'request_title', with: title
      fill_in 'request_corporate_list_site_start_url', with: start_url

      find("span", text: '保存されているデータがあれば使う').click # チェック

      find("span", text: 'このページのみから収集する', class: 'click-target-for-spec').click # チェック

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業一覧ページの設定').click # Open

      expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')

      fill_in 'request_corporate_list_1_url', with: list_config_url1

      find("#add_corporate_list_url_config", text: '追加').click

      fill_in 'request_corporate_list_2_url', with: list_config_url2

      find("#add_corporate_list_url_config", text: '追加').click

      fill_in 'request_corporate_list_3_url', with: list_config_url3

      find('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く').click # Open

      fill_in 'request_corporate_list_3_organization_name_1', with: list_config_url3_org1
      fill_in 'request_corporate_list_3_organization_name_2', with: list_config_url3_org2
      fill_in 'request_corporate_list_3_organization_name_3', with: list_config_url3_org3
      fill_in 'request_corporate_list_3_organization_name_4', with: list_config_url3_org4

      fill_in 'request_corporate_list_3_contents_1_title', with: list_config_url3_title1
      fill_in 'request_corporate_list_3_contents_1_text_1', with: list_config_url3_text1_1
      fill_in 'request_corporate_list_3_contents_1_text_2', with: list_config_url3_text1_2

      within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
        find('button.add_corporate_list_url_contents_config', text: '追加').click
      end

      fill_in 'request_corporate_list_3_contents_2_title', with: list_config_url3_title2
      fill_in 'request_corporate_list_3_contents_2_text_1', with: list_config_url3_text2_1
      fill_in 'request_corporate_list_3_contents_2_text_2', with: list_config_url3_text2_2
      fill_in 'request_corporate_list_3_contents_2_text_3', with: list_config_url3_text2_3

      find("h5", text: '企業個別ページの設定').click # Open

      fill_in 'request_corporate_individual_1_url', with: individual_config_url1

      find("#add_corporate_individual_url_config", text: '追加').click

      fill_in 'request_corporate_individual_2_url', with: individual_config_url2


      find("h3", text: 'より正確にクロールするための詳細設定').click # Close


      #------------
      #
      #   テストリクエスト送信
      #
      #------------
      click_button 'request_test' # テストリクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      req = Request.find_by_title(title)

      expect(Request.count).to eq req_cnt + 1
      expect(RequestedUrl.count).to eq req_url_cnt + 1

      expect(req.corporate_list_config).to be_nil
      expect(req.corporate_individual_config).to be_nil

      expect(page).not_to have_selector('input#accept_id')

      within "#accept" do
        within 'table tbody' do
          expect(page).not_to have_content '受付ID'
          expect(page).not_to have_content req.accept_id
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      #------------
      #
      #   リクエスト確認
      #
      #------------
      within "#requests" do
        within 'table tbody tr:nth-child(2)' do
          find('i', text: 'find_in_page').click # Confirm 確認ボタン
        end
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う'
          expect(page).to have_content '期限なし'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end

        expect(page).not_to have_content('クロール詳細設定')
        expect(page).not_to have_content('企業一覧ページの設定')
        expect(page).not_to have_selector('企業個別ページの設定')
      end

      #------------
      #
      #   再設定
      #
      #------------
      within "#confirm_request_form" do
        click_button 'submit_button', text: '再設定' # 再設定ボタン
      end

      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id')

        expect(page).not_to have_selector('h3#confirm_request_form_result', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within '#confirm_request_form table.config-1 tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content title
          expect(page).to have_content '企業一覧サイトのURL'
          expect(page).to have_content start_url
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '実行の種類'
          expect(page).to have_content 'テスト実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
        end

        expect(page).to have_selector('h3#confirm_request_form_config', text: '設定')

        within '#confirm_request_form table.config-2 tbody' do
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content '保存データがあれば使うか'
          expect(page).to have_content '使う'
          expect(page).to have_content '期限なし'
          expect(page).to have_content 'ページ遷移の設定'
          expect(page).to have_content 'このページのみから収集する'
        end
      end

      within '#request_form_part' do
        expect(page).to have_content'リクエスト送信'
        expect(find_field('request_mail_address').value).to be_blank
        expect(page).to have_content '保存されているデータがあれば使う'
        expect(find_field('request_using_storage_days').value).to be_blank
        expect(page).to have_content '日前の取得データなら使う'
        expect(page).to have_content '指定しない'
        expect(page).to have_content 'このページのみから収集する'
        expect(page).to have_content 'ページ送りのみ行う'

        expect(find_field('request_title').value).to eq title
        expect(page).to have_selector('label[for="request_title"]', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')

        expect(find_field('request_corporate_list_site_start_url').value).to eq start_url
        expect(page).to have_selector('label[for="request_corporate_list_site_start_url"]', text: '企業一覧サイトのURL')

        expect(page).to have_content 'より正確にクロールするための詳細設定'
        expect(page).to have_selector('#detail_configuration_off', text: '設定なし')
        expect(page).not_to have_content '企業一覧ページの設定'
        expect(page).not_to have_content '企業個別ページの設定'
      end
    end
  end
end
require 'rails_helper'
require 'features/corporate_list_config_operation'

RSpec.feature "ホーム：企業一覧サイトからの収集のテスト：画面周りの操作", type: :feature do
  before { create_public_user }
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:preferences) { create(:preference, user: user2, advanced_setting_for_crawl: true) }
  let(:agree_terms_of_service) { '本サービスを実行される場合は、 サービス利用規約 に同意したものとみなします。' }

  scenario 'パブリックユーザ：企業一覧サイトからの収集ページを開いた時の状態', js: true do
    visit root_path
    within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

    # リクエスト確認フィールドがある
    within "#confirm_request_form" do
      expect(page).to have_content 'リクエスト確認'
      expect(page).to have_selector('input#accept_id[type="text"]')
      expect(page).to have_selector('button#confirm', text: '確認')
    end

    # リクエスト送信フィールドがある
    within "#request_form_part" do
      expect(page).to have_content 'リクエスト送信'
      expect(page).to have_selector('input#request_mail_address')
      expect(page).to have_selector('label', text: 'メールアドレス')
      # expect(page).to have_selector('input#request_use_storage')
      expect(page).not_to have_content '保存されているデータがあれば使う'
      expect(page).not_to have_selector('input#request_using_storage_days')
      expect(page).not_to have_content '日前の取得データなら使う'

      expect(page).not_to have_selector('input#request_title')
      expect(page).not_to have_selector('label', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')
      expect(page).to have_selector('input#request_corporate_list_site_start_url')
      expect(page).to have_selector('label', text: '企業一覧サイトのURL')

      expect(page).not_to have_content 'より正確にクロールするための詳細設定'
      expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')

      expect(page).not_to have_content '企業一覧ページの設定'
      expect(page).not_to have_selector('#corporate_list_config_off')
      expect(page).not_to have_content '企業個別ページの設定'
      expect(page).not_to have_selector('#corporate_individual_config_off')

      expect(page).to have_content agree_terms_of_service

      expect(page).not_to have_selector('button#request_test', text: 'テストリクエスト送信')
      expect(page).to have_selector('button#request_main', text: 'リクエスト送信')
    end

    # リクエスト一覧フィールドなし
    expect(page).not_to have_content 'リクエスト一覧'
  end

  context 'ログイン済み' do
    before do
      Timecop.freeze
      sign_in user
    end

    after { Timecop.return }

    describe '通常ページ表示の確認' do
      before do
        r = create(:request, :corporate_site_list, user: user, title: 'AAAリクエスト_メイン_DL可能', status: EasySettings.status[:completed], test: false, result_file_path: 'path', expiration_date: 4.days.from_now)
        create(:corporate_list_requested_url_finished, request: r)
        r = create(:request, :corporate_site_list, user: user, title: 'AAAリクエスト_メイン_DL不可', status: EasySettings.status[:completed], test: false, expiration_date: nil)
        create(:corporate_list_requested_url_finished, request: r)
        create(:request, :corporate_site_list, user: user, title: 'AAAリクエスト_テスト', status: EasySettings.status[:new], test: true)
      end

      scenario '企業一覧サイトからの収集ページを開いた時の状態', js: true do

        visit root_path
        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

        # リクエスト確認フィールドがない
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).not_to have_selector('input#accept_id[type="text"]')
        expect(page).not_to have_selector('button#confirm', text: '確認')

        # リクエスト送信フィールドがある
        within "#request_form_part" do
          expect(page).to have_content 'リクエスト送信'
          expect(page).to have_selector('input#request_mail_address')
          expect(page).to have_selector('label', text: 'メールアドレス')
          expect(page).to have_content '保存されているデータがあれば使う'
          expect(page).not_to have_selector('input#request_using_storage_days')
          expect(page).not_to have_content '日前の取得データなら使う'

          expect(page).to have_selector('input#request_title')
          expect(page).to have_selector('label', text: 'リクエスト名（作成するリクエストに任意の名前をつけてください）')
          expect(page).to have_selector('input#request_corporate_list_site_start_url')
          expect(page).to have_selector('label', text: '企業一覧サイトのURL')

          expect(page).not_to have_content 'より正確にクロールするための詳細設定'
          expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')

          expect(page).not_to have_content '企業一覧ページの設定'
          expect(page).not_to have_selector('#corporate_list_config_off')
          expect(page).not_to have_content '企業個別ページの設定'
          expect(page).not_to have_selector('#corporate_individual_config_off')

          expect(page).not_to have_content agree_terms_of_service

          expect(page).to have_selector('button#request_test', text: 'テストリクエスト送信')
          expect(page).to have_selector('button#request_main', text: '本リクエスト送信')
        end

        # リクエスト一覧フィールドがある
        within '#requests' do
          expect(page).to have_content 'リクエスト一覧'

          within 'table tbody tr:first-child' do
            expect(page).to have_content 'リクエスト名'
            expect(page).to have_content 'リクエスト日時'
            expect(page).to have_content '実行の種類'
            expect(page).to have_content 'ステータス'
            expect(page).to have_content '詳細'
            expect(page).to have_content '中止要求'
            expect(page).to have_content '結果DL'
            expect(page).to have_content 'ダウンロード期限'
            expect(page).to have_content '全体数'
            expect(page).to have_content '完了数'
            expect(page).to have_content '失敗数'
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content 'AAAリクエスト_テスト'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content 'テスト実行'
            expect(page).to have_content '未完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content 'AAAリクエスト_メイン_DL不可'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).not_to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
            expect(page).not_to have_content 4.days.from_now.strftime("%Y年%m月%d日")
          end

          within 'table tbody tr:nth-child(4)' do
            expect(page).to have_content 'AAAリクエスト_メイン_DL可能'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).not_to have_selector('i', text: 'stop')
            expect(page).to have_selector('i', text: 'file_download')
            expect(page).to have_content 4.days.from_now.strftime("%Y年%m月%d日")
          end
        end
      end
    end

    describe 'リクエスト一覧の確認：１ページ目' do
      before do
        rq = create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_メイン_ダウンロードできない1', status: EasySettings.status[:working], test: false, created_at: 6.day.ago)
        create(:corporate_list_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:successful])
        rq = create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_メイン_ダウンロードできない2', status: EasySettings.status[:working], test: false, created_at: 5.day.ago)
        create(:corporate_list_requested_url, request: rq, status: EasySettings.status[:working], finish_status: EasySettings.finish_status[:new])
        rq = create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_メイン1', status: EasySettings.status[:completed], test: false, result_file_path: 'path', expiration_date: 4.days.from_now, created_at: 3.day.ago)
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:successful])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:can_not_get_info])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:using_storaged_date])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        rq = create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_メイン2', status: EasySettings.status[:new], test: false, expiration_date: nil)
        rq = create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_メイン3', status: EasySettings.status[:discontinued], test: false, result_file_path: 'path', expiration_date: 3.days.from_now)
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:successful])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:can_not_get_info])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:using_storaged_date])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:new], finish_status: nil)
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        rq = create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_メイン4', status: EasySettings.status[:working], test: false, expiration_date: nil, created_at: 1.day.ago) 
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:successful])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:can_not_get_info])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:completed], finish_status: EasySettings.finish_status[:using_storaged_date])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:new], finish_status: nil)
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:new], finish_status: nil)
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        create(:company_info_requested_url, request: rq, status: EasySettings.status[:error], finish_status: EasySettings.finish_status[:error])
        create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_テスト1', status: EasySettings.status[:new], test: true)
        create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_テスト2', status: EasySettings.status[:discontinued], test: true)
        create(:request, :corporate_site_list, user: user, title: 'BBBリクエスト_テスト3', status: EasySettings.status[:completed], test: true, created_at: 2.days.ago)

        # 表示させないもの
        create(:request, user: user, title: 'BBBその他リクエスト_メイン1', status: EasySettings.status[:completed], test: false, expiration_date: 4.days.from_now)
        create(:request, user: user, title: 'BBBその他リクエスト_メイン2', type: Request.types[:csv_string], status: EasySettings.status[:new], test: false, expiration_date: nil)
        create(:request, user: User.get_public, title: 'BBBその他リクエスト_メイン3', status: EasySettings.status[:new], test: false, expiration_date: nil)
        create(:request, :corporate_site_list, user: User.get_public, title: 'BBBその他リクエスト_メイン4', status: EasySettings.status[:new], test: false, expiration_date: nil)
        create(:request, :corporate_site_list, user: User.get_public, title: 'BBBその他リクエスト_テスト5', status: EasySettings.status[:new], test: true, expiration_date: nil)
      end

      scenario 'リクエスト一覧の確認', js: true do
        visit root_path
        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).to have_content 'リクエスト送信'

        # リクエスト一覧フィールドがある
        within '#requests' do
          expect(page).to have_content 'リクエスト一覧'

          within 'table tbody tr:first-child' do
            expect(page).to have_content 'リクエスト名'
            expect(page).to have_content 'リクエスト日時'
            expect(page).to have_content '実行の種類'
            expect(page).to have_content 'ステータス'
            expect(page).to have_content '詳細'
            expect(page).to have_content '中止要求'
            expect(page).to have_content '結果DL'
            expect(page).to have_content 'ダウンロード期限'
            expect(page).to have_content '全体数'
            expect(page).to have_content '完了数'
            expect(page).to have_content '失敗数'
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content 'BBBリクエスト_テスト2'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content 'テスト実行'
            expect(page).to have_content '中止'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).not_to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content 'BBBリクエスト_テスト1'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content 'テスト実行'
            expect(page).to have_content '未完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(4)' do
            expect(page).to have_content 'BBBリクエスト_メイン3'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '中止'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).not_to have_selector('i', text: 'stop')
            expect(page).to have_selector('i', text: 'file_download')
            expect(page).to have_content 3.day.from_now.strftime("%Y年%m月%d日")
            expect(page).to have_content '6'
            expect(page).to have_content '3'
            expect(page).to have_content '2'
          end

          within 'table tbody tr:nth-child(5)' do
            expect(page).to have_content 'BBBリクエスト_メイン2'
            expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '未完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
            expect(page).to have_content '0'
            expect(page).to have_content '0'
            expect(page).to have_content '0'
          end

          within 'table tbody tr:nth-child(6)' do
            expect(page).to have_content 'BBBリクエスト_メイン4'
            expect(page).to have_content 1.day.ago.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '未完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
            expect(page).to have_content '9'
            expect(page).to have_content '3'
            expect(page).to have_content '4'
          end

          within 'table tbody tr:nth-child(7)' do
            expect(page).to have_content 'BBBリクエスト_テスト3'
            expect(page).to have_content 2.days.ago.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content 'テスト実行'
            expect(page).to have_content '完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).not_to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(8)' do
            expect(page).to have_content 'BBBリクエスト_メイン1'
            expect(page).to have_content 3.days.ago.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).not_to have_selector('i', text: 'stop')
            expect(page).to have_selector('i', text: 'file_download')
            expect(page).to have_content 4.day.from_now.strftime("%Y年%m月%d日")
            expect(page).to have_content '4'
            expect(page).to have_content '3'
            expect(page).to have_content '1'
          end

          within 'table tbody tr:nth-child(9)' do
            expect(page).to have_content 'BBBリクエスト_メイン_ダウンロードできない2'
            expect(page).to have_content 5.days.ago.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '未完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
            expect(page).to have_content '未定 0 0'
          end

          within 'table tbody tr:nth-child(10)' do
            expect(page).to have_content 'BBBリクエスト_メイン_ダウンロードできない1'
            expect(page).to have_content 6.days.ago.strftime("%Y年%m月%d日 %H:%M:%S")
            expect(page).to have_content '本実行'
            expect(page).to have_content '完了'
            expect(page).to have_selector('i', text: 'find_in_page')
            expect(page).to have_selector('i', text: 'stop')
            expect(page).not_to have_selector('i', text: 'file_download')
            expect(page).to have_content '未定 1 0'
          end

          within 'nav.pagy-nav' do
            expect(page).to have_selector('span.prev.disabled', text: '‹ Prev')
            expect(page).to have_selector('span.page.active', text: '1')
            expect(page).not_to have_content '2'
            expect(page).to have_selector('span.next.disabled', text: 'Next ›')
          end

          expect(page).not_to have_content 'BBBその他リクエスト_メイン1'
          expect(page).not_to have_content 'BBBその他リクエスト_メイン2'
          expect(page).not_to have_content 'BBBその他リクエスト_メイン3'
          expect(page).not_to have_content 'BBBその他リクエスト_メイン4'
          expect(page).not_to have_content 'BBBその他リクエスト_メイン5'
        end
      end
    end

    describe 'リクエスト一覧の確認：ページネーションの複数ページ' do
      before do
        25.times do |i|
          create(:request, :corporate_site_list, user: user, title: "CCCリクエスト_メイン#{i}", status: EasySettings.status[:completed], test: false, expiration_date: 4.days.from_now)
        end
      end

      scenario 'ページ移動ができる', js: true do
        visit root_path
        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).to have_content 'リクエスト送信'

        # リクエスト一覧フィールドがある
        within '#requests' do
          expect(page).to have_content 'CCCリクエスト_メイン24'
          expect(page).to have_content 'CCCリクエスト_メイン23'
          expect(page).to have_content 'CCCリクエスト_メイン22'
          expect(page).to have_content 'CCCリクエスト_メイン21'
          expect(page).to have_content 'CCCリクエスト_メイン20'
          expect(page).to have_content 'CCCリクエスト_メイン19'
          expect(page).to have_content 'CCCリクエスト_メイン18'
          expect(page).to have_content 'CCCリクエスト_メイン17'
          expect(page).to have_content 'CCCリクエスト_メイン16'
          expect(page).to have_content 'CCCリクエスト_メイン15'
          expect(page).not_to have_content 'CCCリクエスト_メイン14'
        end

        within 'nav.pagy-nav' do
          expect(page).to have_selector('span.prev.disabled', text: '‹ Prev')
          expect(page).to have_selector('span.page.active', text: '1')
          expect(page).to have_selector('span.page:not(.active)', text: '2')
          expect(page).to have_selector('span.page:not(.active)', text: '3')
          expect(page).not_to have_content '4'
          expect(page).to have_selector('span.next:not(.disabled)', text: 'Next ›')
        end


        find('nav.pagy-nav span', text: '2').click

        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).to have_content 'リクエスト送信'

        within '#requests' do
          expect(page).not_to have_content 'CCCリクエスト_メイン15'
          expect(page).to have_content 'CCCリクエスト_メイン14'
          expect(page).to have_content 'CCCリクエスト_メイン13'
          expect(page).to have_content 'CCCリクエスト_メイン12'
          expect(page).to have_content 'CCCリクエスト_メイン11'
          expect(page).to have_content 'CCCリクエスト_メイン10'
          expect(page).to have_content 'CCCリクエスト_メイン9'
          expect(page).to have_content 'CCCリクエスト_メイン8'
          expect(page).to have_content 'CCCリクエスト_メイン7'
          expect(page).to have_content 'CCCリクエスト_メイン6'
          expect(page).to have_content 'CCCリクエスト_メイン5'
          expect(page).not_to have_content 'CCCリクエスト_メイン4'
        end

        within 'nav.pagy-nav' do
          expect(page).to have_selector('span.prev:not(.disabled)', text: '‹ Prev')
          expect(page).to have_selector('span.page:not(.active)', text: '1')
          expect(page).to have_selector('span.page.active', text: '2')
          expect(page).to have_selector('span.page:not(.active)', text: '3')
          expect(page).not_to have_content '4'
          expect(page).to have_selector('span.next:not(.disabled)', text: 'Next ›')
        end


        find('nav.pagy-nav span', text: '3').click

        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).to have_content 'リクエスト送信'

        within '#requests' do
          expect(page).not_to have_content 'CCCリクエスト_メイン5'
          expect(page).to have_content 'CCCリクエスト_メイン4'
          expect(page).to have_content 'CCCリクエスト_メイン3'
          expect(page).to have_content 'CCCリクエスト_メイン2'
          expect(page).to have_content 'CCCリクエスト_メイン1'
          expect(page).to have_content 'CCCリクエスト_メイン0'
        end

        within 'nav.pagy-nav' do
          expect(page).to have_selector('span.prev:not(.disabled)', text: '‹ Prev')
          expect(page).to have_selector('span.page:not(.active)', text: '1')
          expect(page).to have_selector('span.page:not(.active)', text: '2')
          expect(page).to have_selector('span.page.active', text: '3')
          expect(page).not_to have_content '4'
          expect(page).to have_selector('span.next.disabled', text: 'Next ›')
        end

        find('nav.pagy-nav span', text: '‹ Prev').click

        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).to have_content 'リクエスト送信'

        # パラレルでは高確率で落ちる
        within '#requests' do
          expect(page).not_to have_content 'CCCリクエスト_メイン15'
          expect(page).to have_content 'CCCリクエスト_メイン14'
          expect(page).to have_content 'CCCリクエスト_メイン13'
          expect(page).to have_content 'CCCリクエスト_メイン12'
          expect(page).to have_content 'CCCリクエスト_メイン11'
          expect(page).to have_content 'CCCリクエスト_メイン10'
          expect(page).to have_content 'CCCリクエスト_メイン9'
          expect(page).to have_content 'CCCリクエスト_メイン8'
          expect(page).to have_content 'CCCリクエスト_メイン7'
          expect(page).to have_content 'CCCリクエスト_メイン6'
          expect(page).to have_content 'CCCリクエスト_メイン5'
          expect(page).not_to have_content 'CCCリクエスト_メイン4'
        end

        within 'nav.pagy-nav' do
          expect(page).to have_selector('span.prev:not(.disabled)', text: '‹ Prev')
          expect(page).to have_selector('span.page:not(.active)', text: '1')
          expect(page).to have_selector('span.page.active', text: '2')
          expect(page).to have_selector('span.page:not(.active)', text: '3')
          expect(page).not_to have_content '4'
          expect(page).to have_selector('span.next:not(.disabled)', text: 'Next ›')
        end

        within 'nav.pagy-nav' do
          find('span', text: 'Next ›').click
        end

        within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }
        expect(page).not_to have_content 'リクエスト確認'
        expect(page).to have_content 'リクエスト送信'

        within '#requests' do
          expect(page).not_to have_content 'CCCリクエスト_メイン5'
          expect(page).to have_content 'CCCリクエスト_メイン4'
          expect(page).to have_content 'CCCリクエスト_メイン3'
          expect(page).to have_content 'CCCリクエスト_メイン2'
          expect(page).to have_content 'CCCリクエスト_メイン1'
          expect(page).to have_content 'CCCリクエスト_メイン0'
        end

        within 'nav.pagy-nav' do
          expect(page).to have_selector('span.prev:not(.disabled)', text: '‹ Prev')
          expect(page).to have_selector('span.page:not(.active)', text: '1')
          expect(page).to have_selector('span.page:not(.active)', text: '2')
          expect(page).to have_selector('span.page.active', text: '3')
          expect(page).not_to have_content '4'
          expect(page).to have_selector('span.next.disabled', text: 'Next ›')
        end
      end
    end

    scenario '保存情報を使うフィールドの開閉操作', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      # 保存のフィールド出現確認
      confirm_storaged_data_field_operation
    end
  end

  context 'アドミンログイン済み' do
    before do
      preferences
      sign_in user2
    end

    scenario 'より正確にクロールするための詳細設定フィールドの開閉操作', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      confirm_top_crawle_config_toggle_button_operation
    end

    #--------------------------
    #
    #   企業一覧ページの設定
    #
    #--------------------------
    scenario 'より正確にクロールするための詳細設定 > 企業一覧ページの設定 の操作', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      confirm_corporate_list_page_config_operation
    end

    scenario 'より正確にクロールするための詳細設定 > 企業一覧ページの設定 > 一覧ページURLは5つまでしか追加できない', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業一覧ページの設定').click # Open

      4.times do |i|
        find('button#add_corporate_list_url_config', text: '追加').click
      end

      expect(page).to have_selector('input#request_corporate_list_5_url[type="text"]')
      expect(page).to have_selector('label[for="request_corporate_list_5_url"]', text: '企業一覧ページのサンプルURL')

      expect(page).not_to have_selector('input#request_corporate_list_6_url[type="text"]')
      expect(page).not_to have_selector('label[for="request_corporate_list_6_url"]', text: '企業一覧ページのサンプルURL')

      expect(page).to have_selector('button#add_corporate_list_url_config.disabled', text: '追加')
      expect(page).to have_selector('button#remove_corporate_list_url_config:not(.disabled)', text: '削除')

      find('button#remove_corporate_list_url_config', text: '削除').click

      expect(page).not_to have_selector('input#request_corporate_list_5_url[type="text"]')
      expect(page).not_to have_selector('label[for="request_corporate_list_5_url"]', text: '企業一覧ページのサンプルURL')

      expect(page).to have_selector('button#add_corporate_list_url_config:not(.disabled)', text: '追加')
    end

    scenario 'より正確にクロールするための詳細設定 > 企業一覧ページの設定 > 一覧ページの種別名、サンプル文字は20個までしか追加できない', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業一覧ページの設定').click # Open

      find('#corporate_list_1_details_toggle_btn', text: '詳細設定を開く').click # Open

      within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
        19.times do |i|
          find('button.add_corporate_list_url_contents_config', text: '追加').click
        end

        expect(page).to have_selector('input#request_corporate_list_1_contents_20_title[type="text"]')
        expect(page).to have_selector('label[for="request_corporate_list_1_contents_20_title"]', text: '種別名 または そのXパス')
        expect(page).to have_selector('input#request_corporate_list_1_contents_20_text_1[type="text"]')
        expect(page).to have_selector('label[for="request_corporate_list_1_contents_20_text_1"]', text: 'サンプル文字1 または そのXパス')

        expect(page).not_to have_selector('input#request_corporate_list_1_contents_21_title[type="text"]')
        expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_21_title"]', text: '種別名 または そのXパス')
        expect(page).not_to have_selector('input#request_corporate_list_1_contents_21_text_1[type="text"]')
        expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_21_text_1"]', text: 'サンプル文字1 または そのXパス')

        expect(page).to have_selector('button.add_corporate_list_url_contents_config.disabled', text: '追加')
        expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')

        find('button.remove_corporate_list_url_contents_config', text: '削除').click

        expect(page).not_to have_selector('input#request_corporate_list_1_contents_20_title[type="text"]')
        expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_20_title"]', text: '種別名 または そのXパス')
        expect(page).not_to have_selector('input#request_corporate_list_1_contents_20_text_1[type="text"]')
        expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_20_text_1"]', text: 'サンプル文字1 または そのXパス')

        expect(page).to have_selector('button.add_corporate_list_url_contents_config:not(.disabled)', text: '追加')
      end
    end

    scenario 'より正確にクロールするための詳細設定 > 企業個別ページの設定 の操作', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      confirm_corporate_individual_page_config_operation
    end

    scenario 'より正確にクロールするための詳細設定 > 企業個別ページの設定 > 個別ページURLは5つまでしか追加できない', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業個別ページの設定').click # Open

      4.times do |i|
        find('button#add_corporate_individual_url_config', text: '追加').click
      end

      expect(page).to have_selector('input#request_corporate_individual_5_url')
      expect(page).to have_selector('label[for="request_corporate_individual_5_url"]', text: '企業個別ページのサンプルURL')

      expect(page).not_to have_selector('input#request_corporate_individual_6_url')
      expect(page).not_to have_selector('label[for="request_corporate_individual_6_url"]', text: '企業個別ページのサンプルURL')

      expect(page).to have_selector('button#add_corporate_individual_url_config.disabled', text: '追加')
      expect(page).to have_selector('button#remove_corporate_individual_url_config:not(.disabled)', text: '削除')

      find('button#remove_corporate_individual_url_config', text: '削除').click

      expect(page).not_to have_selector('input#request_corporate_individual_5_url')
      expect(page).not_to have_selector('label[for="request_corporate_individual_5_url"]', text: '企業個別ページのサンプルURL')

      expect(page).to have_selector('button#add_corporate_individual_url_config:not(.disabled)', text: '追加')
    end

    scenario 'より正確にクロールするための詳細設定 > 企業一覧ページの設定 > 個別ページの種別名、サンプル文字は20個までしか追加できない', js: true do
      visit root_path
      within('h1') { expect(page).to have_content '企業一覧サイトからの収集' }

      find("h3", text: 'より正確にクロールするための詳細設定').click # Open

      find("h5", text: '企業個別ページの設定').click # Open

      find('#corporate_individual_1_details_toggle_btn', text: '詳細設定を開く').click # Open

      within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
        19.times do |i|
          find('button.add_corporate_individual_url_contents_config', text: '追加').click
        end

        expect(page).to have_selector('input#request_corporate_individual_1_contents_20_text[type="text"]')
        expect(page).to have_selector('label[for="request_corporate_individual_1_contents_20_text"]', text: 'サンプル文字 または そのXパス')

        expect(page).not_to have_selector('input#request_corporate_individual_1_contents_21_text[type="text"]')
        expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_21_text"]', text: 'サンプル文字 または そのXパス')

        expect(page).to have_selector('button.add_corporate_individual_url_contents_config.disabled', text: '追加')
        expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')

        find('button.remove_corporate_individual_url_contents_config', text: '削除').click

        expect(page).not_to have_selector('input#request_corporate_individual_1_contents_20_text[type="text"]')
        expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_20_text"]', text: 'サンプル文字 または そのXパス')

        expect(page).to have_selector('button.add_corporate_individual_url_contents_config:not(.disabled)', text: '追加')
      end
    end
  end
end

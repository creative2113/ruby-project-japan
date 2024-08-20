require 'rails_helper'

RSpec.feature "結果ファイル作成", type: :feature do
  before { create_public_user }
  let(:user) { create(:user) }

  before { Timecop.freeze }

  after { Timecop.return }

  context 'ログインユーザ' do

    let(:request) { create(:request, :corporate_site_list, user: user, status: EasySettings.status.working, result_file_path: nil, expiration_date: nil) }
    let(:req_url1) { create(:corporate_list_requested_url_finished, request: request) }
    let(:req_url2) { create(:company_info_requested_url, request: request) }

    before do
      allow_any_instance_of(BatchAccessor).to receive(:request_result_file).and_return(StabMaker.new({code: 200}))
      req_url1
      req_url2
    end

    scenario '結果ファイル作成、ダウンロード周りの動作確認', js: true do
      sign_in user

      visit root_path

      # リクエスト一覧フィールド
      within '#requests' do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content request.title
          expect(page).to have_content request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '本実行'
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')

          find('i', text: 'find_in_page').click
        end
      end

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).not_to have_content "有効期限は結果ダウンロード、結果ファイル作成、"

        expect(page).not_to have_selector('button', text: '全結果ダウンロード')
        expect(page).to have_selector('button', text: '結果ファイル作成')
        expect(page).not_to have_content "直近の5つまでダウンロード可能です。"

        expect(page).not_to have_selector '#result_files_download'
        expect(page).not_to have_content "作成依頼日時"
        # expect(page).not_to have_content "種類" この単語は他で登場する
        expect(page).not_to have_content "DL期限"
        expect(page).not_to have_content "DL"
        expect(page).not_to have_content "備考"

        expect(page).to have_selector('label span', text: 'エクセル')
        expect(page).to have_selector('label span', text: 'CSV')

        find('label span', text: 'エクセル').click
        find('button', text: '結果ファイル作成').click
      end

      expect(page).to have_content "結果ファイル作成を受け付けました。完了までお待ちください。"

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).not_to have_content "有効期限は結果ダウンロード、結果ファイル作成、"

        expect(page).not_to have_selector('button', text: '全結果ダウンロード')
        expect(page).to have_selector('button', text: '結果ファイル作成')

        expect(page).to have_content "直近の5つまでダウンロード可能です。"

        within '#result_files_download' do
          within 'table tbody tr:first-child' do
            expect(page).to have_content "作成依頼日時"
            expect(page).to have_content "種類"
            expect(page).to have_content "ステータス"
            expect(page).to have_content "DL期限"
            expect(page).to have_content "DL"
            expect(page).to have_content "備考"
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日 %H:%M:%S")
            expect(page).to have_content 'XLSX'
            expect(page).to have_content '作成中'
            expect(page).not_to have_selector('i', text: 'file_download')
          end
        end
      end

      time1 = Time.zone.now

      Timecop.travel(Time.zone.now + 1.minutes)

      result_file1 = request.result_files.last
      result_file1.update!(path: 'aaa', status: ResultFile.statuses[:completed], expiration_date: Time.zone.today + 3.day)

      visit current_url

      within '#result_files_download' do
        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:%S")
          expect(page).to have_content "XLSX"
          expect(page).not_to have_content "作成中"
          expect(page).to have_content "作成完了"
          expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
          expect(page).to have_selector('i', text: 'file_download')
        end
      end

      within '#confirm_request_form' do
        find('label span', text: 'CSV').click
        find('button', text: '結果ファイル作成').click
      end

      expect(page).to have_content "結果ファイル作成を受け付けました。完了までお待ちください。"

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).not_to have_content "有効期限は結果ダウンロード、結果ファイル作成、"

        expect(page).not_to have_selector('button', text: '全結果ダウンロード')
        expect(page).to have_selector('button', text: '結果ファイル作成')

        expect(page).to have_content "直近の5つまでダウンロード可能です。"

        within '#result_files_download' do
          within 'table tbody tr:first-child' do
            expect(page).to have_content "作成依頼日時"
            expect(page).to have_content "種類"
            expect(page).to have_content "ステータス"
            expect(page).to have_content "DL期限"
            expect(page).to have_content "DL"
            expect(page).to have_content "備考"
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content Time.zone.now.strftime("%Y年%-m月%-d日 %H:%M:") # 秒まで一致させるのは難しい
            expect(page).to have_content "CSV"
            expect(page).to have_content "作成中"
            expect(page).not_to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:%S")
            expect(page).to have_content "XLSX"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).to have_selector('i', text: 'file_download')
          end
        end
      end

      time2 = Time.zone.now

      Timecop.travel(Time.zone.now + 1.minutes)

      result_file2 = request.result_files.last
      result_file2.update!(path: 'aaa', status: ResultFile.statuses[:completed], expiration_date: Time.zone.today + 5.day)

      visit current_url


      within '#result_files_download' do
        within 'table tbody tr:first-child' do
          expect(page).to have_content "作成依頼日時"
          expect(page).to have_content "種類"
          expect(page).to have_content "ステータス"
          expect(page).to have_content "DL期限"
          expect(page).to have_content "DL"
          expect(page).to have_content "備考"
        end

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content time2.strftime("%Y年%-m月%-d日 %H:%M:") # 秒まで一致させるのは難しい
          expect(page).to have_content "CSV"
          expect(page).not_to have_content "作成中"
          expect(page).to have_content "作成完了"
          expect(page).to have_content result_file2.expiration_date.strftime("%Y年%-m月%-d日")
          expect(page).to have_selector('i', text: 'file_download')
        end

        within 'table tbody tr:nth-child(3)' do
          expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:") # 秒まで一致させるのは難しい
          expect(page).to have_content "XLSX"
          expect(page).not_to have_content "作成中"
          expect(page).to have_content "作成完了"
          expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
          expect(page).to have_selector('i', text: 'file_download')
        end
      end

      request.update!(status: EasySettings.status.completed, result_file_path: 'asd', expiration_date: Time.zone.today + 4.days)

      visit current_url


      within '#requests' do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content request.title
          expect(page).to have_content request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '本実行'
          expect(page).not_to have_content '未完了'
          expect(page).to have_content '完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).not_to have_selector('i', text: 'stop')
          expect(page).to have_selector('i', text: 'file_download')
          expect(page).to have_content request.expiration_date.strftime("%Y年%m月%d日")

          find('i', text: 'find_in_page').click
        end
      end

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).not_to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).to have_content "有効期限は結果ダウンロード、結果ファイル作成、共に、#{request.expiration_date.strftime("%Y年%-m月%-d日")}までです。"

        expect(page).to have_selector('button', text: '全結果ダウンロード')
        expect(page).to have_selector('button', text: '結果ファイル作成')

        expect(page).to have_content "直近の5つまでダウンロード可能です。"

        within '#result_files_download' do
          within 'table tbody tr:first-child' do
            expect(page).to have_content "作成依頼日時"
            expect(page).to have_content "種類"
            expect(page).to have_content "ステータス"
            expect(page).to have_content "DL期限"
            expect(page).to have_content "DL"
            expect(page).to have_content "備考"
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content time2.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "CSV"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file2.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "XLSX"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).to have_selector('i', text: 'file_download')
          end
        end
      end

      Timecop.travel(Time.zone.now + 4.days)

      visit current_url

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).not_to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).to have_content "有効期限は結果ダウンロード、結果ファイル作成、共に、#{request.expiration_date.strftime("%Y年%-m月%-d日")}までです。"

        expect(page).to have_selector('button', text: '全結果ダウンロード')
        expect(page).to have_selector('button', text: '結果ファイル作成')

        expect(page).to have_content "直近の5つまでダウンロード可能です。"

        within '#result_files_download' do
          within 'table tbody tr:first-child' do
            expect(page).to have_content "作成依頼日時"
            expect(page).to have_content "種類"
            expect(page).to have_content "ステータス"
            expect(page).to have_content "DL期限"
            expect(page).to have_content "DL"
            expect(page).to have_content "備考"
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content time2.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "CSV"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file2.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "XLSX"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).not_to have_selector('i', text: 'file_download')
          end
        end
      end

      Timecop.travel(Time.zone.now + 1.days)

      visit current_url

      within '#requests' do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).to have_content request.title
          expect(page).to have_content request.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '本実行'
          expect(page).not_to have_content '未完了'
          expect(page).to have_content '完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).not_to have_selector('i', text: 'stop')
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content request.expiration_date.strftime("%Y年%m月%d日")

          find('i', text: 'find_in_page').click
        end
      end

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).to have_content 'ダウンロードの有効期限が切れました。'
        expect(page).not_to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).not_to have_content "有効期限は結果ダウンロード、結果ファイル作成、共に、#{request.expiration_date.strftime("%Y年%-m月%-d日")}までです。"

        expect(page).not_to have_selector('button', text: '全結果ダウンロード')
        expect(page).not_to have_selector('button', text: '結果ファイル作成')

        expect(page).to have_content "直近の5つまでダウンロード可能です。"

        within '#result_files_download' do
          within 'table tbody tr:first-child' do
            expect(page).to have_content "作成依頼日時"
            expect(page).to have_content "種類"
            expect(page).to have_content "ステータス"
            expect(page).to have_content "DL期限"
            expect(page).to have_content "DL"
            expect(page).to have_content "備考"
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content time2.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "CSV"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file2.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "XLSX"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).not_to have_selector('i', text: 'file_download')
          end
        end
      end

      Timecop.travel(Time.zone.now + 1.days)

      visit current_url

      within '#confirm_request_form' do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: '結果')
        expect(page).to have_content '結果の見方'
        expect(page).to have_content '取得したデータは利用する前に情報が正しいか必ずご確認をお願いします。'
        expect(page).to have_content 'ダウンロードの有効期限が切れました。'
        expect(page).not_to have_content 'ステータスが未完了の場合は途中結果をダウンロードできます。'
        expect(page).not_to have_content "有効期限は結果ダウンロード、結果ファイル作成、共に、#{request.expiration_date.strftime("%Y年%-m月%-d日")}までです。"

        expect(page).not_to have_selector('button', text: '全結果ダウンロード')
        expect(page).not_to have_selector('button', text: '結果ファイル作成')

        expect(page).to have_content "直近の5つまでダウンロード可能です。"

        within '#result_files_download' do
          within 'table tbody tr:first-child' do
            expect(page).to have_content "作成依頼日時"
            expect(page).to have_content "種類"
            expect(page).to have_content "ステータス"
            expect(page).to have_content "DL期限"
            expect(page).to have_content "DL"
            expect(page).to have_content "備考"
          end

          within 'table tbody tr:nth-child(2)' do
            expect(page).to have_content time2.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "CSV"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file2.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).not_to have_selector('i', text: 'file_download')
          end

          within 'table tbody tr:nth-child(3)' do
            expect(page).to have_content time1.strftime("%Y年%-m月%-d日 %H:%M:")
            expect(page).to have_content "XLSX"
            expect(page).not_to have_content "作成中"
            expect(page).to have_content "作成完了"
            expect(page).to have_content result_file1.expiration_date.strftime("%Y年%-m月%-d日")
            expect(page).not_to have_selector('i', text: 'file_download')
          end
        end
      end
    end
  end
end
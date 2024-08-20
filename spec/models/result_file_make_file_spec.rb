require 'rails_helper'

# このテストではユーザプランによる違いは生じない
# publicのみのテストでOK

RSpec.describe ResultFile, type: :model do
  let!(:pu) { create_public_user }

  describe '#make_file' do
    subject { result_file.make_file(mode) }

    ar_coca_cola = AccessRecord.create(:hokkaido_coca_cola)
    ar_nexway    = AccessRecord.create(:nexway)
    ar_starbacks = AccessRecord.create(:starbacks)
    AccessRecord.delete_items(['www.hokkaido.ccbc.co.jp', 'www.example.com', 'www.nexway.co.jp', 'www.starbucks.co.jp'])

    let(:title)              { 'test_title' }
    let(:file_name)          { 'rspec_test_excel_file' }
    let(:download_file_name) { "1_結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.#{file_type}" }
    let(:dir_path)           { "#{Rails.application.credentials.s3_bucket[:results]}/#{result_file.id}" }
    let(:file_path)          { "#{dir_path}/#{download_file_name}" }

    let(:correct_file)      { Rails.root.join('spec', 'fixtures', 'result_download.xlsx').to_s }
    let(:correct_ex)        { Excel::Import.new(correct_file, 1, true).to_hash_data }
    let(:output_file_ex) do
      Dir.mktmpdir do |dir|
        tmp_path = "#{dir}/tmp.#{file_type}"
        S3Handler.new.download(s3_path: file_path, output_path: tmp_path)
        if file_type == 'xlsx'
          Excel::Import.new(tmp_path, 1, true).to_hash_data
        elsif file_type == 'csv'
          CsvHandler::Import.new(tmp_path, true).to_hash_data
        end
      end
    end

    let(:user)              { create(:user, billing_attrs: { payment_method: :credit }) }
    let(:unpaid_user)       { create(:user) }
    let(:history)           { create(:monthly_history, plan: plan) }
    let(:expiration_date)   { Time.zone.today }
    let(:status)            { EasySettings.status[:completed] }
    let(:file_type)         { 'xlsx' }
    let(:request_user)      { user }
    let(:history)           { create(:monthly_history, user: request_user, plan: plan) }
    let(:list_site_result_headers) { nil }
    let(:mode)              { :at_once }
    let(:plan)              { EasySettings.plan[:standard] }
    let(:result_file)       { create(:result_file, path: nil, status: described_class.statuses[:accepted], file_type: described_class.file_types[file_type], request: request) }
    let(:request)           { create(:request, status: status, title: title, file_name: file_name, plan: plan,
                                               expiration_date: expiration_date, user: request_user,
                                               list_site_result_headers: list_site_result_headers ) }
    let(:free_search_result) { '{}' }
    let(:requested_url1) { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { corporate_list: corporate_list_result1, free_search: free_search_result } ) }
    let(:requested_url2) { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { corporate_list: corporate_list_result2, free_search: free_search_result } ) }
    let(:requested_url3) { create(:company_info_requested_url_finished, request: request, url: 'https://www.sample.co.cn', domain: nil, finish_status: EasySettings.finish_status.banned_domain, result_attrs: { corporate_list: corporate_list_result3, free_search: free_search_result } ) }
    let(:requested_url4) { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { corporate_list: corporate_list_result4, free_search: free_search_result } ) }
    let(:corporate_list_result1) { nil }
    let(:corporate_list_result2) { nil }
    let(:corporate_list_result3) { nil }
    let(:corporate_list_result4) { nil }

    let(:result_file2) { create(:result_file, path: nil, status: described_class.statuses[:accepted], request: request) }
    let(:result_file3) { create(:result_file, path: nil, status: described_class.statuses[:accepted], request: request) }

    before do
      Timecop.freeze(current_time)
      result_file2
      result_file3
    end

    after do
      del_file = Rails.root.join('downloads', 'results', '*').to_s
      `rm -rf #{del_file}`
      del_file = Rails.root.join('downloads', 'tmp_results', Time.zone.today.day.to_s, '*').to_s
      `rm -rf #{del_file}`

      S3Handler.new.delete(s3_path: file_path)
      Timecop.return
    end

    context 'フェーズ1：company_infoまでたどり着いていない時' do
      let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{Time.zone.today.year}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{result_file.id}" }
      let(:correct_file) { Rails.root.join('spec', 'fixtures', 'phase1_result_download.xlsx').to_s }

      let(:request) { create(:request, :corporate_site_list, user: user, title: title, status: status) }
      let(:status) { EasySettings.status[:working] }
      let(:m1) { create(:corporate_list_requested_url_finished, :result_1, request: request) }
      let(:s1) { create(:corporate_single_requested_url_finished, :a, request: request) }
      let(:s2) { create(:corporate_single_requested_url_finished, :b, request: request) }
      let(:s3) { create(:corporate_single_requested_url_finished, :c, request: request) }

      let(:m2) { create(:corporate_list_requested_url_finished, :result_2, request: request) }
      let(:s4) { create(:corporate_single_requested_url_finished, :d, request: request) }
      let(:s5) { create(:corporate_single_requested_url_finished, :e, request: request) }

      before do
        m1
        m2
        s1
        s2
        s3
        s4
        s5
      end

      context 'STOPの時' do
        let(:status) { EasySettings.status[:discontinued] }

        context 'EXCEL' do
          let(:file_type) { 'xlsx' }

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(result_file.request.tmp_company_info_urls.count).to eq 0

            # データの中身が正しいこと
            expect(output_file_ex).to eq correct_ex
          end
        end
      end

      context 'tmp_company_info_urlが他にない時' do

        context 'EXCEL' do
          let(:file_type) { 'xlsx' }

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(result_file.request.tmp_company_info_urls.count).to eq 0

            # データの中身が正しいこと
            expect(output_file_ex).to eq correct_ex
          end
        end

        context 'CSV' do
          let(:file_type) { 'csv' }

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(result_file.request.tmp_company_info_urls.count).to eq 0

            # データの中身が正しいこと
            expect(described_class.compare_for_test(csv_hash: output_file_ex, excel_hash: correct_ex[:data])).to be_truthy
          end
        end
      end

      context 'tmp_company_info_urlが他にもあるとき' do

        context '同じresult_file_idが存在しないとき' do
          before do
            create(:tmp_company_info_url, request: request, result_file: result_file2, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
            create(:tmp_company_info_url, request: request, result_file: result_file2, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
            create(:tmp_company_info_url, request: request, result_file: result_file3, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
            create(:tmp_company_info_url, request: request, result_file: result_file3, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
          end

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            expect(request.tmp_company_info_urls.count).to eq 4
            expect(TmpCompanyInfoUrl.where(result_file_id: result_file.id).count).to eq 0

            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(request.tmp_company_info_urls.count).to eq 4
            expect(TmpCompanyInfoUrl.where(result_file_id: result_file.id).count).to eq 0

            # データの中身が正しいこと
            expect(output_file_ex).to eq correct_ex
          end
        end

        # bunch_idがあるので、result_file_idが被っていても、問題ない
        context '同じresult_file_idが存在するとき' do
          before do
            create(:tmp_company_info_url, request: request, result_file_id: result_file.id, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
            create(:tmp_company_info_url, request: request, result_file_id: result_file.id, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
            create(:tmp_company_info_url, request: request, result_file_id: result_file.id, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
            create(:tmp_company_info_url, request: request, result_file_id: result_file.id, result: m2.result.main, corporate_list_result: s1.result.corporate_list )
          end

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            expect(request.tmp_company_info_urls.count).to eq 4
            expect(TmpCompanyInfoUrl.where(result_file_id: result_file.id).count).to eq 4

            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(request.tmp_company_info_urls.count).to eq 4
            expect(TmpCompanyInfoUrl.where(result_file_id: result_file.id).count).to eq 4

            # データの中身が正しいこと
            expect(output_file_ex).to eq correct_ex
          end
        end
      end

      context 'company_infoを作り途中の時' do
        let(:status) { EasySettings.status[:arranging] }

        before do
          requested_url1
          requested_url2
          requested_url3
        end

        context 'EXCEL' do
          let(:file_type) { 'xlsx' }

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(result_file.request.tmp_company_info_urls.count).to eq 0

            # データの中身が正しいこと
            expect(output_file_ex).to eq correct_ex
          end
        end

        context 'CSV' do
          let(:file_type) { 'csv' }

          it 'ファイルが作成されること、未完了のファイルパスであること' do
            subject

            result_file.reload
            expect(result_file.path).to eq file_path
            expect(result_file.fail_files).to be_nil
            expect(result_file.status).to eq 'completed'
            expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
            expect(result_file.parameters).to be_present
            expect(result_file.phase).to eq 'phase4'

            # ファイルが存在すること
            expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

            # ZIPが存在しないこと
            expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

            # result_file_pathに保存されない
            expect(request.result_file_path).to be_nil

            # corporate_list_urlsのresultの値が入っていない
            expect(m1.result.reload.main).to be_nil

            # tmp_company_info_urlsが削除されている
            expect(result_file.request.tmp_company_info_urls.count).to eq 0

            # データの中身が正しいこと
            expect(described_class.compare_for_test(csv_hash: output_file_ex, excel_hash: correct_ex[:data])).to be_truthy
          end
        end
      end
    end

    context 'フェーズ2: company_infoがある時' do
      before do
        allow_any_instance_of(AccessRecord).to receive(:get) do |ar, _|
          if ar.domain.include?('hokkaido.ccbc')
            ar_coca_cola
          elsif ar.domain.include?('nexway')
            ar_nexway
          elsif ar.domain.include?('starbucks')
            ar_starbacks
          end
        end

        history
        requested_url1.fetch_access_record(force_fetch: true)
        requested_url2.fetch_access_record(force_fetch: true)
        requested_url3
        requested_url4.fetch_access_record(force_fetch: true)
      end

      context '単数ファイル作成' do
        context '正常系' do
          context '企業一覧クロール結果がある場合' do
            let(:list_site_result_headers) { {'ドメイン'=>5,'名称'=>5,'aa'=>4,'住所1'=>3,'dd'=>2}.to_json }
            let(:corporate_list_result1) { {'ドメイン' => 'aa','名称' => 'コカコーラ','住所1' => 'bb','ss' => 'ff' }.to_json }
            let(:corporate_list_result2) { nil }
            let(:corporate_list_result3) { nil }
            let(:corporate_list_result4) { {'住所1' => 'aa','TEL' => 'asd','従業員' => 'efg','名称' => 'スタバ' }.to_json }

            context 'リクエストがSTOPの場合' do
              let(:status) { EasySettings.status[:discontinued] }
              let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{Time.zone.today.year}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{result_file.id}" }
              let(:correct_file) { Rails.root.join('spec', 'fixtures', 'result_download_with_list1.xlsx').to_s }

              context 'EXCEL' do
                let(:file_type) { 'xlsx' }

                it 'ファイルが作成されること、未完了のファイルパスであること' do
                  subject

                  result_file.reload
                  expect(result_file.path).to eq file_path
                  expect(result_file.fail_files).to be_nil
                  expect(result_file.status).to eq 'completed'
                  expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                  expect(result_file.parameters).to be_present
                  expect(result_file.phase).to eq 'phase4'

                  # ファイルが存在すること
                  expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                  # ZIPが存在しないこと
                  expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                  # result_file_pathに保存されない
                  expect(request.result_file_path).to be_nil

                  # requestd_urlsのresultの値が残っている
                  expect(request.requested_urls[0].result.main).not_to be_nil
                  expect(request.requested_urls[1].result.main).not_to be_nil
                  expect(request.requested_urls[2].result.main).to be_nil
                  expect(request.requested_urls[3].result.main).not_to be_nil
                  expect(request.requested_urls[0].result.free_search).not_to be_nil
                  expect(request.requested_urls[1].result.free_search).not_to be_nil
                  expect(request.requested_urls[2].result.free_search).not_to be_nil
                  expect(request.requested_urls[3].result.free_search).not_to be_nil

                  # データの中身が正しいこと
                  # 最後に修正する方が効率がいい！！！
                  expect(output_file_ex).to eq correct_ex
                end
              end
            end

            context 'リクエストが未完了の場合' do
              let(:status) { EasySettings.status[:new] }
              let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{Time.zone.today.year}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{result_file.id}" }
              let(:correct_file) { Rails.root.join('spec', 'fixtures', 'result_download_with_list1.xlsx').to_s }

              context 'EXCEL' do
                let(:file_type) { 'xlsx' }

                it 'ファイルが作成されること、未完了のファイルパスであること' do
                  subject

                  result_file.reload
                  expect(result_file.path).to eq file_path
                  expect(result_file.fail_files).to be_nil
                  expect(result_file.status).to eq 'completed'
                  expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                  expect(result_file.parameters).to be_present
                  expect(result_file.phase).to eq 'phase4'

                  # ファイルが存在すること
                  expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                  # ZIPが存在しないこと
                  expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                  # result_file_pathに保存されない
                  expect(request.result_file_path).to be_nil

                  # requestd_urlsのresultの値が残っている
                  expect(request.requested_urls[0].result.main).not_to be_nil
                  expect(request.requested_urls[1].result.main).not_to be_nil
                  expect(request.requested_urls[2].result.main).to be_nil
                  expect(request.requested_urls[3].result.main).not_to be_nil
                  expect(request.requested_urls[0].result.free_search).not_to be_nil
                  expect(request.requested_urls[1].result.free_search).not_to be_nil
                  expect(request.requested_urls[2].result.free_search).not_to be_nil
                  expect(request.requested_urls[3].result.free_search).not_to be_nil

                  # データの中身が正しいこと
                  # 最後に修正する方が効率がいい！！！
                  expect(output_file_ex).to eq correct_ex
                end
              end

              context 'CSV' do
                let(:file_type) { 'csv' }
           
                it 'ファイルが作成されること、未完了のファイルパスであること' do
                  subject

                  result_file.reload
                  expect(result_file.path).to eq file_path
                  expect(result_file.fail_files).to be_nil
                  expect(result_file.status).to eq 'completed'
                  expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                  expect(result_file.parameters).to be_present
                  expect(result_file.phase).to eq 'phase4'

                  # ファイルが存在すること
                  expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                  # ZIPが存在しないこと
                  expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                  # result_file_pathに保存されない
                  expect(request.result_file_path).to be_nil

                  # requestd_urlsのresultの値が残っている
                  expect(request.requested_urls[0].result.main).not_to be_nil
                  expect(request.requested_urls[1].result.main).not_to be_nil
                  expect(request.requested_urls[2].result.main).to be_nil
                  expect(request.requested_urls[3].result.main).not_to be_nil
                  expect(request.requested_urls[0].result.free_search).not_to be_nil
                  expect(request.requested_urls[1].result.free_search).not_to be_nil
                  expect(request.requested_urls[2].result.free_search).not_to be_nil
                  expect(request.requested_urls[3].result.free_search).not_to be_nil

                  # データの中身が正しいこと
                  expect(described_class.compare_for_test(csv_hash: output_file_ex, excel_hash: correct_ex[:data])).to be_truthy
                end
              end
            end

            context 'リクエストが完了の場合' do
              let(:status) { EasySettings.status[:completed] }
              let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:results]}/#{result_file.id}" }
              let(:correct_file) { Rails.root.join('spec', 'fixtures', 'result_download_with_list2.xlsx').to_s }

              before do
                company_data1 = requested_url1.company_data
                company_data4 = requested_url4.company_data
                requested_url1.update!(finish_status: EasySettings.finish_status.can_not_get_info)
                allow_any_instance_of(RequestedUrl).to receive(:company_data) do |req_url, _|
                  raise if req_url.id == requested_url2.id
                  if req_url.id == requested_url1.id
                    company_data1
                  elsif req_url.id == requested_url4.id
                    company_data4
                  end
                end

                allow(Json2).to receive(:parse) do |sorce, option|
                  raise if sorce == corporate_list_result4
                  option = { symbolize_names: true } if option.nil?
                  sorce.nil? ? nil : JSON.parse(sorce, option)
                end
              end

              context 'EXCEL' do
                let(:file_type) { 'xlsx' }

                it 'ファイルが作成されること、完了のファイルパスであること' do
                  subject

                  result_file.reload
                  expect(result_file.path).to eq file_path
                  expect(result_file.fail_files).to be_nil
                  expect(result_file.status).to eq 'completed'
                  expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                  expect(result_file.parameters).to be_present
                  expect(result_file.phase).to eq 'phase4'

                  # ファイルが存在すること
                  expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                  # ZIPが存在しないこと
                  expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                  expect(request.result_file_path).to be_nil

                  # requestd_urlsのresult、free_search_resultが残っている
                  expect(request.requested_urls[0].result.main).to be_present
                  expect(request.requested_urls[1].result.main).to be_present
                  expect(request.requested_urls[2].result.main).to be_nil
                  expect(request.requested_urls[3].result.main).to be_present
                  expect(request.requested_urls[0].result.free_search).to be_present
                  expect(request.requested_urls[1].result.free_search).to be_present
                  expect(request.requested_urls[2].result.free_search).to be_present
                  expect(request.requested_urls[3].result.free_search).to be_present

                  # データの中身が正しいこと
                  expect(output_file_ex).to eq correct_ex
                end
              end

              context 'CSV' do
                let(:file_type) { 'csv' }

                it 'ファイルが作成されること、完了のファイルパスであること' do
                  subject

                  result_file.reload
                  expect(result_file.path).to eq file_path
                  expect(result_file.fail_files).to be_nil
                  expect(result_file.status).to eq 'completed'
                  expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                  expect(result_file.parameters).to be_present
                  expect(result_file.phase).to eq 'phase4'

                  # ファイルが存在すること
                  expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                  # ZIPが存在しないこと
                  expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                  expect(request.result_file_path).to be_nil

                  # requestd_urlsのresult、free_search_resultが残っている
                  expect(request.requested_urls[0].result.main).to be_present
                  expect(request.requested_urls[1].result.main).to be_present
                  expect(request.requested_urls[2].result.main).to be_nil
                  expect(request.requested_urls[3].result.main).to be_present
                  expect(request.requested_urls[0].result.free_search).to be_present
                  expect(request.requested_urls[1].result.free_search).to be_present
                  expect(request.requested_urls[2].result.free_search).to be_present
                  expect(request.requested_urls[3].result.free_search).to be_present

                  # データの中身が正しいこと
                  expect(described_class.compare_for_test(csv_hash: output_file_ex, excel_hash: correct_ex[:data])).to be_truthy
                end
              end
            end
          end

          context 'リクエストが未完了の場合' do
            let(:status) { EasySettings.status[:new] }
            let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{Time.zone.today.year}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{result_file.id}" }

            context 'EXCEL' do
              let(:file_type) { 'xlsx' }

              it 'ファイルが作成されること、未完了のファイルパスであること' do
                subject

                result_file.reload
                expect(result_file.path).to eq file_path
                expect(result_file.fail_files).to be_nil
                expect(result_file.status).to eq 'completed'
                expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                expect(result_file.parameters).to be_present
                expect(result_file.phase).to eq 'phase4'

                # ファイルが存在すること
                expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                # ZIPが存在しないこと
                expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                # result_file_pathに保存されない
                expect(request.result_file_path).to be_nil

                # requestd_urlsのresultの値が残っている
                expect(request.requested_urls[0].result.main).not_to be_nil
                expect(request.requested_urls[1].result.main).not_to be_nil
                expect(request.requested_urls[2].result.main).to be_nil
                expect(request.requested_urls[3].result.main).not_to be_nil
                expect(request.requested_urls[0].result.free_search).not_to be_nil
                expect(request.requested_urls[1].result.free_search).not_to be_nil
                expect(request.requested_urls[2].result.free_search).not_to be_nil
                expect(request.requested_urls[3].result.free_search).not_to be_nil

                # データの中身が正しいこと
                expect(output_file_ex).to eq correct_ex
              end
            end

            context 'CSV' do
              let(:file_type) { 'csv' }

              it 'ファイルが作成されること、未完了のファイルパスであること' do
                subject

                result_file.reload
                expect(result_file.path).to eq file_path
                expect(result_file.fail_files).to be_nil
                expect(result_file.status).to eq 'completed'
                expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                expect(result_file.parameters).to be_present
                expect(result_file.phase).to eq 'phase4'

                # ファイルが存在すること
                expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                # ZIPが存在しないこと
                expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                # result_file_pathに保存されない
                expect(request.result_file_path).to be_nil

                # requestd_urlsのresultの値が残っている
                expect(request.requested_urls[0].result.main).not_to be_nil
                expect(request.requested_urls[1].result.main).not_to be_nil
                expect(request.requested_urls[2].result.main).to be_nil
                expect(request.requested_urls[3].result.main).not_to be_nil
                expect(request.requested_urls[0].result.free_search).not_to be_nil
                expect(request.requested_urls[1].result.free_search).not_to be_nil
                expect(request.requested_urls[2].result.free_search).not_to be_nil
                expect(request.requested_urls[3].result.free_search).not_to be_nil

                # データの中身が正しいこと
                expect(described_class.compare_for_test(csv_hash: output_file_ex, excel_hash: correct_ex[:data])).to be_truthy
              end
            end
          end

          context 'リクエストが完了の場合' do
            let(:status)   { EasySettings.status[:completed] }
            let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:results]}/#{result_file.id}" }

            context 'EXCEL' do
              let(:file_type) { 'xlsx' }

              it 'ファイルが作成されること、完了のファイルパスであること' do
                subject

                result_file.reload
                expect(result_file.path).to eq file_path
                expect(result_file.fail_files).to be_nil
                expect(result_file.status).to eq 'completed'
                expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                expect(result_file.parameters).to be_present
                expect(result_file.phase).to eq 'phase4'

                # ファイルが存在すること
                expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                # ZIPが存在しないこと
                expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                # result_file_pathに保存される
                expect(request.result_file_path).to be_nil

                # requestd_urlsのresult、free_search_resultが残っている
                expect(request.requested_urls[0].result.main).to be_present
                expect(request.requested_urls[1].result.main).to be_present
                expect(request.requested_urls[2].result.main).to be_nil
                expect(request.requested_urls[3].result.main).to be_present
                expect(request.requested_urls[0].result.free_search).to be_present
                expect(request.requested_urls[1].result.free_search).to be_present
                expect(request.requested_urls[2].result.free_search).to be_present
                expect(request.requested_urls[3].result.free_search).to be_present

                # データの中身が正しいこと
                expect(output_file_ex).to eq correct_ex
              end
            end

            context 'CSV' do
              let(:file_type) { 'csv' }

              it 'ファイルが作成されること、完了のファイルパスであること' do
                subject

                result_file.reload
                expect(result_file.path).to eq file_path
                expect(result_file.fail_files).to be_nil
                expect(result_file.status).to eq 'completed'
                expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                expect(result_file.parameters).to be_present
                expect(result_file.phase).to eq 'phase4'

                # ファイルが存在すること
                expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true

                # ZIPが存在しないこと
                expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                # result_file_pathに保存される
                expect(request.result_file_path).to be_nil

                # requestd_urlsのresult、free_search_resultが残っている
                expect(request.requested_urls[0].result.main).to be_present
                expect(request.requested_urls[1].result.main).to be_present
                expect(request.requested_urls[2].result.main).to be_nil
                expect(request.requested_urls[3].result.main).to be_present
                expect(request.requested_urls[0].result.free_search).to be_present
                expect(request.requested_urls[1].result.free_search).to be_present
                expect(request.requested_urls[2].result.free_search).to be_present
                expect(request.requested_urls[3].result.free_search).to be_present

                # データの中身が正しいこと
                expect(described_class.compare_for_test(csv_hash: output_file_ex, excel_hash: correct_ex[:data])).to be_truthy
              end
            end
          end

          context 'プランユーザの場合' do
            let(:request_user) { user }

            it 'データの数値が隠されていないこと' do
              subject
              expect(output_file_ex).to eq correct_ex
            end
          end

          context 'パブリックユーザの場合' do
            let(:request_user) { User.get_public }

            it 'データの数値が隠されていないこと' do
              subject
              expect(output_file_ex).to eq correct_ex
            end
          end

          context '無課金ユーザの場合' do
            let(:request_user) { unpaid_user }

            it 'データの数値が隠されていないこと' do
              subject
              expect(output_file_ex).to eq correct_ex
            end
          end
        end

        context '異常系' do
          context 'エクセル保存に失敗したとき' do
            before { allow_any_instance_of(Excel::Export).to receive(:save).and_return( false ) }

            it do
              expect(subject).to eq false

              # ファイルが存在しないこと
              expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq false

              # result_file_pathに保存されない
              expect(request.result_file_path).to be_nil
            end
          end

          context 'ヘッダーが空のとき' do
            before do
              allow_any_instance_of(Excel::Export).to receive(:save).and_return( false )
              request.update!(list_site_result_headers: nil, company_info_result_headers: nil)
            end

            it do
              expect(subject).to eq false

              # ファイルが存在しないこと
              expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq false

              # result_file_pathに保存されない
              expect(request.result_file_path).to be_nil
            end
          end
        end
      end

      context '複数ファイル作成とZIP化' do

        let(:file_name)          { 'rspec_test_excel_file' }
        let(:download_file_name) { "結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.zip" }
        let(:excel_file_name1)   { "1_結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx" }
        let(:excel_file_name2)   { "2_結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx" }
        let(:excel_file_name3)   { "3_結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx" }
        let(:excel_file_name4)   { "4_結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx" }
        let(:dir_path)           { "#{Rails.application.credentials.s3_bucket[:results]}/#{result_file.id}" }
        let(:file_path)          { "#{dir_path}/#{download_file_name}" }

        let(:correct_file)       { Rails.root.join('spec', 'fixtures', 'result_download_for_unzip.xlsx').to_s }
        let(:correct_ex)         { Excel::Import.new(correct_file, 1, true).to_hash_data }

        let(:requested_url3)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { corporate_list: corporate_list_result4, free_search: free_search_result } ) }
        let(:requested_url4)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { free_search: free_search_result  } ) }
        let(:requested_url5)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url6)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url7)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url8)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url9)     { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url10)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url11)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url12)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url13)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url14)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url15)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url16)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url17)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { free_search: free_search_result } ) }
        let(:requested_url18)    { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { free_search: free_search_result } ) }

        before do
          stub_const('ResultFile::EXCEL_MAX_CEL_SIZE', 185)

          requested_url3.fetch_access_record(force_fetch: true)
          requested_url4.fetch_access_record(force_fetch: true)
          requested_url5.fetch_access_record(force_fetch: true)
          requested_url6.fetch_access_record(force_fetch: true)
          requested_url7.fetch_access_record(force_fetch: true)
          requested_url8.fetch_access_record(force_fetch: true)
          requested_url9.fetch_access_record(force_fetch: true)
          requested_url10.fetch_access_record(force_fetch: true)
          requested_url11.fetch_access_record(force_fetch: true)
          requested_url12.fetch_access_record(force_fetch: true)
          requested_url13.fetch_access_record(force_fetch: true)
          requested_url14.fetch_access_record(force_fetch: true)
          requested_url15.fetch_access_record(force_fetch: true)
          requested_url16.fetch_access_record(force_fetch: true)
          requested_url17.fetch_access_record(force_fetch: true)
          requested_url18.fetch_access_record(force_fetch: true)
        end

        context '正常系' do
          after do
            hdl = S3Handler.new
            hdl.delete(s3_path: file_path)
            hdl.delete(s3_path: file_path1)
            hdl.delete(s3_path: file_path2)
            hdl.delete(s3_path: file_path3)
            hdl.delete(s3_path: file_path4)
          end

          context 'リクエストが未完了、エクセルファイルが3つ、企業一覧クロールの結果なし' do
            let(:status) { EasySettings.status[:new] }
            let(:dir_path) { "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{Time.zone.today.year}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{result_file.id}" }

            let(:file_path) { File.join(dir_path, download_file_name).to_s }
            let(:file_path1) { File.join(dir_path, 'zip', excel_file_name1).to_s }
            let(:file_path2) { File.join(dir_path, 'zip', excel_file_name2).to_s }
            let(:file_path3) { File.join(dir_path, 'zip', excel_file_name3).to_s }
            let(:file_path4) { File.join(dir_path, 'zip', excel_file_name4).to_s }

            context 'EXCEL' do
              let(:file_type) { 'xlsx' }

              it 'ファイルが作成されること、未完了のファイルパスであること' do
                subject

                result_file.reload
                expect(result_file.path).to eq file_path
                expect(result_file.fail_files).to be_nil
                expect(result_file.status).to eq 'completed'
                expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                expect(result_file.parameters).to be_present
                expect(result_file.phase).to eq 'phase4'

                # ファイルが存在すること
                expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true
                expect(S3Handler.new.exist_object?(s3_path: file_path1)).to eq true
                expect(S3Handler.new.exist_object?(s3_path: file_path2)).to eq true
                expect(S3Handler.new.exist_object?(s3_path: file_path3)).to eq true
                expect(S3Handler.new.exist_object?(s3_path: file_path4)).to eq false

                # ZIPが存在すること
                expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq true

                # result_file_pathに保存されない
                expect(request.result_file_path).to be_nil

                # requestd_urlsのresultの値が残っている
                expect(request.requested_urls[0].result).not_to be_nil
                expect(request.requested_urls[1].result).not_to be_nil
                expect(request.requested_urls[2].result).not_to be_nil
                expect(request.requested_urls[0].free_search_result).not_to be_nil
                expect(request.requested_urls[1].free_search_result).not_to be_nil
                expect(request.requested_urls[2].free_search_result).not_to be_nil

                Dir.mktmpdir do |dir|
                  tmp_path = "#{dir}/tmp.zip"
                  S3Handler.new.download(s3_path: file_path, output_path: tmp_path)

                  # ZIP解凍
                  Zip::File.open(tmp_path) do |zip|
                    zip.each do |entry|
                      # { true } は展開先に同名ファイルが存在する場合に上書きする指定
                      zip.extract(entry, dir + '/' + entry.name) { true }
                    end
                  end

                  # データの中身が正しいこと
                  expect(Excel::Import.new(dir + '/' + excel_file_name1, 1, true).to_hash_data).to eq correct_ex
                  expect(Excel::Import.new(dir + '/' + excel_file_name2, 1, true).to_hash_data).to eq correct_ex
                  expect(Excel::Import.new(dir + '/' + excel_file_name3, 1, true).to_hash_data).to eq correct_ex
                end
              end
            end

            context 'CSV' do
              let(:file_type) { 'csv' }
              let(:download_file_name) { "1_結果_#{title}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.csv" }

              it 'ファイルが作成されること、未完了のファイルパスであること。CSVは一つのファイルしかできないこと' do
                subject

                result_file.reload
                expect(result_file.path).to eq file_path
                expect(result_file.fail_files).to be_nil
                expect(result_file.status).to eq 'completed'
                expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
                expect(result_file.parameters).to be_present
                expect(result_file.phase).to eq 'phase4'

                # ファイルが存在すること
                expect(S3Handler.new.exist_object?(s3_path: file_path)).to eq true
                expect(S3Handler.new.exist_object?(s3_path: file_path1)).to eq false
                expect(S3Handler.new.exist_object?(s3_path: file_path2)).to eq false
                expect(S3Handler.new.exist_object?(s3_path: file_path3)).to eq false

                # ZIPが存在しない
                expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq false

                # result_file_pathに保存されない
                expect(request.result_file_path).to be_nil

                # requestd_urlsのresultの値が残っている
                expect(request.requested_urls[0].result).not_to be_nil
                expect(request.requested_urls[1].result).not_to be_nil
                expect(request.requested_urls[2].result).not_to be_nil
                expect(request.requested_urls[0].free_search_result).not_to be_nil
                expect(request.requested_urls[1].free_search_result).not_to be_nil
                expect(request.requested_urls[2].free_search_result).not_to be_nil

                Dir.mktmpdir do |dir|
                  tmp_path = "#{dir}/tmp.csv"
                  S3Handler.new.download(s3_path: file_path, output_path: tmp_path)

                  # データの中身が正しいこと
                  expect(described_class.compare(csv_path: tmp_path, excel_path: correct_file, csv_start_row: nil)).to be_truthy
                  expect(described_class.compare(csv_path: tmp_path, excel_path: correct_file, csv_start_row: 8)).to be_truthy
                  expect(described_class.compare(csv_path: tmp_path, excel_path: correct_file, csv_start_row: 14)).to be_truthy
                end
              end
            end
          end

          context 'リクエストが完了、エクセルファイルが4つ、企業一覧クロールの結果あり' do
            let(:correct_file1) { Rails.root.join('spec', 'fixtures', 'result_download_for_unzip2.xlsx').to_s }
            let(:correct_file2) { Rails.root.join('spec', 'fixtures', 'result_download_for_unzip3.xlsx').to_s }
            let(:correct_file3) { Rails.root.join('spec', 'fixtures', 'result_download_for_unzip3.xlsx').to_s }
            let(:correct_file4) { Rails.root.join('spec', 'fixtures', 'result_download_with_list1.xlsx').to_s }
            let(:correct_ex1)        { Excel::Import.new(correct_file1, 1, true).to_hash_data }
            let(:correct_ex2)        { Excel::Import.new(correct_file2, 1, true).to_hash_data }
            let(:correct_ex3)        { Excel::Import.new(correct_file3, 1, true).to_hash_data }
            let(:correct_ex4)        { Excel::Import.new(correct_file4, 1, true).to_hash_data }

            let(:status) { EasySettings.status[:completed] }
            let(:file_path) { File.join(dir_path, download_file_name).to_s }
            let(:file_path1) { File.join(dir_path, 'zip', excel_file_name1).to_s }
            let(:file_path2) { File.join(dir_path, 'zip', excel_file_name2).to_s }
            let(:file_path3) { File.join(dir_path, 'zip', excel_file_name3).to_s }
            let(:file_path4) { File.join(dir_path, 'zip', excel_file_name4).to_s }
            let(:list_site_result_headers) { {'ドメイン'=>5,'名称'=>5,'aa'=>4,'住所1'=>3,'dd'=>2}.to_json }

            let(:requested_url19) { create(:company_info_requested_url_finished, request: request, url: 'https://www.hokkaido.ccbc.co.jp/', domain: ar_coca_cola.domain, result_attrs: { corporate_list: corporate_list_result1, free_search: free_search_result } ) }
            let(:requested_url20) { create(:company_info_requested_url_finished, request: request, url: 'https://www.nexway.co.jp/', domain: ar_nexway.domain, result_attrs: { corporate_list: corporate_list_result2, free_search: free_search_result } ) }
            let(:requested_url21) { create(:company_info_requested_url_finished, request: request, url: 'https://www.sample.co.cn', domain: nil, finish_status: EasySettings.finish_status.banned_domain, result_attrs: { corporate_list: corporate_list_result3, free_search: free_search_result } ) }
            let(:requested_url22) { create(:company_info_requested_url_finished, request: request, url: 'https://www.starbucks.co.jp/', domain: ar_starbacks.domain, result_attrs: { corporate_list: corporate_list_result4, free_search: free_search_result } ) }
            let(:corporate_list_result1) { {'ドメイン' => 'aa','名称' => 'コカコーラ','住所1' => 'bb','ss' => 'ff' }.to_json }
            let(:corporate_list_result2) { nil }
            let(:corporate_list_result3) { nil }
            let(:corporate_list_result4) { {'住所1' => 'aa','TEL' => 'asd','従業員' => 'efg','名称' => 'スタバ' }.to_json }

            before do
              requested_url19.fetch_access_record(force_fetch: true)
              requested_url20.fetch_access_record(force_fetch: true)
              requested_url21
              requested_url22.fetch_access_record(force_fetch: true)
            end

            it 'ZIPファイルが作成されること、ZIPの中身が正しいこと、未完了のファイルパスであること' do
              subject

              result_file.reload
              expect(result_file.path).to eq file_path
              expect(result_file.fail_files).to be_nil
              expect(result_file.status).to eq 'completed'
              expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
              expect(result_file.parameters).to be_present
              expect(result_file.phase).to eq 'phase4'

              # ファイルが存在すること
              expect(S3Handler.new.exist_object?(s3_path: file_path)).to  eq true
              expect(S3Handler.new.exist_object?(s3_path: file_path1)).to eq true
              expect(S3Handler.new.exist_object?(s3_path: file_path2)).to eq true
              expect(S3Handler.new.exist_object?(s3_path: file_path3)).to eq true
              expect(S3Handler.new.exist_object?(s3_path: file_path4)).to eq true

              # ZIPが存在すること
              expect(S3Handler.new.get_list_keys(s3_path: dir_path).to_s.include?('.zip')).to eq true

              # result_file_pathに保存されない
              expect(request.result_file_path).to be_nil

              # requestd_urlsのresultの値が残っている
              expect(request.requested_urls[0].result).not_to be_nil
              expect(request.requested_urls[1].result).not_to be_nil
              expect(request.requested_urls[2].result).not_to be_nil
              expect(request.requested_urls[0].free_search_result).not_to be_nil
              expect(request.requested_urls[1].free_search_result).not_to be_nil
              expect(request.requested_urls[2].free_search_result).not_to be_nil

              Dir.mktmpdir do |dir|
                tmp_path = "#{dir}/tmp.zip"
                S3Handler.new.download(s3_path: file_path, output_path: tmp_path)

                # ZIP解凍
                Zip::File.open(tmp_path) do |zip|
                  zip.each do |entry|
                    # { true } は展開先に同名ファイルが存在する場合に上書きする指定
                    zip.extract(entry, dir + '/' + entry.name) { true }
                  end
                end

                # データの中身が正しいこと
                expect(Excel::Import.new(dir + '/' + excel_file_name1, 1, true).to_hash_data).to eq correct_ex1
                expect(Excel::Import.new(dir + '/' + excel_file_name2, 1, true).to_hash_data).to eq correct_ex2
                expect(Excel::Import.new(dir + '/' + excel_file_name3, 1, true).to_hash_data).to eq correct_ex3
                expect(Excel::Import.new(dir + '/' + excel_file_name4, 1, true).to_hash_data).to eq correct_ex4
              end
            end
          end
        end

        context '異常系' do
          context 'エクセルの保存に失敗した場合' do
            let(:fail_file) { "2_結果_test_title_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx" }
            before do
              Timecop.freeze(current_time)
              fail_file
              allow_any_instance_of(RubyXL::Workbook).to receive(:write) do |book, args|
                raise if args.include?('2_結果')
                true
              end
              allow_any_instance_of(described_class).to receive(:make_zip_file).and_return(true)
              allow_any_instance_of(S3Handler).to receive(:upload).and_return(true)
            end

            after { Timecop.return }

            it 'fail_filesに失敗した番号が返ること' do
              subject

              result_file.reload
              expect(result_file.path).to eq file_path
              expect(result_file.fail_files).to eq [fail_file].to_json
              expect(result_file.status).to eq 'completed'
              expect(result_file.expiration_date).to eq Time.zone.today + EasySettings.request_expiration_days[result_file.request.plan_name]
              expect(result_file.parameters).to be_present
              expect(result_file.phase).to eq 'phase4'
            end
          end
        end
      end
    end
  end

  describe '#make_header' do
  end

  describe '#make_list_site_headers' do
    let(:result_file) { create(:result_file) }
    subject { result_file.send(:make_list_site_headers, list_site_headers) }

    context 'list_site_headersがnil' do
      let(:list_site_headers) {}
      it { expect(subject).to eq([]) }
    end

    context 'list_site_headersにその他を含む' do
      let(:list_site_headers) { ['a', Crawler::Items.local('日本語')[:others]] }
      it { expect(subject).to eq(list_site_headers + ['']) }
    end

    context 'list_site_headersにその他を含まない' do
      let(:list_site_headers) { ['a', 'b'] }
      it { expect(subject).to eq(['a', 'b', Crawler::Items.local('日本語')[:others], '']) }
    end
  end
end

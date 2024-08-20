class DeleteWorker

  class << self

    def delete_requests

      requests = Request.delete_candidates.preload(requested_urls: [:result])

      hdl = S3Handler.new

      del_reqs = []
      requests.each do |req|
        del_reqs << "#{req.id} #{req.type} #{req.file_name} #{req.corporate_list_site_start_url} #{req.result_file_path}"
        hdl.delete(s3_path: req.result_file_path) if req.result_file_path.present?
        req.result_files.each do |res_file|
          del_reqs << "　　#{res_file.id} #{res_file.path}"
          hdl.delete(s3_path: res_file.path) if res_file.path.present?
        end
        req.destroy
      end

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("削除したリクエスト\n#{del_reqs.join("\n")}", 'リクエスト削除 delete_requests', 'バッチ'))
    rescue => e
      Lograge.job_logging('Workers', 'error', 'DeleteWorker', 'delete_requests', { issue: 'delete_requests Error', delete_reqs: del_reqs.join(';; '), err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    end

    # 結果レコード削除
    # 完了後、8日間で削除
    def delete_results

      requests = Request.delete_result_candidates

      del_reqs = []
      last_id = ''
      requests.each do |req|

        next if req.requested_urls[0]&.deleted_result?

        del_reqs << "#{req.id} #{req.type} #{req.file_name} #{req.corporate_list_site_start_url} カウント:#{req.requested_urls_count}"

        req.requested_urls.preload(:result).each do |req_url|
          last_id = "requested_url id: #{req_url.id}"
          req_url.result.update!(free_search: nil, candidate_crawl_urls: nil, single_url_ids: nil, main: nil, corporate_list: nil)
        end
      end

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("削除した結果\n#{del_reqs.join("\n")}", '結果削除 delete_results', 'バッチ'))
    rescue => e
      Lograge.job_logging('Workers', 'error', 'DeleteWorker', 'delete_results', { issue: 'delete_results Error', delete_reqs: del_reqs.join(';; '), last_id: last_id, err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    end

    def delete_tmp_results_files(loop_cnt = 600)

      keys = []

      hdl = S3Handler.new
      loop_cnt.times do |i|
        day = (Time.zone.today - i.day - 60.day).strftime("%Y/%-m/%-d")
        objcts = hdl.get_list(s3_path: "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{day}/")

        objcts.each do |obj|
          keys << obj.key
          hdl.delete(bucket: Rails.application.credentials.s3_bucket[:tmp_results], key: obj.key)
        end
      end

      del_result_files = []
      ResultFile.where(deletable: true).each do |res_file|
        del_result_files << "#{res_file.request.id} ResultFile ID: #{res_file.id} 削除ファイル: #{res_file.path}"
        hdl.delete(s3_path: res_file.path) if res_file.path.present?
        res_file.destroy
      end

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("削除したオブジェクトキー\n#{keys.join("\n")}\n\n削除したResultFile\n#{del_result_files.join("\n")}", 'TMP結果ファイル削除 delete_tmp_results_files', 'バッチ'))
    rescue => e
      Lograge.job_logging('Workers', 'error', 'DeleteWorker', 'delete_tmp_results_files', { issue: 'delete_tmp_results_files Error', delete_keys: keys.join(', '), err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    end

    # def delete_test_env_s3_result_files(loop_cnt = 5000)
    #   return unless Rails.env.test?
    #   puts 'OK'

    #   hdl = S3Handler.new
    #   loop_cnt.times do |i|
    #     id = i + 1
    #     objcts = hdl.get_list(s3_path: "#{Rails.application.credentials.s3_bucket[:results]}/#{id}/")

    #     objcts.each do |obj|
    #       # hdl.delete(bucket: Rails.application.credentials.s3_bucket[:results], key: obj.key)
    #       hdl.delete(s3_path: "#{Rails.application.credentials.s3_bucket[:results]}/#{obj.key}")
    #     end
    #   end
    # rescue => e
    #   Lograge.job_logging('Workers', 'error', 'DeleteWorker', 'perform', { issue: 'delete_tmp_results_files Error', delete_keys: keys.join(', '), err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    # end

    def delete_results_files_working_dirs
      dirs = []
      base_dir = Rails.application.credentials.result_file_working_directory[:path]

      3.times do |i|
        path = "#{base_dir}/#{(Time.zone.now - 2.months - i.months).month}"
        FileUtils.rm_rf(path)
        dirs << path
      end

      30.times do |i|
        date = Time.zone.now - 5.days - i.days
        path = "#{base_dir}/#{date.month}/#{date.day}"
        FileUtils.rm_rf(path)
        dirs << path
      end

      NoticeMailer.deliver_later(NoticeMailer.notice_simple("削除したDir\n#{dirs.join("\n")}", '結果ファイルワーキングDir削除 delete_results_files_working_dirs', 'バッチ'))
    rescue => e
      Lograge.job_logging('Workers', 'error', 'DeleteWorker', 'delete_results_files_working_dirs', { issue: 'delete_results_files_working_dirs Error', delete_dir: dirs.join(', '), err_class: e.class, err_msg: e.message, backtrace: e.backtrace})
    end

  end
end

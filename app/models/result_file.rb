class ResultFile < ApplicationRecord
  belongs_to :request
  has_many :tmp_company_info_urls

  enum file_type: [ :xlsx, :csv ]
  enum status: [ :accepted, :waiting, :making, :completed, :error ]

  scope :unfinished, ->{ where('status <= ?', statuses[:making]) }
  scope :status_accepted, ->{ where(status: statuses[:accepted]) }
  scope :status_making, ->{ where(status: statuses[:making]) }

  EXCEL_MAX_CEL_SIZE = 160_000

  def finished?
    completed? || error?
  end

  def available_download?
    return false if expiration_date.present? && expiration_date < Time.zone.today
    true
  end

  def available_request?
    return false if request.expiration_date.present? && request.expiration_date < Time.zone.today
    true
  end

  def parse_params
    Json2.parse(parameters)
  end

  def to_log
    log = "ID: #{id}"
    log = log + ", PHASE: #{phase}" if phase.present?

    if ( params = parse_params ).present?
      log = log + ", START_FROM: #{params[:last_req_url_id]}" if params[:last_req_url_id].present?
      log = log + ", STOP_SIDEKIQ: #{params[:stop_sidekiq]}" if params[:stop_sidekiq].present?
    end
    log
  end

  # 各フェーズが冪等になるように作成すること！！！
  def make_file(mode = :phase)
    if mode == :at_once
      prepare_headers
      while self.reload.phase == 'phase2' do
        output_file
      end
      upload_to_s3
      clean_and_record
      ActiveRecord::Base.connection.close
      return
    end

    if phase.blank?

      prepare_headers

    elsif phase == 'phase2'

      output_file

    elsif phase == 'phase3'

      upload_to_s3

    elsif phase == 'phase4'

      clean_and_record

    end

    ActiveRecord::Base.connection.close
  rescue => e
    MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFile][#make_file] error #{e} #{e.message}  \n #{e.backtrace}"
    Lograge.logging('error', { class: 'Request', method: 'make_file 3', issue: "ALL #{e}", request: request, err_msg: e.message, backtrace: e.backtrace })

    params = parse_params

    request.update!(result_file_path: nil) if final?
    update!(status: self.class.statuses[:error])
    ActiveRecord::Base.connection.close

    GC.start

    false
  end

  private

  def single_header(header_name, num)
    tmp = num == 0 ? '(個別ページ)' : "(個別ページ#{num})"
    header_name + tmp
  end

  def make_s3_path(total_status, file_name)
    if total_status == 'incomplete'
      "#{Rails.application.credentials.s3_bucket[:tmp_results]}/#{Time.zone.today.year}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{id}/#{file_name}"
    else
      "#{Rails.application.credentials.s3_bucket[:results]}/#{id}/#{file_name}"
    end
  end

  def output_file_name
    if self.xlsx?
      "結果_#{self.request.title.to_base_name[0..50]}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xlsx"
    elsif self.csv?
      "結果_#{self.request.title.to_base_name[0..50]}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.csv"
    end
  end

  def zip_file_name
    "結果_#{self.request.title.to_base_name[0..50]}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.zip"
  end

  def make_zip_file(work_dir:, input_files:, zip_file_name_path:)
    Zip::File.open(zip_file_name_path, create: true) do |zipfile|
      input_files.each do |filename|
        zipfile.add(filename, File.join(work_dir, filename))
      end
    end
    true
  rescue => e
    Lograge.logging('error', { class: 'Request', method: 'make_zip_file', issue: "#{e}", request: self, err_msg: e.message, backtrace: e.backtrace })
    self.request.update!(result_file_path: nil)
    self.update!(path: nil)
    false
  end

  def prepare_headers

    params = {}
    params[:start_at] = Time.zone.now
    params[:file_pathes] = []
    params[:file_names] = []
    params[:fail_exce_files] = []

    req = self.request

    params[:total_status] = ( req.stop? || !req.finished? ) ? 'incomplete' : 'complete'
    params[:list_crawl_phase1] = params[:total_status] == 'incomplete' && req.corporate_list_site? && ( req.company_info_urls.size == 0 || req.status == EasySettings.status.arranging )

    lang = req.user.language

    requested_url = Crawler::Items.local(lang)[:requested_url]
    status        = Crawler::Items.local(lang)[:status]
    source_title  = Crawler::Items.local(lang)[:source_title]
    source_url    = Crawler::Items.local(lang)[:source_url]

    if params[:list_crawl_phase1] # つまりフェーズ１のリスト取得が終わっていない時

      dc = DataCombiner.new(request: req)
      dc.combine_results_and_save_tmp_company_info_urls(self.id)
      params[:dc_bunch_id] = dc.bunch_id

      common_headers       = []
      list_site_headers    = dc.headers.keys[0..300]
      company_site_headers = []

      dc = nil
      GC.start
    else
      common_headers       = [requested_url]
      list_site_headers    = req.get_list_site_result_headers
      company_site_headers = [status]
    end

    params[:category_max_counts] = Json2.parse(req.company_info_result_headers, symbolize: false) || {}

    if list_site_headers.blank? && params[:category_max_counts].blank?
      req.tmp_company_info_urls.where(bunch_id: params[:dc_bunch_id], result_file_id: self.id).destroy_all if params[:total_status] == 'incomplete' && params[:list_crawl_phase1]
      GC.start
      raise 'No headers in #make_file'
    end


    params[:common_headers]       = common_headers
    params[:list_site_headers]    = make_list_site_headers(list_site_headers)
    params[:company_site_headers] = company_site_headers + make_header_for_company_info(params[:category_max_counts])

    params[:dir] = "#{Rails.application.credentials.result_file_working_directory[:path]}/#{Time.zone.today.month}/#{Time.zone.today.day}/#{id}"

    update!(parameters: params.to_json, phase: 'phase2')
  end

  def make_list_site_headers(list_site_headers)
    if list_site_headers.present?
      lang = request.user.language
      if list_site_headers.include?(Crawler::Items.local(lang)[:others])
        list_site_headers + ['']
      else
        list_site_headers + [Crawler::Items.local(lang)[:others]] + ['']
      end
    else
      []
    end
  end

  def make_header_for_company_info(category_max_counts)
    return [] if category_max_counts.blank?
    lang = self.request.user.language

    country_datum  = Crawler::Country.find(lang).new
    localize_words = country_datum.localize_words
    max_counts     = category_max_counts

    res = [
      Crawler::Items.local(lang)[:url],
      Crawler::Items.local(lang)[:domain],
      localize_words[Crawler::Items.company_name],
      Crawler::Items.local(lang)[:title],
      localize_words[Crawler::Items.extracted_post_code],
      localize_words[Crawler::Items.extracted_address],
      localize_words[Crawler::Items.extracted_telephone],
      localize_words[Crawler::Items.extracted_fax],
      localize_words[Crawler::Items.extracted_mail_address],
      localize_words[Crawler::Items.extracted_capital],
      localize_words[Crawler::Items.extracted_sales],
      localize_words[Crawler::Items.extracted_employee],
      localize_words[Crawler::Items.extracted_representative_position],
      localize_words[Crawler::Items.extracted_representative],
      Crawler::Items.local(lang)[Crawler::Items.inquiry_form]
    ]

    1.upto(max_counts[Crawler::Items.contact_information]) do |i|
      res << localize_words[Crawler::Items.contact_information] + i.to_s
    end

    res << localize_words[Crawler::Items.mail_address]

    country_datum.indicate_words.keys.each do |word|
      res << localize_words[word]
    end

    1.upto(max_counts[Crawler::Items.others]) do |i|
      res << Crawler::Items.local(lang)[:others] + i.to_s
    end

    1.upto(max_counts[Crawler::Items.another_company]) do |i|
      res << Crawler::Items.local(lang)[Crawler::Items.another_company] + i.to_s
    end

    if request.free_search
      request.get_target_words.each do |word|
        1.upto(max_counts[word]) do |i|
          res << "Original Crawl #{word}" + i.to_s
        end
      end
    end
    res
  end

  def output_file
    params = parse_params

    dir = params[:dir]

    req = self.request

    work_dir = "#{dir}/zip"

    FileUtils.rm_rf(dir) if params[:last_req_url_id].blank? && Dir.exist?(dir)
    FileUtils.mkdir_p(work_dir) unless Dir.exist?(work_dir)


    params[:file_name] = output_file_name if params[:file_name].blank?

    params[:file_name_prefix] = params[:file_name_prefix].blank? ? 1 : params[:file_name_prefix] + 1

    path = "#{work_dir}/#{params[:file_name_prefix]}_#{params[:file_name]}"

    if self.xlsx?
      handler = Excel::Export.new(path, 'result', auto_save: false)
    elsif self.csv?
      handler = CsvHandler::Export.new(path, auto_save: false)
    end

    handler.add_header(params[:common_headers], params[:list_site_headers], params[:company_site_headers])

    if params[:list_crawl_phase1]
      company_info_urls = req.tmp_company_info_urls.select(:id, :url, :domain, :request_id, :corporate_list_result, :result).where(bunch_id: params[:dc_bunch_id], result_file_id: self.id).order(id: :asc)
      company_info_urls = company_info_urls.where('tmp_company_info_urls.id > ?', params[:last_req_url_id]) if params[:last_req_url_id].present?
    else
      company_info_urls = req.requested_urls.company_info_urls.preload(:result).select(:id, :url, :domain, :request_id, :finish_status).order(id: :asc)
      company_info_urls = company_info_urls.where('requested_urls.id > ?', params[:last_req_url_id]) if params[:last_req_url_id].present?
    end

    company_info_urls.each do |req_url|

      rc = req_url.make_contents_for_output(common_headers: params[:common_headers], list_site_headers: params[:list_site_headers], category_max_counts: params[:category_max_counts].stringify_keys)

      handler.add_row_contents(rc[:common], rc[:list_site], rc[:company_site])

      if self.xlsx?
        if handler.cel_cnt > 100_000 && !params[:stop_sidekiq]
          params[:stop_sidekiq] = true
          params[:file_name_prefix] = params[:file_name_prefix] - 1
          update!(parameters: params.to_json)
          return
        end

        if handler.cel_cnt > EXCEL_MAX_CEL_SIZE

          handler.save
          if handler.save_result[:result] == :done
            params[:file_pathes] << handler.save_result[:path]
            params[:file_names] << handler.save_result[:file_name]
          elsif handler.save_result[:result] == :failure
            params[:fail_exce_files] << handler.save_result[:file_name]
          end

          params[:last_req_url_id] = req_url.id
          update!(parameters: params.to_json)
          return
        end
      end

    rescue => e
      Lograge.logging('error', { class: 'Request', method: 'make_file 1', issue: "ONE #{e.class}", url: req_url.url, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
    end

    if company_info_urls.size > 0
      handler.save
      if handler.save_result[:result] == :done
        params[:file_pathes] << handler.save_result[:path]
        params[:file_names] << handler.save_result[:file_name]
      elsif handler.save_result[:result] == :failure
        params[:fail_exce_files] << handler.save_result[:file_name]
      end

      company_info_urls = nil
      GC.start
    end

    update!(parameters: params.to_json, phase: 'phase3')
  end

  def upload_to_s3
    params = parse_params

    req = self.request

    s3_path = nil
    dir = params[:dir]
    work_dir = "#{dir}/zip"

    # ZIP
    download_file_path = if params[:file_names].size > 1
      zip_file_path = "#{dir}/#{zip_file_name}"
      zip_res = make_zip_file(work_dir: work_dir, input_files: params[:file_names], zip_file_name_path: zip_file_path)
      raise 'ZIP ERROR' unless zip_res

      # 個別エクセルファイルのアップロード
      params[:file_pathes].each do |fp|
        s3_path = make_s3_path(params[:total_status], "zip/#{fp.split('/')[-1]}")
        unless S3Handler.new.upload(s3_path: s3_path, file_path: fp)
          Lograge.logging('error', { class: 'Request', method: 'make_file 4', issue: "Failed S3 Uploads", request: req })
        end
      end

      zip_file_path
    else
      params[:file_pathes][0]
    end

    MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFile][#make_file] ZIP OK"

    p "Making #{file_type.upcase} File Complete! Time #{Time.zone.now - params[:start_at].to_time} sec"
    Lograge.logging('info', { class: 'Request', method: 'make_file', issue: "Making Excel File Complete! Time #{Time.zone.now - params[:start_at].to_time} sec" })


    params[:s3_path] = make_s3_path(params[:total_status], download_file_path.split('/')[-1])

    unless S3Handler.new.upload(s3_path: params[:s3_path], file_path: download_file_path)
      raise 'Failed S3 Uploads.'
    end

    MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFile][#make_file] S3 Upload OK"

    FileUtils.rm_rf(dir)
    MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFile][#make_file] Dir 削除"

    update!(parameters: params.to_json, phase: 'phase4')
  end

  def clean_and_record
    params = parse_params
    req = self.request

    if params[:total_status] == 'incomplete'
      req.tmp_company_info_urls.where(bunch_id: params[:dc_bunch_id], result_file_id: self.id).destroy_all if params[:list_crawl_phase1]
    else
      req.update!(result_file_path: params[:s3_path], expiration_date: Time.zone.today + EasySettings.request_expiration_days[req.plan_name]) if final?
    end

    GC.start

    MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFile][#make_file] 後片付け"

    self.fail_files = params[:fail_exce_files].to_json if params[:fail_exce_files].present?
    self.path = params[:s3_path]
    self.status = self.class.statuses[:completed]
    self.expiration_date = Time.zone.today + EasySettings.request_expiration_days[request.plan_name]
    self.save!

    MyLog.new('my_crontab').log "[#{Time.zone.now}][ResultFile][#make_file] 保存"
  end

  class << self
    def set_delete_flag!(request)
      if ( cnt = self.where(request: request, final: false).count ) > 7
        self.where(request: request, final: false).order(:created_at).limit(cnt - 7).update_all(deletable: true)
      end
    end

    def compare(csv_path:, excel_path:, csv_start_row: nil, csv_end_row: nil, look_around_csv: nil)
      exl = Excel::Import.new(excel_path, 1, true).to_hash_data[:data]
      puts 'EXCEL OK'
      csv = CsvHandler::Import.new(csv_path, true).to_hash_data
      puts 'CSV OK'

      if csv_start_row.present? || csv_end_row.present?
        if look_around_csv.present?
          (look_around_csv * 2 + 1).times do |i|
            num = csv_start_row - look_around_csv + i
            puts "#{num} #{csv[num][0]} #{csv[num][1]}"
          end
        end

        csv.delete_if do |key, vals|
          next if key == 1
          key < ( csv_start_row || -1 ) ||
          key > ( csv_end_row || 9_999_999 )
        end

        if csv_start_row.present?
          csv.transform_keys! do |key|
            next 1 if key == 1
            key - csv_start_row + 2
          end
        end
      end
      puts 'CSV Change OK'

      row_size = exl.size

      row_size.times do |i|
        i = i + 1
        exl_size = exl[i]&.size
        csv_size = csv[i]&.size
        raise "#{i}行目 サイズが違う EXCEL=#{exl_size}  CSV=#{csv_size}" unless exl_size == csv_size

        exl[i].each_with_index do |val, j|
          next if exl[i][j].gsub("\n", ' ') == csv[i][j]
          next if exl[i][j].blank? && csv[i][j].blank?
          puts "EXCEL = #{exl[i][j]}"
          puts "CSV   = #{csv[i][j]}"
          puts "行: #{exl[i][0]}  #{exl[i][1]}  #{exl[i][2]}  #{exl[i][3]}"
          puts "列EXCEL: [[#{exl[1][j]}]]  列CSV: [[#{csv[1][j]}]]"
          raise "#{i}行目 #{j}列目 内容が違う EXCEL=#{exl_size}  CSV=#{csv_size}"
        end
      end

      puts '合致'
      true
    end

    def compare_for_test(csv_hash:, excel_hash:)
      row_size = csv_hash.size > excel_hash.size ? csv_hash.size : excel_hash.size

      row_size.times do |i|
        i = i + 1
        exl_size = excel_hash[i]&.size
        csv_size = csv_hash[i]&.size
        larger = csv_size > exl_size ? csv_hash[i] : excel_hash[i]

        larger.each_with_index do |val, j|
          next if excel_hash[i][j].blank? && csv_hash[i][j].blank?
          next if excel_hash[i][j].gsub("\n", ' ') == csv_hash[i][j]
          puts "EXCEL = #{excel_hash[i][j]}"
          puts "CSV   = #{csv_hash[i][j]}"
          raise "#{i}行目 #{j}列目 内容が違う"
        end
      end

      true
    end

    def compare_char(str1, str2)
      diff = nil
      str1.length.times do |i|
        unless str1[i] == str2[i]
          puts "#{i}番目 #{str1[i]} #{str2[i]} コード: #{str1[i].ord} #{str2[i].ord}"
          diff = i
          break
        end
      end
      diff
    end
  end
end

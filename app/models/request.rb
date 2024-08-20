class Request < ApplicationRecord
  self.inheritance_column = :_type_disabled # 予約語typeを使えるように許可する

  mount_uploader :excel, ExcelUploader

  EXCEL_MAX_SIZE = 6_000_000

  belongs_to :user
  has_many   :requested_urls,   dependent: :destroy
  has_many   :tmp_company_info_urls, dependent: :destroy
  has_many   :result_files, dependent: :destroy
  has_one    :simple_investigation_history

  enum type: [ :file, :csv_string, :word_search, :corporate_list_site, :company_db_search ]
  enum paging_mode: { normal: 0, only_this_page: 1, only_paging: 2 } # default:, all, not_configured:, normal, basic

  scope :working,           -> { where(status: EasySettings.status.working) }
  scope :all_working,       -> { where(status: EasySettings.status.all_working) }
  scope :unfinished,        -> { where(status: EasySettings.status.new..EasySettings.status.working) }
  scope :completed,         -> { where(status: EasySettings.status.completed) }
  scope :error,             -> { where(status: EasySettings.status.error) }
  scope :arranging,         -> { where(status: EasySettings.status.arranging) }
  scope :delete_candidates, -> { where('expiration_date <= ? OR updated_at <= ?', Time.zone.today - 2.month, Time.zone.today - 2.month) }
  scope :delete_result_candidates, -> { where('expiration_date <= ? OR updated_at <= ?', Time.zone.today - 8.days, Time.zone.today - 39.days) }

  scope :find_token,       -> (token) { where(token: token) }
  scope :unfinished_by_ip, -> (ip)    { where(ip: ip).unfinished }
  scope :main,             -> { where(test: false) }
  scope :test_mode,        -> { where(test: true) }
  scope :viewable,         -> { where('status <= 4 OR ( status >= 5 AND updated_at >= ?)', Time.zone.today.beginning_of_day - 1.month ) }

  def plan_name
    EasySettings.plan.invert[self.plan]
  end

  def company_info_urls
    self.requested_urls.where(type: 'SearchRequest::CompanyInfo')
  end

  def corporate_list_urls
    self.requested_urls.where(type: 'SearchRequest::CorporateList')
  end

  def corporate_single_urls
    self.requested_urls.where(type: 'SearchRequest::CorporateSingle')
  end

  def test_req_url
    corporate_list_urls.find_by(test: true)
  end

  def corporate_list_domain
    self.corporate_list_urls[0]&.domain
  end

  def set_working
    return if self.reload.stop?
    update!(status: EasySettings.status[:working]) unless all_working?
  end

  def get_new_urls_and_update_status(limit)
    return [] if self.stop?

    exec_urls = []
    if ( list_url = self.corporate_list_urls.main.status_new[0] ).present?
      exec_urls << list_url if list_url.update_waiting
    end

    if limit - exec_urls.size > 0 && ( singles = self.corporate_single_urls.main.status_new.limit(limit) ).present?
      singles.each { |req_url| exec_urls << req_url if req_url.update_waiting }
    end

    if limit - exec_urls.size > 0 && ( company_urls = self.company_info_urls.main.status_new.limit(limit-exec_urls.size) ).present?
      company_urls.each { |req_url| exec_urls << req_url if req_url.update_waiting }
    end

    if all_working?
      return [] if self.stop?
      self.update!(status: EasySettings.status.all_working)
    end

    exec_urls

  # 以下のエラーは出現しなくなったら削除する
  rescue => e
    puts e.class
    puts e.message
    puts "limit = #{limit}"
    puts "exec_urls.size = #{exec_urls.size}"
    raise e
  end

  def all_working?
    if self.corporate_list_site?
      return corporate_list_extraction_complete? && self.get_new_urls.size == 0
    else
      return self.get_new_urls.size == 0
    end
    false
  end

  def all_urls_finished?
    self.get_unfinished_urls.size == 0
  end

  def corporate_list_extraction_complete?
    corporate_list_urls.unfinished.size == 0 && corporate_single_urls.unfinished.size == 0
  end

  def complete(status = :completed)
    self.status          = EasySettings.status[status]
    self.expiration_date = Time.zone.today + EasySettings.request_expiration_days[self.plan_name] unless self.test
    self.save!
  end

  def stop?
    self.status == EasySettings.status.discontinued
  end

  def stop
    self.complete(:discontinued)
    self.get_waiting_urls.update_all(status: EasySettings.status[:discontinued],
                                     finish_status: EasySettings.finish_status[:discontinued])
    self.get_retry_urls.update_all(status: EasySettings.status[:discontinued],
                                   finish_status: EasySettings.finish_status[:discontinued])
  end

  def get_new_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.new)
  end

  def get_only_waiting_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.waiting)
  end

  def get_waiting_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.new..EasySettings.status.waiting)
  end

  def get_unfinished_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.new..EasySettings.status.retry)
  end

  def get_retry_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.retry)
  end

  def get_working_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.working)
  end

  def get_completed_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.completed)
  end

  def get_error_urls
    RequestedUrl.where(request_id: self.id, status: EasySettings.status.error)
  end

  def get_status_string
    if self.status <= EasySettings.status.all_working || self.status == EasySettings.status.arranging
      '未完了'
    elsif self.status == EasySettings.status.discontinued
      '中止'
    elsif finished?
      '完了'
    end
  end

  def fail_reason
    return nil unless self.corporate_list_site?

    f_st = self.test ? test_req_url.finish_status : corporate_list_urls.find_by(test: false)&.finish_status

    case f_st
    when EasySettings.finish_status.invalid_url
      'URLが無効の可能性があります。'
    when EasySettings.finish_status.unavailable_site
      '取得(クロール)できないサイトです。'
    when EasySettings.finish_status.banned_domain
      'こちらのサイトは取得(クロール)を禁止しています。'
    when EasySettings.finish_status.access_sealed_page
      'こちらのページは取得(クロール)できません。大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
    when EasySettings.finish_status.unsafe_and_sealed_page
      'こちらのページは取得(クロール)できません。大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
    when EasySettings.finish_status.user_over_access
      'アクセス制限にひっかかりました。'
    when EasySettings.finish_status.current_access_limit
      'アクセス制限にひっかかりました。'
    when EasySettings.finish_status.error
      '取得(クロール)に失敗しました。大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
    when EasySettings.finish_status.unexist_page
      'このページは存在しません。'
    when EasySettings.finish_status.timeout
      'タイムアウトし、取得(クロール)に失敗しました。時間をおいて再度お試しください。それでも取得できないようでしたら、大変申し訳ございませんが、このサイトには対応していない可能性がございます。'
    else
      nil
    end
  end

  def finished?
    self.status >= EasySettings.status.completed && self.status != EasySettings.status.arranging
  end

  def available?
    self.class.where(id: self.id).viewable.present?
  end

  def available_result_files(limit = 5)
    self.result_files.where(final: false, deletable: false).order(created_at: :desc).limit(limit)
  end

  def available_download?
    return false if over_expiration_date?

    downloadable?
  end

  def downloadable?
    return false if test

    return false if corporate_list_site? && corporate_list_urls.success.main.size == 0 && company_info_urls.size == 0

    return false if !corporate_list_site? && company_info_urls.finished.size == 0

    true
  end

  def over_expiration_date?
    return true if expiration_date.present? && expiration_date < Time.zone.today
    false
  end

  def total_count_decided?
    return true unless corporate_list_site?

    return true if finished?

    return false if !finished? && company_info_urls.size == 0

    true
  end

  def accepted_url_count
    self.requested_urls.company_info_urls.main.size
  end

  def get_expiration_date
    self.status >= EasySettings.status.completed ? self.expiration_date&.strftime("%Y年%m月%d日") : nil
  end

  def requested_date
    self.created_at.strftime("%Y年%m月%d日 %H:%M:%S")
  end

  def plan_user?
    self.user.my_plan_number > EasySettings.plan[:free]
  end

  def registered_user?
    self.user.my_plan_number >= EasySettings.plan[:free]
  end

  def status_mean
    EasySettings.status.invert[self.status]
  end

  def get_target_words
    self.target_words.split_and_trim(',')
  end

  def free_search_option
   { link_words: link_words, target_words: target_words }
  end

  def corporate_list_size
    cnt = 0
    self.corporate_list_urls.each do |list_url|
      cnt += Json2.parse(list_url.result.main)&.size || 0
    end
    cnt
  end

  def update_company_info_result_headers(requested_url)
    self.with_lock do
      category_max_counts = Json2.parse(self.company_info_result_headers, symbolize: false) || initialize_category_max_counts

      category_max_counts = update_category_max_counts(category_max_counts: category_max_counts, requested_url: requested_url)

      self.company_info_result_headers = category_max_counts.to_json
      self.save!
    end
  end

  def analysis_result
    Json2.parse(list_site_analysis_result, symbolize: false)
  end

  # 何度実行してもOK！
  # 冪等処理を維持すること！！
  def update_multi_path_analysis(complete_multi_path_analysis:, multi_path_candidates:, multi_path_analysis:)
    self.with_lock do
      unless self.complete_multi_path_analysis
        self.complete_multi_path_analysis = complete_multi_path_analysis

        multi_pathes = Json2.parse(self.multi_path_candidates)
        if multi_pathes.present?
          multi_pathes.concat(multi_path_candidates)
        else
          multi_pathes = multi_path_candidates
        end
        multi_pathes.uniq!

        self.multi_path_candidates = multi_pathes.to_json
        self.multi_path_analysis = multi_path_analysis.to_json
        self.save!
      end
    end
  end

  def update_list_site_result_headers(new_list_site_result_headers, absolute_headers = nil)
    return if new_list_site_result_headers.blank?

    self.with_lock do
      headers = Json2.parse(self.list_site_result_headers, symbolize: false)

      if headers.present?
        new_list_site_result_headers.each do |hd|
          headers[hd] = headers.has_key?(hd) ? headers[hd] + 1 : 1
        end
      else
        headers = new_list_site_result_headers.map { |hd| [hd, 1] }.to_h
      end

      # 「安定なソート」を実施。その他は、そのままの順にしておく。
      i = 0
      headers = headers.sort_by { |_, v| [-v, i += 1] }.to_h

      if headers.size > 500
        headers.keys[500..-1]&.each { |hd| headers.delete(hd) }
      end

      self.list_site_result_headers = headers.to_json
      self.save!
    end
  end

  def get_list_site_result_headers
    headers = Json2.parse(self.list_site_result_headers, symbolize: false)
    return [] if headers.blank?
    return headers if headers.class == Array # 旧バージョンの互換のため

    headers = headers.keys[0..299]

    multi = []
    multi << Analyzer::BasicAnalyzer::ATTR_ORG_NAME   if headers.include?(Analyzer::BasicAnalyzer::ATTR_ORG_NAME)
    multi << Analyzer::BasicAnalyzer::ATTR_PAGE       if headers.include?(Analyzer::BasicAnalyzer::ATTR_PAGE)
    multi << Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE if headers.include?(Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE)

    single = {}
    headers.each do |hd|
      if hd.match?(/\(個別ページ\d*\)$/)
        num = hd.include?('(個別ページ)') ? 0 : hd.split('(個別ページ')[1].split(')')[0].to_i

        if single.has_key?(num)
          single[num] << hd
        else
          single[num] = []
          single[num] << single_header(Analyzer::BasicAnalyzer::ATTR_ORG_NAME, num)   if headers.include?(single_header(Analyzer::BasicAnalyzer::ATTR_ORG_NAME, num))
          single[num] << single_header(Analyzer::BasicAnalyzer::ATTR_PAGE, num)       if headers.include?(single_header(Analyzer::BasicAnalyzer::ATTR_PAGE, num))
          single[num] << single_header(Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE, num) if headers.include?(single_header(Analyzer::BasicAnalyzer::ATTR_PAGE_TITLE, num))
          single[num] << hd
        end
      else
        multi << hd
      end
    end

    single = single.sort_by { |k,v| k }.to_h

    multi.uniq + single.map { |k,v| v.uniq }.flatten
  end

  def update_accessed_urls(new_accessed_urls)
    urls = []
    self.with_lock do
      urls = Json2.parse(self.accessed_urls)

      if urls.present?
        urls.concat(new_accessed_urls)
      else
        urls = new_accessed_urls
      end
      urls.uniq!

      self.accessed_urls = urls.to_json
      self.save!
    end
    urls
  end

  # 別のリクエストにanalysis_resultを複製する
  def copy_analysis_result_from(request_id)
    source_request = self.class.find_by_id(request_id)
    return nil if source_request.blank?

    self.list_site_analysis_result = source_request.list_site_analysis_result
    save!
  end

  # 別のユーザのリクエストとして複製する
  def copy_to(user_id)
    user = User.find_by_id(user_id)
    return nil if user.blank?

    new_request = nil
    ActiveRecord::Base.transaction do
      new_request = self.dup
      new_request.move_to(user_id)

      copy_ids_map = {}

      requested_urls.each do |req_url|
        new_req_url = req_url.dup
        new_req_url.request_id = new_request.id
        new_req_url.save! # ここでコールバックで、resultが作成される

        copy_ids_map[req_url.id] = new_req_url.id
      end

      requested_urls.each do |req_url|
        new_req_url = RequestedUrl.find(copy_ids_map[req_url.id])

        if ( corp_list_url_id = req_url.corporate_list_url_id ).present? &&
           RequestedUrl.find_by_id(corp_list_url_id).present?

          new_req_url.update!(corporate_list_url_id: copy_ids_map[corp_list_url_id])
        end

        new_result = new_req_url.result

        source_result_attribute = req_url.result.attributes
        source_result_attribute.delete('id')
        source_result_attribute.delete('created_at')
        source_result_attribute.delete('updated_at')
        source_result_attribute['requested_url_id'] = copy_ids_map[req_url.id]

        if ( single_url_ids = source_result_attribute['single_url_ids']).present?
          source_result_attribute['single_url_ids'] = Json2.parse(single_url_ids).map { |id| copy_ids_map[id] }.to_json
        end

        new_result.update!(source_result_attribute)
      end
    end
    new_request
  end

  # 別のユーザのリクエストに変更する
  def move_to(user_id)
    user = User.find_by_id(user_id)
    return nil if user.blank?

    self.status = EasySettings.status.completed
    self.accept_id = self.class.create_accept_id
    self.expiration_date = nil
    self.mail_address = nil
    self.plan = EasySettings.plan[user.my_plan]
    self.ip = nil
    self.token = nil
    self.user_id = user_id
    self.save!
  end

  def public?
    self.plan == EasySettings.plan[:public]
  end

  def to_log
    "#{self.class.to_s}:: id:#{id} title:#{title} status:#{status_mean} accept_id:#{accept_id} type:#{type} test:#{test} ip:#{ip} token:#{token} user:#{user_id}"
  end

  private

  def single_header(header_name, num)
    tmp = num == 0 ? '(個別ページ)' : "(個別ページ#{num})"
    header_name + tmp
  end

  def initialize_category_max_counts
    category_max_counts = { Crawler::Items.contact_information => 0,
                            Crawler::Items.others              => 0,
                            Crawler::Items.another_company     => 0 }

    if self.free_search
      get_target_words.each { |w| category_max_counts.store(w, 0) }
    end
    category_max_counts
  end

  def update_category_max_counts(category_max_counts:, requested_url:)
    requested_url.company_data.get_category_counts.each do |key, cnt|
      category_max_counts[key] = cnt if category_max_counts[key] < cnt
    end

    requested_url.company_data.optional_info.each do |word, result|
      category_max_counts[word] = result.size if category_max_counts[word] < result.size
    end

    category_max_counts
  end

  class << self

    def catch_unfinished_requests(limit, user_ids = nil)
      query = self.main.unfinished
      query = query.where(user_id: user_ids) if user_ids.present? && user_ids.class == Array
      ids = query.limit(limit).ids
      self.where(id: ids).update(status: EasySettings.status.working)
      self.where(id: ids)
    end

    def same_token?(user_id, file_name, token)
      same_token_req = self.find_token(token)
      return false if same_token_req.size == 0
      same_token_req.each do |req|
        return true if req.user_id == user_id && req.file_name == file_name
      end
      false
    end

    # 受付IDの生成
    def create_accept_id
      accept_id = SecureRandom.create_accept_id
      while have_same_accept_id?(accept_id)
        accept_id = SecureRandom.create_accept_id
      end
      accept_id
    end

    def have_same_accept_id?(accept_id)
      self.find_by_accept_id(accept_id).present?
    end

    # エラーのシステム停止、再起動からのやり直しに使用する
    #   workingのリクエストの中にwoking, retryのリクエストURLが含まれていると一生終わらないので、ステータスを戻す
    def restart_from_system_stop
      self.working.each do |req|
        req.requested_urls.unfinished.each do |req_url|
          next if req_url.status == EasySettings.status.new && req_url.finish_status == EasySettings.finish_status.new
          req_url.update!(status: EasySettings.status.new, finish_status: EasySettings.finish_status.new)
        end
      end
    end
  end
end

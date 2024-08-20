class DataCombiner
  attr_reader :headers, :multi_headers, :single_headers, :count, :bunch_id

  def initialize(request:)
    @request = request
    @headers = {}
    @multi_headers = []
    @single_headers = {}
  end

  def combine_results(corporate_list_url)
    seeker = Crawler::Seeker.new

    results = Json2.parse(corporate_list_url.corporate_list_result, symbolize: false)
    return nil if results.blank?

    single_url_ids = Json2.parse(corporate_list_url.single_url_ids)
    single_result  = arrange_single_result_by_multi_content_url(single_url_ids: single_url_ids, multi_result: results)

    seeker.combine_results(multi_result: results['result'], multi_table_result: results['table_result'], single_result: single_result)

    seeker
  end

  # ルール
  #   マルチヘッダーは登場順番を壊さないように並べる
  #   シングルヘッダーは登場回数順に並び替える
  #   マルチとシングルの区別がないヘッダーは登場回数順に並び替える
  def count_headers(headers)
    if @headers.blank?
      @headers = if exist_single_headers?(headers)
        @multi_headers, s_headers = divide_headers(headers)

        @single_headers = s_headers.map { |h| [h, 1] }.to_h

        @multi_headers.map { |h| [h, 1] }.to_h.merge(@single_headers)
      else
        headers.map { |h| [h, 1] }.to_h
      end
      return @headers
    end

    if @single_flg || exist_single_headers?(headers)
      m_headers, s_headers = divide_headers(headers)

      @multi_headers = @multi_headers.sorting_add(m_headers)
      @single_headers = add_and_sort_headers(@single_headers, s_headers)

      @headers = @multi_headers.map { |h| [h, 1] }.to_h.merge(@single_headers)
    else
      @headers = add_and_sort_headers(@headers, headers)
    end

    @headers
  end

  def combine_results_and_save_tmp_company_info_urls(result_file_id = nil)
    start = Time.zone.now

    # bunch_idはresult_file_idがあるので、消せるかも。パブリックユーザが無くなったら消せそう。
    @bunch_id = ( @request.tmp_company_info_urls.maximum(:bunch_id) || 0 ) + 1

    cnt = 0
    limit = EasySettings.excel_row_limit[@request.plan_name]
    inserter = BulkInserter.new(TmpCompanyInfoUrl)
    seeker = Crawler::Seeker.new
    MyLog.new('my_crontab').log "[#{Time.zone.now}][HEADER] START #{Memory.free_and_available} "
    @request.reload.corporate_list_urls.success.main.each do |list_url|
      seeker.reset

      begin
        results = Json2.parse(list_url.corporate_list_result, symbolize: false)
        next if results.blank?

        single_url_ids = Json2.parse(list_url.single_url_ids)
        single_result  = arrange_single_result_by_multi_content_url(single_url_ids: single_url_ids, multi_result: results)


        seeker.combine_results(multi_result: results['result'], multi_table_result: results['table_result'], single_result: single_result)

        count_headers(seeker.headers) if seeker.headers.present?
      rescue => e
        Lograge.job_logging('SYSTEM', 'error', 'DataCombiner', 'combine_results_and_save_tmp_company_info_urls', { issue: "failed each", request: @request.to_log, list_url: list_url.to_log, err_msg: e.message, backtrace: e.backtrace })
        next
      end

      seeker.combined_result.each_with_index do |(key, contents), idx|
        inserter.add( { url: '',
                        bunch_id: @bunch_id,
                        organization_name: contents[Analyzer::BasicAnalyzer::ATTR_ORG_NAME],
                        corporate_list_result: contents.to_json,
                        request_id: @request.id,
                        result_file_id: result_file_id } )
        cnt += 1
        break if limit <= cnt
      end

      ActiveRecord::Base.connection.close
      break if limit <= cnt
    end

    MyLog.new('my_crontab').log "[#{Time.zone.now}][HEADER] END count = #{@headers.size} #{Memory.free_and_available} "

    begin
      inserter.execute!
    rescue => e
      Lograge.job_logging('SYSTEM', 'error', 'DataCombiner', 'combine_results_and_save_tmp_company_info_urls', { issue: "recoed save error", request: @request.to_log, bunch_id: @bunch_id, err_msg: e.message, backtrace: e.backtrace })
      raise e.class, e.message
    end

    Lograge.job_logging('SYSTEM', 'info', 'DataCombiner', 'combine_results_and_save_tmp_company_info_urls', { issue: "経過時間: #{Time.zone.now - start} 秒", request: @request.to_log, bunch_id: @bunch_id })
  rescue => e
    Lograge.job_logging('SYSTEM', 'error', 'DataCombiner', 'combine_results_and_save_tmp_company_info_urls', { issue: "failed", request: @request.to_log, err_msg: e.message, backtrace: e.backtrace })
    raise e.class, e.message
  end


  # シングルの収集方法
  # マルチのcontent_urlsに記載のあるURLのみを集めてくる方式
  # ３種類
  def arrange_single_result_by_multi_content_url(single_url_ids: nil, multi_result:)

    @ar_single_urls = single_url_ids.present? ? @request.corporate_single_urls.where(id: single_url_ids).success.left_joins(:result).where('results.corporate_list IS NOT NULL') : nil
    @ar_full_single_urls = @request.corporate_single_urls.success.left_joins(:result).where('results.corporate_list IS NOT NULL')

    @hash_single_urls = if single_url_ids.present? && single_url_ids.size <= 1_000
      @request.corporate_single_urls.eager_load(:result).where(id: single_url_ids).success.where('results.corporate_list IS NOT NULL')&.pluck(:url, 'results.corporate_list')&.to_h || {}
    else
      {}
    end

    single_result = {}
    extract_single_result(multi_result: multi_result['result'],       single_result: single_result)
    extract_single_result(multi_result: multi_result['table_result'], single_result: single_result)

    single_result
  end

  def extract_single_result(multi_result:, single_result:)
    multi_result.each do |key, result|
      result[Analyzer::BasicAnalyzer::ATTR_CONTENT_URL].each do |url|
        s_result = extract_value_from_key_urls(key_urls: Url.make_urls_comb(url))
        next if s_result.blank?

        s_result = Json2.parse(s_result, symbolize: false)

        single_result.merge!(s_result)
      rescue => e
        Lograge.job_logging('SYSTEM', 'error', 'DataCombiner', 'extract_single_result', { issue: "failed", err_msg: e.message, backtrace: e.backtrace })
      end
    end
  end

  def extract_value_from_key_urls(key_urls:)
    res = nil
    if @hash_single_urls.present?
      @hash_single_urls.each do |url, v|
        (res = v; break) if key_urls.include?(url)
      end
    elsif @ar_single_urls.present?
      res = @ar_single_urls.where(url: key_urls).first
      res = res.present? ? res.corporate_list_result : nil
    end

    return res if res.present?

    res = @ar_full_single_urls.where(url: key_urls).first
    res.present? ? res.corporate_list_result : nil
  end

  private

  def divide_headers(headers)
    m_h = []
    s_h = []
    headers.each do |h|
      h.include?(Crawler::Seeker::SINGLE_PAGE) ? s_h << h : m_h << h
    end
    [m_h, s_h]
  end

  # 個別ページがあるか確認
  def exist_single_headers?(headers)
    headers.each { |h| ( @single_flg = true; break ) if h.include?(Crawler::Seeker::SINGLE_PAGE) }

    unless @single_flg
      @headers.keys.each { |h| ( @single_flg = true; break ) if h.include?(Crawler::Seeker::SINGLE_PAGE) }
    end
    @single_flg
  end

  def add_and_sort_headers(base_headers, add_headers)
    add_headers.each do |hd|
      base_headers[hd] = base_headers.has_key?(hd) ? base_headers[hd] + 1 : 1
    end

    # 「安定なソート」を実施。その他は、そのままの順にしておく。
    i = 0
    base_headers = base_headers.sort_by { |_, v| [-v, i += 1] }.to_h

    if base_headers.size > 3000
      base_headers.keys[3000..-1]&.each { |hd| base_headers.delete(hd) }
    end
    GC.start
    base_headers
  end
end

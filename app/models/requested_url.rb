class RequestedUrl < ApplicationRecord
  # 注意
  # typeがcompany_infoでもurlがないレコードは、企業個別サイトに取得（スクレイピング）しに行かない
  #   企業一覧サイトから企業データをスクレイピングしても、URLの記載がなかったケース

  include ExcelMaking
  include BaseRequest

  after_create :create_result!

  belongs_to :request
  has_one :result, dependent: :destroy

  enum arrange_status: [ :no_required, :accepted, :waiting, :working, :completed, :error ], _prefix: true

  validates :url, uniqueness: { scope: [:type, :request_id, :test] }, if: -> { type == 'SearchRequest::CorporateList' || type == 'SearchRequest::CorporateSingle' }

  scope :company_info_urls, -> { where(type: 'SearchRequest::CompanyInfo') }
  scope :corporate_list_urls, -> { where(type: 'SearchRequest::CorporateList') }
  scope :corporate_single_urls, -> { where(type: 'SearchRequest::CorporateSingle') }
  scope :main, -> { where(test: false) }
  scope :test_mode, -> { where(test: true) }

  def company_info?
    self.type == SearchRequest::CompanyInfo::TYPE
  end

  def update_waiting
    self.update!(status: EasySettings.status.waiting)
  rescue ActiveRecord::RecordInvalid => e
    if e.message == 'バリデーションに失敗しました: Urlはすでに存在します'

      req_urls = RequestedUrl.where(url: self.url, test: self.test, type: self.type, request_id: self.request_id)

      str = req_urls.map { |ru| ru.to_log }.join("\n")
      NoticeMailer.notice_simple("ID: #{self.id} #{self.request.id} #{self.url}\n\n重複リクエスト=>\n#{str}\n\n\n#{e.class}\n#{e.message}\n#{e.backtrace}", 'update_waiting バリデーションエラー', 'バリデーションエラー').deliver_now

      id = req_urls[0].id

      req_urls.each do |req_url|
        next if id == req_url.id
        req_url.destroy
      end

      RequestedUrl.find(id).update(status: EasySettings.status.new)
    else
      raise e.class, e.message
    end

    false
  end

  def find_result_or_create(**attribututs)
    if result.present?
      result.update!(attribututs)
    else
      create_result!(attribututs)
    end
    result
  end

  def free_search_result
    result.present? ? result.free_search : nil
  end

  def candidate_crawl_urls
    result.present? ? result.candidate_crawl_urls : nil
  end

  def single_url_ids
    result.present? ? result.single_url_ids : nil
  end

  def corporate_list_result
    result.present? ? result.corporate_list : nil
  end

  def get_access_record(domain: nil)
    domain = ( self.domain.nil? ? Url.get_domain(url) : self.domain ) if domain.blank?
    AccessRecord.new(domain).get
  end

  def fetch_access_record(force_fetch: false, domain: nil)
    access_record = get_access_record(domain: domain)

    if access_record.exist? && access_record.have_result?

      if ( self.request.use_storage && use_storage_data?(access_record, self.request.using_storage_days) ) ||
         ( access_record.last_fetch_date > Time.zone.now - 5.hours ) ||
         force_fetch

        access_record.count_up
        ActiveRecord::Base.transaction do
          domain = domain || access_record.domain
          complete_with_updating_acquisition_count(1, EasySettings.finish_status.using_storaged_date, domain) do |over|
            unless over
              self.find_result_or_create(main: access_record.result.to_json)

              # requestのヘッダー情報を更新する
              self.request.update_company_info_result_headers(self) if self.request.present?
            end
          end
        end
        return true
      end
    end
    false
  end

  ###   usage   ###
  # requ_url.complete_with_updating_acquisition_count(count, finish_status) do |over, total_count|
  #   if over
  #   else
  #   end
  # end
  #
  def complete_with_updating_acquisition_count(count, finish_status, domain = nil)
    req = self.request
    total_count = nil

    if req.public? ||
       ( req.corporate_list_site? && company_info? )

      yield false
      self.complete(finish_status, domain)
    else
      history = MonthlyHistory.find_around(req.user, req.created_at)
      history.with_lock do
        if EasySettings.monthly_acquisition_limit[req.plan_name] <= history.reload.acquisition_count
          finish_status = EasySettings.finish_status.monthly_limit
          over = true
        else
          over = false
        end

        total_count = history.acquisition_count + count unless over

        yield over, total_count

        unless over
          total_count = EasySettings.monthly_acquisition_limit[req.plan_name] if EasySettings.monthly_acquisition_limit[req.plan_name] < total_count
          history.update!(acquisition_count: total_count)
        end

        self.complete(finish_status, domain)
      end
    end
    total_count
  end

  def update_single_url_ids(new_url_ids)
    find_result_or_create.update_array_attribute('single_url_ids', new_url_ids)
  end

  def update_candidate_urls(new_candidate_urls)
    find_result_or_create.update_array_attribute('candidate_crawl_urls', new_candidate_urls)
  end

  def take_out_candidate_urls(count)
    find_result_or_create.take_out_candidate_urls(count)
  end

  def make_contents_for_output(common_headers:, list_site_headers:, category_max_counts:)
    lang = request.user.language

    begin
      request_url = common_headers[0]
      common_contents = {request_url => url}
    rescue => e
      Lograge.logging('error', { class: 'RequestedUrl', method: 'make_contents_for_output common_contents', issue: "#{e}", url: url, err_msg: e.message, backtrace: e.backtrace })
      common_contents = {}
    end

    list_site_contents = make_list_site_contents(lang, list_site_headers)

    # contents = contents.merge({source_title => req_url.source_page_title, source_url => req_url.source_page_url}) if self.corporate_list_site?

    company_site_contents = {}
    begin
      status = Crawler::Items.local(lang)[:status]
      company_site_contents[status] = EasySettings.finish_status_word[lang][finish_status_word]
      company_site_contents[Crawler::Items.local(lang)[:url]] = url.to_s
      company_site_contents[Crawler::Items.local(lang)[:domain]] = domain.to_s
      if success?
        begin
          data = company_data.arrange_for_excel(category_max_counts)
          company_site_contents.merge!(data)
        rescue => e
          Lograge.logging('error', { class: 'RequestedUrl', method: 'make_contents_for_output company_site_contents', issue: "#{e}", url: url, err_msg: e.message, backtrace: e.backtrace })
          company_site_contents[status] = EasySettings.finish_status_word[lang][:error]
        end
      end
    rescue => e
      Lograge.logging('error', { class: 'RequestedUrl', method: 'make_contents_for_output', issue: "#{e}", url: url, err_msg: e.message, backtrace: e.backtrace })
      company_site_contents = {}
      company_site_contents[status] = EasySettings.finish_status_word[lang][:error]
    end

    {common: common_contents, list_site: list_site_contents, company_site: company_site_contents}
  end

  def company_data
    if @company_data.blank?
      @company_data = CompanyData.new(url, Json2.parse(result.main), get_free_search_result)
    end
    @company_data
  end

  def get_free_search_result
    return {} if free_search_result.nil?
    JSON.parse(free_search_result)
  end

  def corporate_list?
    self.type == SearchRequest::CorporateList::TYPE || self.type == SearchRequest::CorporateSingle::TYPE
  end

  def to_log
    "#{self.class.to_s}:: id:#{id} url:#{url} domain:#{domain} test:#{test} organization_name:#{organization_name} type:#{type} status:#{status_mean} finish_status:#{finish_status_mean} retry_count:#{retry_count} request_id:#{request_id}"
  end

  def deleted_result?
    return true if result.blank?

    result.free_search == nil          &&
    result.candidate_crawl_urls == nil &&
    result.single_url_ids == nil       &&
    result.main == nil                 &&
    result.corporate_list == nil
  end

  def self.move_result
    10_000.times do |i|
      req_urls = self.where(id: [i*100+1..(i+1)*100])

      next if req_urls.blank?

      req_urls.each do |req_url|

        attr = { free_search: req_url.attributes['free_search_result'],
                 candidate_crawl_urls: req_url.attributes['candidate_crawl_urls'],
                 single_url_ids: req_url.attributes['single_url_ids'],
                 main: req_url.attributes['result'],
                 corporate_list: req_url.attributes['corporate_list_result'] }
        req_url.find_result_or_create(attr)
      end

      puts "#{i}終了　ID #{req_urls[-1].id}"
    end
  rescue => e
    puts e
    puts e.message
    puts e.backtrace
  end

  def self.delete_result
    10_000.times do |i|
      req_urls = self.where(id: [i*100+1..(i+1)*100])

      next if req_urls.blank?

      req_urls.each do |req_url|

        atr = req_url.attributes
        if req_url.result.free_search == atr['free_search_result'] &&
           req_url.result.candidate_crawl_urls == atr['candidate_crawl_urls'] &&
           req_url.result.single_url_ids == atr['single_url_ids'] &&
           req_url.result.main == atr['result'] &&
           req_url.result.corporate_list == atr['corporate_list_result']

          req_url.update_columns(free_search_result: nil, candidate_crawl_urls: nil, single_url_ids: nil,
                                 result: nil, corporate_list_result: nil)
        else
          puts "失敗ID #{req_url[-1].id}"
        end
      end

      puts "#{i}終了　ID #{req_urls[-1].id}"
    end
  rescue => e
    puts e
    puts e.message
    puts e.backtrace
  end

  private

  def use_storage_data?(access_record, request_date)
    if access_record.accessed?
      if request_date.nil? ||
        access_record.last_fetch_date >= (Time.zone.today - request_date.days).to_time
        return true
      end
    end
    false
  end
end

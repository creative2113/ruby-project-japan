module BaseRequest
  extend ActiveSupport::Concern

  SUCCESS = [EasySettings.finish_status.successful, EasySettings.finish_status.using_storaged_date].freeze

  included do

    scope :status_new, -> { where(status: EasySettings.status.new) }
    scope :waiting, -> { where(status: EasySettings.status.waiting) }
    scope :working, -> { where(status: EasySettings.status.working) }
    scope :retry, -> { where(status: EasySettings.status.retry) }
    scope :unfinished, -> { where(status: EasySettings.status.new..EasySettings.status.retry) }
    scope :finished, -> { where(status: EasySettings.status.completed..EasySettings.status.error) }
    scope :success, -> { where(finish_status: SUCCESS) }


    def complete(finish_status, domain = nil)
      self.finish_status = finish_status
      self.status        = EasySettings.status.completed
      self.domain        = domain unless domain.nil?
      self.save!
    end

    def discontinue
      self.finish_status = EasySettings.finish_status.discontinued
      self.status        = EasySettings.status.discontinued
      self.save!
    end

    def renew
      self.finish_status = EasySettings.finish_status.new
      self.status        = EasySettings.status.new
      self.save!
    end

    def rewaiting
      self.finish_status = EasySettings.finish_status.new
      self.status        = EasySettings.status.waiting
      self.save!
    end

    def count_up_retry
      self.retry_count += 1
      self.save!
    end

    def access_record
      domain = self.domain.nil? ? Url.get_domain(url) : self.domain
      AccessRecord.new(domain).get
    end

    def company_data
      if @company_data.blank?
        @company_data = CompanyData.new(url, Json2.parse(result), get_free_search_result)
      end
      @company_data
    end

    def status_mean
      EasySettings.status.invert[self.status]
    end

    def finish_status_mean
      EasySettings.finish_status.invert[self.finish_status]
    end

    def get_free_search_result
      return {} if free_search_result.nil?
      JSON.parse(free_search_result)
    end

    def success?
      if SUCCESS.include?(finish_status)
        true
      else
        false
      end
    end

    def finished?
      self.status >= EasySettings.status.completed && self.status != EasySettings.status.arranging
    end

    def finish_status_word
      if finish_status == EasySettings.finish_status.new
        :incomplete
      elsif success?
        :successful
      elsif finish_status == EasySettings.finish_status.invalid_url
        :invalid_url
      elsif finish_status == EasySettings.finish_status.banned_domain
        :banned_domain
      elsif finish_status == EasySettings.finish_status.can_not_get_info       ||
            finish_status == EasySettings.finish_status.access_sealed_page     ||
            finish_status == EasySettings.finish_status.unsafe_and_sealed_page ||
            finish_status == EasySettings.finish_status.unsafe_and_sealed_page
        :can_not_get
      elsif finish_status == EasySettings.finish_status.discontinued
        :discontinued
      elsif finish_status == EasySettings.finish_status.monthly_limit
        :monthly_limit
      else
        :error
      end
    end
  end
end

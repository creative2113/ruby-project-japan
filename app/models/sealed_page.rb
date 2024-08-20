class SealedPage < DynamoDb

  TABLE          = EasySettings.dynamodb_table_prefix + 'SealedPage' + ENV['TEST_ENV_NUMBER'].to_s
  ITEMS          = %w(count last_access_date address_possibility_urls tel_possibility_urls other_info_possibility_urls domain_type reason
                      definitely_safe)
  CHANGE_STR_COL = %w()
  RESERVED_WORDS = { 'count' => '#C' }
  PRIMARY_KEY    = :domain

  attr_reader :domain, :count, :last_access_date, :address_possibility_urls, :tel_possibility_urls,
              :other_info_possibility_urls, :domain_type, :reason, :definitely_safe

  def initialize(domain, new_items = {})
    super

    raise 'Invalid domain.' unless domain?(domain)

    @domain = domain

    set_key_value(@domain)
    register_count
  end

  def add_new_item(new_items)
    super

    register_count
  end

  def get
    super

    if @exist
      @count                       = @items['count'].to_i
      @last_access_date            = @items['last_access_date'].to_date unless @items['last_access_date'].nil?
      @address_possibility_urls    = @items['address_possibility_urls'].nil?    ? [] : @items['address_possibility_urls']
      @tel_possibility_urls        = @items['tel_possibility_urls'].nil?        ? [] : @items['tel_possibility_urls']
      @other_info_possibility_urls = @items['other_info_possibility_urls'].nil? ? [] : @items['other_info_possibility_urls']
      @domain_type                 = @items['domain_type'].to_s
      @reason                      = @items['reason'].to_s
      @definitely_safe             = @items['definitely_safe']
    end

    self
  end

  def accessed?
    get if @exist.nil?
    @count > 0
  end

  def sealed_because_can_not_get?
    get if @exist.nil?
    return false unless @exist
    return true if @reason == EasySettings.sealed_reason['can_not_get'] &&
                   @count > EasySettings.access_limit_to_sealed_page
    false
  end

  def sealed_because_of_unsafe?
    get if @exist.nil?
    return false unless @exist
    return true if @reason == EasySettings.sealed_reason['unsafe']

    false
  end

  def safe?
    get if @exist.nil?
    return true unless @exist
    if @reason == EasySettings.sealed_reason['unsafe'] && @count > 4
      return false if @last_access_date > Time.zone.today - 1.year
    end
    true
  end

  def count_up
    get if @exist.nil?
    return false unless @exist

    update([:count, :last_access_date], {count: @count + 1, last_access_date: Time.zone.today})
  end

  def register
    get if @exist.nil?

    if @exist
      count_up
    else
      create({ count: 1,
               last_access_date: Time.zone.today,
               domain_type: EasySettings.domain_type['final'],
               reason: EasySettings.sealed_reason['can_not_get'] })
    end
  end

  private

  def domain?(domain)
    return false unless domain.class == String
    return false if domain.include?('/')
    true
  end

  def register_count
    if !@new_items[:count].nil? && @new_items[:count].class == Integer
      @count = @new_items[:count]
    end
  end

  class << self

    def check_safety(url)
      # Safety Check
      # pass only 'Safe' or 'Unknown', not pass in case 'Unsafe'
      domain = Url.get_domain(url)
      sealed_page = self.new(domain).get

      return :safe if sealed_page.definitely_safe

      unless sealed_page.safe?
        return :unsafe_from_saved_sealed_page
      end

      # Safety Check
      unsafe = false
      checker = Crawler::UrlSafeChecker.new(url)
      case checker.get_rating
      when :unsafe
        unsafe = true
      when :unknown
        # trendmicro_checker = Crawler::UrlSafeChecker.new(url, :trendmicro)
        # unsafe = true if trendmicro_checker.get_rating == :unsafe
      when :failure
        # trendmicro_checker = Crawler::UrlSafeChecker.new(url, :trendmicro)
        # unsafe = true if trendmicro_checker.get_rating == :unsafe
      end

      if unsafe

        sealed_page.create({count: sealed_page.exist? ? sealed_page.count + 1 : 1,
                            last_access_date: Time.zone.today,
                            domain_type: EasySettings.domain_type['entrance'],
                            reason: checker.possible_sealed_reason})

        return :unsafe_from_url_web_checker
      else
        self.delete_items([domain]) if sealed_page.exist? && sealed_page.reason == EasySettings.sealed_reason['unsafe']
      end

      :probably_safe
    end

    def add_safe_flag(domain)
      sp = self.new(domain).get
      res = sp.create({definitely_safe: true})

      if res
        puts "Flag definitely_safe to #{domain}"
      else
        puts "Failed!! Miss to flag definitely_safe to #{domain}"
      end
    end

    private

    def get_params(symbol = :normal)
      case symbol
      when :normal
        {
          domain: 'example.com',
          count: 1,
          last_access_date: Time.zone.today - 3.day
        }
      when :unsafe
        {
          reason: EasySettings.sealed_reason['unsafe'],
          domain_type: EasySettings.domain_type['entrance']
        }
      when :unknown
        {
          reason: EasySettings.sealed_reason['unknown'],
          domain_type: EasySettings.domain_type['entrance']
        }
      when :can_not_get
        {
          reason: EasySettings.sealed_reason['can_not_get'],
          domain_type: EasySettings.domain_type['final']
        }
      else
        raise 'No Test Data Sample.'
      end
    end
  end

end
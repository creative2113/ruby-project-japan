require Rails.root.join('spec', 'corporate_results.rb')

class AccessRecord < DynamoDb
  TABLE          = EasySettings.dynamodb_table_prefix + 'AccessRecord' + ENV['TEST_ENV_NUMBER'].to_s
  ITEMS          = %w(count last_access_date name title result last_fetch_date urls accessed_urls supporting_urls category)
  CHANGE_STR_COL = %w(result)
  RESERVED_WORDS = {'name' => '#N', 'count' => '#C', 'result' => '#R'}
  PRIMARY_KEY    = :domain

  attr_reader :domain, :count, :last_access_date, :name, :last_fetch_date, :urls, :accessed_urls, 
              :supporting_urls, :result, :items, :title, :category

  def initialize(domain, new_items = {})
    super

    raise 'Invalid domain.' unless domain?(domain)

    @domain          = domain
    @supporting_urls = []

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
      @count            = @items['count'].to_i
      @name             = @items['name']                     unless @items['name'].nil?
      @title            = @items['title']                    unless @items['title'].nil?
      @last_access_date = @items['last_access_date'].to_time unless @items['last_access_date'].nil?
      @last_fetch_date  = @items['last_fetch_date'].to_time  unless @items['last_fetch_date'].nil?
      @urls             = @items['urls'].nil?            ? [] : @items['urls']
      @accessed_urls    = @items['accessed_urls'].nil?   ? [] : @items['accessed_urls']
      @supporting_urls  = @items['supporting_urls'].nil? ? [] : @items['supporting_urls']
      @result           = normalize_result(@items['result']) unless @items['result'].nil?
      @category         = @items['category']                 unless @items['category'].nil?
    end

    self
  end

  def accessed?
    get if @exist.nil?
    @count > 0
  end

  def have_result?
    get if @exist.nil?

    @result.present? && @last_fetch_date.present?
  end

  def count_up
    get if @exist.nil?
    return false unless @exist

    update([:count, :last_access_date], {count: @count + 1, last_access_date: Time.zone.now})
  end

  def company_data(optional_info = {})
    get if @exist.nil?
    cd = CompanyData.new('http://' + @domain, @result, optional_info)
    @localize_words = cd.localize_words
    cd
  end

  def arrange_data
    company_data.arrange
  end

  def arrange_data_for_excel(max_counts, optional_info)
    company_data(optional_info).arrange_for_excel(max_counts)
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

  def normalize_result(result)
    res = change_simbolized_key(result)

    res.map do |h|
      h[:priority] = h[:priority].to_i if h[:priority].present?
      h
    end
  end

  def change_simbolized_key(result)
    # 整理して、どちらかにしたい。
    if result.class == String
      Json2.parse(@items['result'])
    else
      result = result.class == Hash ? [result] : result

      result.map { |hash| hash.symbolize_keys }
    end
  end

  class << self

    def add_supporting_urls(domain, urls)
      ar = self.new(domain).get
      urls = ar.supporting_urls + urls
      res = ar.create({supporting_urls: urls.uniq})

      if res
        puts "Add supporting urls: #{urls} to #{domain}"
      else
        puts "Failed!! Add supporting urls: #{urls} to #{domain}"
      end
    end

    private

    def get_params(symbol = :normal)
      case symbol
      when :normal
        {
          domain: 'example.com',
          count: 1,
          last_access_date: Time.zone.now,
          last_fetch_date: Time.zone.now
        }
      when :yesterday
        {
          last_access_date: Time.zone.now - 1.day
        }
      when :starbacks
        {
          domain: 'www.starbucks.co.jp',
          name: 'スターバックス コーヒー ジャパン 株式会社',
          result: AC_RES_STARBUCKS
        }
      when :nexway
        {
          domain: 'www.nexway.co.jp',
          name: '株式会社ネクスウェイ',
          result: AC_RES_NEXWAY
        }
      when :hokkaido_coca_cola
        {
          domain: 'www.hokkaido.ccbc.co.jp',
          name: '北海道コカ・コーラボトリング株式会社 HOKKAIDO COCA-COLA BOTTLING CO.,Ltd.',
          result: RES_HOKKAIDO_COCA_COLA
        }
      else
        raise 'No Test Data Sample.'
      end
    end
  end
end

class SearchRequest::CorporateList < RequestedUrl

  TYPE = 'SearchRequest::CorporateList'.freeze

  def select_test_data
    cl_result = Json2.parse(corporate_list_result, symbolize: false)
    return nil if cl_result.blank?

    total_size = cl_result.size

    page_list = cl_result.map { |k, value| value[Analyzer::BasicAnalyzer::ATTR_PAGE] }.uniq

    page_url_map = page_list.map {|page| [page, []]}.to_h

    single_result_map = {}
    single_url_map = {}

    cl_result.each do |k, v|
      page_url_map[v[Analyzer::BasicAnalyzer::ATTR_PAGE]] << k
      single_result_map.store(k, v) if v.keys.to_s.include?(Crawler::Seeker::SINGLE_PAGE)
    end


    res2 = []
    if single_result_map.present?
      res = {}
      single_result_map.each do |k, v|
        if res.has_key?(v[Analyzer::BasicAnalyzer::ATTR_PAGE])
          res[v[Analyzer::BasicAnalyzer::ATTR_PAGE]] << {k => v}
        else
          res[v[Analyzer::BasicAnalyzer::ATTR_PAGE]] = [{k => v}]
        end
      end

      res3 = []
      res.each do |k, vs|
        if vs.size <= 3
          res2.concat(vs)
        else
          res2.concat(vs[0..2])
          res3.concat(vs[3..-1])
        end
      end

      res2.concat(res3)
      res2 = res2[0..12]
      res2.sort { |a, b| extract_url_from_corp_keys(a.keys[0]) <=> extract_url_from_corp_keys(b.keys[0]) }

      res2 = res2.map { |a| [a.keys[0], a.values[0]] }.to_h

      return res2 if res2.size > 9
    end

    key_res = []
    total_size.times do |round|
      page_url_map.each do |page, keys|
        key_res << keys[round] if keys[round].present?
      end
      break if key_res.size >= 12 || key_res.size >= total_size
    end

    key_res = key_res.sort{ |a, b| extract_url_from_corp_keys(a) <=> extract_url_from_corp_keys(b) }

    res = key_res.map { |key| [key, cl_result[key]] }.to_h

    res2.present? ? res2.merge(res) : res
  end

  def separation_info
    cl_result = Json2.parse(corporate_list_result, symbolize: false)
    return {} if cl_result.blank?
    sep = {}
    cl_result.each do |_, val|
      val.each do |key, v|
        next unless key.start_with?('仕切り情報')
        sep.has_key?(key) ? sep[key] << v : sep[key] = [v]
      end
    end
    sep.map { |key, val| [key, val.uniq] }.to_h
  end

  def select_results(org_name)
    res = Json2.parse(corporate_list_result, symbolize: false)
    return nil if res.blank?

    res['result'].select { |k, v| k.include?(org_name) }
  end

  def select_singles(org_name)
    res = select_results(org_name)
    return nil if res.blank?

    urls = res.map { |k, v| v["$$content_urls$$"] }.flatten.uniq
    request.corporate_single_urls.where(url: urls)
  end

  private

  # "株式会社ABC https://sample.com/portal/abc"
  # "株式会社EFG https://sample.com/portal/efg"
  # " https://sample.com/portal/abc" たまに会社名が取れないものがある
  def extract_url_from_corp_keys(key)
     key.split(' ').size == 2 ? key.split(' ')[1] : key.split(' ')[0]
  end

  class << self
    def create_with_first_status(url:, request_id:, test: false)
      self.create!(url:           url,
                   status:        EasySettings.status.new,
                   finish_status: EasySettings.finish_status.new,
                   request_id:    request_id,
                   test:          test)
    rescue ActiveRecord::RecordInvalid => e
      if e.message == 'バリデーションに失敗しました: Urlはすでに存在します'
        return self.find_by(url: url, request_id: request_id, test: test)
      end
      raise e.class, e.message
    end
  end
end

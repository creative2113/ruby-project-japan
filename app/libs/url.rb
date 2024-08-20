class Url

  attr_reader :raw_url, :url, :domain, :domain_url, :port, :domain_port, :domain_port_url, :path, :escaped_url, :unescaped_url

  ANYTHING_DIR   = '$$$DIR$$$'
  ONLY_NUMBER    = '$$$NUM$$$'
  ANYTHING_VALUE = '$$$VALUE$$$'


  def initialize(url)
    @raw_url = url
    @url = self.class.escape(url)
    uri = URI.parse(@url)
    @domain     = uri.host
    @domain_url = "#{uri.scheme}://#{@domain}"
    @port       = ( uri.port == 80 || uri.port == 443 ) ? nil : uri.port
    @domain_port     = @port.blank? ? @domain : "#{@domain}:#{@port}"
    @domain_port_url = @port.blank? ? @domain_url : "#{@domain_url}:#{@port}"
    @path = uri.path

    @escaped_url = @url

    # ブラウザ検索のURLには基本的にescapeしたものを使う
    # unescapeしたものを、再度escapeしても、元に戻るかは保証がない
    # escapeしたものを何度escapeしても、同じ結果になると思っている。（おそらく）
    @unescaped_url = self.class.unescape(@url)
  end

  # ややこしいURL
  # "https://tenshoku.mynavi.jp/shutoken/list/p11+p12+p13+p14/o147+o14710+o14713+o14717+o14725/?ags=0"

  def add_path(path)
    new_uri = URI.parse(self.class.escape(path))

    uri = URI.parse(@url)
    uri.fragment = nil
    uri.query = new_uri.query if new_uri.query&.present?

    curr_path = uri.path
    if curr_path[-1] == '/'
      uri.path = "#{uri.path}/#{new_uri.path}".gsub('//','/')
    else
      curr_path = curr_path.split('/')
      curr_path.delete_at(-1)
      uri.path = "#{curr_path.join('/')}/#{new_uri.path}".gsub('//','/')
    end

    self.class.unescape(uri.to_s)
  end

  def replace_path(path)
    new_uri = URI.parse(self.class.escape(path))

    uri = URI.parse(@url)
    uri.fragment = nil
    uri.path = "/#{new_uri.path}".gsub('//','/')
    uri.query = new_uri.query if new_uri.query&.present?

    self.class.unescape(uri.to_s)
  end

  def upper_path
    uri = URI.parse(@url)

    path = uri.path

    path = path.chop if path[-1] == '/'
    path = path.split('/')
    path.delete_at(-1)
    path = path.join('/')

    uri.path = path
    uri.fragment = nil
    uri.query = nil
    uri.scheme = nil
    uri.to_s
  end

  class << self
    def exists?(url)
      org = Url.escape(url)
      url = URI.parse(org)
      res = get_response(url)

      # 301 Moved Parmanently, 302 Moved Temporarily
      if %w(301 302).include?(res.code)
        return true if org == Url.escape(res['location'])
        return self.exists?(to_url(url, res['location']))
      end

      res.code == '200'
    rescue => e
      Lograge.logging('fatal', { class: self.to_s, method: 'exists?', issue: e, url: url, err_msg: e.message, backtrace: e.backtrace })
      return false
    end

    def confirm_and_get_link_url(url)
      org = Url.escape(url)
      url = URI.parse(org)
      res = get_response(url)

      # 301 Moved Parmanently, 302 Moved Temporarily
      if %w(301 302).include?(res.code)
        return org if org == Url.escape(res['location'])
        return confirm_and_get_link_url(to_url(url, res['location']))
      end

      res.code == '200' ? org : nil
    rescue => e
      Lograge.logging('fatal', { class: self.to_s, method: 'exists?', issue: e, url: url, err_msg: e.message, backtrace: e.backtrace })
      nil
    end

    def ban_domain?(url: nil, domain: nil)
      raise ArgumentError, 'Need url or domain' if url.nil? && domain.nil?

      if url.present?
        org = Url.escape(url)
        domain = URI.parse(org).host
      end

      tld = domain.split('.')[-1]
      EasySettings.ban_top_level_domain.include?(tld)
    end

    def check_http_or_https(url)
      final_scheme = url.start_with?('http://') ? 'https' : 'http'
      tmp_url = Url.get_final_url(url)
      return tmp_url.to_s if tmp_url.class == URI

      "#{final_scheme}://#{Url.get_domain(url)}"
    end

    def add_query(url, query, value)
      tmp_url = escape(url)
      unescape_flg = tmp_url != url
      uri = URI.parse(tmp_url)

      if uri.query.blank?
        uri.query = "#{query}=#{value}"
      else
        uri.query = "#{uri.query}&#{query}=#{value}"
      end

      unescape_flg ? unescape(uri.to_s) : uri.to_s
    end

    def get_final_url(url, re_locations = {})
      if url.class == String
        org = Url.escape(url)
        url = URI.parse(org)
      else
        org = url.to_s
      end
      res = get_response(url)
      if [:time_out, :ssl_error].include?(res)
        return URI.parse(get_final_url_with_selenium(url.to_s))
      end

      if res.code == '503' # 503 Service Unavailable
        10.times do |i|
          sleep 1 * i
          res = get_response(url)
          if [:time_out, :ssl_error].include?(res)
            return URI.parse(get_final_url_with_selenium(url.to_s))
          end
          break if res.code != '503'
        end
        return '503' if res.code == '503'
      elsif res.code == '403' # 403 Forbidden
        return URI.parse(get_final_url_with_selenium(url.to_s))
      elsif res.code == '404' # 404 Not Found
        return '404'
      end

      # 301 Moved Parmanently, 302 Moved Temporarily
      if %w(301 302).include?(res.code)
        return url if org == Url.escape(res['location'])

        # リダイレクトループする時
        loc_url = to_url(url, res['location'])
        if re_locations.has_key?(loc_url)
          re_locations[loc_url] += 1
          return nil if re_locations[loc_url] >= 3
        else
          re_locations[loc_url] = 1
        end

        return self.get_final_url(loc_url, re_locations)
      end

      if res.code == '200'
        return url
      else
        return nil
      end
    rescue => e
      Lograge.logging('warn', { class: self.to_s, method: 'get_final_url', issue: e, url: url, err_msg: e.message, backtrace: e.backtrace })
      return nil
    end

    def get_final_domain(url)
      url = get_final_url(url)

      return nil if url.blank?
      return url if %w(503 403 404).include?(url)

      url.host
    rescue => e
      Lograge.logging('warn', { class: self.to_s, method: 'get_final_domain', issue: e, url: url, err_msg: e.message, backtrace: e.backtrace })
      return nil
    end

    def get_domain(url)
      URI.parse(self.escape(url)).host
    rescue => e
      nil
    end

    def same_domain?(url1, url2)
      if url1.class == String
        domain1 = get_domain(url1)
      else
        domain1 = url1.host
      end
      if url2.class == String
        domain2 = get_domain(url2)
      else
        domain2 = url2.host
      end

      domain1 == domain2
    end

    def same_final_domain?(url1, url2)
      return true if same_domain?(url1, url2)

      domain1 = get_final_domain(url1)
      domain2 = get_final_domain(url2)

      return false if domain1.blank? || domain2.blank?

      domain1 == domain2
    end

    # 語尾に/は付かない
    # ポートは付かない
    # (例) http(s)://example.com:80/aa/bb/cc ->　http(s)://example.com or http(s)://example.com
    def make_domain_url(url)
      uri = URI.parse(self.escape(url))
      "#{uri.scheme}://#{@domain}"
    end

    def correct_url_form?(url)
      uri = URI.parse(Url.escape(url))
      return false if uri.host.nil?
      return false if uri.scheme.nil?
      return false unless ['http', 'https'].include?(uri.scheme)

      true
    rescue => e
      false
    end

    def delete_dots(url)
      if url.include?('://')
        host = url.sub('://','#$%#$%#$%#$%').split('/')[0].sub('#$%#$%#$%#$%', '://')
        path = normalize_path(url.sub(host,''))
        host + path
      else
        normalize_path(url)
      end
    end

    def delete_id_fragment(url)
      unescape_flg = url != escape(url)
      uri = URI.parse(escape(url))
      uri.fragment = nil
      unescape_flg ? unescape(uri.to_s) : uri.to_s
    end

    def html_url?(url)
      uri = URI.parse(escape(url))

      path = uri.path

      return true if path[-1] == '/' || !path.split('/')[-1]&.include?('.')

      path[-5..-1] == '.html' || path[-6..-1].match?(/\.\whtml$/) || path[-4..-1] == '.php' || path[-5..-1] == '.aspx'
    end

    def make_comparing_path(url1, url2)
      url1 = URI.parse(url1)
      url2 = URI.parse(url2)

      return nil if ( url1.scheme.present? && !%w(http https).include?(url1.scheme) ) ||
                    ( url2.scheme.present? && !%w(http https).include?(url2.scheme) )

      return nil unless url1.host == url2.host

      host = url1.host

      divide1 = make_path_array(url1.path)
      divide2 = make_path_array(url2.path)

      return nil unless divide1.size == divide2.size

      comparing_path = divide1.map.with_index do |dir, i|
        if dir == divide2[i]
          dir
        else
          ANYTHING_DIR
        end
      end

      query1 = make_query_set(url1.query)
      query2 = make_query_set(url2.query)

      # クエリは共通のものだけを取り出す、
      comparing_query = query1.map do |q, v|
        if query2[q] == v
          [q, v]
        elsif query2[q].nil?
          nil
        elsif query2[q] != v && query2[q].match?(/^\d*$/) && v.match?(/^\d*$/)
          [q, ONLY_NUMBER]
        else
          [q, ANYTHING_VALUE]
        end
      end.compact.to_h
  
      [host, comparing_path, comparing_query].to_json
    end

    def match_with_comparing_path?(comparing_path, url)
      comparing_path = Json2.parse(comparing_path, symbolize: false) if comparing_path.class == String

      url = URI.parse(escape(url))

      return false if url.scheme.present? && !%w(http https).include?(url.scheme)

      return false unless comparing_path[0] == url.host

      divide = make_path_array(url.path)

      return false unless comparing_path[1].size == divide.size

      comparing_path[1].each_with_index do |dir, i|
        return false if dir != ANYTHING_DIR && dir != divide[i]
      end

      return true unless comparing_path[2].present?

      query = make_query_set(url.query)

      comparing_path[2].each do |q, v|
        return false if query[q].nil?

        if v == ONLY_NUMBER
          return false unless query[q].match?(/^\d*$/)
        elsif v == ANYTHING_VALUE
        else
          return false unless v == query[q]
        end
      end

      true
    end

    def escape(url)
      unless url.include?('://')
        return escape_path(url)
      end

      scheme = url.split('://')[0]
      query = url.split('?')[1]
      path  = url.split('://')[1].split('?')[0]

      path  = escape_path(path)
      query = encode_ja(query, query: true)
      query.present? ? "#{scheme}://#{path}?#{query}" : "#{scheme}://#{path}"
    end

    def escape_path(path_str)
      end_chr = path_str[-1] == '/' ? '/' : ''
      path_str.split('/').map { |str| /\A[-_.!~*'()a-zA-Z0-9;\/\?:@&=+$,%#]*\Z/ =~ str ? str : encode_ja(str) }.join('/') + end_chr
    end

    # 日本語のみ URL エンコード
    def encode_ja(str, query: false)
      return '' if str.blank?
      ret = ''
      str.split(//).each do |c|
        new_c = if /[-_.!~*'()a-zA-Z0-9;\/\?:@&=+$,%#]/ =~ c
          c
        elsif / / =~ c
          query ? CGI.escape(c) : '%20'
        else
          CGI.escape(c)
        end
        ret.concat(new_c)
      end
      ret
    end

    def unescape(url)
      CGI.unescape(url)
    end

    def include?(urls, url, match_final_domain: true)
      res = extract_matched_url(urls, url, match_final_domain: match_final_domain)
      res.present?
    end

    def extract_matched_url(urls, url, match_final_domain: true)
      return nil if urls.blank? || url.blank?

      url = URI.parse(escape(url))

      urls.each do |u, k|
        u = URI.parse(escape(u))
        if same_domain_and_path?(u, url, match_final_domain: match_final_domain)
          return k.present? ? { u => k } : u
        end
      end
      nil
    end

    def same_domain_and_path?(url1, url2, match_final_domain: true)
      return false if url1.blank? || url2.blank?

      url1 = URI.parse(escape(url1)) if url1.class == String
      url2 = URI.parse(escape(url2)) if url2.class == String

      return false if  match_final_domain && !same_final_domain?(url1, url2)
      return false if !match_final_domain && !same_domain?(url1, url2)

      if ( url1.port == 80 || url1.port == 443 ) && ( url2.port == 80 || url2.port == 443 )
        return true if same_path?(url1.path, url2.path) && url1.query == url2.query
      else
        return true if url1.port == url2.port && same_path?(url1.path, url2.path) && url1.query == url2.query
      end
      false
    end

    def uniq(urls)
      return urls if urls.blank?

      copy_urls = []

      urls.each do |url|
        next if url.blank?
        p_url = URI.parse(escape(url))
        same = false
        copy_urls.each do |u|
          u = URI.parse(escape(u))
          (same = true; break) if same_domain_and_path?(u, p_url)
        end
        copy_urls << url if same == false
      end
      copy_urls
    end

    def make_url_from_href(href:, curent_url:)
      tmp_url      = parse(href)
      unescape_flg = tmp_url.to_s != href
      curent_url   = URI.parse(escape(curent_url))

      return nil if tmp_url.scheme.present? && tmp_url.scheme != 'http' && tmp_url.scheme != 'https'

      tmp_url.scheme = curent_url.scheme if tmp_url.scheme.blank?

      if tmp_url.host.present?
        normalize_path(tmp_url.path)
        return ( unescape_flg ? unescape(URI.parse(tmp_url.to_s).to_s) : URI.parse(tmp_url.to_s).to_s )
      end

      tmp_url.host = curent_url.host
      tmp_url.port = curent_url.port

      if tmp_url.path[0] == '/'
        normalize_path(tmp_url.path)
        return ( unescape_flg ? unescape(URI.parse(tmp_url.to_s).to_s) : URI.parse(tmp_url.to_s).to_s )
      end

      if curent_url.path[-1] == '/'
        path = curent_url.path + tmp_url.path
      else
        path_arr = curent_url.path.split('/')
        path_arr.delete_at(-1)
        path = path_arr.join('/') + '/' + tmp_url.path
      end

      tmp_url.path = normalize_path(path)

      unescape_flg ? unescape(URI.parse(tmp_url.to_s).to_s) : URI.parse(tmp_url.to_s).to_s
    end

    def is_href_url?(href)
      return false if href.blank?

      url = parse(href)
      return false if url.to_s.blank?
      return false if url.scheme.present? && url.scheme != 'http' && url.scheme != 'https'

      true
    end

    def parse(url)
      URI.parse(escape(url))
    rescue URI::InvalidURIError => e
      raise e if Rails.env.development? || Rails.env.test?
      nil
    end

    def make_url_from_text(url:)
      tmp_url = URI.parse(escape(url))

      tmp_url.path = normalize_path(tmp_url.path)

      tmp_url.to_s
    end

     def make_urls_comb(url)
      res = []

      url = url.chop if url[-1] == '/'
      if url[0..7] == 'https://'
        res << url
        res << url + '/'
        res << url.gsub('https://', 'http://')
        res << url.gsub('https://', 'http://') + '/'
      else
        res << url
        res << url + '/'
        res << url.gsub('http://', 'https://')
        res << url.gsub('http://', 'https://') + '/'
      end
      res
    end

    def get_response_with_timeout(url, timeout_sec)
      start = Time.zone.now
      uri = URI.parse(url)
      response = nil
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true if uri.port == 443
      https.open_timeout = timeout_sec
      https.read_timeout = timeout_sec
      start = Time.zone.now
      https.start { response = https.get(uri.path) }
      response
    rescue Net::OpenTimeout => e
      puts Time.zone.now - start
      :time_out
    end

    def get_final_url_with_selenium(url)
      ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"

      options  = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      options.add_argument("--user-agent=#{ua}")
      options.add_argument('--blink-settings=imagesEnabled=false') # 画像を許可しない
      options.add_argument('--disable-sync')
      session = Selenium::WebDriver.for :chrome, options: options

      session.get(url)
      url = session.current_url.deep_dup
      session.close
      session.quit
      url
    rescue Net::ReadTimeout => e
      session.close
      session.quit
      nil
    end

    def make_query_set(query_str)
      return {} if query_str.blank?
      set = query_str.split('&').map do |q|
        if q.include?('=')
          [q.split('=')[0], ( q.split('=')[1] || '' )]
        else
          [q, nil]
        end
      end.sort.to_h
    end

    def not_exist_page?(url)
      res = get_response(URI.parse(escape('https://www.google.com/')))
      return false unless res.code == '200'

      tmp_url = URI.parse(escape(url.gsub('https://', 'http://')))
      get_response(tmp_url)
      false
    rescue SocketError => e
      return false unless ['Name or service not known', 'nodename nor servname provided, or not know'].select { |s| e.message.include?(s) }.present?

      tmp_url = URI.parse(escape(url.gsub('http://', 'https://')))
      begin
        get_response(tmp_url)
      rescue SocketError => e
        return true if ['Name or service not known', 'nodename nor servname provided, or not know'].select { |s| e.message.include?(s) }.present?
      rescue => e
        return false
      end
      false
    rescue => e
      false
    end

    private

    def same_path?(path1, path2)
      tmp1 = path1.dup
      tmp2 = path2.dup
      if path1 == ''
        tmp1 = '/index'
      elsif path1[-1] == '/'
        tmp1 = path1 + 'index'
      else
        if path1.split('/')[-1].include?('.')
          tmp1 = path1.cut_after('.', from_end: true)
        end
      end

      if path2 == ''
        tmp2 = '/index'
      elsif path2[-1] == '/'
        tmp2 = path2 + 'index'
      else
        if path2.split('/')[-1].include?('.')
          tmp2 = path2.cut_after('.', from_end: true)
        end
      end

      tmp1 == tmp2
    end

    def normalize_path(path)
      path = path.gsub('/./','/').gsub('/./','/').gsub('///','/').gsub('//','/').gsub('//','/')

      path = path[2..-1] if path[0..1] == './'
      path = path[3..-1] if path[0..2] == '../'

      return path unless path.include?('..')

      100_000.times do
        break if path == loop_cut_back_in_path(path)

        path = loop_cut_back_in_path(path)
      end

      path = '/' + path unless path[0] == '/'

      path
    end

    def loop_cut_back_in_path(path)
      surfix = path[-1] == '/' ? '/' : ''

      path_arr = path.split('/')

      idx = nil
      path_arr.each_with_index do |pt, i|
        next unless pt == '..'
        idx = i
        break
      end

      if idx.present?
        path_arr.delete_at(idx)
        path_arr.delete_at(idx-1) unless idx == 0
      end

      path_arr.join('/') + surfix
    end

    def get_response(url)
      Net::HTTP.get_response(url)

      # 使えなくなった
      # req = Net::HTTP.new(url.host, url.port)
      # req.use_ssl = true if url.scheme == 'https'
      # req.request_head(url.path.empty? ? '/' : url.path )
    rescue Net::ReadTimeout => e
      :time_out
    rescue OpenSSL::SSL::SSLError => e
      :ssl_error
    end

    def to_url(parsed_url, location)
      location_url = URI.parse(location) # escape不要

      location_url.scheme = parsed_url.scheme       if location_url.scheme.nil?
      location_url.host   = parsed_url.host         if location_url.host.nil?
      unless location_url.path.empty?
        location_url.path   = '/' + location_url.path if location_url.path[0] != '/'
      end

      location_url.to_s
    end

    def make_path_array(path)
      divide = path.split('/')
      return [''] if divide.blank?
      divide = divide.reject(&:empty?) if divide[0].empty?
      divide << '' if path[-1] == '/'
      divide
    end
  end
end

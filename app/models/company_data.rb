class CompanyData

  OPTIONAL_MARK_STR = 'additional_company_info'

  attr_reader :name, :clean_data, :domain, :title, :localize_words, :clean_data_with_option, :optional_info

  def initialize(url, data, optional_info = {}, country = Crawler::Country.japan[:english], language = Crawler::Country.languages[:japanese])
    @url           = url
    @domain        = Url.get_domain(url)
    @data          = data || []
    @country       = Crawler::Country.find(country).new
    @localize_words = Crawler::Items.local(language).merge(@country.localize_words)
    @title         = get_title
    @clean_data    = ''
    @attr_finder   = Crawler::AttributionFinder.new(country)

    if optional_info[OPTIONAL_MARK_STR].present?
      @additional_data_info = clean_result(optional_info[OPTIONAL_MARK_STR])
    end

    optional_info.delete(OPTIONAL_MARK_STR)
    @optional_info = optional_info


    # 既にクリーンされているか確認
    if @data[0][:category] == Crawler::Items.url    &&
       @data[1][:category] == Crawler::Items.domain &&
       @additional_data_info.nil?

      @clean_data = @data
    else
      @data.concat(@additional_data_info) if @additional_data_info.present?
      clean_result
      @clean_data = @data if @clean_data.empty?
    end

    @clean_data_with_option = add_optional_to_clean_data

    @name = extract_company_name
  end

  def localize_clean_data
    @clean_data_with_option.map do |hash|
      tmp_hash = {name: hash[:name], value: hash[:value], category: hash[:category]}
      tmp_hash[:name]     = @localize_words[hash[:name]] if Crawler::Items.local(:English).keys.include?(hash[:name])
      tmp_hash[:name]     = @localize_words[hash[:name]] if localizable_name_value?(hash)
      tmp_hash[:category] = @localize_words[hash[:category]].blank? ? hash[:category] : @localize_words[hash[:category]]
      tmp_hash
    end
  end

  # 同じカテゴリをハッシュでくくる
  # localize
  def arrange
    arrange_data = {@localize_words[Crawler::Items.url]          => @url,
                    @localize_words[Crawler::Items.domain]       => @domain,
                    @localize_words[Crawler::Items.company_name] => @name,
                    @localize_words[Crawler::Items.title]        => @title}

    @clean_data_with_option.each do |hash|
      category = @localize_words[hash[:category]]
      category = hash[:category] if category.blank?
      size     = size_of_same_category(hash[:category])

      hash[:name]  = '' if hash[:name].nil?
      hash[:value] = '' if hash[:value].nil?

      if size == 1
        if [Crawler::Items.contact_information].include?(hash[:category])
          arrange_data.store(category, {hash[:name] => hash[:value]})
        else
          arrange_data.store(category, hash[:value])
        end
      elsif size > 1
        next if hash[:category] == Crawler::Items.company_name
        arrange_data.store(category, {}) if arrange_data[category].nil?

        hash[:name] = @localize_words[hash[:name]] if localizable_name_value?(hash)

        if arrange_data[category].has_key?(hash[:name])
          arrange_data[category].store(hash[:name], arrange_data[category][hash[:name]].push(hash[:value]))
        else
          arrange_data[category].store(hash[:name], hash[:value])
        end
      end
    end

    arrange_data
  end

  def json
    JSON.pretty_generate(arrange)
  end

  def arrange_for_excel(max_counts)
    before_data = arrange
    after_data  = {}

    before_data.each do |key, value|

      if key.one_equal?([@localize_words[Crawler::Items.others]])

        cnt = max_counts[@localize_words.invert[key]]

        after_data.merge!(make_block_for_excel(value, key, cnt))

      elsif key == @localize_words[Crawler::Items.contact_information]

        cnt = max_counts[Crawler::Items.contact_information]

        after_data.merge!(make_block_for_excel(value, key, cnt))

      elsif key == @localize_words[Crawler::Items.another_company]

        cnt = max_counts[Crawler::Items.another_company]

        after_data.merge!(make_block_for_excel(value, key, cnt))

      elsif key.include?('Original Crawl')

        cnt = max_counts[key.gsub('Original Crawl ', '')]

        after_data.merge!(make_block_for_excel(value, key, cnt))

      else

        after_data.store(key, value)
      end
    end

    after_data
  end

  def tel_data
    extract_tel_column
  end

  def get_category_counts
    res = { Crawler::Items.contact_information => 0,
            Crawler::Items.others              => 0,
            Crawler::Items.another_company     => 0 }

    data = arrange

    res.keys.each do |item|
      val = data[@localize_words[item]]
      res[item] = val.class == Hash ? val.size : 1 unless val.nil?
    end

    res
  end

  private

  def get_title
    @data.each do |hash|
      return hash[:value] if hash[:name] == Crawler::Items.title
    end

    ''
  end

  def make_block_for_excel(value, column_word, max_col_count)
    data = {}

    if value.class == String
      data.store(column_word + 1.to_s, value)
    else

      value.each.with_index(1) do |(k, v), i|
        if i > max_col_count && max_col_count != 0
          data[column_word + max_col_count.to_s] =
            data[column_word + max_col_count.to_s] + "\n" + k + ':' + v
          next
        end

        data.store(column_word + i.to_s, k.to_s + ':' + v.to_s)
      end
    end

    data
  end

  def localizable_name_value?(hash)
    [Crawler::Items.contact_information, Crawler::Items.telephone, Crawler::Items.address].include?(hash[:name])
  end

  def clean_result(target_data = @data)
    return if target_data.empty?

    @clean_data = target_data.map.with_index do |h, i|
      h.symbolize_keys
      h[:name]  = h[:name].more_simplify
      h[:value] = h[:value].more_simplify
      h[:index] = i

      h
    end

    @clean_data.sort_by! { |d| [-d[:priority], d[:index]] }

    @clean_data = sort

    # 値が同じならまとめる。uniq作業も兼ねる。
    ( @clean_data.size + 10 ).times do |_|
      break unless delete_same_content?
    end

    @clean_data = @clean_data.map do |hash|
      {name:     hash[:name].more_simplify,
       value:    hash[:value].more_simplify,
       category: hash[:category],
       priority: hash[:priority]}
    end

    extraction

    @clean_data
  end

  # ここのロジックが時間がかかるので、改善の余地あり
  def delete_same_content?
    del = nil
    @clean_data.each_combination_with_index do |h1, h1_idx, h2, h2_idx|
      next if h1[:category] == Crawler::Items.another_company

      if h1[:value].more_simplify == h2[:value].more_simplify && h1[:name] == h2[:name] && h1[:category] == h2[:category]
        if h1[:priority] == h2[:priority]
          del = h1_idx < h2_idx ? h2_idx : h1_idx
        else
          del = h1[:priority] > h2[:priority] ? h2_idx : h1_idx
        end
        break
      end
    end

    @clean_data.delete_at(del) if del.present?

    del.present?
  end

  def sort
    data_with_flag = []

    @clean_data.each do |d|
      use = d[:name] == Crawler::Items.title ? true : false
      data_with_flag.push(name: d[:name], value: d[:value], priority: d[:priority], group: d[:group], use: use)
    end

    sort_data = [{name: Crawler::Items.url,    value: @url,    category: Crawler::Items.url, priority: 1000 },
                 {name: Crawler::Items.domain, value: @domain, category: Crawler::Items.domain, priority: 1000 }]

    data_with_flag.each do |d|
      d[:use] = true if d[:name] == 'url' || d[:name] == 'domain'
    end

    # 名称
    # その他の会社情報
    first_companies = []
    first_company_idx = 0
    first_company_group = 0
    another_companies = []
    data_with_flag.each_with_index do |hash, i|
      if company_name?(hash[:name])
        if first_companies.blank?
          first_companies << hash[:value]
          first_company_idx = i
          first_company_group = hash[:group]

        # 連続社名(例: https://brady.co.jp)の場合は、その他の会社でないことが多い
        elsif !first_companies.include?(hash[:value]) && i - first_company_idx <= 2 && first_company_group == hash[:group]
          first_companies << hash[:value]
          first_company_idx = i
        elsif !first_companies.include?(hash[:value])
          data_with_flag.each_with_index do |h2, j|
            next if i > j || hash[:group] != h2[:group]
            data_with_flag[j][:use] = true
            tmp_name = h2[:name] == Crawler::Items.possible_company_name ? @localize_words[Crawler::Items.possible_company_name] : h2[:name]
            another_companies << {name: h2[:name], value: h2[:value], category: Crawler::Items.another_company, priority: h2[:priority] }
          end
          MyLog.new('crawl_alert').log "[#{Time.zone.now}] Another Company Name検知 #{@url} #{hash[:name]} #{hash[:value]}"
          next
        end

        tmp_name = hash[:name] == Crawler::Items.possible_company_name ? @localize_words[Crawler::Items.possible_company_name] : hash[:name]
        data_with_flag[i][:use] = true
        sort_data.push({name: tmp_name, value: @attr_finder.extract_org_name_surely_case(hash[:value]), category: Crawler::Items.company_name, priority: hash[:priority] })
      end
    end

    # その他の会社を検索する (他のメソッドで選別できなかった場合)
    # 会社情報のグループに社名も住所がない場合。
    # 例) https://www.kyushu-mitsubishi-motors.co.jp/company/outline/
    # if another_companies.blank?
    #   another_data = find_another_company_info_group(data_with_flag)

    #   if another_data.keys.size > 1
    #     another_data.keys[1..-1].each do |group_id|
    #       data_with_flag.each_with_index do |h, i|
    #         next if h[:use] == true
    #         next if h[:group] != group_id
    #         data_with_flag[i][:use] = true
    #         another_companies << {name: h[:name], value: h[:value], category: Crawler::Items.another_company, priority: h[:priority] }
    #       end
    #     end

    #     NoticeMailer.deliver_later(NoticeMailer.notice_simple("#{@url} \n#{another_data.to_s}", '3 Another Company INFO検知'))
    #   end
    # end

    # タイトル
    sort_data.push({name: Crawler::Items.title, value: @title, category:  Crawler::Items.title, priority: 1000})

    # 問い合わせ
    data_with_flag.each_with_index do |hash, i|
      next if hash[:use]

      if hash[:name] == Crawler::Items.inquiry_form
        data_with_flag[i][:use] = true

        sort_data.push({name: hash[:name], value: hash[:value], category: Crawler::Items.inquiry_form, priority: hash[:priority] })
      end
    end

    # 連絡先 郵便番号、住所、電話番号、FAX
    post_code = nil
    data_with_flag.each_with_index do |hash, i|
      next if hash[:use]

      if only_post_code_and_next_only_address?(hash, data_with_flag[i+1])
        post_code = hash.dup
        data_with_flag[i][:use] = true
      elsif telephone_data?(hash[:name], hash[:value]) ||
            address_data?(hash[:value])

        data_with_flag[i][:use] = true

        name, value = decide_address_value(hash, post_code)
        post_code = nil
        sort_data.push({name: name, value: value, category: Crawler::Items.contact_information, priority: hash[:priority] })
      end
    end

    # メールアドレス
    data_with_flag.each_with_index do |hash, i|
      next if hash[:use]

      if @attr_finder.mail_address?(hash[:value])
        data_with_flag[i][:use] = true

        mail_str = @attr_finder.extract_mail_address(hash[:value]).join('; ')
        next if mail_str.blank?

        sort_data.push({name: hash[:name], value: mail_str, category: Crawler::Items.mail_address, priority: hash[:priority] })
      end
    end

    # 指標
    @country.indicate_words.keys.each do |word|
      data_with_flag.each_with_index do |hash, i|
        next if hash[:use] == true

        # nameがないときは１個前のname、カテゴリと同じにする
        if hash[:name].blank? &&
           data_with_flag[i-1][:name] == sort_data[-1][:name] && data_with_flag[i-1][:value] == sort_data[-1][:value]

          next if [Crawler::Items.url,
                   Crawler::Items.domain,
                   Crawler::Items.title,
                   Crawler::Items.contact_information].include?(sort_data[-1][:category])

          data_with_flag[i][:use] = true
          sort_data.push({name: hash[:name], value: hash[:value], category: sort_data[-1][:category], priority: hash[:priority] })

        elsif @country.indicate_words[word].include_each_element?(hash[:name])

          data_with_flag[i][:use] = true
          sort_data.push({name: hash[:name], value: hash[:value], category: word, priority: hash[:priority] })

        end
      end
    end

    # その他
    tmp_name  = ''
    tmp_group = 0
    data_with_flag.each do |hash|
      next if hash[:use] == true

      if hash[:name].blank? && hash[:group] == tmp_group
        hash[:name] = tmp_name
      else
        tmp_name  = hash[:name]
        tmp_group = hash[:group]
      end

      # next if hash[:value].blank? ここは様子を見る
      sort_data.push({name: hash[:name], value: hash[:value], category: Crawler::Items.others, priority: hash[:priority] })
    end

    sort_data.concat(another_companies)

    sort_data
  end

  # def find_another_company_info_group(data_with_flag)
  #   group = nil
  #   cnt = 0
  #   another_data = {}
  #   data_with_flag.each do |h|
  #     if group.nil?
  #       group = h[:group]
  #     elsif group != h[:group]
  #       another_data[group] = cnt if cnt >= 2
  #       group = h[:group]
  #       cnt = 0
  #     end

  #     @country.indicate_words.each do |key, words|
  #       ( cnt += 1; break ) if h[:name].one_equal?(words)
  #     end
  #   end

  #   another_data[group] = cnt if group.present? && cnt >= 2

  #   another_data
  # end

  # 郵便番号と住所の行が分かれている場合
  def only_post_code_and_next_only_address?(this_hash, next_hash)
    return false if this_hash.blank? || next_hash.blank?

     @attr_finder.post_code?(this_hash[:value]) && !address_data?(this_hash[:value]) &&
    !@attr_finder.post_code?(next_hash[:value]) &&  address_data?(next_hash[:value])
  end

  def decide_address_value(this_hash, post_code_hash)
    if post_code_hash.present?
      name = post_code_hash[:name].present? && this_hash[:name].blank? ? post_code_hash[:name] : this_hash[:name]
      value = "#{post_code_hash[:value]} #{this_hash[:value]}"
    else
      name = this_hash[:name]
      value = this_hash[:value]
    end
    [name, value]
  end

  def extraction

    # 電話番号、FAXを抽出する
    val_tel = nil
    val_fax = nil
    @clean_data.each do |hash|
      if hash[:category] == Crawler::Items.contact_information
        next unless telephone_data?(hash[:name], hash[:value])

        if address_data?(hash[:value])
          value = @attr_finder.extract_first_tel_from_address_text(hash[:value])
          next unless value.present? && ( val_tel.blank? || val_fax.blank? )

          values = @attr_finder.divide_tel_and_fax(value)
        else
          values = @attr_finder.divide_tel_and_fax(hash[:value], hash[:name])
        end

        if val_tel.blank? && values[:tel][0].present? && ( val = @attr_finder.extract_first_phone_number(values[:tel][0]) ).present?
          val_tel = { name: hash[:name], value: val.more_simplify, category: Crawler::Items.extracted_telephone }
        end

        if val_fax.blank? && values[:fax][0].present? && ( val = @attr_finder.extract_first_phone_number(values[:fax][0]) ).present?
          val_fax = { name: hash[:name], value: val.more_simplify, category: Crawler::Items.extracted_fax }
        end

        break if val_tel.present? && val_fax.present?
      end
    end

    # 郵便番号、住所を抽出する
    val_post_code = nil
    val_address = nil
    @clean_data.each do |hash|
      if hash[:category] == Crawler::Items.contact_information

        next unless address_data?(hash[:value])

        if telephone_data?(hash[:name], hash[:value])

          tmp_val_addr = @attr_finder.extract_first_address_from_tel_text(hash[:value])

          next unless tmp_val_addr.present? && val_address.blank?

          tmp_val_post = @attr_finder.extract_post_code(tmp_val_addr, :possible)
        else
          tmp_val_addr = hash[:value]
          tmp_val_post = @attr_finder.extract_post_code(hash[:name] + ' ' + hash[:value], :possible)
        end

        val_post_code = { name: hash[:name], value: tmp_val_post.more_simplify, category: Crawler::Items.extracted_post_code } if tmp_val_post.present?


        tmp_val_addr = @attr_finder.extract_address(tmp_val_addr)
        val_address = { name: hash[:name], value: tmp_val_addr.more_simplify, category: Crawler::Items.extracted_address } if val_address.blank? && tmp_val_addr.present?

        break if val_address.present?
      end
    end

    # メールアドレス
    # 資本金
    # 代表者
    val_mail_address = nil
    val_capital = nil
    val_sales = nil
    val_employee = nil
    val_representative_position = nil
    val_representative = nil
    @clean_data.each do |hash|
      if hash[:category] == Crawler::Items.mail_address && val_mail_address.blank?
        value = @attr_finder.extract_mail_address(hash[:value])[0]
        val_mail_address = { name: hash[:name], value: value.more_simplify, category: Crawler::Items.extracted_mail_address } if value.present?
      end

      if hash[:category] == Crawler::Items.capital && val_capital.blank?
        value = @attr_finder.money_to_number(hash[:value])
        val_capital = { name: hash[:name], value: value.to_s(:delimited), category: Crawler::Items.extracted_capital } if value.present?
      end

      if hash[:category] == Crawler::Items.sales && val_sales.blank?
        value = @attr_finder.money_to_number(hash[:value])
        val_sales = { name: hash[:name], value: value.to_s(:delimited), category: Crawler::Items.extracted_sales } if value.present?
      end

      if hash[:category] == Crawler::Items.employee && val_employee.blank?
        value = @attr_finder.number_of_people_to_number(hash[:value])
        val_employee = { name: hash[:name], value: value.to_s(:delimited), category: Crawler::Items.extracted_employee } if value.present?
      end

      if hash[:category] == Crawler::Items.board_member && val_representative.blank?
        value = @attr_finder.extract_representative_from_set(hash[:value], hash[:name])
        val_representative_position = { name: '', value: value[:position], category: Crawler::Items.extracted_representative_position } if value[:position].present?
        val_representative          = { name: '', value: value[:name],     category: Crawler::Items.extracted_representative          } if value[:name].present?
      end
    end

    # 後ろになるものから挿入していく
    insert_to_clean_data(val_representative, after: Crawler::Items.title) if val_representative.present?
    insert_to_clean_data(val_representative_position, after: Crawler::Items.title) if val_representative_position.present?
    insert_to_clean_data(val_employee, after: Crawler::Items.title) if val_employee.present?
    insert_to_clean_data(val_sales, after: Crawler::Items.title) if val_sales.present?
    insert_to_clean_data(val_capital, after: Crawler::Items.title) if val_capital.present?
    insert_to_clean_data(val_mail_address, after: Crawler::Items.title) if val_mail_address.present?
    insert_to_clean_data(val_fax, after: Crawler::Items.title) if val_fax.present?
    insert_to_clean_data(val_tel, after: Crawler::Items.title) if val_tel.present?
    insert_to_clean_data(val_address, after: Crawler::Items.title) if val_address.present?
    insert_to_clean_data(val_post_code, after: Crawler::Items.title) if val_post_code.present?
  end

  def add_optional_to_clean_data
    return @clean_data if @optional_info.empty?

    dup_data = @clean_data.dup

    @optional_info.each do |k, contents|
      contents.each do |cont|
        dup_data << { name:     k.more_simplify,
                      value:    cont.simplify,
                      category: "Original Crawl #{k}" }
      end
    end

    dup_data
  end

  def size_of_same_category(category)
    count = 0
    @clean_data_with_option.each do |hash|
      count += 1 if hash[:category] == category
    end
    count
  end

  def extract_company_name
    @clean_data.each do |hash|
      if company_name?(hash[:name])
        return hash[:value]
      end
    end
    ''
  end

  def extract_tel_column

    # 最初の抽出
    @clean_data.select do |hash|
      next if hash[:name].empty?
      telephone_data?(hash[:name], hash[:value])
    end
  end

  def company_name?(text)
    return false if text.nil?
    text.clean.one_include?(@country.company_names) || text == Crawler::Items.possible_company_name
  end

  def telephone_data?(name, value)
    @country.tel_words.include_each_element?(name) ||
    @attr_finder.include_phone_number?(value)
  end

  def address_data?(value)
    @attr_finder.search_address(value).present?
  end

  def insert_to_clean_data(value, before: nil, after: nil)
    raise ArgumentError, 'argument before or after is needed.' if before.blank? && after.blank?

    idx = -1
    last_category = nil
    @clean_data.each_with_index do |hash, i|
      ( idx = i - 1; break ) if before == hash[:category]
      ( idx = i; break )     if after  == last_category && after != hash[:category]
      last_category = hash[:category]
    end

    if idx == -1
      @clean_data << value
    else
      @clean_data.insert(idx, value)
    end
  end
end

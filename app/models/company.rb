class Company < ApplicationRecord
  has_many :company_category_connectors
  has_many :category_connectors, through: :company_category_connectors
  has_many :company_area_connectors
  has_many :area_connectors, through: :company_area_connectors
  has_many :company_company_groups
  has_many :company_groups
  has_many :groups, through: :company_company_groups, source: :company_group

  scope :where_by_connector, ->(connector_where_clause, group_ids = nil, group_count = nil, not_own_capitals = false) do
    query = eager_load(:area_connectors, :category_connectors).where(connector_where_clause)

    if not_own_capitals
      ids = CompanyGroup.range.where(grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL]).pluck(:id)

      query = query.where.not(id: CompanyCompanyGroup.select(:company_id).where(company_group_id: ids))

    elsif group_ids.present? && group_count.present?
      query = query.where(id: CompanyCompanyGroup.select(:company_id).where(company_group_id: group_ids)
                                                                     .group(:company_id)
                                                                     .having('count("company_id") = ?', group_count)
                         )
    end
    query
  end

  def categories_str
    category_connectors.eager_load(:large_category, :middle_category, :small_category, :detail_category)
                       .order('large_categories.sort', 'middle_categories.id', 'small_categories.id', 'detail_categories.id').map do |con|
      str = "#{con.large_category.name}"
      str += " > #{con.middle_category.name}" if con.middle_category.present?
      str += " > #{con.small_category.name}"  if con.small_category.present?
      str += " > #{con.detail_category.name}" if con.detail_category.present?
      str
    end.join(', ')
  end

  class << self

    def select_by_connector_where_clause(where_clause, group_ids, group_count, not_own_capitals = false, limit = nil)
      if limit.nil?
        where_by_connector(where_clause, group_ids, group_count, not_own_capitals)
      else
        where_by_connector(where_clause, group_ids, group_count, not_own_capitals).limit(limit)
      end
    end

    def select_domain_by_connector_where_clause(where_clause, group_ids, group_count, not_own_capitals = false, limit = nil)
      if limit.nil?
        select(:domain).distinct.where_by_connector(where_clause, group_ids, group_count, not_own_capitals).pluck(:domain)
      else
        select(:domain).distinct.where_by_connector(where_clause, group_ids, group_count, not_own_capitals).limit(limit).pluck(:domain)
      end
    end

    def select_by_connectors(areas_connector_id, categories_connector_id, capitals_id, employees_id, sales_id, not_own_capitals = false, limit = nil)
      where_clause = make_where_clause(areas_connector_id, categories_connector_id)

      group_ids, group_cnt = join_group_ids(capitals_id, employees_id, sales_id)

      select_by_connector_where_clause(where_clause, group_ids, group_cnt, not_own_capitals, limit)
    end

    def select_domain_by_connectors(areas_connector_id, categories_connector_id, capitals_id, employees_id, sales_id, not_own_capitals = false, limit = nil)
      where_clause = make_where_clause(areas_connector_id, categories_connector_id)

      group_ids, group_cnt = join_group_ids(capitals_id, employees_id, sales_id)

      select_domain_by_connector_where_clause(where_clause, group_ids, group_cnt, not_own_capitals, limit)
    end

    def import(file_path)
      row_cnt = 0

      importer = Excel::Import.new(file_path, 1, true)

      raise 'ヘッダーが間違っています。' unless correct_header?(importer.get_row(1))

      surfixies = check_surfix_headers(importer.get_row(1))

      group_constraint = CompanyGroupConstraint.new(importer.get_row(1))

      ActiveRecord::Base.transaction do
        2.upto(importer.row_max+2) do |i|
          row_cnt = i

          data = importer.get_row_with_header(i)
          next if data.blank?

          raise "ドメインが空の行があります。#{i}行目付近。" if data['ドメイン'].hyper_strip.blank?

          check_category_validation(data, surfixies[:category])
          check_area_validation(data, surfixies[:area])

          # どちらかがなければ、登録する意味がない
          raise "業種もエリアもありません。#{i}行目付近。" if data['大業種'].hyper_strip.blank? && data['地方'].hyper_strip.blank?

          domain = url_to_domain(data).hyper_strip

          company = self.find_by(domain: domain)
          if company.blank?
            company = self.create!(domain: domain)
          end

          group_ids = group_constraint.select_group_ids(data)

          group_ids.each { |id| CompanyCompanyGroup.find_or_create(company: company, company_group_id: id) }

          # 業種の登録
          register_category(company, data, surfixies[:category])

          # エリアの登録
          register_area(company, data, surfixies[:area])

          # レンジグループの登録
          register_range_group(company, data)
        end
      end

      true
    rescue => e
      raise e, "#{e.message} #{row_cnt}行目付近 #{e.backtrace[0..5]}"
    end

    private

    def url_to_domain(data)
      if data['ドメイン'].include?('://')
        data['ドメイン'].hyper_strip.split('://')[1].split('/')[0]
      else
        data['ドメイン'].hyper_strip.split('/')[0]
      end
    end

    def register_category(company, data, category_surfixies)
      CategoryConnector.import_and_make(company, data['大業種'], data['中業種'], data['小業種'], data['細業種'])

      category_surfixies.each do |surfix|
        CategoryConnector.import_and_make(company, data["大業種_#{surfix}"], data["中業種_#{surfix}"], data["小業種_#{surfix}"], data["細業種_#{surfix}"])
      end
    end

    def register_area(company, data, area_surfixies)
      AreaConnector.import_and_make(company, data['地方'], data['県'], data['市区町村'])

      area_surfixies.each do |surfix|
        AreaConnector.import_and_make(company, data["地方_#{surfix}"], data["県_#{surfix}"], data["市区町村_#{surfix}"])
      end
    end

    def register_range_group(company, data)
      raise "ソースがsource_listに存在しません。=> #{data['ソース']}" if data['ソース'].present? && CompanyCompanyGroup.source_list[data['ソース']].blank?

      source = data['ソース'].blank? || data['資本金'].blank? ? 'only_register' : data['ソース']
      CompanyCompanyGroup.create_connection_to(CompanyGroup::CAPITAL, source, db_company: company, value: data['資本金'])

      source = data['ソース'].blank? || data['従業員数'].blank? ? 'only_register' : data['ソース']
      CompanyCompanyGroup.create_connection_to(CompanyGroup::EMPLOYEE, source, db_company: company, value: data['従業員数'])

      source = data['ソース'].blank? || data['売上'].blank? ? 'only_register' : data['ソース']
      CompanyCompanyGroup.create_connection_to(CompanyGroup::SALES, source, db_company: company, value: data['売上'])
    end

    def correct_header?(headers)
      if headers.include?('ドメイン') &&
         headers.include?('大業種') &&
         headers.include?('中業種') &&
         headers.include?('小業種') &&
         headers.include?('細業種') &&
         headers.include?('地方') &&
         headers.include?('県') &&
         headers.include?('市区町村')
        return true
      end

      false
    end

    def check_surfix_headers(headers)
      category_surfixes = []
      area_surfixes = []
      headers.each do |str|
        if str.start_with?('大業種_')
          surfix = str.sub('大業種_', '')

          raise "業種ヘッダーが間違っています。surfix => #{surfix}。" if !headers.include?("中業種_#{surfix}") || !headers.include?("小業種_#{surfix}") || !headers.include?("細業種_#{surfix}")
          category_surfixes << surfix

        elsif str.start_with?('地方_')
          surfix = str.sub('地方_', '')

          raise "エリアヘッダーが間違っています。surfix => #{surfix}。" if !headers.include?("県_#{surfix}") || !headers.include?("市区町村_#{surfix}")
          area_surfixes << surfix
        end
      end

      headers.each do |str|
        if str.start_with?('中業種_')
          surfix = str.sub('中業種_', '')
          raise "間違っている中業種ヘッダーがあります。surfix => #{surfix}。" unless category_surfixes.include?(surfix)

        elsif str.start_with?('小業種_')
          surfix = str.sub('小業種_', '')
          raise "間違っている小業種ヘッダーがあります。surfix => #{surfix}。" unless category_surfixes.include?(surfix)

        elsif str.start_with?('細業種_')
          surfix = str.sub('細業種_', '')
          raise "間違っている細業種ヘッダーがあります。surfix => #{surfix}。" unless category_surfixes.include?(surfix)

        elsif str.start_with?('県_')
          surfix = str.sub('県_', '')
          raise "間違っている県ヘッダーがあります。surfix => #{surfix}。" unless area_surfixes.include?(surfix)

        elsif str.start_with?('市区町村_')
          surfix = str.sub('市区町村_', '')
          raise "間違っている市区町村ヘッダーがあります。surfix => #{surfix}。" unless area_surfixes.include?(surfix)
        end
      end

      { category: category_surfixes, area: area_surfixes }
    end

    def make_where_clause(areas_connector_id, categories_connector_id)
      areas_connector_id = areas_connector_id.split(',') if areas_connector_id.class == String
      categories_connector_id = categories_connector_id.split(',') if categories_connector_id.class == String

      clauses = []

      clauses << ( areas_connector_id.present? ? AreaConnector.make_where_clause(areas_connector_id) : nil )

      clauses << ( categories_connector_id.present? ? CategoryConnector.make_where_clause(categories_connector_id) : nil )

      clauses.compact!

      if clauses.size == 1
        clauses[0]
      else
        clauses.map { |clause| "( #{clause} )" }.join(' AND ')
      end
    end

    def join_group_ids(capitals_id = [], employees_id = [], sales_id = [])
      capitals_id  = capitals_id.split(',')  if capitals_id.class == String
      employees_id = employees_id.split(',') if employees_id.class == String
      sales_id     = sales_id.split(',')     if sales_id.class == String

      capitals_id  ||= []
      employees_id ||= []
      sales_id     ||= []

      group_cnt = 0
      group_cnt += 1 if capitals_id.present?
      group_cnt += 1 if employees_id.present?
      group_cnt += 1 if sales_id.present?
      group_cnt = nil if group_cnt == 0

      [ (capitals_id + employees_id + sales_id).sort, group_cnt]
    end

    def check_category_validation(data, category_surfixies)
      raise 'surfixなし業種が間違っています。' unless corrent_category?(data['大業種'], data['中業種'], data['小業種'], data['細業種'])

      category_surfixies.each do |surfix|
        raise "「#{surfix}」業種が間違っています。" unless corrent_category?(data["大業種_#{surfix}"], data["中業種_#{surfix}"], data["小業種_#{surfix}"], data["細業種_#{surfix}"])
      end
      data
    end

    def corrent_category?(large, middle, small, detail)
      if detail.hyper_strip.present?
        return false if large.hyper_strip.blank? || middle.hyper_strip.blank? || small.hyper_strip.blank?
      elsif small.hyper_strip.present?
        return false if large.hyper_strip.blank? || middle.hyper_strip.blank?
      elsif middle.hyper_strip.present?
        return false if large.hyper_strip.blank?
      end

      true
    end

    def check_area_validation(data, area_surfixies)
      data['地方'] = AreaConnector.select_region_from_prefecture(data['県']) || '' if data['地方'].blank? && data['県'].present?
      raise 'surfixなしエリアが間違っています。' unless corrent_area?(data['地方'], data['県'], data['市区町村'])

      area_surfixies.each do |surfix|
        data["地方_#{surfix}"] = AreaConnector.select_region_from_prefecture(data["県_#{surfix}"]) || '' if data["地方_#{surfix}"].blank? && data["県_#{surfix}"].present?
        raise "「#{surfix}」エリアが間違っています。" unless corrent_area?(data["地方_#{surfix}"], data["県_#{surfix}"], data["市区町村_#{surfix}"])
      end
      data
    end

    def corrent_area?(region, prefecture, city)
      if city.hyper_strip.present?
        return false if region.hyper_strip.blank? || prefecture.hyper_strip.blank?
      elsif prefecture.hyper_strip.present?
        return false if region.hyper_strip.blank?
      end

      true
    end
  end
end

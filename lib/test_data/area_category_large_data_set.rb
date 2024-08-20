class TestData::AreaCategoryLargeDataSet

  class << self
    def load(count: 1_000_000, only_company: true)

      unless only_company
        prepare_cities

        prepare_category
      end

      prepare_company(count)
    end

    def prepare_cities
      puts 'START prepare_cities'
      Prefecture.all.each do |prfc|
        region = AreaConnector.find_by(prefecture: prfc).region
        rand(10..30).times do |i|
          city = City.create!(name: "#{Random.alphanumeric(20)}#{random_select(['区','市','町', '村'])}")
          AreaConnector.create!(region: region, prefecture: prfc, city: city)
        end
      end
      puts 'END prepare_cities'
    end

    def prepare_category
      puts 'START prepare_category'

      (30 - LargeCategory.count).times do |i|
        if i == 0
          middle_size = 24
          large_name = '製造業'
        elsif i == 1
          middle_size = 12
          large_name = '小売業'
        else
          middle_size = rand(2..10)
          large_name = "#{Random.alphanumeric(10)} 業"
        end
        large = LargeCategory.create!(name: large_name)
        CategoryConnector.create!(large_category: large)

        middle_size.times do |j|
          middle = MiddleCategory.create!(name: "#{Random.alphanumeric(20)} 業")
          CategoryConnector.create!(large_category: large, middle_category: middle)

          rand(3..10).times do |_|
            small = SmallCategory.create!(name: "#{Random.alphanumeric(20)} 業")
            CategoryConnector.create!(large_category: large, middle_category: middle, small_category: small)
            
            rand(5..20).times do |_|
              detail = DetailCategory.create!(name: "#{Random.alphanumeric(20)} 業")
              CategoryConnector.create!(large_category: large, middle_category: middle, small_category: small, detail_category: detail)
            end
          end
        end
        puts "END #{large.name} #{i}"
      end

      puts 'END prepare_category'
    end

    def prepare_company(count = 1_000_000)
      puts 'START prepare_company'

      ranges = {}

      # カテゴリー
      manufac_ids = CategoryConnector.where(large_category: LargeCategory.find_by(name: '製造業')).pluck(:id)
      ranges[:manufac_range] = manufac_ids.min..manufac_ids.max

      retail_ids = CategoryConnector.where(large_category: LargeCategory.find_by(name: '小売業')).pluck(:id)
      ranges[:retail_range] = retail_ids.min..retail_ids.max

      ranges[:all_category_range] = CategoryConnector.first.id..CategoryConnector.last.id

      # 地域
      tokyo_ids = AreaConnector.where(prefecture: Prefecture.find_by(name: '東京都')).pluck(:id)
      ranges[:tokyo_range] = tokyo_ids[1]..tokyo_ids.max

      osaka_ids = AreaConnector.where(prefecture: Prefecture.find_by(name: '大阪府')).pluck(:id)
      ranges[:osaka_range] = osaka_ids[1]..osaka_ids.max

      kana_ids = AreaConnector.where(prefecture: Prefecture.find_by(name: '神奈川県')).pluck(:id)
      ranges[:kana_range] = kana_ids[1]..kana_ids.max

      aichi_ids = AreaConnector.where(prefecture: Prefecture.find_by(name: '愛知県')).pluck(:id)
      ranges[:aichi_range] = aichi_ids[1]..aichi_ids.max

      miya_ids = AreaConnector.where(prefecture: Prefecture.find_by(name: '宮城県')).pluck(:id)
      ranges[:miya_range] = miya_ids[1]..miya_ids.max

      fuku_ids = AreaConnector.where(prefecture: Prefecture.find_by(name: '福岡県')).pluck(:id)
      ranges[:fuku_range] = fuku_ids[1]..fuku_ids.max

      ranges[:all_area_range] = AreaConnector.first.id..AreaConnector.last.id



      company_attrs = []
      count.times do |i|
        if i%10_000 == 0 && company_attrs.present?

          company_insertions(company_attrs, ranges)

          company_attrs = []
        end

        company_attrs << {domain: Random.alphanumeric(30), created_at: Time.zone.now, updated_at: Time.zone.now}

        puts "#{i} END " if i%10_000 == 0
      end

      company_insertions(company_attrs, ranges) if company_attrs


      puts 'END prepare_company'
    end

    def destroy_all_category
      CategoryConnector.destroy_all
      DetailCategory.destroy_all
      SmallCategory.destroy_all
      MiddleCategory.destroy_all
      LargeCategory.destroy_all
    end

    def destroy_all_company
      Company.destroy_all
      CompanyAreaConnector.destroy_all
      CompanyCategoryConnector.destroy_all
    end

    private

    def company_insertions(company_attrs, ranges)
      return if company_attrs.blank?

      last_id = Company.last&.id || 0

      Company.insert_all(company_attrs)

      companies = Company.where('id > ?', last_id)

      area_connector_attrs = []
      category_connector_attrs = []
      companies.each do |company|
        n = random_with_weighting([24,24,19,14,14,14,36])

        if n == 0
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:tokyo_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        elsif n == 1
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:osaka_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        elsif n == 2
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:kana_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        elsif n == 3
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:aichi_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        elsif n == 4
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:miya_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        elsif n == 5
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:fuku_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        else
          area_connector_attrs << {company_id: company.id, area_connector_id: rand(ranges[:all_area_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        end

        n = random_with_weighting([25,20,55])

        if n == 0
          category_connector_attrs << {company_id: company.id, category_connector_id: rand(ranges[:manufac_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        elsif n == 1
          category_connector_attrs << {company_id: company.id, category_connector_id: rand(ranges[:retail_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        else
          category_connector_attrs << {company_id: company.id, category_connector_id: rand(ranges[:all_category_range]), created_at: Time.zone.now, updated_at: Time.zone.now}
        end
      end

      CompanyAreaConnector.insert_all!(area_connector_attrs)
      CompanyCategoryConnector.insert_all!(category_connector_attrs)
    end

    # [5,3,2] = 50% => 0, 30% => 1, 20% => 2
    def random_with_weighting(arr)
      sum = 0
      next_n = 0
      arr = arr.map do |n|
        sum += n
        next_n = next_n + n
        (next_n - n..next_n - 1)
      end

      n = rand(sum)

      arr.each_with_index do |range, i|
        return i if range.include?(n)
      end
      -1
    end

    def random_select(arr)
      arr[rand(arr.size)]
    end
  end
end

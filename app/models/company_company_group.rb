class CompanyCompanyGroup < ApplicationRecord
  belongs_to :company
  belongs_to :company_group

  class << self
    def find_or_create(**atters)
      res = self.find_by(atters)
      res = self.create!(atters) if res.blank?
      res
    end

    def find_by_reserved_group(company, title)
      return nil if ( gnum = CompanyGroup::RESERVED[title] ).blank?

      find_by(company: company, company_group: CompanyGroup.where(grouping_number: gnum))
    end

    def source_list
      {
        'corporate_site' => { level: 10, expired_at: 1.years }, # 1年経ったら、更新しても良い
        'biz_map' => { level: 7, expired_at: 1.years },
        'only_register' => { level: 0, expired_at: 1.month },
      }
    end

    def create_main_connections(domain, company_data = nil, value = nil)
      create_connection_to(CompanyGroup::CAPITAL, 'corporate_site', domain: domain, company_data: company_data)
      create_connection_to(CompanyGroup::EMPLOYEE, 'corporate_site', domain: domain, company_data: company_data)
      create_connection_to(CompanyGroup::SALES, 'corporate_site', domain: domain, company_data: company_data)
    end

    # title 例: CompanyGroup::CAPITAL
    def create_connection_to(title, source, domain: nil, db_company: nil, company_data: nil, value: nil)
      return nil if domain.blank? && db_company.blank?

      if db_company.blank?
        return nil unless ( db_company = Company.find_by(domain: domain) ).present?
      end

      return nil if source_list[source].blank?

      title_converter = { CompanyGroup::CAPITAL => Crawler::Items.extracted_capital,
                          CompanyGroup::EMPLOYEE => Crawler::Items.extracted_employee,
                          CompanyGroup::SALES => Crawler::Items.extracted_sales
                        }

      value = if company_data.present?
        value = company_data.clean_data.select { |d| d[:category] == title_converter[title] }[0]
        value.present? && value[:value].present? ? value[:value].gsub(',', '').to_i : nil
      elsif value.present?
        value = value.to_s.hyper_strip.gsub(',', '')
        value.to_i.to_s == value ? value.to_i : nil
      else
        nil
      end

      return nil if ( group = CompanyGroup.find_by_range(title, value) ).blank?

      if ( ccg = find_by_reserved_group(db_company, title) ).present?

        return nil if value.blank? # unknownには更新しない

        # ソースレベルの比較 → 更新期限切れの比較
        unless ccg.company_group.id == CompanyGroup.find_unknown(title).id
          return nil if source_list[ccg.source][:level] > source_list[source][:level] && ccg.expired_at >= Time.zone.now
          return nil if source_list[ccg.source][:level] - 5 > source_list[source][:level] # レベルが５以上離れていれば、更新しない
        end

        ccg.update!(company_group: group, source: source, expired_at: Time.zone.now + source_list[source][:expired_at])
      else
        create!(company: db_company, company_group: group, source: source, expired_at: Time.zone.now + source_list[source][:expired_at])
      end
    rescue => e
      Lograge.job_logging('MODEL', 'error', 'CompanyCompanyGroup', 'create_connection_to', { domain: domain, company_clean_data: company_data.clean_data, title: title, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
      nil
    end
  end
end

class CountryDatum < ApplicationRecord
  def data_set
    {
      company_name:          JSON.parse(company_names),
      org_words:             JSON.parse(organization_words),
      address:               JSON.parse(address_words),
      tel_words:             JSON.parse(tel_words),
      fax_words:             JSON.parse(fax_words),
      contact_words:         JSON.parse(contact_words),
      mail_words:            JSON.parse(mail_words),
      indicate_words:        JSON.parse(indicate_words),
      indicators:            JSON.parse(indicators),
      extraction_item_words: JSON.parse(extraction_item_words),
      tel_info:              tel_info
    }
  end

  def localize_words
    items = Crawler::Items

    {
      items.company_name                      => JSON.parse(company_names)[0],
      items.address                           => JSON.parse(address_words)[0],
      items.telephone                         => JSON.parse(tel_words)[0],
      items.fax                               => JSON.parse(fax_words)[0],
      items.post_code                         => JSON.parse(post_code_words)[0],
      items.contact_information               => JSON.parse(contact_words)[0],
      items.board_member                      => JSON.parse(indicate_words)[items.board_member][0],
      items.capital                           => JSON.parse(indicate_words)[items.capital][0],
      items.sales                             => JSON.parse(indicate_words)[items.sales][0],
      items.employee                          => JSON.parse(indicate_words)[items.employee][0],
      items.establish                         => JSON.parse(indicate_words)[items.establish][0],
      items.branch                            => JSON.parse(indicate_words)[items.branch][0],
      items.stockholder                       => JSON.parse(indicate_words)[items.stockholder][0],
      items.business                          => JSON.parse(indicate_words)[items.business][0],
      items.extracted_telephone               => JSON.parse(extraction_item_words)[items.extracted_telephone],
      items.extracted_fax                     => JSON.parse(extraction_item_words)[items.extracted_fax],
      items.extracted_post_code               => JSON.parse(extraction_item_words)[items.extracted_post_code],
      items.extracted_address                 => JSON.parse(extraction_item_words)[items.extracted_address],
      items.extracted_mail_address            => JSON.parse(extraction_item_words)[items.extracted_mail_address],
      items.extracted_capital                 => JSON.parse(extraction_item_words)[items.extracted_capital],
      items.extracted_sales                   => JSON.parse(extraction_item_words)[items.extracted_sales],
      items.extracted_employee                => JSON.parse(extraction_item_words)[items.extracted_employee],
      items.extracted_representative_position => JSON.parse(extraction_item_words)[items.extracted_representative_position],
      items.extracted_representative          => JSON.parse(extraction_item_words)[items.extracted_representative],
    }
  end

  def tel_info
    { national_num: country_code, max_size: tel_number_max_size, min_size: tel_number_min_size }
  end

  def exclude_search_words(link_words_str)
    link_words_str.split_and_trim(',')[0..4].exclude_content_include(self.search_words)
  end

  class << self

    def find(country_or_lang = Crawler::Country.japan[:english])
      if country_or_lang.class == String
        if country_or_lang == country_or_lang.to_i.to_s
          super
        else
          ActiveRecord::Base.connection_pool.with_connection do
            self.find_by_name(country_or_lang) || self.find_by_language(country_or_lang)
          end
        end
      elsif country_or_lang.class == Integer
        super
      end
    end
  end
end

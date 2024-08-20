module ExcelMaking
  extend ActiveSupport::Concern

  included do

    private

    def make_list_site_contents(lang, list_site_headers)
      list_site_contents = {}

      begin
        list_site_result = Json2.parse(corporate_list_result, symbolize: false) || {}

        list_site_result.each do |header, value|
          value = value.join('; ') if value.class == Array

          if list_site_headers.include?(header)
            list_site_contents.merge!({header => value.to_s})
          else
            if list_site_contents[Crawler::Items.local(lang)[:others]].present?
              list_site_contents[Crawler::Items.local(lang)[:others]] = list_site_contents[Crawler::Items.local(lang)[:others]] + ", #{header}:#{value.to_s}"
            else
              list_site_contents.merge!({Crawler::Items.local(lang)[:others] => "#{header}:#{value.to_s}"})
            end
          end
        end
      rescue => e
        Lograge.logging('error', { class: self.class.to_s, method: 'make_list_site_contents', issue: "#{e}", url: url, err_msg: e.message, backtrace: e.backtrace })
        list_site_contents = ['書き込みエラー']
      end

      list_site_contents
    end
  end
end

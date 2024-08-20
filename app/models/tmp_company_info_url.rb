class TmpCompanyInfoUrl < ApplicationRecord
  include ExcelMaking

  belongs_to :request
  belongs_to :result_file, optional: true

  def make_contents_for_output(common_headers:, list_site_headers:, category_max_counts:)
    lang = request.user.language

    common_contents = {}

    list_site_contents = make_list_site_contents(lang, list_site_headers)

    company_site_contents = {}

    {common: common_contents, list_site: list_site_contents, company_site: company_site_contents}
  end
end

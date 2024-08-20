class SearchRequest::CompanyInfo < RequestedUrl

  TYPE = 'SearchRequest::CompanyInfo'.freeze

  class << self

    def new_attributes_with_first_status(url, request_id)
      { url:           url,
        status:        EasySettings.status.new,
        finish_status: EasySettings.finish_status.new,
        request_id:    request_id,
        test:          false,
      }
    end

    def create_with_first_status(url, request_id)
      self.create!(new_attributes_with_first_status(url, request_id))
    end

    def create_with_first_status_from_corporate_list(url:, organization_name:, result_corporate_list: nil, request_id:, corporate_list_url_id: nil)
      ci = self.create!(url:                   url,
                        organization_name:     organization_name,
                        status:                EasySettings.status.new,
                        finish_status:         EasySettings.finish_status.new,
                        request_id:            request_id,
                        corporate_list_url_id: corporate_list_url_id,
                        test:                  false)

      ci.find_result_or_create(corporate_list: result_corporate_list)
      ci
    end
  end
end

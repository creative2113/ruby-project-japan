class SearchRequest::CorporateSingle < RequestedUrl

  TYPE = 'SearchRequest::CorporateSingle'.freeze

  class << self
    def create_with_first_status(url:, request_id:)
      self.create!(url:           url,
                   status:        EasySettings.status.new,
                   finish_status: EasySettings.finish_status.new,
                   request_id:    request_id,
                   test:          false)
    rescue ActiveRecord::RecordInvalid => e
      if e.message == 'バリデーションに失敗しました: Urlはすでに存在します'
        return self.find_by(url: url, request_id: request_id, test: false)
      end
      raise e.class, e.message
    end
  end
end

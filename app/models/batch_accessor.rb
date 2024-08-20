class BatchAccessor
  def initialize
    target_uri = Rails.application.credentials.batch_server[:url]
    @uri = URI.parse(target_uri)

    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = @uri.scheme === 'https'
  end

  def request_search(search_request_id, user_id)
    @uri.path = '/batches/search_request'
    params = { search_request_id: search_request_id, user_id: user_id }
    @uri.query = URI.encode_www_form(params)
    @http.get(@uri.request_uri)
  end

  def request_result_file(result_file_id, user_id)
    @uri.path = '/batches/result_file_request'
    params = { result_file_id: result_file_id, user_id: user_id }
    @uri.query = URI.encode_www_form(params)
    @http.get(@uri.request_uri)
  end

  def request_test_search(test_request_id, user_id)
    @uri.path = '/batches/test_search_request'
    params = { test_request_id: test_request_id, user_id: user_id }
    @uri.query = URI.encode_www_form(params)
    @http.get(@uri.request_uri)
  end
end

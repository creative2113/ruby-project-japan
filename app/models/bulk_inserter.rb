class BulkInserter
  attr_reader :attrs

  # 注意!!!
  #  バルクインサートの時の通信パケット数が大きすぎると
  #  「MySQL client is not connected」 エラーが発生する
  #  「max_allowed_packet」を大きくする必要がある。
  #  参考値：リクナビ1万件をバルクインサートする時、「max_allowed_packet」が128M必要だった。
  #  もしくは、分割して、送信する必要がある

  def initialize(class_name)
    @class = class_name
    @attrs = []
  end

  def execute!
    return if @attrs.blank?

    if @class == SearchRequest::CompanyInfo
      insert_company_info
    else
      insert_normal
    end
  end

  def add(attrs)
    attrs[:created_at] = Time.zone.now unless attrs.has_key?(:created_at) # rails7 からrecord_timestampsオプションが使えて、これは不要になる
    attrs[:updated_at] = Time.zone.now unless attrs.has_key?(:updated_at) # rails7 からrecord_timestampsオプションが使えて、これは不要になる

    if @class == SearchRequest::CompanyInfo
      attrs = add_company_info(attrs)
    end

    @attrs << attrs
  end

  private

  def add_company_info(attrs)
    @request_id = attrs[:request_id] if @request_id.blank?
    raise 'request_idが異なります'     if @request_id.present? && @request_id != attrs[:request_id]
    attrs[:type] = SearchRequest::CompanyInfo.to_s
    attrs
  end

  def insert_company_info
    ActiveRecord::Base.transaction do

      SearchRequest::CompanyInfo.insert_all!(@attrs)

      ids = SearchRequest::CompanyInfo.eager_load(:result)
                                      .where('requested_urls.request_id = ? AND requested_urls.type = "SearchRequest::CompanyInfo" AND results.id IS NULL', @request_id)
                                      .pluck(:id)

      result_attrs = ids.map { |id| { requested_url_id: id, created_at: Time.zone.now, updated_at: Time.zone.now } }

      Result.insert_all!(result_attrs)
    end
  end

  def insert_normal
    ActiveRecord::Base.transaction do
      @class.insert_all!(@attrs)
    end
  end
end

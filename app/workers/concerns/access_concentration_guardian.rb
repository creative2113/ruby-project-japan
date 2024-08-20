module AccessConcentrationGuardian

  def exec_other_request_now?
    return false unless @requested_url.corporate_list?
    return false if key.blank?

    redis = Redis.new
    res = redis.get(key)

    if res.blank?
      return false if execute?
    else
      case res.split(' ')[1]
      when 'TEST'
      when 'MULTI'
      when 'SINGLE'
        if @requested_url.type == SearchRequest::CorporateList::TYPE
          return false if execute?
        else
          sleep rand(2) + 1
          return false
        end
        return false 
      else
      end
    end

    set_reserve_mark if @requested_url.test?

    puts "CANCEL #{@req.id} #{@requested_url.id} : #{@requested_url.url}"
    true
  end

  def delete_current_mark
    return false unless @requested_url.corporate_list?
    return false if key.blank?

    redis = Redis.new
    res   = redis.get(key)

    return if res.blank? || res.split(' ')[0].to_i != @requested_url.id

    redis.del(key)
  end

  private

  def execute?
    if !reserved?
      set_mark
      delete_reserve_mark if selef_reservation?
      true
    else
      false
    end
  end

  def set_mark

    val, expire = if @req.test?
      ['TEST', 90]
    elsif @requested_url.type == SearchRequest::CorporateList::TYPE
      ['MULTI', 2]
    elsif @requested_url.type == SearchRequest::CorporateSingle::TYPE
      ['SINGLE', 1]
    else
      ['OTHER', 10]
    end
    value = "#{@requested_url.id} #{val}"

    redis = Redis.new
    res = redis.multi do |pipeline|
      pipeline.set(key, value)
      pipeline.expire(key, expire)
    end
  end

  def set_reserve_mark
    return unless @requested_url.test?

    return if reserved?

    redis = Redis.new
    res = redis.multi do |pipeline|
      pipeline.set(key, @requested_url.id)
      pipeline.expire(key, 15*60)
    end
  end

  def reserved?
    redis = Redis.new
    res = redis.get(reserve_key)
    return false if res.blank?

    return false if res.to_i == @requested_url.id

    req_url = SearchRequest::CorporateList.where(id: res.to_i).unfinished.test_mode.first
    if req_url.blank?
      delete_reserve_mark
      return false
    end

    true
  end

  def selef_reservation?
    redis = Redis.new
    res = redis.get(reserve_key)
    return false if res.blank?

    res.to_i == @requested_url.id
  end

  def delete_reserve_mark
    redis = Redis.new
    redis.del(reserve_key)
  end

  def key
    @domain
  end

  def reserve_key
    "reserve #{@domain}"
  end
end
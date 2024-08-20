class Rediser

  def initialize
    @redis = Redis.new
  end

  def get_count(key)
    count = @redis.get(key)
    count.present? ? count.to_i + 1 : 1
  end

  def set_count(key, value, expire = 15*60)
    @redis.multi do |pipeline|
      pipeline.set(key, value)
      pipeline.expire(key, expire)
    end
  end

  def set_times(key, value = Time.zone.now, max_count = 5, expire = 3*60*60)
    raise ArgumentError, 'Arg value class must be Time or ActiveSupport::TimeWithZone.' unless value.class == ActiveSupport::TimeWithZone || value.class == Time

    times = get_times(key)
    while times.size >= max_count do
      times.delete_at(0)
    end
    times << value

    @redis.multi do |pipeline|
      pipeline.set(key, times.to_json)
      pipeline.expire(key, expire)
    end
  end

  def reset_times(key, expire = 3*60*60)
    @redis.multi do |pipeline|
      pipeline.set(key, [].to_json)
      pipeline.expire(key, expire)
    end
  end

  def get_times(key)
    times = @redis.get(key)
    times = times.present? ? JSON.parse(times) : []
    times.map { |time| time&.to_time }
  end
end

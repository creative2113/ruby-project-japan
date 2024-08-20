class Hash
  def hide_num
    h = {}
    self.each do |k, v|
      if v.class == Hash
        h.store(k, v.hide_num)
      elsif v.class == Array
        h.store(k, v.hide_num)
      elsif v.class == Integer
        h.store(k, v.to_s.gsub(/[0-9]/,'*').gsub(/[０-９]/,'*'))
      elsif v.class == NilClass
        h.store(k, v)
      else
        h.store(k, v.gsub(/[0-9]/,'*').gsub(/[０-９]/,'*'))
      end
    end
    h
  end

  # {a:1,b:2,c:3,d:4,e:5} => [:a, 1, :b, 2], [:a, 1, :c, 3], [:a, 1, :d, 4], [:a, 1, :e, 5], [:b, 2, :c, 3], [:b, 2, :d, 4], [:b, 2, :e, 5], [:c, 3, :d, 4], [:c, 3, :e, 5], [:d, 4, :e, 5]
  def each_combination
    tmp_hash = if self.count > 600
      self.sample(600).dup
    else
      self.dup
    end

    tmp_hash.each_with_index do |(k1, v1),  i|
      tmp_hash.each_with_index do |(k2, v2), j|
        next if i >= j

        yield k1, v1, k2, v2
      end
    end
  end

  def sample(num)
    raise ArgumentError, 'argument number should be smaller than element size.' if self.count < num
    tmp_keys = self.keys.sample(num).dup

    tmp_keys.map { |key| [key, self[key]] }.to_h
  end

  def all_values_presents?
    self.each do |k,v|
      return false unless v.presents?
    end
    true
  end

  def to_key_value
    res = self.map { |k, v| "#{k}=#{v}" }
    res.join(' ')
  end

  def cut_by_range(range)
    keys = self.keys[range]
    keys.map { |key| [key, self[key]] }.to_h
  end

  def store_after(key, value, after_key)
    if self.has_key?(key)
      tmp = self.deep_dup
      tmp[key] = value
      return tmp
    end

    before_hash = {}
    after_hash = {}
    flg = false

    self.each do |k, v|
      flg ? after_hash[k] = v : before_hash[k] = v
      flg = true if k == after_key
    end

    before_hash[key] = value
    before_hash.merge(after_hash)
  end

  def max_value
    max = self.values.max
    self.select { |k,v| v == max }
  end
end
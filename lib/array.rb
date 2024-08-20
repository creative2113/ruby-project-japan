class Array
  def hide_num
    a = []
    self.each do |v|
      if v.class == Hash
        a.push(v.hide_num)
      elsif v.class == Array
        a.push(v.hide_num)
      elsif v.class == Integer
        a.push(v.to_s.gsub(/[0-9]/,'*').gsub(/[０-９]/,'*'))
      elsif v.class == NilClass
        a.push(v)
      else
        a.push(v.gsub(/[0-9]/,'*').gsub(/[０-９]/,'*'))
      end
    end
    a
  end

  def average
    return nil if self.blank?
    self.sum.fdiv(self.length)
  end

  def include_initialize_element?(word)
    self.each do |ele|
      return true if word[0..ele.length-1] == ele
    end
    false
  end

  def include_all?(arr)
    raise ArgumentError, 'argument must be array.' unless arr.class == Array
    arr.each do |el|
      return false unless self.include?(el)
    end
    true
  end

  def include_each_element?(array)
    if array.class == String
      return false if array.clean.empty?
      array = [array]
    end
    self.each do |ele1|
      array.each do |ele2|
        if ele1.class == String && ele2.class == String
          ele1 = ele1.clean.downcase
          ele2 = ele2.clean.downcase
          return true if ele1.include?(ele2) || ele2.include?(ele1)
        else
          return true if ele1 == ele2
        end
      end
    end
    false
  end

  def equal_each_one_element?(array)
    if array.class == String
      return false if array.clean.empty?
      array = [array]
    end
    self.each do |ele1|
      array.each do |ele2|
        return true if ele1 == ele2
      end
    end
    false
  end

  # [1,2,3,4,5] => [1, 2], [1, 3], [1, 4], [1, 5], [2, 3], [2, 4], [2, 5], [3, 4], [3, 5], [4, 5]
  def each_combination
    tmp_arr = if self.count > 800
      self.sample(800).dup
    else
      self.dup
    end

    tmp_arr.each_with_index do |con1, i|
      tmp_arr.each_with_index do |con2, j|
        next if i >= j

        yield con1, con2
      end
    end
  end

  def each_combination_with_index
    tmp_arr = if self.count > 800
      self.sample(800).dup
    else
      self.dup
    end

    self.each_with_index do |con1, i|
      self.each_with_index do |con2, j|
        next if i >= j

        yield con1, i, con2, j
      end
    end
  end

  def bulk_delete(pos_index_arr)
    raise ArgumentError, 'argument must be array' unless pos_index_arr.class == Array
    pos_index_arr.uniq!
    pos_index_arr.each { |num| raise ArgumentError, 'array contens must be integer' unless num.class == Integer }

    pos_index_arr.sort.reverse.each do |num|
      self.delete_at(num)
    end
    self
  end

  def exclude_content_include(words)
    arr = []

    self.each do |content|
      arr << content unless content.one_include?(words)
    end

    arr
  end

  # Only String Array
  # size = 1000 -> 9.8 sec
  # size = 2000 -> 38.7 sec
  # size = 4000 -> 164.0 sec
  def insert_to_similar_part(content)
    raise unless content.class == String
    idx = 0

    self.each_with_index do |str, i|
      if self[i+1].nil?
        idx = i + 1
        break
      end

      cm1 = str&(content)
      cm2 = self[i+1]&(content)

      if cm1.size > cm2.size
        idx = i + 1
        break
      end
    end

    self.insert(idx, content)
  end

  def get_index_to_insert_to_similar_part(content)
    raise unless content.class == String
    idx = 0

    self.each_with_index do |str, i|
      if self[i+1].nil?
        idx = i + 1
        break
      end

      cm1 = str&(content)
      cm2 = self[i+1]&(content)

      if cm1.size > cm2.size
        idx = i + 1
        break
      end
    end

    idx
  end

  def all_blank?
    self.each { |val| return false unless val.blank? }
    true
  end

  def count_present_value
    cnt = 0
    self.each { |val| cnt += 1 if val.present? }
    cnt
  end

  def delete_first(elemnt)
    position = nil
    self.each_with_index { |el, i| (position = i; break) if el == elemnt }
    return nil if position.nil?
    self.delete_at(position)
  end

  def group
    res = {}
    self.map do |con|
      if res.has_key?(con)
        res[con] = res[con] + 1
      else
        res[con] = 1
      end
    end
    res
  end

  def sorting_add(arr)
    # 引数arrの並び順をベースにしながら、配列同士をマージする。
    # [0,2,2,4,7,8,11].sorting_add([1,2,3,2,5,6,8,9,10]) => [1, 0, 2, 3, 2, 5, 6, 4, 7, 8, 9, 10, 11]

    s_arr = self.dup
    b_arr = arr.dup

    new_arr = []
    (s_arr.size + arr.size + 10).times do |i|
      if s_arr.empty? && b_arr.empty?
        break
      elsif s_arr.empty? && !b_arr.empty?
        new_arr << b_arr[0]
        b_arr.shift

      elsif !s_arr.empty? && b_arr.empty?
        new_arr << s_arr[0]
        s_arr.shift

      elsif s_arr[0] == b_arr[0]
        new_arr << s_arr[0]
        s_arr.shift
        b_arr.shift

      elsif s_arr.include?(b_arr[0]) && b_arr.include?(s_arr[0])
        new_arr << b_arr[0]
        s_arr.delete_first(b_arr[0])
        b_arr.shift

      elsif !s_arr.include?(b_arr[0]) && b_arr.include?(s_arr[0])
        new_arr << b_arr[0]
        b_arr.shift

      elsif s_arr.include?(b_arr[0]) && !b_arr.include?(s_arr[0])
        new_arr << s_arr[0]
        s_arr.shift

      elsif !s_arr.include?(b_arr[0]) && !b_arr.include?(s_arr[0])
        new_arr << b_arr[0]
        b_arr.shift

      end
    end
    new_arr
  end
end

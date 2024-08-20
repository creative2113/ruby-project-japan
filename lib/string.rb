require 'nkf'

class String

  # 対象文字列が配列の単語を1つでも含んでいるかどうか
  def include_array_content(array, order = false)
    res = []
    array.each do |content|
      if self.include?(content)
        res << {content: content, index: self.index(content)}
      end
    end

    if order && !res.empty?
      res.sort!{ |a, b| a[:index] <=> b[:index]}
    end
    res
  end

  def longer_than?(char)
    if self.size > char.size
      return true
    else
      return false
    end
  end

  # 先頭から共通文字列を抜き出す
  def &(str)
    # k = $KCODE # $KCODEはRUBY上で日本語の文字コードを保存しているグローバル変数
    # $KCODE='u'
    a = self.split(//).zip(str.split(//)).map{ |e| e.uniq.size==1 }
    idx = a.index(false)
    return self if idx == nil
    return self[0...idx]
    # $KCODE= k
  end

  # 末尾から共通文字列を抜き出す 
  def revers_common_part(str)
    self.reverse.&(str.reverse).reverse
  end

  def cut_after(str, from_end: false)
    return self unless self.include?(str)
    idx = self.index(str)
    idx = self.rindex(str) if from_end
    return '' if idx == 0
    self[0..idx-1]
  end

  def cut_end_chr(cut_num)
    raise ArgumentError, 'argument must be smaller than string length.' if self.length < cut_num
    self[0..-cut_num-1]
  end

  def cut_front(str)
    same_front?(str) ? self[str.size..-1] : self
  end

  def cut_end(str)
    same_end?(str) ? self[0..-str.size-1] : self
  end

  def same_end?(str)
    self[-str.size..-1] == str
  end

  def same_front?(str)
    self[0..str.size-1] == str
  end

  def is_url?
    self[0..6] == 'http://' || self[0..7] == 'https://'
  end

  def include_url?
    self.include?('http://') || self.include?('https://')
  end

  def clean
    self.strip.delete_line_brake.delete_space
  end

  def simplify
    begin
      self.double_line_break_to_single.double_space_to_single.strip
    rescue => e
      puts e
      self.strip
    end
  end

  def more_simplify
    begin
      self.double_line_break_to_single.line_break_to_space.double_space_to_single.strip
    rescue => e
      puts e
      self.strip
    end
  end

  def split_simply
    self.full_space_to_half_space.line_break_to_space.split(' ')
  end

  def full_space_to_half_space
    self.gsub('　', ' ')
  end

  def unify_space
    self.gsub(/\u00A0/, ' ')
  end

  def to_half_and_down
    self.to_half.downcase
  end

  def to_half
    if self.size == NKF.nkf('-w -Z0', self).size
      NKF.nkf('-w -Z0', self)
    else
      tmp = ''
      self.each_char { |c| tmp = "#{tmp}#{NKF.nkf('-w -Z0', c)}" }
      tmp
    end
  end

  def unify_line_break
    self.gsub(/\r\n|\r/, "\n")
  end

  def line_break_to_space
    self.gsub(/\r\n|\r|\n/, ' ')
  end

  def delete_line_brake
    self.gsub(/\r\n|\r|\n/, '')
  end

  def unify_hyphen
    self.gsub('-','-').gsub('ー','-').gsub('‐','-').gsub('‑','-').gsub('–','-').gsub('—','-')
        .gsub('―','-').gsub('−','-').gsub('ｰ','-').gsub('－','-')
  end

  def double_space_to_single
    str = self.full_space_to_half_space.gsub(/\t|\f|\v|[\u00A0]/, ' ')
    while str.include?('  ')
      str = str.gsub('  ', ' ')
    end
    str
  end

  def hyper_strip
    self.gsub(/^[\t\f\v\u00A0\s\p{blank}]+/, '').gsub(/[\t\f\v\u00A0\s\p{blank}]+$/, '')
  end

  def double_line_break_to_single
    str = self.unify_line_break
    while str.include?("\n\n")
      str = str.gsub("\n\n", "\n")
    end
    str
  end

  def delete_space
    self.full_space_to_half_space.gsub(' ', '').gsub(/\t|\f|\v|[\u00A0]/, '')
  end

  def until_next_space
    hyper_strip.line_break_to_space.double_space_to_single.split(' ')[0]
  end

  def one_include?(words_arr)

    if words_arr.class == String
      return self.include?(words_arr) ? true : false
    end

    words_arr.each do |w|
      return true if self.include?(w)
    end
    false
  end

  def one_equal?(words_arr)
    if words_arr.class == String
      return self == words_arr ? true : false
    end

    words_arr.each do |w|
      return true if self == w
    end
    false
  end

  def one_initialize_from?(words_arr)

    if words_arr.class == String
      return self.include?(words_arr) ? true : false
    end

    words_arr.each do |w|
      return true if self[0..w.length-1] == w
    end
    false
  end

  def what_include?(words_arr)
    words_arr.each do |w|
      return w if self.include?(w)
    end
    false
  end

  def what_equal?(words_arr)
    words_arr.each do |w|
      return w if self == w
    end
    false
  end

  def split_by_newline
    words = []
    self.split(/\R/).each do |row_word|
      w = row_word.gsub("\t", ' ').gsub("\v", ' ').strip
      next if w.empty?
      words << w
    end
    words
  end

  def split_and_trim(delimiter)
    tmp = self.split(delimiter).map { |w| w.strip }
    tmp.select { |w| w.present? }
  end

  def split_by_multi(arr)
    mark = '##$%#$%#$%##'
    str = self.dup
    arr.each { |w| str = str.gsub(w, mark) }
    str.split(mark)
  end

  def gsub_by_multi(before_str_arr, after_str)
    str = self.dup
    before_str_arr = before_str_arr.sort_by {|w| -w.size}

    before_str_arr.each { |w| str = str.gsub(w, after_str) }

    str
  end

  def chop_by(regx, also_half: true)
    tmp_str = self.dup
    tmp_str.length.times do |_|
      char = also_half ? tmp_str[-1].to_half_and_down : tmp_str[-1]
      break unless char.match?(regx)
      tmp_str.chop!
    end
    tmp_str
  end

  def multi_index(arr)
    reg = ''
    arr.each { |w| reg = "#{reg}#{w}|" }
    reg.chop!

    reg = reg.gsub('[', '\\[').gsub(']', '\\]').gsub('$', '\\$').gsub('(', '\\(').gsub(')', '\\)').gsub('~', '\\~')
             .gsub('^', '\\^').gsub('?', '\\?').gsub('+', '\\+').gsub('*', '\\*').gsub('{', '\\{').gsub('}', '\\}')
             .gsub('.', '\\.').gsub('/', '\\/')

    self.index(/#{reg}/)
  end

  def multi_rindex(arr)
    reg = ''
    arr.each { |w| reg = "#{reg}#{w}|" }
    reg.chop!

    self.rindex(/#{reg}/)
  end

  # 記号を削除する
  def rm_symbol
    self.gsub(/[^\p{Hiragana}|\p{Katakana}|\p{Han}|a-zA-Z0-9]/, '')
  end

  def push(element)
    [self, element]
  end

  def to_base_name
    ext = File.extname(self)
    File.basename(self, ext)
  end

  def pj
    JSON.parse(self)
  end

  def to_path
    self.split('/').map { |tag| tag.split('$$')[0] }.join('/')
  end
end

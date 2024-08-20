class Excel
  class Import
    attr_reader :row_max, :col_max

    def initialize(file_path, sheet_num_or_name = 1, header = false)
      raise 'InvalidExtension' unless file_path[-5..-1].downcase == '.xlsx'
      @path    = file_path
      @book    = RubyXL::Parser.parse(@path)
      if sheet_num_or_name.class == Numeric || sheet_num_or_name.class == Integer
        sheet_num_or_name = sheet_num_or_name - 1
      end
      @sheet   = @book[sheet_num_or_name] # シート番号0始まり、または、シート名でもいい
      @row_max = @sheet.dimension.ref.row_range.max # 0始まり
      @col_max = @sheet.dimension.ref.col_range.max # 0始まり
      @header  = header
    end

    # col_numは1始まり
    def get_one_column_values(col_num, max_row)
      res       = []
      col_num = 1 if col_num < 1
      start_row = @header ? 1 : 0 # ヘッダーがあるかないかで開始行が変わる
      max_row  -= @header ? 0 : 1 # ヘッダーがあるかないかで終了行が変わる
      end_row   = max_row < @row_max ? max_row : @row_max
      start_row.upto(end_row) do |i|
        val = ( @sheet[i][col_num-1].nil? ? '' : @sheet[i][col_num-1].value.to_s )
        res << ( val.nil? ? '' : val.strip )
      end
      res
    end

    # インデックスはEXCELの行数(先頭行は1)
    def get_one_column_values_with_index(col_num, max_row)
      res       = {}
      col_num = 1 if col_num < 1
      start_row = @header ? 1 : 0 # ヘッダーがあるかないかで開始行が変わる
      max_row  -= @header ? 0 : 1 # ヘッダーがあるかないかで終了行が変わる
      end_row   = max_row < @row_max ? max_row : @row_max

      start_row.upto(end_row) do |i|
        val = ( @sheet[i].nil? || @sheet[i][col_num-1].nil? ) ? '' : @sheet[i][col_num-1].value.to_s
        res.store(i + 1, val.nil? ? '' : val.strip)
      end
      res
    end

    # ヘッダーによらない
    def get_row(row_num = 1, max_column = 50)
      res = []
      row_num = 1 if row_num < 1
      max_column -= 1
      end_col = max_column < @col_max ? max_column : @col_max
      0.upto(end_col) do |i|
        val = ( @sheet[row_num - 1][i].nil? ? '' : @sheet[row_num - 1][i].value.to_s ) # row番号は0始まり
        res << ( val.nil? ? '' : val.strip )
      end
      res
    end

    def get_row_with_header(row_num = 1, max_column = 50)
      return nil if @row_max + 1 < row_num
      @header_names = get_row(1, max_column) if @header_names.blank?
      contents      = get_row(row_num, max_column)

      res = {}
      @header_names.each_with_index do |hd, i|
        hd = "ヘッダー#{i}" if hd.blank?
        res[hd] = contents[i]
      end
      res
    end

    def to_hash_data
      res              = {sheet_name: nil, col_max: @col_max, row_max: @row_max, data: {} }
      res[:sheet_name] = @sheet.sheet_name

      # end_row = @header ? @row_max : @row_max + 1 # ヘッダーがあるかないかで終了行が変わる

      row = 1
      while @row_max + 1 >= row do
        res[:data].store(row, get_row(row, @col_max + 1) )
        row += 1
      end

      res
    end
  end

  class Export
    attr_reader :save_result, :reach_limit, :cel_cnt

    def initialize(file_path, sheet_name = nil, auto_save: false, auto_save_cels_limit: 1_000_000, initialize_header: true)
      raise 'InvalidExtension' unless file_path[-5..-1].downcase == '.xlsx'
      @path         = file_path
      @book         = RubyXL::Workbook.new
      @sheet        = @book[0]
      @sheet_name   = sheet_name
      @header       = false if initialize_header
      @header_names = []    if initialize_header
      @row_num      = 0
      @chr_length   = 0
      @chr_size     = 0
      @max_col      = 0
      @header_cnt   = 0
      @cel_cnt      = 0
      @reach_limit  = false

      @auto_save            = auto_save
      @auto_save_cels_limit = auto_save_cels_limit

      @sheet.sheet_name = @sheet_name unless @sheet_name.nil?
    end

    def add_header(*headers)
      headers.each { |h| return false unless h.class == Array }
      @header_cnt   = headers.flatten.size
      @max_col      = @header_cnt
      @header_names = headers

      cnt = 0
      @start_col_map = headers.map do |h_names|
        val = cnt
        cnt = cnt + h_names.count
        val
      end

      cnt = -1
      headers.each do |h_names|
        h_names.each do |h|
          cnt += 1
          next if h.blank?
          @sheet.add_cell(0, cnt, check_cell(h.to_s))
        end
      end
      @header  = true
      @row_num = 1
      true
    end

    # 順番に詰め込む配列を渡すか、ヘッダーをキーとしたハッシュを渡すか
    def add_row_contents(*contents)
      @save_result = {result: :none}
      return false if @header_names.present? && contents.size > @header_names.size

      cnt = 0
      contents.each_with_index do |each_content, i|

        if each_content.class == Array
          each_content.each_with_index do |c, j|
            offset = @header ? @start_col_map[i] : cnt
            next if c.blank?
            @sheet.add_cell(@row_num, j+offset, check_cell(c.to_s))
          end
          cnt += each_content.size

        elsif each_content.class == Hash
          # ヘッダーが空の時、ヘッダー名がダブっている時は使えない

          raise 'NoHeader' unless @header

          @header_names[i].each_with_index do |h, j|
            next if each_content[h].blank?

            @sheet.add_cell(@row_num, j+@start_col_map[i], check_cell(each_content[h].to_s))
          end
        else
          raise 'InvalidContents'
        end

      end

      @max_col = cnt if @max_col < cnt

      @row_num += 1

      if @auto_save_cels_limit < @cel_cnt # 80,000　=>sidekiq止める、 160,000 => 800M程度消費（autosave）
        @reach_limit = true
      end

      if @auto_save && @reach_limit
        execute_auto_save
      end

      true
    rescue => e
      false
    end

    def execute_auto_save
      GC.start
      if save
        hd_names = @sheet[0].cells.map { |d| d.value } if @header
        header_names = @header_names.deep_dup if @header

        @sheet = nil
        GC.start
        initialize(@path, @sheet_name, auto_save: @auto_save, auto_save_cels_limit: @auto_save_cels_limit, initialize_header: false)
        add_header(*header_names) if @header
        true
      else
        false
      end
    rescue => e
      Lograge.logging('fatal', { class: self.class.to_s, method: 'execute_auto_save', issue: 'EXCEL Auto Save Initialize Error', err_msg: e.message, backtrace: e.backtrace })
      @save_result = { result: :initialize_failure, error: "#{e.class} #{e.message}", file_name: @path.split('/')[-1] }
      false
    end

    def save
      @save_result = {result: :none}
      return false if @auto_save && @row_num == 1

      @start_time = Time.now
      # notice('エクセルファイル作成　前')
      MyLog.new('my_crontab').log "[#{Time.zone.now}][EXCEL][#make] START  #{Memory.free_and_available} [セル数: #{@cel_cnt.to_s(:delimited)} ] [行数: #{@row_num.to_s(:delimited)} ] [列数: #{@max_col.to_s(:delimited)} ] [文字バイトサイズ: #{@chr_size.to_s(:delimited)} ] [文字数: #{@chr_length.to_s(:delimited)} ]"
      @book.write(@path)
      MyLog.new('my_crontab').log "[#{Time.zone.now}][EXCEL][#make] END    #{Memory.free_and_available} [セル数: #{@cel_cnt.to_s(:delimited)} ] [行数: #{@row_num.to_s(:delimited)} ] [列数: #{@max_col.to_s(:delimited)} ] [文字バイトサイズ: #{@chr_size.to_s(:delimited)} ] [文字数: #{@chr_length.to_s(:delimited)} ]"
      # notice('エクセルファイル作成　後')

      @save_result = { result: :done, path: @path, file_name: @path.split('/')[-1] }
      true
    rescue => e
      Lograge.logging('fatal', { class: self.class.to_s, method: 'save', issue: 'EXCEL File Save Error', err_msg: e.message, backtrace: e.backtrace })
      @save_result = { result: :failure, error: "#{e.class} #{e.message}", file_name: @path.split('/')[-1] }
      false
    end

    private

    def make_file_name(path)
      tmp_path = @path
      tmp_path = increment_file_name(@path, type: :pre) if path.nil? && @auto_save
      tmp_path = path if path.present?
      @file_name = tmp_path.split('/')[-1]
      tmp_path
    end

    def increment_file_name(path, type: :pre)
      fname = path.split('/')[-1]
      ext   = fname.split('.')[-1]
      @file_name_increment = @file_name_increment.present? ? @file_name_increment + 1 : 1
      if type == :sur
        @new_fname = fname.sub(/\.#{ext}$/,"_#{@file_name_increment}.#{ext}")
      else
        @new_fname = "#{@file_name_increment}_#{fname}"
      end
      path.sub(/#{fname}$/,@new_fname)
    end

    def notice(title)
      return if Rails.env.test?

      mem = if Rails.env.development?
        `top -l 1 | grep Mem`
      else
        `free -mt`
      end

      body = "[ファイルパス: #{@path} ] \n [メモリー: #{mem} ] \n [時間: #{Time.now - @start_time} ] \n [セル数: #{@cel_cnt.to_s(:delimited)} ] \n [行数: #{@row_num.to_s(:delimited)} ] \n [列数: #{@max_col.to_s(:delimited)} ] \n [文字バイトサイズ: #{@chr_size.to_s(:delimited)} ] \n [文字数: #{@chr_length.to_s(:delimited)} ]"

      NoticeMailer.deliver_later(NoticeMailer.notice_simple(body, title))
    end

    def check_cell(str)
      str = str.gsub(/\n|\r|\r\n/, "\n")
      str = str.hyper_strip
      str = str.unify_space
      str = str.gsub(/\u0001|\u0002|\u0003|\u0004|\u0005|\u0006|\u0007|\u0008|\u0009|\u000B|\u000C|\u000D|\u000E|\u000F/, ' ')
      str = str.gsub(/\u0011|\u0012|\u0013|\u0014|\u0015|\u0016|\u0017|\u0018|\u0019|\u001A|\u001B|\u001C|\u001D|\u001E|\u001F/, ' ')
      str = str.gsub(/\u0081|\u0082|\u0083|\u0084|\u0085|\u0086|\u0087|\u0088|\u0089|\u008A|\u008B|\u008C|\u008D|\u008E|\u008F/, ' ')
      str = str.gsub(/\u0091|\u0092|\u0093|\u0094|\u0095|\u0096|\u0097|\u0098|\u0099|\u009A|\u009B|\u009C|\u009D|\u009E|\u009F/, ' ')
      str = str[0..29_999] if str.size > 30_000

      if str.scan(/\n/).size >= 249
        str = str.split("\n")
        str = str[0..249].join("\n") + "\n" + str[250..-1].join(' ')
      end

      @cel_cnt += 1
      @chr_length += str.size
      @chr_size   += str.bytesize

      str
    end
  end
end
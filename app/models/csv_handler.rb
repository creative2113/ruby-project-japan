require 'csv'

class CsvHandler
  # BOM付きのCSVはエラーになる。
  # 大きなファイルのメモリ効率も考慮し、CSV.foreachで対応することを検討
  def initialize(csv_string, header)
    @header = header
    @data   = CSV.parse(csv_string, headers: @header)
  end

  def get_one_column_values(col_num, max_row)
    res       = []
    start_row = @header ? 1 : 0 # ヘッダーがあるかないかで開始行が変わる
    max_row  -= @header ? 0 : 1 # ヘッダーがあるかないかで終了行が変わる
    @data.each_with_index do |data, i|
      break if max_row < i + start_row
      res << ( data[col_num-1].nil? ? '' : data[col_num-1].strip )
    end
    res
  end

  # インデックスはCSVの行数(先頭行は1)
  def get_one_column_values_with_index(col_num, max_row)
    res       = {}
    start_row = @header ? 1 : 0 # ヘッダーがあるかないかで開始行が変わる
    max_row  -= @header ? 0 : 1 # ヘッダーがあるかないかで終了行が変わる
    @data.each_with_index do |data, i|
      break if max_row < i + start_row
      res.store(i + start_row + 1, data[col_num-1].nil? ? '' : data[col_num-1].strip)
    end
    res
  end

  def get_row(row_num = 1, max_column)
    row_num = 1 if row_num < 1

    return @data.headers[0..max_column - 1] if @header && row_num == 1

    row_num -= @header ? 2 : 1
    return nil if @data[row_num].nil?

    @data[row_num][0..max_column - 1]
  end

  def to_hash_data
    res = {}
    row = 1
    if @header
      res.store(row, @data.headers)
      row += 1
    end

    @data.each do |data|
      data = @header ? data.values_at : data
      res.store(row, data)
      row += 1
    end

    res
  end

  class Import < CsvHandler
    def initialize(file_path, header)
      raise 'File extension should be "csv".' unless file_path[-4..-1].downcase == '.csv'
      @header = header
      @path   = file_path
      begin
        @data = CSV.read(@path, headers: @header, encoding: 'SJIS:UTF-8')
      rescue => e
        if e.class == Encoding::UndefinedConversionError && e.message.include?('from Windows-31J to UTF-8') &&
           ( e.message.include?('\xEF') || e.message.include?('\xef') )
          @data = CSV.read(@path, encoding: 'BOM|UTF-8', headers: @header)
        else
          begin
            @data = CSV.read(@path, headers: @header, encoding: 'CP932:UTF-8')
          rescue => e
            @data = CSV.read(@path, headers: @header, encoding: 'UTF-8')
          end
        end
      end
    end
  end

  class Export
    attr_reader :save_result

    class InvalidExtensionError < StandardError; end
    class InvalidContentsError < StandardError; end
    class AutoSavedError < StandardError; end

    def initialize(file_path, bom: true, auto_save: false, auto_save_byte_limit: 10_000_000)
      raise InvalidExtensionError, 'File extension should be "csv".' unless file_path[-4..-1].downcase == '.csv'
      @path       = file_path
      @bom        = bom
      @auto_save  = auto_save
      @header     = []
      @chr_size   = 0
      @cel_cnt    = 0
      @chr_length = 0
      @auto_save_byte_limit = auto_save_byte_limit

      # CSV.openではBOMの書き出しが難しい
      # FileクラスはIOが使える
      @file_io = File.open(@path, 'w')
      @file_io.sync = true
      @file_io.print("\xEF\xBB\xBF") if @bom #UTF-8のbomを先頭に追加
    end

    def add_header(*headers)
      headers.each { |h| return false unless h.class == Array }
      @header     = headers
      @header_cnt = headers.flatten.size

      tmp_header = @header.map { |hds| hds.map { |str| check_cell(str) } }

      @file_io.puts(tmp_header.flatten.to_csv(:force_quotes => true))
      true
    end

    # 順番に詰め込む配列を渡すか、ヘッダーをキーとしたハッシュを渡すか
    def add_row_contents(*contents)
      raise AutoSavedError, 'Can not add row because auto saved already.' if @close
      @save_result = {result: :none}

      type = nil

      res_contents = []
      contents.each_with_index do |each_content, i|

        if each_content.class == Array

          if @header.blank?
            res_contents << each_content
          else
            next if @header[i].blank?
            headers_map = @header[i].map.with_index { |h, j| [h, ( each_content[j] || '' )]}.to_h
            res_contents << headers_map.values
          end
        elsif each_content.class == Hash

          next if @header[i].blank?

          headers_map = @header[i].map { |h| [h, '']}.to_h

          each_content.each do |h, val|
            headers_map[h] = val.to_s if headers_map.has_key?(h)
          end
          res_contents << headers_map.values
        else
          raise InvalidContentsError, 'Contents must be Array or Hash.'
        end
      end

      res_contents = res_contents.flatten

      res_contents = res_contents.map { |str| check_cell(str) }

      puts_contents(res_contents)

      if @auto_save && @chr_size > @auto_save_byte_limit
        if save
          @save_result = { result: :done, path: @path, file_name: @path.split('/')[-1] }
        else
        end
        @close = true
      end

      true
    end

    def save
      @file_io.close
      @save_result = { result: :done, path: @path, file_name: @path.split('/')[-1] }
      true
    rescue => e
      Lograge.logging('fatal', { class: self.class.to_s, method: 'save', issue: 'CSV File Save Error', err_msg: e.message, backtrace: e.backtrace })
       @save_result = { result: :failure, error: "#{e.class} #{e.message}", file_name: @path.split('/')[-1] }
      false
    end

    private

    def puts_contents(contents)
      @file_io.puts(contents.to_csv(:force_quotes => true))
    end

    def check_cell(str)
      # str = str.gsub(/\n|\r|\r\n/, "\n") # エクセルで開いた時に、セル内改行になることを確認済み。ただ、テキストで開けば、CSVとしては、不自然な改行になる。改行にするか、空白にするのがいいかはユーザにしか決められない。
      str = str.gsub(/\n|\r|\r\n/, ' ')
      str = str.hyper_strip
      str = str.unify_space
      str = str.gsub(/\u0001|\u0002|\u0003|\u0004|\u0005|\u0006|\u0007|\u0008|\u0009|\u000B|\u000C|\u000D|\u000E|\u000F/, ' ')
      str = str.gsub(/\u0011|\u0012|\u0013|\u0014|\u0015|\u0016|\u0017|\u0018|\u0019|\u001A|\u001B|\u001C|\u001D|\u001E|\u001F/, ' ')
      str = str.gsub(/\u0081|\u0082|\u0083|\u0084|\u0085|\u0086|\u0087|\u0088|\u0089|\u008A|\u008B|\u008C|\u008D|\u008E|\u008F/, ' ')
      str = str.gsub(/\u0091|\u0092|\u0093|\u0094|\u0095|\u0096|\u0097|\u0098|\u0099|\u009A|\u009B|\u009C|\u009D|\u009E|\u009F/, ' ')
      str = str[0..29_999] if str.size > 30_000 # 文字数が多いと、誤動作を起こす可能性がある。 32,767文字でセルがおかしくなった。

      if str.scan(/\n/).size >= 249
        str = str.split("\n")
        str = str[0..249].join("\n") + "\n" + str[250..-1].join(' ')
      end

      @cel_cnt    += 1
      @chr_length += str.size
      @chr_size   += str.bytesize

      str
    end
  end
end

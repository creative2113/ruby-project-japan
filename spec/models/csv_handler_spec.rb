require 'rails_helper'

RSpec.describe CsvHandler::Import, type: :model do
  let(:file_name) { 'normal.csv' }
  let(:file_path) { Rails.root.join('spec', 'fixtures', file_name).to_s }
  let(:csv)       { CsvHandler::Import.new(file_path, false) }

  describe 'BOM付き UTF-8' do
    let(:file_name) { 'bom_utf8.csv' }

    it do
      expect(csv.to_hash_data).to eq({1=>['H1', 'H2', 'H3', 'H4'], 2=>["髙", '﨑', '㌔', 'ｱｲｳｴｵ']})
    end
  end

  describe 'get_one_column_valuesに関して' do

    it 'col1、ヘッダーなし, 10行目までで、存在する5行目まで取れること' do
      expect(csv.get_one_column_values(1, 10)).to eq ['ttps://aaa',
                                                      'https://www.nexway.co.jp',
                                                      '',
                                                      'http://www.hokkaido.ccbc.co.jp/',
                                                      'http:/bbb',
                                                      'https://www.starbucks.co.jp/',
                                                      'https://sample.co.cn']
    end

    it 'col1、ヘッダーなし, 3行目まで' do
      expect(csv.get_one_column_values(1, 3)).to eq ['ttps://aaa',
                                                     'https://www.nexway.co.jp',
                                                     '']
    end

    context 'ヘッダーなしの場合' do
      let(:file_name) { 'sample_with_header.csv' }
      it 'col2、3行目まで取れること' do
        expect(csv.get_one_column_values(2, 3)).to eq ['Header-2', 'Col2-2', 'Col2-3']
      end

      it 'col4、7行目までで、存在する5行目まで取れること' do
        expect(csv.get_one_column_values(4, 7)).to eq ['Header-4', 'Col4-2', 'Col4-3', 'Col4-4', 'Col4-5']
      end

      it '存在しないcol7、10行目の指定で、最大行の5行目まで空文字列の配列として取れること' do
        expect(csv.get_one_column_values(7, 10)).to eq ['', '', '', '', '']
      end
    end

    context 'ヘッダーありの場合' do
      let(:file_name) { 'sample_with_header.csv' }
      let(:csv)       { CsvHandler::Import.new(file_path, true) }

      it 'col1、3行目(2行)まで取れること' do
        expect(csv.get_one_column_values(1, 2)).to eq ['Col1-2', 'Col1-3']
      end

      it 'col3、7行目までで、存在する5行目(4行)まで取れること' do
        expect(csv.get_one_column_values(3, 7)).to eq ['Col3-2', 'Col3-3', 'Col3-4', 'Col3-5']
      end

      it '存在しないcol7、8行目の指定で、ヘッダーを除いた最大行の5行目(4行)まで取れること' do
        expect(csv.get_one_column_values(7, 15)).to eq ['', '', '', '']
      end
    end

  end

  describe 'get_one_column_values_with_indexに関して' do
    let(:file_name) { 'sample_with_header.csv' }

    context 'ヘッダーなしの場合' do
      it 'col2、3行目まで取れること' do
        expect(csv.get_one_column_values_with_index(2, 3)).to eq ( { 1 => 'Header-2', 2 => 'Col2-2', 3 => 'Col2-3' } )
      end

      it 'col3、7行目までで、存在する5行目まで取れること' do
        expect(csv.get_one_column_values_with_index(3, 7)).to eq ( { 1 => 'Header-3', 2 => 'Col3-2', 3 => 'Col3-3',
                                                                     4 => 'Col3-4', 5 => 'Col3-5'} )
      end

      it '存在しないcol7、8行目の指定で、最大行の5行目まで取れること' do
        expect(csv.get_one_column_values_with_index(7, 8)).to eq ( { 1 => '', 2 => '', 3 => '', 4 => '', 5 => ''} )
      end
    end

    context 'ヘッダーありの場合' do
      let(:csv) { CsvHandler::Import.new(file_path, true) }

      it 'col4、4行目(3行)まで取れること' do
        expect(csv.get_one_column_values_with_index(4, 3)).to eq ( { 2 => 'Col4-2', 3 => 'Col4-3', 4 => 'Col4-4'} )
      end

      it 'col1、7行目までで、存在する5行目(4行)まで取れること' do
        expect(csv.get_one_column_values_with_index(1, 7)).to eq ( { 2 => 'Col1-2', 3 => 'Col1-3', 4 => 'Col1-4', 5 => 'Col1-5'} )
      end

      it '存在しないcol7、10行目の指定で、ヘッダーを除いた最大行の5行目(4行)まで取れること' do
        expect(csv.get_one_column_values_with_index(7, 10)).to eq ( { 2 => '', 3 => '', 4 => '', 5 => ''} )
      end
    end
  end

  describe 'get_rowに関して' do
    let(:file_name) { 'sample_with_header.csv' }

    context 'ヘッダーなしの場合' do
      it 'row1、1列目まで取れること' do
        expect(csv.get_row(1, 1)).to eq ['Header-1']
      end

      it 'row1、4列目まで取れること' do
        expect(csv.get_row(1, 3)).to eq ['Header-1', 'Header-2', 'Header-3']
      end

      it 'row3、6列目までの指定で、最大列の4列目まで取れること' do
        expect(csv.get_row(3, 6)).to eq ['Col1-3', 'Col2-3', 'Col3-3', 'Col4-3']
      end

      it 'row4、1列目まで取れること' do
        expect(csv.get_row(4, 1)).to eq ['Col1-4']
      end

      it 'row2、3列目まで取れること' do
        expect(csv.get_row(2, 3)).to eq ['Col1-2', 'Col2-2', 'Col3-2']
      end

      it '存在しないrow6、2列目の指定で、nilが返ること' do
        expect(csv.get_row(6, 2)).to be_nil
      end

      it '存在しないrow6、7列目の指定で、nilが返ること' do
        expect(csv.get_row(6, 7)).to be_nil
      end
    end

    context 'ヘッダーありの場合' do
      let(:csv) { CsvHandler::Import.new(file_path, true) }

      it 'row1、1列目まで取れること' do
        expect(csv.get_row(1, 1)).to eq ['Header-1']
      end

      it 'row1、3列目まで取れること' do
        expect(csv.get_row(1, 3)).to eq ['Header-1', 'Header-2', 'Header-3']
      end

      it 'row5、2列目まで取れること' do
        expect(csv.get_row(5, 2)).to eq ['Col1-5', 'Col2-5']
      end

      it 'row2、1列目までの指定で、1列目まで取れること' do
        expect(csv.get_row(2, 1)).to eq ['Col1-2']
      end

      it 'row3、3列目までの指定で、3列目まで取れること' do
        expect(csv.get_row(3, 3)).to eq ['Col1-3', 'Col2-3', 'Col3-3']
      end

      it 'row4、10列目までの指定で、最大列の4列目まで取れること' do
        expect(csv.get_row(4, 10)).to eq ['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4']
      end

      it 'row1、8列目までの指定で、最大列の4列目まで取れること' do
        expect(csv.get_row(1, 8)).to eq ['Header-1', 'Header-2', 'Header-3', 'Header-4']
      end

      it '存在しないrow6、2列目の指定で、nilが返ること' do
        expect(csv.get_row(6, 2)).to be_nil
      end

      it '存在しないrow6、7列目の指定で、nilが返ること' do
        expect(csv.get_row(6, 7)).to be_nil
      end
    end
  end

  describe '特殊ケースのエクセルに関して' do
    context '改行セルありエクセルの場合' do
      let(:make_csv)  { CsvHandler::Import.new(file_path, true).to_hash_data }
      let(:file_name) { 'linebreak.csv' }
      it '正しく表示されること' do
        expect(make_csv).to eq({ 1 => ['Header1', 'Header2', 'Header3'],
                                 2 => ["\n\n", nil, nil],
                                 3 => [nil, "Line\nBreak\n", 'normal'],
                                 4 => ["Line\nBreak\n", "\nLine\nBreak", 'normal']
                                })
      end
    end
  end
end

RSpec.describe CsvHandler::Export, type: :model do
  let(:correct_file) { Rails.root.join('spec', 'fixtures', 'sample_with_header.csv').to_s }
  let(:file_path)    { Rails.root.join('spec', 'tmp', file_name).to_s }
  let(:file_name)    { 'rspec_test_sample.csv' }
  let(:csv)          { CsvHandler::Export.new(file_path) }
  let(:make_csv)     { CsvHandler::Import.new(file_path, false).to_hash_data }
  let(:correct_csv)  { CsvHandler::Import.new(correct_file, false).to_hash_data }

  context '正常ケース' do

    after { `rm #{file_path}` }

    context 'ヘッダーあり、配列とハッシュを使って作成する場合' do
      let(:file_name) { 'rspec_test_with_header.csv' }
      it '正しいエクセルファイルが作られること' do
        csv.add_header(['Header-1', 'Header-2', 'Header-3', 'Header-4'])
        csv.add_row_contents(['Col1-2', 'Col2-2', 'Col3-2', 'Col4-2'])
        # 余計なヘッダーを混ぜている
        csv.add_row_contents({'Header-1' => 'Col1-3', 'Header-2' => 'Col2-3', 'Header-3' => 'Col3-3',
                              'Header-4' => 'Col4-3', '' => ''})
        csv.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4'])
        # 余計なヘッダーを混ぜている
        csv.add_row_contents({'Header-5' => 'Col5-5', 'Header-1' => 'Col1-5', 'Header-2' => 'Col2-5',
                              'Header-4' => 'Col4-5', 'Header-3' => 'Col3-5'})

        expect(csv.save).to be_truthy

        # BOMで読み込む
        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    context 'ヘッダーあり、ハッシュの組み合わせで作成する場合1' do
      let(:file_name) { 'rspec_test_with_header.csv' }
      it '正しいエクセルファイルが作られること' do
        csv.add_header(['Header-1', 'Header-2'], ['Header-3', 'Header-4'])
        csv.add_row_contents({'Header-1' => 'Col1-2', 'Header-2' => 'Col2-2'}, {'Header-3' => 'Col3-2',
                              'Header-4' => 'Col4-2'})
        # 余計なヘッダーを混ぜている
        csv.add_row_contents({'Header-1' => 'Col1-3', 'Header-2' => 'Col2-3'}, {'Header-3' => 'Col3-3',
                              'Header-4' => 'Col4-3', '' => ''})
        csv.add_row_contents({'Header-1' => 'Col1-4', 'Header-2' => 'Col2-4', 'Header-3' => 'dummy'}, {'Header-2' => 'dummy', 'Header-3' => 'Col3-4',
                              'Header-4' => 'Col4-4', '' => ''})
        # 余計なヘッダーを混ぜている
        csv.add_row_contents({'Header-2' => 'Col2-5', 'Header-5' => 'Col5-5', 'Header-1' => 'Col1-5'}, {'Header-2' => 'Col2-5',
                              'Header-4' => 'Col4-5', 'Header-3' => 'Col3-5'})

        expect(csv.save).to be_truthy

        # BOMで読み込む
        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    context 'ヘッダーあり、ハッシュの組み合わせで作成する場合2' do
      let(:file_name) { 'rspec_test_with_header.csv' }
      it '正しいエクセルファイルが作られること' do
        csv.add_header(['Header-1'], ['Header-2', 'Header-3'], ['Header-4'])
        csv.add_row_contents({'Header-1' => 'Col1-2', 'Header-2' => 'Col2-2'}, {'Header-2' => 'Col2-2', 'Header-3' => 'Col3-2'},
                             {'Header-4' => 'Col4-2'})
        # 余計なヘッダーを混ぜている
        csv.add_row_contents({'Header-1' => 'Col1-3'}, {'Header-2' => 'Col2-3', 'Header-3' => 'Col3-3',
                              'Header-4' => 'Col4-3', '' => ''}, {'Header-4' => 'Col4-3', '' => ''})
        csv.add_row_contents({'Header-1' => 'Col1-4'}, {'Header-2' => 'Col2-4', 'Header-3' => 'Col3-4'},
                             {'Header-4' => 'Col4-4', '' => ''})
        # 余計なヘッダーを混ぜている
        csv.add_row_contents({'Header-5' => 'Col5-5', 'Header-1' => 'Col1-5'}, {'Header-3' => 'Col3-5', 'Header-2' => 'Col2-5',
                              'Header-4' => 'Col4-5'}, {'Header-3' => 'Col3-5', 'Header-4' => 'Col4-5'})

        expect(csv.save).to be_truthy

        # BOMで読み込む
        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    context 'ヘッダーなし、配列を使って作成する場合' do
      let(:file_name) { 'rspec_test_without_header.csv' }
      it '正しいエクセルファイルが作られること' do
        csv.add_row_contents(['Header-1', 'Header-2', 'Header-3', 'Header-4'])
        csv.add_row_contents(['Col1-2', 'Col2-2', 'Col3-2', 'Col4-2'])
        csv.add_row_contents(['Col1-3', 'Col2-3', 'Col3-3', 'Col4-3'])
        csv.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4'])
        csv.add_row_contents(['Col1-5', 'Col2-5', 'Col3-5', 'Col4-5'])

        expect(csv.save).to be_truthy

        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    context 'ヘッダーなし、配列の組み合わせで作成する場合' do
      let(:file_name) { 'rspec_test_without_header.csv' }
      it '正しいエクセルファイルが作られること' do
        csv.add_row_contents(['Header-1', 'Header-2'], ['Header-3', 'Header-4'])
        csv.add_row_contents(['Col1-2', 'Col2-2'], ['Col3-2', 'Col4-2'])
        csv.add_row_contents(['Col1-3'], ['Col2-3', 'Col3-3', 'Col4-3'])
        csv.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4'], ['Col4-4'])
        csv.add_row_contents(['Col1-5'], ['Col2-5', 'Col3-5'], ['Col4-5'])

        expect(csv.save).to be_truthy

        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    context 'ヘッダーあり、配列の組み合わせで作成する場合' do
      let(:file_name) { 'rspec_test_without_header.csv' }
      let(:correct_file) { Rails.root.join('spec', 'fixtures', 'sample_with_header2.csv').to_s }

      it '正しいエクセルファイルが作られること' do
        csv.add_header(['Header-1', 'Header-2'], ['Header-3', 'Header-4'])
        csv.add_row_contents(['Col1-2', 'Col2-2'], ['Col3-2', 'Col4-2'])
        csv.add_row_contents(['Col1-3'], ['Col2-3', 'Col3-3', 'Col4-3'])
        csv.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4'], ['Col4-4'])
        csv.add_row_contents(['Col1-5'], ['Col2-5', 'Col3-5'], ['Col4-5'])

        expect(csv.save).to be_truthy

        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    context 'ヘッダーあり、配列とハッシュの組み合わせで作成する場合' do
      let(:file_name) { 'rspec_test_without_header.csv' }
      it '正しいエクセルファイルが作られること' do
        csv.add_header(['Header-1', 'Header-2'], ['Header-3', 'Header-4'])
        csv.add_row_contents({'Header-1' => 'Col1-2', 'Header-2' => 'Col2-2'}, ['Col3-2', 'Col4-2', 'dummy'])
        csv.add_row_contents(['Col1-3', 'Col2-3', 'dummy'], ['Col3-3', 'Col4-3', 'dummy'])
        csv.add_row_contents(['Col1-4', 'Col2-4'], {'Header-3' => 'Col3-4', 'Header-4' => 'Col4-4'})
        csv.add_row_contents(['Col1-5', 'Col2-5', 'dummy'], {'Header-3' => 'Col3-5', 'Header-4' => 'Col4-5', 'Header-5' => 'dummy'})

        expect(csv.save).to be_truthy

        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq correct_csv
      end
    end

    xcontext 'auto_save' do
      let(:csv)       { CsvHandler::Export.new(file_path, auto_save: true, auto_save_byte_limit: 100) }
      let(:file_name) { 'rspec_test_without_header.csv' }
      it '自動で保存されて、正しいエクセルファイルが作られること' do
        csv.add_row_contents(['Header-1', 'Header-2', 'Header-3', 'Header-4'])
        expect(csv.save_result).to eq({result: :none})
        csv.add_row_contents(['Col1-2', 'Col2-2', 'Col3-2', 'Col4-2'])
        expect(csv.save_result).to eq({result: :none})
        csv.add_row_contents(['Col1-3', 'Col2-3', 'Col3-3', 'Col4-3'])
        expect(csv.save_result).to eq({ result: :done, path: file_path, file_name: file_name })

        expect { csv.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4']) }.to raise_error(CsvHandler::Export::AutoSavedError, 'Can not add row because auto saved already.')

        csv_data = CSV.read(file_path, encoding: 'BOM|UTF-8', headers: false)
        made_csv = csv_data.map.with_index(1) { |data, i| [i, data] }.to_h

        expect(made_csv).to eq({1=>["Header-1", "Header-2", "Header-3", "Header-4"], 2=>["Col1-2", "Col2-2", "Col3-2", "Col4-2"], 3=>["Col1-3", "Col2-3", "Col3-3", "Col4-3"]})
      end
    end
  end

  context 'エラーのケース' do
    it 'csv以外の拡張子の場合はエラーが表示される' do
      expect { CsvHandler::Export.new('aaa.xls') }.to raise_error(CsvHandler::Export::InvalidExtensionError, 'File extension should be "csv".')
    end

    it '配列以外はヘッダーに入れられないこと' do
      expect(csv.add_header('a')).to be_falsey
      expect(csv.add_header(1)).to be_falsey
      expect(csv.add_header({1 => 4})).to be_falsey
    end

    it '配列とハッシュ以外はコンテンツとして登録できないこと' do
      expect { csv.add_row_contents('a') }.to raise_error(CsvHandler::Export::InvalidContentsError, 'Contents must be Array or Hash.')
      expect { csv.add_row_contents(1) }.to raise_error(CsvHandler::Export::InvalidContentsError, 'Contents must be Array or Hash.')
    end

    describe '保存に関して' do
      let(:file_path) { Rails.root.join('spec', 'tmp', 'aaa', file_name).to_s }
      it '存在しないパスには保存できないこと' do
        expect { csv }.to raise_error(Errno::ENOENT)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Excel::Import, type: :model do
  let(:file_name) { 'normal_urlcol1.xlsx' }
  let(:file_path) { Rails.root.join('spec', 'fixtures', file_name).to_s }
  let(:ex)        { Excel::Import.new(file_path, 1, false) }

  describe 'get_one_column_values' do
    let(:file_name) { 'normal_urlcol1.xlsx' }

    # col, row_max, headerの組み合わせ
    it 'col1の時、ヘッダーなし, 10行目まで' do
      expect(ex.get_one_column_values(1, 10)).to eq ['https://www.nexway.co.jp',
                                                     'http://www.hokkaido.ccbc.co.jp/',
                                                     'https://bbb',
                                                     'https://www.honda.co.jp/',
                                                     'http://aaaa.com',
                                                     'https://www.starbucks.co.jp/',
                                                     'http://ccc',
                                                     '', '', '']
    end

    it 'col1の時、ヘッダーなし, 5行目まで' do
      expect(ex.get_one_column_values(1, 5)).to eq ['https://www.nexway.co.jp',
                                                    'http://www.hokkaido.ccbc.co.jp/',
                                                    'https://bbb',
                                                    'https://www.honda.co.jp/',
                                                    'http://aaaa.com']
    end

    context '単数シートの場合' do
      let(:file_name) { 'sample_with_header.xlsx' }

      context 'ヘッダーなしの場合' do
        it 'col2の時、3行目まで取れること' do
          expect(ex.get_one_column_values(2, 3)).to eq ['Header2', 'Col2-2', 'Col2-3']
        end

        it 'col3の時、7行目まで取れること' do
          expect(ex.get_one_column_values(3, 7)).to eq ['Header3', 'Col3-2', 'Col3-3', 'Col3-4', 'Col3-5',
                                                        '', '']
        end

        it 'col1の時、15行目の指定で、最大行の10行目まで取れること' do
          expect(ex.get_one_column_values(1, 15)).to eq ['Header1', 'Col1-2', 'Col1-3', 'Col1-4', 'Col1-5',
                                                         '', '', '', '', '']
        end
      end

      context 'ヘッダーありの場合' do
        let(:ex) { Excel::Import.new(file_path, 1, true) }

        it 'col4の時、4行目まで取れること' do
          expect(ex.get_one_column_values(4, 4)).to eq ['Col4-2', 'Col4-3', 'Col4-4', 'Col4-5']
        end

        it 'col1の時、7行目まで取れること' do
          expect(ex.get_one_column_values(1, 7)).to eq ['Col1-2', 'Col1-3', 'Col1-4', 'Col1-5',
                                                        '', '', '']
        end

        it 'col2の時、15行目の指定で、ヘッダーを除いた最大行の9行目まで取れること' do
          expect(ex.get_one_column_values(2, 15)).to eq ['Col2-2', 'Col2-3', 'Col2-4', 'Col2-5',
                                                         '', '', '', '', '']
        end
      end
    end

    context '複数シートの場合' do
      let(:file_name) { 'sample_multi_sheet_with_header.xlsx' }
      context 'ヘッダーなしの場合' do
        it '2シート目、col2の時、3行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, false)
          expect(ex.get_one_column_values(2, 3)).to eq ['S2-Header2', 'S2-Col2-2', 'S2-Col2-3']
        end

        it '3シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 3, false)
          expect(ex.get_one_column_values(3, 7)).to eq ['S3-Header3', 'S3-Col3-2', 'S3-Col3-3', 'S3-Col3-4', 'S3-Col3-5',
                                                        '', '']
        end

        it '1シート目、col1の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 1, false)
          expect(ex.get_one_column_values(1, 15)).to eq ['S1-Header1', 'S1-Col1-2', 'S1-Col1-3', 'S1-Col1-4', 'S1-Col1-5',
                                                         '', '', '', '', '']
        end

        it '2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, false)
          expect(ex.get_one_column_values(5, 15)).to eq ['S2-Header5', 'S2-Col5-2', 'S2-Col5-3', 'S2-Col5-4', 'S2-Col5-5',
                                                         '', '', '', '', '']
        end

        it 'シート名指定、2シート目、col2の時、3行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', false)
          expect(ex.get_one_column_values(2, 3)).to eq ['S2-Header2', 'S2-Col2-2', 'S2-Col2-3']
        end

        it 'シート名指定、3シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet3', false)
          expect(ex.get_one_column_values(3, 7)).to eq ['S3-Header3', 'S3-Col3-2', 'S3-Col3-3', 'S3-Col3-4', 'S3-Col3-5',
                                                        '', '']
        end

        it 'シート名指定、1シート目、col1の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet1', false)
          expect(ex.get_one_column_values(1, 15)).to eq ['S1-Header1', 'S1-Col1-2', 'S1-Col1-3', 'S1-Col1-4', 'S1-Col1-5',
                                                         '', '', '', '', '']
        end

        it 'シート名指定、2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', false)
          expect(ex.get_one_column_values(5, 15)).to eq ['S2-Header5', 'S2-Col5-2', 'S2-Col5-3', 'S2-Col5-4', 'S2-Col5-5',
                                                         '', '', '', '', '']
        end
      end

      context 'ヘッダーありの場合' do
        it '1シート目、col2の時、5行目まで取れること' do
          ex = Excel::Import.new(file_path, 1, true)
          expect(ex.get_one_column_values(2, 2)).to eq ['S1-Col2-2', 'S1-Col2-3']
        end

        it '2シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_one_column_values(3, 6)).to eq ['S2-Col3-2', 'S2-Col3-3', 'S2-Col3-4', 'S2-Col3-5',
                                                        '', '']
        end

        it '3シート目、col4の時、18行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 3, true)
          expect(ex.get_one_column_values(4, 18)).to eq ['S3-Col4-2', 'S3-Col4-3', 'S3-Col4-4', 'S3-Col4-5',
                                                         '', '', '', '', '']
        end

        it '2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_one_column_values(5, 15)).to eq ['S2-Col5-2', 'S2-Col5-3', 'S2-Col5-4', 'S2-Col5-5',
                                                         '', '', '', '', '']
        end

        it 'シート名指定、1シート目、col2の時、5行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet1', true)
          expect(ex.get_one_column_values(2, 2)).to eq ['S1-Col2-2', 'S1-Col2-3']
        end

        it 'シート名指定、2シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_one_column_values(3, 6)).to eq ['S2-Col3-2', 'S2-Col3-3', 'S2-Col3-4', 'S2-Col3-5',
                                                        '', '']
        end

        it 'シート名指定、3シート目、col4の時、18行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet3', true)
          expect(ex.get_one_column_values(4, 18)).to eq ['S3-Col4-2', 'S3-Col4-3', 'S3-Col4-4', 'S3-Col4-5',
                                                         '', '', '', '', '']
        end

        it 'シート名指定、2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_one_column_values(5, 15)).to eq ['S2-Col5-2', 'S2-Col5-3', 'S2-Col5-4', 'S2-Col5-5',
                                                         '', '', '', '', '']
        end
      end
    end
  end

  describe 'get_one_column_values_with_index' do

    context '単数シートの場合' do
      let(:file_name) { 'sample_with_header.xlsx' }

      context 'ヘッダーなしの場合' do
        it 'col2の時、3行目まで取れること' do
          expect(ex.get_one_column_values_with_index(2, 3)).to eq ( { 1 => 'Header2', 2 => 'Col2-2', 3 => 'Col2-3' } )
        end

        it 'col3の時、7行目まで取れること' do
          expect(ex.get_one_column_values_with_index(3, 7)).to eq ( { 1 => 'Header3', 2 => 'Col3-2', 3 => 'Col3-3',
                                                                      4 => 'Col3-4', 5 => 'Col3-5',
                                                                      6 => '', 7 => ''} )
        end

        it 'col1の時、15行目の指定で、最大行の10行目まで取れること' do
          expect(ex.get_one_column_values_with_index(1, 15)).to eq ( { 1 => 'Header1', 2 => 'Col1-2', 3 => 'Col1-3',
                                                                       4 => 'Col1-4', 5 => 'Col1-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end
      end

      context 'ヘッダーありの場合' do
        let(:ex) { Excel::Import.new(file_path, 1, true) }

        it 'col4の時、4行目まで取れること' do
          expect(ex.get_one_column_values_with_index(4, 4)).to eq ( { 2 => 'Col4-2', 3 => 'Col4-3', 4 => 'Col4-4',
                                                                      5 => 'Col4-5'} )
        end

        it 'col1の時、7行目まで取れること' do
          expect(ex.get_one_column_values_with_index(1, 7)).to eq ( { 2 => 'Col1-2', 3 => 'Col1-3', 4 => 'Col1-4',
                                                                      5 => 'Col1-5',
                                                                      6 => '', 7 => '', 8 => ''} )
        end

        it 'col2の時、15行目の指定で、ヘッダーを除いた最大行の9行目まで取れること' do
          expect(ex.get_one_column_values_with_index(2, 15)).to eq ( { 2 => 'Col2-2', 3 => 'Col2-3', 4 => 'Col2-4',
                                                                       5 => 'Col2-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end
      end
    end

    context '複数シートの場合' do
      let(:file_name) { 'sample_multi_sheet_with_header.xlsx' }
      context 'ヘッダーなしの場合' do
        it '2シート目、col2の時、3行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, false)
          expect(ex.get_one_column_values_with_index(2, 3)).to eq ( { 1 => 'S2-Header2', 2 => 'S2-Col2-2', 3 => 'S2-Col2-3'} )
        end

        it '3シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 3, false)
          expect(ex.get_one_column_values_with_index(3, 7)).to eq ( { 1 => 'S3-Header3', 2 => 'S3-Col3-2', 3 => 'S3-Col3-3',
                                                                      4 => 'S3-Col3-4',  5 => 'S3-Col3-5',
                                                                      6 => '', 7 => ''} )
        end

        it '1シート目、col1の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 1, false)
          expect(ex.get_one_column_values_with_index(1, 15)).to eq ( { 1 => 'S1-Header1', 2 => 'S1-Col1-2', 3 => 'S1-Col1-3',
                                                                       4 => 'S1-Col1-4', 5 => 'S1-Col1-5',
                                                                       6 => '',  7 => '', 8 => '', 9 => '', 10 => '' } )
        end

        it '2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, false)
          expect(ex.get_one_column_values_with_index(5, 15)).to eq ( { 1 => 'S2-Header5', 2 => 'S2-Col5-2', 3 => 'S2-Col5-3',
                                                                       4 => 'S2-Col5-4', 5 => 'S2-Col5-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end

        it 'シート名指定、2シート目、col2の時、3行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', false)
          expect(ex.get_one_column_values_with_index(2, 3)).to eq ( { 1 => 'S2-Header2', 2 => 'S2-Col2-2', 3 => 'S2-Col2-3'} )
        end

        it 'シート名指定、3シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet3', false)
          expect(ex.get_one_column_values_with_index(3, 7)).to eq ( { 1 => 'S3-Header3', 2 => 'S3-Col3-2', 3 => 'S3-Col3-3',
                                                                      4 => 'S3-Col3-4',  5 => 'S3-Col3-5',
                                                                      6 => '', 7 => ''} )
        end

        it 'シート名指定、1シート目、col1の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet1', false)
          expect(ex.get_one_column_values_with_index(1, 15)).to eq ( { 1 => 'S1-Header1', 2 => 'S1-Col1-2', 3 => 'S1-Col1-3',
                                                                       4 => 'S1-Col1-4', 5 => 'S1-Col1-5',
                                                                       6 => '',  7 => '', 8 => '', 9 => '', 10 => '' } )
        end

        it 'シート名指定、2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', false)
          expect(ex.get_one_column_values_with_index(5, 15)).to eq ( { 1 => 'S2-Header5', 2 => 'S2-Col5-2', 3 => 'S2-Col5-3',
                                                                       4 => 'S2-Col5-4', 5 => 'S2-Col5-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end
      end

      context 'ヘッダーありの場合' do
        it '1シート目、col2の時、5行目まで取れること' do
          ex = Excel::Import.new(file_path, 1, true)
          expect(ex.get_one_column_values_with_index(2, 2)).to eq ( { 2 => 'S1-Col2-2', 3 => 'S1-Col2-3'} )
        end

        it '2シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_one_column_values_with_index(3, 6)).to eq ( { 2 => 'S2-Col3-2', 3 => 'S2-Col3-3', 4 => 'S2-Col3-4',
                                                                      5 => 'S2-Col3-5',
                                                                      6 => '', 7 => ''} )
        end

        it '3シート目、col4の時、18行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 3, true)
          expect(ex.get_one_column_values_with_index(4, 18)).to eq ( { 2 => 'S3-Col4-2', 3 => 'S3-Col4-3', 4 => 'S3-Col4-4',
                                                                       5 => 'S3-Col4-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end

        it '2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_one_column_values_with_index(5, 15)).to eq ( { 2 => 'S2-Col5-2', 3 => 'S2-Col5-3', 4 => 'S2-Col5-4',
                                                                       5 => 'S2-Col5-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end

        it 'シート名指定、1シート目、col2の時、5行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet1', true)
          expect(ex.get_one_column_values_with_index(2, 2)).to eq ( { 2 => 'S1-Col2-2', 3 => 'S1-Col2-3'} )
        end

        it 'シート名指定、2シート目、col3の時、7行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_one_column_values_with_index(3, 6)).to eq ( { 2 => 'S2-Col3-2', 3 => 'S2-Col3-3', 4 => 'S2-Col3-4',
                                                                      5 => 'S2-Col3-5',
                                                                      6 => '', 7 => ''} )
        end

        it 'シート名指定、3シート目、col4の時、18行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet3', true)
          expect(ex.get_one_column_values_with_index(4, 18)).to eq ( { 2 => 'S3-Col4-2', 3 => 'S3-Col4-3', 4 => 'S3-Col4-4',
                                                                       5 => 'S3-Col4-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end

        it 'シート名指定、2シート目、col5の時、15行目の指定で、最大行の10行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_one_column_values_with_index(5, 15)).to eq ( { 2 => 'S2-Col5-2', 3 => 'S2-Col5-3', 4 => 'S2-Col5-4',
                                                                       5 => 'S2-Col5-5',
                                                                       6 => '', 7 => '', 8 => '', 9 => '', 10 => ''} )
        end
      end
    end
  end

  describe 'get_rowに関して' do

    context '単数シートの場合' do
      let(:file_name) { 'sample_with_header.xlsx' }

      context 'ヘッダーなしの場合' do
        it 'row1の時、5列目まで取れること' do
          expect(ex.get_row(1, 5)).to eq ['Header1', 'Header2', 'Header3', 'Header4', 'Header5']
        end

        it 'row3の時、6列目まで取れること' do
          expect(ex.get_row(3, 6)).to eq ['Col1-3', 'Col2-3', 'Col3-3', 'Col4-3', 'Col5-3', '']
        end

        it 'row5の時、19列目の指定で、最大列の7列目まで取れること' do
          expect(ex.get_row(5, 10)).to eq ['Col1-5', 'Col2-5', 'Col3-5', 'Col4-5', 'Col5-5',
                                           '', '']
        end
      end

      context 'ヘッダーありの場合' do
        let(:ex) { Excel::Import.new(file_path, 1, true) }

        it 'row4の時、4列目まで取れること' do
          expect(ex.get_row(4, 4)).to eq ['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4']
        end

        it 'row1の時、7列目まで取れること' do
          expect(ex.get_row(1, 7)).to eq ['Header1', 'Header2', 'Header3', 'Header4', 'Header5',
                                          '', '']
        end

        it 'row2の時、15列目の指定で、最大列の7列目まで取れること' do
          expect(ex.get_row(2, 15)).to eq ['Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2',
                                           '', '']
        end
      end
    end

    context '複数シートの場合' do
      let(:file_name) { 'sample_multi_sheet_with_header.xlsx' }
      context 'ヘッダーなしの場合' do
        it '2シート目、row2の時、3列目まで取れること' do
          ex = Excel::Import.new(file_path, 2, false)
          expect(ex.get_row(2, 3)).to eq ['S2-Col1-2', 'S2-Col2-2', 'S2-Col3-2']
        end

        it '3シート目、row3の時、6列目まで取れること' do
          ex = Excel::Import.new(file_path, 3, false)
          expect(ex.get_row(3, 6)).to eq ['S3-Col1-3', 'S3-Col2-3', 'S3-Col3-3', 'S3-Col4-3', 'S3-Col5-3', '']
        end

        it '1シート目、row1の時、15列目の指定で、最大列の7行目まで取れること' do
          ex = Excel::Import.new(file_path, 1, false)
          expect(ex.get_row(1, 15)).to eq ['S1-Header1', 'S1-Header2', 'S1-Header3', 'S1-Header4', 'S1-Header5', '', '']
        end

        it '2シート目、row5の時、15列目の指定で、最大列の10列目まで取れること' do
          ex = Excel::Import.new(file_path, 2, false)
          expect(ex.get_row(5, 15)).to eq ['S2-Col1-5', 'S2-Col2-5', 'S2-Col3-5', 'S2-Col4-5', 'S2-Col5-5', '', '']
        end

        it 'シート名指定、2シート目、row2の時、3列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', false)
          expect(ex.get_row(2, 3)).to eq ['S2-Col1-2', 'S2-Col2-2', 'S2-Col3-2']
        end

        it 'シート名指定、3シート目、row3の時、6列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet3', false)
          expect(ex.get_row(3, 6)).to eq ['S3-Col1-3', 'S3-Col2-3', 'S3-Col3-3', 'S3-Col4-3', 'S3-Col5-3', '']
        end

        it 'シート名指定、1シート目、row1の時、15列目の指定で、最大列の7行目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet1', false)
          expect(ex.get_row(1, 15)).to eq ['S1-Header1', 'S1-Header2', 'S1-Header3', 'S1-Header4', 'S1-Header5', '', '']
        end

        it 'シート名指定、2シート目、row5の時、15列目の指定で、最大列の10列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', false)
          expect(ex.get_row(5, 15)).to eq ['S2-Col1-5', 'S2-Col2-5', 'S2-Col3-5', 'S2-Col4-5', 'S2-Col5-5', '', '']
        end
      end

      context 'ヘッダーありの場合' do
        it '1シート目、row2の時、5列目まで取れること' do
          ex = Excel::Import.new(file_path, 1, true)
          expect(ex.get_row(2, 2)).to eq ['S1-Col1-2', 'S1-Col2-2']
        end

        it '2シート目、row3の時、7列目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_row(3, 6)).to eq ['S2-Col1-3', 'S2-Col2-3', 'S2-Col3-3', 'S2-Col4-3', 'S2-Col5-3', '']
        end

        it '3シート目、row4の時、18列目の指定で、最大列の7列目まで取れること' do
          ex = Excel::Import.new(file_path, 3, true)
          expect(ex.get_row(4, 18)).to eq ['S3-Col1-4', 'S3-Col2-4', 'S3-Col3-4', 'S3-Col4-4', 'S3-Col5-4', '', '']
        end

        it '2シート目、row1の時、15列目の指定で、最大列の7列目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_row(1, 15)).to eq ['S2-Header1', 'S2-Header2', 'S2-Header3', 'S2-Header4', 'S2-Header5', '', '']
        end

        it '2シート目、row6の時、15列目の指定で、最大列の7列目まで取れること' do
          ex = Excel::Import.new(file_path, 2, true)
          expect(ex.get_row(6, 15)).to eq ['', '', '', '', '', '', '']
        end

        it '1シート目、row2の時、5列目まで取れること' do
          ex = Excel::Import.new(file_path, 1, true)
          expect(ex.get_row(2, 2)).to eq ['S1-Col1-2', 'S1-Col2-2']
        end

        it 'シート名指定、2シート目、row3の時、7列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_row(3, 6)).to eq ['S2-Col1-3', 'S2-Col2-3', 'S2-Col3-3', 'S2-Col4-3', 'S2-Col5-3', '']
        end

        it 'シート名指定、3シート目、row4の時、18列目の指定で、最大列の7列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet3', true)
          expect(ex.get_row(4, 18)).to eq ['S3-Col1-4', 'S3-Col2-4', 'S3-Col3-4', 'S3-Col4-4', 'S3-Col5-4', '', '']
        end

        it 'シート名指定、2シート目、row1の時、15列目の指定で、最大列の7列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_row(1, 15)).to eq ['S2-Header1', 'S2-Header2', 'S2-Header3', 'S2-Header4', 'S2-Header5', '', '']
        end

        it 'シート名指定、2シート目、row6の時、15列目の指定で、最大列の7列目まで取れること' do
          ex = Excel::Import.new(file_path, 'Sheet2', true)
          expect(ex.get_row(6, 15)).to eq ['', '', '', '', '', '', '']
        end
      end
    end
  end

  describe '特殊ケースのエクセルに関して' do
    let(:make_ex) { Excel::Import.new(file_path, 1, false).to_hash_data }
    context '罫線ありエクセルの場合' do
      let(:file_name) { 'with_line5×8.xlsx' }
      it '罫線の範囲まで表示されること' do
        expect(make_ex).to eq({ sheet_name: 'Sheet1', col_max: 4, row_max: 7,
                                data: { 1 => ['Header1', 'Header2', 'Header3', '', ''],
                                        2 => ['Col1-2', 'Col2-2', 'Col3-2', '', ''],
                                        3 => ['Col1-3', 'Col2-3', 'Col3-3', '', ''],
                                        4 => ['Col1-4', 'Col2-4', 'Col3-4', '', ''],
                                        5 => ['', '', '', '', ''],
                                        6 => ['', '', '', '', ''],
                                        7 => ['', '', '', '', ''],
                                        8 => ['', '', '', '', '']
                                      }})
      end
    end

    context 'カラーありエクセルの場合' do
      let(:file_name) { 'with_color5×8.xlsx' }
      it 'カラーの範囲まで表示されること' do
        expect(make_ex).to eq({ sheet_name: 'Sheet1', col_max: 4, row_max: 7,
                                data: { 1 => ['Header1', 'Header2', 'Header3', '', ''],
                                        2 => ['Col1-2', 'Col2-2', 'Col3-2', '', ''],
                                        3 => ['Col1-3', 'Col2-3', 'Col3-3', '', ''],
                                        4 => ['Col1-4', 'Col2-4', 'Col3-4', '', ''],
                                        5 => ['', '', '', '', ''],
                                        6 => ['', '', '', '', ''],
                                        7 => ['', '', '', '', ''],
                                        8 => ['', '', '', '', '']
                                      }})
      end
    end

    context '空セルありエクセルの場合' do
      let(:file_name) { 'empty_column.xlsx' }
      it '正しく表示されること' do
        expect(make_ex).to eq({ sheet_name: 'Sheet1', col_max: 4, row_max: 6,
                                data: { 1 => ['Header1', 'Header2', '', 'Header4', ''],
                                        2 => ['', 'Col2-2', '', '', ''],
                                        3 => ['Col1-3', '', '', 'Col4-3', ''],
                                        4 => ['Col1-4', 'Col2-4', '', 'Col4-4', ''],
                                        5 => ['', '', '', '', ''],
                                        6 => ['Col1-6', 'Col2-6', '', 'Col4-6', ''],
                                        7 => ['', '', '', 'Col4-7', '']
                                      }})
      end
    end

    context '改行セルありエクセルの場合' do
      let(:file_name) { 'linebreak.xlsx' }
      it '正しく表示されること' do
        expect(make_ex).to eq({ sheet_name: 'Sheet1', col_max: 2, row_max: 3,
                                data: { 1 => ['Header1', 'Header2', 'Header3'],
                                        2 => ['', '', ''],
                                        3 => ['', "Line\nBreak", 'normal'],
                                        4 => ["Line\nBreak", "Line\nBreak", 'normal']
                                      }})
      end
    end

    context 'フィルターによる隠し行ありエクセルの場合' do
      let(:file_name) { 'hide_with_filter.xlsx' }
      it '隠し行も表示されること' do
        expect(make_ex).to eq({ sheet_name: 'Sheet1', col_max: 2, row_max: 4,
                                data: { 1 => ['Header1', 'Header2', 'Header3'],
                                        2 => ['Col1-2', 'Col2-2', 'Col3-2'],
                                        3 => ['Hide', 'Col2-3', 'Hide'],
                                        4 => ['Col1-4', 'Hide', 'Col3-4'],
                                        5 => ['Col1-5', 'Col2-5', 'Col3-5']
                                      }})
      end
    end
  end
end

RSpec.describe Excel::Export, type: :model do
  let(:correct_file) { Rails.root.join('spec', 'fixtures', 'sample_with_header2.xlsx').to_s }
  let(:file_path)    { Rails.root.join('spec', 'tmp', file_name).to_s }
  let(:file_name)    { 'rspec_test_sample.xlsx' }
  let(:ex)           { Excel::Export.new(file_path, 'シート1') }
  let(:make_ex)      { Excel::Import.new(file_path, 1, false).to_hash_data }
  let(:correct_ex)   { Excel::Import.new(correct_file, 1, false).to_hash_data }

  context '正常ケース' do

    after { `rm #{file_path}` }

    context 'ヘッダーあり、配列とハッシュを使って作成する場合' do
      let(:file_name) { 'rspec_test_with_header.xlsx' }
      it '正しいエクセルファイルが作られること' do
        expect(ex.add_header(['Header1', 'Header2', 'Header3', 'Header4', 'Header5', '', ''])).to be_truthy
        expect(ex.add_row_contents(['Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2', '', ''])).to be_truthy
        expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3', 'Header3' => 'Col3-3',
                                    'Header4' => 'Col4-3', 'Header5' => 'Col5-3', '' => ''})).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4', '', ''])).to be_truthy
        expect(ex.add_row_contents({'Header5' => 'Col5-5', 'Header1' => 'Col1-5', 'Header2' => 'Col2-5',
                                    'Header4' => 'Col4-5', 'Header3' => 'Col3-5'})).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents({'Header7' => '', 'Header6' => '', 'Header5' => '',
                                    'Header1' => '', 'Header2' => '', 'Header4' => '', 'Header3' => ''})).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy

        expect(ex.save).to be_truthy
        expect(make_ex).to eq correct_ex
      end
    end

    context 'ヘッダーなし、配列を使って作成する場合' do
      let(:file_name) { 'rspec_test_without_header.xlsx' }
      it '正しいエクセルファイルが作られること' do
        expect(ex.add_row_contents(['Header1', 'Header2', 'Header3', 'Header4', 'Header5', '', ''])).to be_truthy
        expect(ex.add_row_contents(['Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2', '', ''])).to be_truthy
        expect(ex.add_row_contents(['Col1-3', 'Col2-3', 'Col3-3', 'Col4-3', 'Col5-3', '', ''])).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4', '', ''])).to be_truthy
        expect(ex.add_row_contents(['Col1-5', 'Col2-5', 'Col3-5', 'Col4-5', 'Col5-5', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
        expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy

        expect(ex.save).to be_truthy
        expect(make_ex).to eq correct_ex
      end
    end

    context '複数に分けて挿入する場合' do
      context 'ヘッダーあり、配列とハッシュを使って作成する場合' do
        let(:file_name) { 'rspec_test_with_header.xlsx' }
        it '正しいエクセルファイルが作られること' do
          expect(ex.add_header(['Header1', 'Header2'],['Header3', 'Header4'], ['Header5', '', ''])).to be_truthy
          expect(ex.add_row_contents(['Col1-2', 'Col2-2'], ['Col3-2', 'Col4-2'], ['Col5-2', '', ''])).to be_truthy
          expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3'},
                                     {'Header3' => 'Col3-3', 'Header4' => 'Col4-3'},
                                     {'Header5' => 'Col5-3', '' => ''})).to be_truthy
          expect(ex.add_row_contents(['Col1-4', 'Col2-4'], {'Header3' => 'Col3-4', 'Header4' => 'Col4-4'}, ['Col5-4', '', ''])).to be_truthy
          expect(ex.add_row_contents({'Header5' => 'Col5-5', 'Header1' => 'Col1-5', 'Header2' => 'Col2-5'},
                                     ['Col3-5', 'Col4-5'],
                                     {'Header4' => 'Col4-5', 'Header5' => 'Col5-5', 'Header3' => 'Col3-5'})).to be_truthy
          expect(ex.add_row_contents(['', '', ''], ['', '', ''], ['', '', ''])).to be_truthy
          expect(ex.add_row_contents({'Header7' => '', 'Header6' => '', 'Header5' => ''},
                                     {'Header1' => '', 'Header2' => '', 'Header4' => '', 'Header3' => ''})).to be_truthy
          expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', '', '', ''], ['', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', ''], ['', ''], ['', '', ''])).to be_truthy

          expect(ex.save).to be_truthy
          expect(make_ex).to eq correct_ex
        end
      end

      context 'ヘッダー名が重複している場合' do
        let(:file_name) { 'rspec_test_with_same_name_header.xlsx' }
        let(:correct_file) { Rails.root.join('spec', 'fixtures', 'sample_with_same_name_header2.xlsx').to_s }
        it '正しいエクセルファイルが作られること' do
          expect(ex.add_header(['Header1', 'Header2'], [''], ['Header1', 'Header2', '', ''])).to be_truthy
          expect(ex.add_row_contents(['Col1-2', 'Col2-2'], [''], ['Col4-2', 'Col5-2', '', ''])).to be_truthy
          expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3'},
                                     {'Header3' => 'Col3-3', 'Header4' => 'Col4-3'},
                                     {'Header2' => 'Col5-3', 'Header1' => 'Col4-3'})).to be_truthy
          expect(ex.add_row_contents(['Col1-4', 'Col2-4'], {'' => ''}, {'Header1' => 'Col4-4', 'Header2' => 'Col5-4'})).to be_truthy
          expect(ex.add_row_contents({'Header5' => 'Col5-5', 'Header1' => 'Col1-5', 'Header2' => 'Col2-5'},
                                     ['', 'asd'],
                                     {'Header1' => 'Col4-5', 'Header2' => 'Col5-5', 'Header3' => 'Col3-5'})).to be_truthy
          expect(ex.add_row_contents(['', '', ''], ['', '', ''], ['', '', ''])).to be_truthy
          expect(ex.add_row_contents({'Header7' => '', 'Header6' => '', 'Header5' => ''},
                                     {'Header1' => '', 'Header2' => '', 'Header4' => '', 'Header3' => ''})).to be_truthy
          expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', '', '', ''], ['', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', ''], ['', ''], ['', '', ''])).to be_truthy

          expect(ex.save).to be_truthy
          expect(make_ex).to eq correct_ex
        end
      end

      context 'ヘッダーなし、配列を使って作成する場合' do
        let(:file_name) { 'rspec_test_without_header.xlsx' }
        it '正しいエクセルファイルが作られること' do
          expect(ex.add_row_contents(['Header1', 'Header2'], ['Header3', 'Header4'], ['Header5', '', ''])).to be_truthy
          expect(ex.add_row_contents(['Col1-2', 'Col2-2'], ['Col3-2', 'Col4-2'], ['Col5-2'])).to be_truthy
          expect(ex.add_row_contents(['Col1-3', 'Col2-3'], ['Col3-3', 'Col4-3'], ['Col5-3', '', ''])).to be_truthy
          expect(ex.add_row_contents(['Col1-4', 'Col2-4'], ['Col3-4', 'Col4-4'], ['Col5-4', ''])).to be_truthy
          expect(ex.add_row_contents(['Col1-5', 'Col2-5'], ['Col3-5', 'Col4-5'], ['Col5-5', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', ''], ['', '', '', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy
          expect(ex.add_row_contents(['', '', '', '', ''], ['', ''])).to be_truthy
          expect(ex.add_row_contents(['', '', '', '', '', '', ''])).to be_truthy

          expect(ex.save).to be_truthy
          expect(Excel::Import.new(file_path, 1, false).to_hash_data).to eq correct_ex
        end
      end
    end
  end

  # オートインクリメントを外しているので、テストできない
  xdescribe 'auto_saveについて' do
    let(:ex)            { Excel::Export.new(file_path, 'シート1', auto_save: true, auto_save_cels_limit: 180) }
    let(:file_path1)    { Rails.root.join('spec', 'tmp', file_name1).to_s }
    let(:file_path2)    { Rails.root.join('spec', 'tmp', file_name2).to_s }
    let(:file_path3)    { Rails.root.join('spec', 'tmp', file_name3).to_s }
    let(:file_path4)    { Rails.root.join('spec', 'tmp', file_name4).to_s }
    let(:file_name1)    { '1_rspec_test_with_header.xlsx' }
    let(:file_name2)    { '2_rspec_test_with_header.xlsx' }
    let(:file_name3)    { '3_rspec_test_with_header.xlsx' }
    let(:file_name4)    { '4_rspec_test_with_header.xlsx' }
    let(:correct_file1) { Rails.root.join('spec', 'fixtures', file_name1).to_s }
    let(:correct_file2) { Rails.root.join('spec', 'fixtures', file_name2).to_s }
    let(:correct_file3) { Rails.root.join('spec', 'fixtures', file_name3).to_s }
    let(:correct_file4) { Rails.root.join('spec', 'fixtures', file_name4).to_s }
    let(:make_ex1)      { Excel::Import.new(file_path1, 1, false).to_hash_data }
    let(:make_ex2)      { Excel::Import.new(file_path2, 1, false).to_hash_data }
    let(:make_ex3)      { Excel::Import.new(file_path3, 1, false).to_hash_data }
    let(:make_ex4)      { Excel::Import.new(file_path4, 1, false).to_hash_data }
    let(:correct_ex1)   { Excel::Import.new(correct_file1, 1, false).to_hash_data }
    let(:correct_ex2)   { Excel::Import.new(correct_file2, 1, false).to_hash_data }
    let(:correct_ex3)  { Excel::Import.new(correct_file3, 1, false).to_hash_data }
    let(:correct_ex4)   { Excel::Import.new(correct_file4, 1, false).to_hash_data }

    after { `rm #{file_path1} #{file_path2} #{file_path3} #{file_path4}` }

    context 'headerがあるとき' do
      let(:file_name) { 'rspec_test_with_header.xlsx' }
      it '正しいエクセルファイルが作られること' do
        expect(ex.add_header(['Header1', 'Header2', 'Header3', 'Header4', 'Header5'])).to be_truthy
        expect(ex.add_row_contents(['1_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3', 'Header3' => 'Col3-3',
                                    'Header4' => 'Col4-3', 'Header5' => 'Col5-3'})).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy
        
        expect(ex.add_row_contents(['2_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3', 'Header3' => 'Col3-3',
                                    'Header4' => 'Col4-3', 'Header5' => 'Col5-3'})).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy

        expect(ex.add_row_contents(['3_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3', 'Header3' => 'Col3-3',
                                    'Header4' => 'Col4-3', 'Header5' => 'Col5-3'})).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy

        expect(ex.add_row_contents(['4_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents({'Header1' => 'Col1-3', 'Header2' => 'Col2-3', 'Header3' => 'Col3-3',
                                    'Header4' => 'Col4-3', 'Header5' => 'Col5-3'})).to be_truthy

        expect(ex.save).to be_truthy
        expect(make_ex1).to eq correct_ex1
        expect(make_ex2).to eq correct_ex2
        expect(make_ex3).to eq correct_ex3
        expect(make_ex4).to eq correct_ex4
      end
    end

    context 'headerがないとき' do
      let(:file_name)    { 'rspec_test_no_header.xlsx' }
      let(:file_name1)   { '1_rspec_test_no_header.xlsx' }
      let(:file_name2)   { '2_rspec_test_no_header.xlsx' }
      let(:file_name3)   { '3_rspec_test_no_header.xlsx' }
      let(:file_name4)   { '4_rspec_test_no_header.xlsx' }
      it '正しいエクセルファイルが作られること' do
        expect(ex.add_row_contents(['1_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents(['1_Col1-3', 'Col2-3', 'Col3-3', 'Col4-3', 'Col5-3'])).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy
        expect(ex.add_row_contents(['Col1-5', 'Col2-5', 'Col3-5', 'Col4-5', 'Col5-5'])).to be_truthy
        
        expect(ex.add_row_contents(['2_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents(['2_Col1-3', 'Col2-3', 'Col3-3', 'Col4-3', 'Col5-3'])).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy
        expect(ex.add_row_contents(['Col1-5', 'Col2-5', 'Col3-5', 'Col4-5', 'Col5-5'])).to be_truthy

        expect(ex.add_row_contents(['3_Col1-3', 'Col2-3', 'Col3-3', 'Col4-3', 'Col5-3'])).to be_truthy
        expect(ex.add_row_contents(['3_Col1-2', 'Col2-2', 'Col3-2', 'Col4-2', 'Col5-2'])).to be_truthy
        expect(ex.add_row_contents(['Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy
        expect(ex.add_row_contents(['Col1-5', 'Col2-5', 'Col3-5', 'Col4-5', 'Col5-5'])).to be_truthy

        expect(ex.add_row_contents(['4_Col1-3', 'Col2-3', 'Col3-3', 'Col4-3', 'Col5-3'])).to be_truthy
        expect(ex.add_row_contents(['4_Col1-4', 'Col2-4', 'Col3-4', 'Col4-4', 'Col5-4'])).to be_truthy

        expect(ex.save).to be_truthy
        expect(make_ex1).to eq correct_ex1
        expect(make_ex2).to eq correct_ex2
        expect(make_ex3).to eq correct_ex3
        expect(make_ex4).to eq correct_ex4
      end
    end
  end

  context 'エラーのケース' do
    it '配列以外はヘッダーに入れられないこと' do
      expect(ex.add_header('a')).to be_falsey
      expect(ex.add_header(1)).to be_falsey
      expect(ex.add_header({1 => 4})).to be_falsey
    end

    it 'ヘッダーを登録していない場合、ハッシュで登録できないこと' do
      expect(ex.add_row_contents({'h' => 'con'})).to be_falsey
    end

    it '配列とハッシュ以外はコンテンツとして登録できないこと' do
      expect(ex.add_row_contents('a')).to be_falsey
      expect(ex.add_row_contents(1)).to be_falsey
    end

    it 'ヘッダ数以上のコンテンツでは行追加できないこと' do
      expect(ex.add_header(['a', 'b'],['c'])).to be_truthy
      expect(ex.add_row_contents(['a', 'b'], ['c'], ['d'])).to be_falsey
      expect(ex.add_row_contents({'a' => 'b'}, {'c' => 'd'}, {'e' => 'f'})).to be_falsey
    end

    describe '保存に関して' do
      let(:file_path) { Rails.root.join('spec', 'tmp', 'aaa', file_name).to_s }
      it '存在しないパスには保存できないこと' do
        ex.add_row_contents(['a', 'b'])
        expect(ex.save).to be_falsey
      end
    end
  end
end

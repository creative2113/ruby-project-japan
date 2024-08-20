require 'rails_helper'

RSpec.describe CompanyGroup, type: :model do
  describe 'バリデーション' do
    context 'titleない時' do
      it do
        expect{ described_class.create!(type: 'source', grouping_number: 111)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Titleを入力してください')
      end
    end

    context 'grouping_numberない時' do
      it do
        expect{ described_class.create!(type: 'source', title: 'title')}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Grouping numberを入力してください')
      end
    end

    describe '#check_range' do
      context 'rangeでない、かつ、lower, upperに値があるとき' do
        it { expect{ described_class.create!(title: 'aa', type: 'source', lower: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Typeの値が間違っています。rangeではないですか？') }
        it { expect{ described_class.create!(title: 'aa', type: 'source', upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Typeの値が間違っています。rangeではないですか？') }
      end

      context 'rangeの時' do
        context 'lower, upperがnilのとき' do
          context 'すでに同じタイトルのlower, upperがnilのものがあるとき' do
            before { described_class.create!(title: 'aa', type: 'range', grouping_number: 1)  }
            it { expect{ described_class.create!(title: 'aa', type: 'range', grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Lowerの値が間違っています。既にlower=nil、upper=nilのレコードがあります。同じグループで作成できるのは一つだけです。') }
          end

          context 'すでに同じgrouping_numberのlower, upperがnilのものがあるとき' do
            before { described_class.create!(title: 'bb', type: 'range', grouping_number: 111)  }
            it { expect{ described_class.create!(title: 'aa', type: 'range', grouping_number: 111)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Lowerの値が間違っています。既にlower=nil、upper=nilのレコードがあります。同じグループで作成できるのは一つだけです。') }
          end
        end

        context 'lowerがnilの時, upperがあるとき' do
          it { expect{ described_class.create!(title: 'aa', type: 'range', lower: nil, upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Lowerの値が間違っています。lowerに値を入れてください。') }
        end

        context 'lowerの方がupperより大きい時' do
          it { expect{ described_class.create!(title: 'aa', type: 'range', lower: 10, upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。upperはlowerより大きな値にしてください。') }
        end

        context '他のレコードとレンジが被っている場合' do
          context 'すでに同じタイトルで被っているとき' do
            context 'ケース1' do
              before { described_class.create!(title: 'aa', type: 'range', lower: 1, upper: 5, grouping_number: 1)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', lower: 5, upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end

            context 'ケース2' do
              before { described_class.create!(title: 'aa', type: 'range', lower: 10, upper: 15, grouping_number: 1)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', lower: 5, upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end

            context 'ケース3' do
              before { described_class.create!(title: 'aa', type: 'range', lower: 4, upper: 15, grouping_number: 1)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', lower: 5, upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end

            context 'ケース4' do
              before { described_class.create!(title: 'aa', type: 'range', lower: 7, upper: 8, grouping_number: 1)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', lower: 5, upper: 10, grouping_number: 1)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end
          end

          context 'すでに同じgrouping_numberで被っているとき' do
            context 'ケース1' do
              before { described_class.create!(title: 'bb', type: 'range', grouping_number: 11, lower: 1, upper: 5)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', grouping_number: 11, lower: 5, upper: 10)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end

            context 'ケース2' do
              before { described_class.create!(title: 'bb', type: 'range', grouping_number: 11, lower: 10, upper: 15)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', grouping_number: 11, lower: 5, upper: 10)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end

            context 'ケース3' do
              before { described_class.create!(title: 'bb', type: 'range', grouping_number: 11, lower: 4, upper: 15)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', grouping_number: 11, lower: 5, upper: 10)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end

            context 'ケース4' do
              before { described_class.create!(title: 'bb', type: 'range', grouping_number: 11, lower: 7, upper: 8)  }
              it { expect{ described_class.create!(title: 'aa', type: 'range', grouping_number: 11, lower: 5, upper: 10)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Upperの値が間違っています。他のレコードとレンジの範囲が被っています。') }
            end
          end
        end
      end

      describe '#check_grouping_number_by_title' do
        context '同じタイトルでも、grouping_numberが違う時' do
          before { described_class.create!(title: 'aa', type: 'source', grouping_number: 111)  }
          it { expect{ described_class.create!(title: 'aa', type: 'source', grouping_number: 112)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Grouping numberを既存のレコードと同じものにしてください。グループ番号 => 111') }
        end

        context '同じタイトル、サブタイトルでも、grouping_numberが違う時' do
          before { described_class.create!(title: 'aa', subtitle: 'bb', type: 'source', grouping_number: 111)  }
          it { expect{ described_class.create!(title: 'aa', subtitle: 'bb', type: 'source', grouping_number: 112)}.to raise_error(ActiveRecord::RecordInvalid, 'バリデーションに失敗しました: Grouping numberを既存のレコードと同じものにしてください。グループ番号 => 111') }
        end

        context '同じタイトルでも、サブタイトルが違う　かつ、grouping_numberが違う時' do
          before { described_class.create!(title: 'aa', subtitle: 'bb', type: 'source', grouping_number: 111)  }
          it { expect{ described_class.create!(title: 'aa', subtitle: 'bb1', type: 'source', grouping_number: 112)}.not_to raise_error }
        end

        context '自分自身のgrouping_numberのアップデート' do
          let!(:group) { create(:company_group, title: 'aa', subtitle: 'bb', type: 'source', grouping_number: 111) }
          it { expect{ group.update!(grouping_number: 112) }.not_to raise_error }
        end
      end
    end
  end

  describe '#find_by_range' do
    let!(:group1) { create(:company_group, :range, title: described_class::CAPITAL, upper: nil, lower: nil, grouping_number: 1) }
    let!(:group2) { create(:company_group, :range, title: described_class::CAPITAL, upper: 10, lower: 0, grouping_number: 1) }
    let!(:group3) { create(:company_group, :range, title: described_class::CAPITAL, upper: 20, lower: 11, grouping_number: 1) }
    let!(:group4) { create(:company_group, :range, title: described_class::CAPITAL, upper: nil, lower: 21, grouping_number: 1) }

    it do
      expect(described_class.find_by_range(described_class::CAPITAL, nil)).to eq(group1)
      expect(described_class.find_by_range(described_class::CAPITAL, 0)).to eq(group2)
      expect(described_class.find_by_range(described_class::CAPITAL, 5)).to eq(group2)
      expect(described_class.find_by_range(described_class::CAPITAL, 10)).to eq(group2)
      expect(described_class.find_by_range(described_class::CAPITAL, 11)).to eq(group3)
      expect(described_class.find_by_range(described_class::CAPITAL, 15)).to eq(group3)
      expect(described_class.find_by_range(described_class::CAPITAL, 20)).to eq(group3)
      expect(described_class.find_by_range(described_class::CAPITAL, 21)).to eq(group4)
      expect(described_class.find_by_range(described_class::CAPITAL, 30)).to eq(group4)
    end
  end

  describe '#range_combs' do
    before { described_class.seed }
    it do
      capital = described_class.range_combs(described_class::CAPITAL)
      capital_records = described_class.where(title: described_class::CAPITAL)
      expect(capital[0]).to eq({:id => capital_records[0].id, :lower=>capital_records[0].lower, :upper=>capital_records[0].upper, :label=>"〜 100万"})
      expect(capital[1]).to eq({:id => capital_records[1].id, :lower=>capital_records[1].lower, :upper=>capital_records[1].upper, :label=>"〜 500万"})
      expect(capital[2]).to eq({:id => capital_records[2].id, :lower=>capital_records[2].lower, :upper=>capital_records[2].upper, :label=>"〜 1,000万"})
      expect(capital[3]).to eq({:id => capital_records[3].id, :lower=>capital_records[3].lower, :upper=>capital_records[3].upper, :label=>"〜 5,000万"})
      expect(capital[12]).to eq({:id => capital_records[12].id, :lower=>capital_records[12].lower, :upper=>capital_records[12].upper, :label=>"それ以上"})
      expect(capital[13]).to eq({:id => capital_records[13].id, :lower=>capital_records[13].lower, :upper=>capital_records[13].upper, :label=>"不明"})

      employee = described_class.range_combs(described_class::EMPLOYEE)
      employee_records = described_class.where(title: described_class::EMPLOYEE)
      expect(employee[0]).to eq({:id => employee_records[0].id, :lower=>employee_records[0].lower, :upper=>employee_records[0].upper, :label=>"〜 5"})
      expect(employee[1]).to eq({:id => employee_records[1].id, :lower=>employee_records[1].lower, :upper=>employee_records[1].upper, :label=>"〜 10"})
      expect(employee[5]).to eq({:id => employee_records[5].id, :lower=>employee_records[5].lower, :upper=>employee_records[5].upper, :label=>"〜 1,000"})
      expect(employee[6]).to eq({:id => employee_records[6].id, :lower=>employee_records[6].lower, :upper=>employee_records[6].upper, :label=>"〜 5,000"})
      expect(employee[7]).to eq({:id => employee_records[7].id, :lower=>employee_records[7].lower, :upper=>employee_records[7].upper, :label=>"〜 1万"})

      sales = described_class.range_combs(described_class::SALES)
      sales_records = described_class.where(title: described_class::SALES)
      expect(sales[2]).to eq({:id => sales_records[2].id, :lower=>sales_records[2].lower, :upper=>sales_records[2].upper, :label=>"〜 1億"})
      expect(sales[8]).to eq({:id => sales_records[8].id, :lower=>sales_records[8].lower, :upper=>sales_records[8].upper, :label=>"〜 1,000億"})
      expect(sales[9]).to eq({:id => sales_records[9].id, :lower=>sales_records[9].lower, :upper=>sales_records[9].upper, :label=>"〜 5,000億"})
      expect(sales[10]).to eq({:id => sales_records[10].id, :lower=>sales_records[10].lower, :upper=>sales_records[10].upper, :label=>"〜 1兆"})
      expect(sales[11]).to eq({:id => sales_records[11].id, :lower=>sales_records[11].lower, :upper=>sales_records[11].upper, :label=>"〜 5兆"})
      expect(sales[15]).to eq({:id => sales_records[15].id, :lower=>sales_records[15].lower, :upper=>sales_records[15].upper, :label=>"それ以上"})
      expect(sales[16]).to eq({:id => sales_records[16].id, :lower=>sales_records[16].lower, :upper=>sales_records[16].upper, :label=>"不明"})
    end
  end
end

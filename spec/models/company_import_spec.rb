require 'rails_helper'

RSpec.describe Company, type: :model do

  describe '#register_category' do
    subject { described_class.send(:register_category, company, data, category_surfixies) }
    let_it_be(:company) { create(:company) }
    let(:data) { { '大業種' => large, '中業種' => middle, '小業種' => small, '細業種' => detail } }
    let(:category_surfixies) { [] }

    let(:large) { '製造業' }
    let(:middle) { '金属' }
    let(:small) { 'アルミ' }
    let(:detail) { 'アルミ缶' }

    let(:large_category) { LargeCategory.find_by(name: large) }
    let(:middle_category) { MiddleCategory.find_by(name: middle) }
    let(:small_category) { SmallCategory.find_by(name: small) }
    let(:detail_category) { DetailCategory.find_by(name: detail) }
    let(:connector1) { CategoryConnector.find_by(large_category: large_category, middle_category: nil, small_category: nil, detail_category: nil) }
    let(:connector2) { CategoryConnector.find_by(large_category: large_category, middle_category: middle_category, small_category: nil, detail_category: nil) }
    let(:connector3) { CategoryConnector.find_by(large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: nil) }
    let(:connector4) { CategoryConnector.find_by(large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: detail_category) }

    context 'サーフィックスがない時' do
      let(:category_surfixies) { [] }

      it { expect{ subject }.to change(LargeCategory, :count).by(1) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(1) }
      it { expect{ subject }.to change(SmallCategory, :count).by(1) }
      it { expect{ subject }.to change(DetailCategory, :count).by(1) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(4) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(1) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present
      end
    end

    context 'サーフィックスがある時' do
      let(:data) { { '大業種'   => large, '中業種'    => middle, '小業種'    => small, '細業種'    => detail,
                     '大業種_1' => large1, '中業種_1' => middle1, '小業種_1' => small1, '細業種_1' => detail1,
                     '大業種_2' => large2, '中業種_2' => middle2, '小業種_2' => small2, '細業種_2' => detail2 } }
      let(:category_surfixies) { ['1', '2'] }

      let(:large1) { '小売' }
      let(:middle1) { '食品' }
      let(:small1) { '小麦' }
      let(:detail1) { 'パン' }

      let(:large2) { '金融' }
      let(:middle2) { '銀行' }
      let(:small2) { '地方銀行' }
      let(:detail2) { '' }

      let(:large_category1) { LargeCategory.find_by(name: large1) }
      let(:middle_category1) { MiddleCategory.find_by(name: middle1) }
      let(:small_category1) { SmallCategory.find_by(name: small1) }
      let(:detail_category1) { DetailCategory.find_by(name: detail1) }
      let(:connector1_1) { CategoryConnector.find_by(large_category: large_category1, middle_category: nil, small_category: nil, detail_category: nil) }
      let(:connector1_2) { CategoryConnector.find_by(large_category: large_category1, middle_category: middle_category1, small_category: nil, detail_category: nil) }
      let(:connector1_3) { CategoryConnector.find_by(large_category: large_category1, middle_category: middle_category1, small_category: small_category1, detail_category: nil) }
      let(:connector1_4) { CategoryConnector.find_by(large_category: large_category1, middle_category: middle_category1, small_category: small_category1, detail_category: detail_category1) }

      let(:large_category2) { LargeCategory.find_by(name: large2) }
      let(:middle_category2) { MiddleCategory.find_by(name: middle2) }
      let(:small_category2) { SmallCategory.find_by(name: small2) }
      let(:detail_category2) { DetailCategory.find_by(name: detail2) }
      let(:connector2_1) { CategoryConnector.find_by(large_category: large_category2, middle_category: nil, small_category: nil, detail_category: nil) }
      let(:connector2_2) { CategoryConnector.find_by(large_category: large_category2, middle_category: middle_category2, small_category: nil, detail_category: nil) }
      let(:connector2_3) { CategoryConnector.find_by(large_category: large_category2, middle_category: middle_category2, small_category: small_category2, detail_category: nil) }

      it { expect{ subject }.to change(LargeCategory, :count).by(3) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(3) }
      it { expect{ subject }.to change(SmallCategory, :count).by(3) }
      it { expect{ subject }.to change(DetailCategory, :count).by(2) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(11) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(3) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present

        expect(large_category1).to be_present
        expect(middle_category1).to be_present
        expect(small_category1).to be_present
        expect(detail_category1).to be_present
        expect(connector1_1).to be_present
        expect(connector1_2).to be_present
        expect(connector1_3).to be_present
        expect(connector1_4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector1_4)).to be_present

        expect(large_category2).to be_present
        expect(middle_category2).to be_present
        expect(small_category2).to be_present
        expect(detail_category2).not_to be_present
        expect(connector2_1).to be_present
        expect(connector2_2).to be_present
        expect(connector2_3).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector2_3)).to be_present
      end
    end
  end

  describe '#register_area' do
    subject { described_class.send(:register_area, company, data, area_surfixies) }
    let_it_be(:company) { create(:company) }
    let(:data) { { '地方' => region_name, '県' => prefecture_name, '市区町村' => city_name } }
    let(:area_surfixies) { [] }

    let(:region_name) { '関東' }
    let(:prefecture_name) { '東京都' }
    let(:city_name) { '新宿区' }

    let(:region) { create(:region, name: region_name) }
    let(:prefecture) { create(:prefecture, name: prefecture_name) }
    let(:city) { City.find_by(name: city_name) }

    let(:connector1) { AreaConnector.find_by(region: region, prefecture: nil, city: nil) }
    let(:connector2) { AreaConnector.find_by(region: region, prefecture: prefecture, city: nil) }
    let(:connector3) { AreaConnector.find_by(region: region, prefecture: prefecture, city: city) }

    before do
      region
      prefecture
      create(:area_connector, region: region, prefecture: nil, city: nil)
      create(:area_connector, region: region, prefecture: prefecture, city: nil)
    end

    context 'サーフィックスがない時' do
      let(:area_surfixies) { [] }

      it { expect{ subject }.to change(Region, :count).by(0) }
      it { expect{ subject }.to change(Prefecture, :count).by(0) }
      it { expect{ subject }.to change(City, :count).by(1) }
      it { expect{ subject }.to change(AreaConnector, :count).by(1) }
      it { expect{ subject }.to change(CompanyAreaConnector, :count).by(1) }
      it do
        subject
        expect(city).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector3)).to be_present
      end
    end

    context 'サーフィックスがある時' do
      let(:data) { { '地方'   => region_name,  '県'   => prefecture_name,  '市区町村'   => city_name,
                     '地方_a' => region_name1, '県_a' => prefecture_name1, '市区町村_a' => city_name1,
                     '地方_b' => region_name2, '県_b' => prefecture_name2, '市区町村_b' => city_name2 } }
      let(:area_surfixies) { ['a', 'b'] }

      let(:region_name1) { '近畿' }
      let(:prefecture_name1) { '大阪府' }
      let(:city_name1) { '大阪市' }

      let(:region_name2) { '東北' }
      let(:prefecture_name2) { '宮城県' }
      let(:city_name2) { '' }

      let(:region1) { create(:region, name: region_name1) }
      let(:prefecture1) { create(:prefecture, name: prefecture_name1) }
      let(:city1) { City.find_by(name: city_name1) }

      let(:region2) { create(:region, name: region_name2) }
      let(:prefecture2) { create(:prefecture, name: prefecture_name2) }
      let(:city2) { City.find_by(name: city_name2) }

      let(:connector1_1) { AreaConnector.find_by(region: region1, prefecture: nil, city: nil) }
      let(:connector1_2) { AreaConnector.find_by(region: region1, prefecture: prefecture1, city: nil) }
      let(:connector1_3) { AreaConnector.find_by(region: region1, prefecture: prefecture1, city: city1) }

      let(:connector2_1) { AreaConnector.find_by(region: region2, prefecture: nil, city: nil) }
      let(:connector2_2) { AreaConnector.find_by(region: region2, prefecture: prefecture2, city: nil) }
      let(:connector2_3) { AreaConnector.find_by(region: region2, prefecture: prefecture2, city: city2) }

      before do
        region1
        prefecture1
        region2
        prefecture2
        create(:area_connector, region: region1, prefecture: nil, city: nil)
        create(:area_connector, region: region1, prefecture: prefecture1, city: nil)
        create(:area_connector, region: region2, prefecture: nil, city: nil)
        create(:area_connector, region: region2, prefecture: prefecture2, city: nil)
      end

      it { expect{ subject }.to change(Region, :count).by(0) }
      it { expect{ subject }.to change(Prefecture, :count).by(0) }
      it { expect{ subject }.to change(City, :count).by(2) }
      it { expect{ subject }.to change(AreaConnector, :count).by(2) }
      it { expect{ subject }.to change(CompanyAreaConnector, :count).by(3) }
      it do
        subject
        expect(city).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector3)).to be_present

        expect(city1).to be_present
        expect(connector1_1).to be_present
        expect(connector1_2).to be_present
        expect(connector1_3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector1_3)).to be_present

        expect(city2).not_to be_present
        expect(connector2_1).to be_present
        expect(connector2_2).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector2_2)).to be_present
      end
    end
  end

  describe '#register_range_group' do
    subject { described_class.send(:register_range_group, company, data) }
    let_it_be(:company) { create(:company) }
    let(:data) { { 'ソース' => source, '資本金' => capital, '従業員数' => employee, '売上' => sales } }

    let(:source) { 'biz_map' }
    let(:capital) { '1,000,000' }
    let(:employee) { '51' }
    let(:sales) { '1,000,000,001' }

    let_it_be(:capital_group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
    let_it_be(:capital_group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10_000_000, lower: 0) }
    let_it_be(:capital_group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 100_000_000, lower: 10_000_001) }
    let_it_be(:capital_group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 100_000_001) }
    let_it_be(:employee_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: nil) }
    let_it_be(:employee_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 50, lower: 0) }
    let_it_be(:employee_group3) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 100, lower: 51) }
    let_it_be(:employee_group4) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 101) }
    let_it_be(:sales_group1) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: nil) }
    let_it_be(:sales_group2) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 10_000_000, lower: 0) }
    let_it_be(:sales_group3) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 1_000_000_000, lower: 10_000_001) }
    let_it_be(:sales_group4) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: 1_000_000_001) }

    before { Timecop.freeze }
    after  { Timecop.return }

    context 'ソースが指定外の時' do
      let(:source) { 'aaa' }

      it { expect{ subject }.to raise_error(RuntimeError, 'ソースがsource_listに存在しません。=> aaa') }
    end

    context 'ソースがない時' do
      let(:source) { nil }

      context '新規作成の時' do
        it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(3) }
        it do
          subject
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'only_register'
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.month).iso8601

          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'only_register'
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.month).iso8601

          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'only_register'
          expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.month).iso8601
        end
      end

      context '更新の時' do
        let!(:capital_ccg) { create(:company_company_group, company: company, company_group: capital_group4, source: 'only_register') }
        let!(:employee_ccg) { create(:company_company_group, company: company, company_group: employee_group2, source: 'biz_map') }
        let!(:sales_ccg) { create(:company_company_group, company: company, company_group: sales_group1, source: 'corporate_site') }

        it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(0) }
        it do
          updated_at = employee_ccg.updated_at
          subject
          expect(capital_ccg.reload.company_group).to eq capital_group2
          expect(capital_ccg.source).to eq 'only_register'
          expect(capital_ccg.expired_at).to eq (Time.zone.now + 1.month).iso8601

          expect(employee_ccg.reload.company_group).to eq employee_group2
          expect(employee_ccg.source).to eq 'biz_map'
          expect(employee_ccg.updated_at).to eq updated_at

          expect(sales_ccg.reload.company_group).to eq sales_group4
          expect(sales_ccg.source).to eq 'only_register'
          expect(sales_ccg.expired_at).to eq (Time.zone.now + 1.month).iso8601
        end
      end
    end

    context 'ソースがある時' do
      let(:source) { 'biz_map' }

      context '新規作成の時' do
        context '全て揃っている時' do
          it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(3) }
          it do
            subject
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601
          end
        end

        context '資本金がないとき' do
          let(:capital) { nil }
          it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(3) }
          it do
            subject
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601
          end
        end

        context '従業員数と売上がないとき' do
          let(:employee) { nil }
          let(:sales) { nil }
          it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(3) }
          it do
            subject
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.month).iso8601
          end
        end
      end

      context '更新の時' do

        let!(:capital_ccg) { create(:company_company_group, company: company, company_group: capital_group4, source: 'only_register') }
        let!(:employee_ccg) { create(:company_company_group, company: company, company_group: employee_group2, source: 'biz_map') }
        let!(:sales_ccg) { create(:company_company_group, company: company, company_group: sales_group1, source: 'corporate_site') }

        context '全て揃っている時' do
          it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(0) }
          it do
            subject
            expect(capital_ccg.reload.company_group).to eq capital_group2
            expect(capital_ccg.source).to eq 'biz_map'
            expect(capital_ccg.expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(employee_ccg.reload.company_group).to eq employee_group3
            expect(employee_ccg.source).to eq 'biz_map'
            expect(employee_ccg.expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(sales_ccg.reload.company_group).to eq sales_group4
            expect(sales_ccg.source).to eq 'biz_map'
            expect(sales_ccg.expired_at).to eq (Time.zone.now + 1.year).iso8601
          end
        end

        context '従業員数と売上がないとき' do
          let(:employee) { nil }
          let(:sales) { nil }

          it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(0) }
          it do
            em_updated_at = employee_ccg.updated_at
            sa_updated_at = sales_ccg.updated_at
            subject
            expect(capital_ccg.reload.company_group).to eq capital_group2
            expect(capital_ccg.source).to eq 'biz_map'
            expect(capital_ccg.expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(employee_ccg.reload.company_group).to eq employee_group2
            expect(employee_ccg.source).to eq 'biz_map'
            expect(employee_ccg.updated_at).to eq em_updated_at

            expect(sales_ccg.reload.company_group).to eq sales_group1
            expect(sales_ccg.source).to eq 'corporate_site'
            expect(employee_ccg.updated_at).to eq sa_updated_at
          end
        end
      end

    end
  end

  describe '#check_surfix_headers' do
    subject { described_class.send(:check_surfix_headers, headers) }

    context '業種が間違っている時' do
      context do
        let(:headers) { ['大業種_1', '中業種_1', '小業種_1', '細業種_2', '', '', ''] }
        it { expect{ subject }.to raise_error(RuntimeError, /業種ヘッダーが間違っています。surfix => 1/) }
      end

      context do
        let(:headers) { ['大業種_1', '中業種_1', '小業種_1', '細業種_1', '大業種_2', '中業種_2', '小業種_3', '細業種_2'] }
        it { expect{ subject }.to raise_error(RuntimeError, /業種ヘッダーが間違っています。surfix => 2/) }
      end

      context do
        let(:headers) { ['大業種_1', '中業種_1', '小業種_1', '細業種_1', '大業種_2', '中業種_2', '小業種_2', '細業種_2', '大業種_3', '中業種_2', '小業種_3', '細業種_3'] }
        it { expect{ subject }.to raise_error(RuntimeError, /業種ヘッダーが間違っています。surfix => 3/) }
      end

      context do
        let(:headers) { ['大業種_1', '中業種_1', '小業種_1', '細業種_1', '中業種_aa', '', ''] }
        it { expect{ subject }.to raise_error(RuntimeError, /間違っている中業種ヘッダーがあります。surfix => aa/) }
      end

      context do
        let(:headers) { ['大業種_1', '中業種_1', '小業種_1', '細業種_1', '小業種_bb', '', ''] }
        it { expect{ subject }.to raise_error(RuntimeError, /間違っている小業種ヘッダーがあります。surfix => bb/) }
      end

      context do
        let(:headers) { ['大業種_1', '中業種_1', '小業種_1', '細業種_1', '細業種_cc', '', ''] }
        it { expect{ subject }.to raise_error(RuntimeError, /間違っている細業種ヘッダーがあります。surfix => cc/) }
      end
    end

    context 'エリアが間違っている時' do
      context do
        let(:headers) { ['地方_1', '県_1', '市区町村_2', '', '', ''] }
        it { expect{ subject }.to raise_error(RuntimeError, /エリアヘッダーが間違っています。surfix => 1/) }
      end

      context do
        let(:headers) { ['地方_1', '県_1', '市区町村_1', '地方_2', '県_3', '市区町村_2'] }
        it { expect{ subject }.to raise_error(RuntimeError, /エリアヘッダーが間違っています。surfix => 2/) }
      end

      context do
        let(:headers) { ['地方_1', '県_1', '市区町村_1', '県_あ', '市区町村_2'] }
        it { expect{ subject }.to raise_error(RuntimeError, /間違っている県ヘッダーがあります。surfix => あ/) }
      end

      context do
        let(:headers) { ['地方_2', '県_2', '市区町村_2', '市区町村_あい'] }
        it { expect{ subject }.to raise_error(RuntimeError, /間違っている市区町村ヘッダーがあります。surfix => あい/) }
      end
    end

    context '正しい時' do
      context do
        let(:headers) { ['地方', '県', '市区町村', '', '', ''] }
        it { expect(subject).to eq({ category: [], area: [] }) }
      end

      context do
        let(:headers) { ['大業種_2', '中業種_2', '小業種_2', '細業種_2', '地方_1', '県_1', '市区町村_1'] }
        it { expect(subject).to eq({ category: ['2'], area: ['1'] }) }
      end

      context do
        let(:headers) { ['大業種_2', '中業種_2', '小業種_2', '細業種_2', '地方_1', '県_1', '市区町村_1', '大業種_a', '中業種_a', '小業種_a', '細業種_a','地方_b', '県_b', '市区町村_b'] }
        it { expect(subject).to eq({ category: ['2', 'a'], area: ['1', 'b'] }) }
      end
    end
  end

  describe '#check_category_validation' do
    subject { described_class.send(:check_category_validation, data, category_surfixies) }

    context '間違っている時' do
      context do
        let(:data) { { '大業種' => 'a', '中業種' => 'b', '小業種' => '', '細業種' => 'd' } }
        let(:category_surfixies) { [] }
        it { expect{ subject }.to raise_error(RuntimeError, /surfixなし業種が間違っています。/) }
      end

      context do
        let(:data) { { '大業種' => 'a', '中業種' => 'b', '小業種' => 'c', '細業種' => 'd', '大業種_1' => 'a', '中業種_1' => '', '小業種_1' => 'c', '細業種_1' => 'd' } }
        let(:category_surfixies) { ['1'] }
        it { expect{ subject }.to raise_error(RuntimeError, /「1」業種が間違っています。/) }
      end

      context do
        let(:data) { { '大業種' => 'a', '中業種' => 'b', '小業種' => 'c', '細業種' => 'd', '大業種_a' => '', '中業種_a' => 'b', '小業種_a' => 'c', '細業種_a' => 'd' } }
        let(:category_surfixies) { ['a'] }
        it { expect{ subject }.to raise_error(RuntimeError, /「a」業種が間違っています。/) }
      end

      context do
        let(:data) { { '大業種' => 'a', '中業種' => '', '小業種' => 'c', '細業種' => '', '大業種_1' => 'a', '中業種_1' => 'b', '小業種_1' => 'c', '細業種_1' => 'd' } }
        let(:category_surfixies) { ['1'] }
        it { expect{ subject }.to raise_error(RuntimeError, /surfixなし業種が間違っています。/) }
      end

      context do
        let(:data) { { '大業種' => 'a', '中業種' => 'b', '小業種' => 'c', '細業種' => 'd', '大業種_2' => '', '中業種_2' => 'b', '小業種_2' => '', '細業種_2' => '' } }
        let(:category_surfixies) { ['2'] }
        it { expect{ subject }.to raise_error(RuntimeError, /「2」業種が間違っています。/) }
      end
    end

    context '正しい時' do
      context do
        let(:data) { { '大業種' => 'a', '中業種' => 'b', '小業種' => 'c', '細業種' => 'd', '大業種_2' => 'a', '中業種_2' => 'b', '小業種_2' => '', '細業種_2' => '' } }
        let(:category_surfixies) { ['2'] }
        it { expect{ subject }.not_to raise_error }
      end
    end
  end

  describe '#check_area_validation' do
    subject { described_class.send(:check_area_validation, data, area_surfixies) }

    context '間違っている時' do
      context do
        let(:data) { { '地方' => 'a', '県' => '', '市区町村' => 'c' } }
        let(:area_surfixies) { [] }
        it { expect{ subject }.to raise_error(RuntimeError, /surfixなしエリアが間違っています。/) }
      end

      context do
        let(:data) { { '地方' => 'a', '県' => 'b', '市区町村' => 'c', '地方_1' => '', '県_1' => 'b', '市区町村_1' => 'c' } }
        let(:area_surfixies) { ['1'] }
        it { expect{ subject }.to raise_error(RuntimeError, /「1」エリアが間違っています。/) }
      end

      context do
        let(:data) { { '地方' => 'a', '県' => 'b', '市区町村' => 'c', '地方_a' => '', '県_a' => 'b', '市区町村_a' => '' } }
        let(:area_surfixies) { ['a'] }
        it { expect{ subject }.to raise_error(RuntimeError, /「a」エリアが間違っています。/) }
      end

      context do
        let(:data) { { '地方' => '', '県' => '', '市区町村' => 'b', '地方_a' => 'a', '県_a' => 'b', '市区町村_a' => '' } }
        let(:area_surfixies) { ['a'] }
        it { expect{ subject }.to raise_error(RuntimeError, /surfixなしエリアが間違っています。/) }
      end

      context do
        let(:data) { { '地方' => 'c', '県' => '', '市区町村' => '', '地方_2' => '', '県_2' => '', '市区町村_2' => 'b' } }
        let(:area_surfixies) { ['2'] }
        it { expect{ subject }.to raise_error(RuntimeError, /「2」エリアが間違っています。/) }
      end
    end

    context '地方の空欄が補完される時' do
      context do
        let(:data) { { '地方' => '', '県' => '熊本県', '市区町村' => 'c' } }
        let(:area_surfixies) { [] }
        it { expect{ subject }.not_to raise_error }
        it { expect(subject['地方']).to eq '九州・沖縄' }
      end

      context do
        let(:data) { { '地方' => 'a', '県' => 'b', '市区町村' => 'c', '地方_1' => '', '県_1' => '宮城県', '市区町村_1' => 'c' } }
        let(:area_surfixies) { ['1'] }
        it { expect{ subject }.not_to raise_error }
        it do
          expect(subject['地方']).to eq 'a'
          expect(subject['地方_1']).to eq '北海道・東北'
        end
      end
    end

    context '正しい時' do
      context do
        let(:data) { { '地方' => 'a', '県' => 'b', '市区町村' => '', '地方_2' => 'a', '県_2' => '', '市区町村_2' => '' } }
        let(:area_surfixies) { ['2'] }
        it { expect{ subject }.not_to raise_error }
      end
    end
  end

  describe '#import' do
    subject { described_class.import(file_path) }
    let(:correct_ex)   { Excel::Import.new(correct_file, 1, true).to_hash_data }

    context '異常系' do
      context 'エクセルのヘッダーが間違っている時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_headers.xlsx').to_s }
        it { expect{subject}.to raise_error(RuntimeError, /ヘッダーが間違っています。 0行目付近/).and change(described_class, :count).by(0) }

        # it { expect{subject}.to change(described_class, :count).by(0) }
      end

      context 'グループIDヘッダーが重複している時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_duplicate_group.xlsx').to_s }

        it { expect{subject}.to raise_error(CompanyGroupConstraint::DuplicatedGroupIDHeaders, /重複しているグループIDが存在しています。 0行目付近/).and change(described_class, :count).by(0) }
      end

      context 'グループIDが存在していない時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_group_id.xlsx').to_s }

        it { expect{subject}.to raise_error(CompanyGroupConstraint::NotFoundGroupID, /グループIDのグループIDは存在しないIDです。1 2行目付近/).and change(described_class, :count).by(0) }
      end

      context 'グループIDが空欄の時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_blank_group_id.xlsx').to_s }

        it { expect{subject}.to raise_error(CompanyGroupConstraint::BlankGroupID, /グループIDのグループIDが空欄です。空欄を許可するにはヘッダーに「空欄許可」を加えてください。 2行目付近/).and change(described_class, :count).by(0) }
      end

      context 'ドメインが間違っている時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_domain.xlsx').to_s }

        let_it_be(:region) { Region.create(name: '関東') }
        let_it_be(:prefecture) { Prefecture.create(name: '東京都') }

        it { expect{subject}.to raise_error(RuntimeError, /ドメインが空の行があります。3行目付近。/).and change(described_class, :count).by(0) }
      end

      context 'カテゴリーが間違っている時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_category.xlsx').to_s }
        it { expect{subject}.to raise_error(RuntimeError, /surfixなし業種が間違っています。 2行目付近/).and change(described_class, :count).by(0) }
      end

      context 'サーフィックス付きのカテゴリーが間違っている時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_category_with_surfix.xlsx').to_s }
        it { expect{subject}.to raise_error(RuntimeError, /「2」業種が間違っています。 2行目付近/).and change(described_class, :count).by(0) }
      end

      context 'エリアが間違っている時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_area.xlsx').to_s }
        it { expect{subject}.to raise_error(RuntimeError, /surfixなしエリアが間違っています。 2行目付近/).and change(described_class, :count).by(0) }
      end

      context 'サーフィックス付きのエリアが間違っている時' do
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_area_with_surfix.xlsx').to_s }
        it { expect{subject}.to raise_error(RuntimeError, /「a」エリアが間違っています。 2行目付近/).and change(described_class, :count).by(0) }
      end

      describe '地域に関して' do
        let_it_be(:region) { Region.create(name: '関東') }
        let_it_be(:prefecture) { Prefecture.create(name: '東京都') }

        context 'エリアが間違っている時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_nothing_category_area.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /業種もエリアもありません。3行目付近。/).and change(described_class, :count).by(0) }
        end

        context '存在しない地方の時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_region.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /存在しない地方、県が記載されています。 2行目付近/).and change(described_class, :count).by(0) }
        end

        context '存在しない県の時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_prefecture.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /存在しない地方、県が記載されています。 2行目付近/).and change(described_class, :count).by(0) }
        end
      end

      describe '複数の業種ヘッダーに関して' do
        context '業種ヘッダーが間違っている時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_category_headers.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /業種ヘッダーが間違っています。surfix => 1。 0行目付近/).and change(described_class, :count).by(0) }
        end

        context '業種ヘッダーが間違っている時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_category_headers2.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /間違っている中業種ヘッダーがあります。surfix => 2。 0行目付近/).and change(described_class, :count).by(0) }
        end
      end

      describe '複数のエリアヘッダーに関して' do
        context '業種ヘッダーが間違っている時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_area_headers.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /エリアヘッダーが間違っています。surfix => a。 0行目付近/).and change(described_class, :count).by(0) }
        end

        context '業種ヘッダーが間違っている時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_area_headers2.xlsx').to_s }
          it { expect{subject}.to raise_error(RuntimeError, /間違っている市区町村ヘッダーがあります。surfix => b。 0行目付近/).and change(described_class, :count).by(0) }
        end
      end

      context 'ソースが間違っている時' do
        let_it_be(:region) { Region.create(name: '関東') }
        let_it_be(:prefecture) { Prefecture.create(name: '東京都') }

        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'wrong_source.xlsx').to_s }
        it { expect{subject}.to raise_error(RuntimeError, /ソースがsource_listに存在しません。=> aaa/).and change(described_class, :count).by(0) }
      end
    end

    context '正常系' do
      let_it_be(:company_group1) { create(:company_group, id: 1, title: '1', grouping_number: 1) }
      let_it_be(:company_group2) { create(:company_group, id: 2, title: '2', grouping_number: 2) }
      let_it_be(:company_group3) { create(:company_group, id: 3, title: '1', grouping_number: 1) }
      let_it_be(:company_group4) { create(:company_group, id: 4, title: '2', grouping_number: 2) }

      let_it_be(:region1) { Region.create(name: '関東') }
      let_it_be(:prefecture1) { Prefecture.create(name: '東京都') }
      let_it_be(:connector1) { AreaConnector.create(region: region1, prefecture: nil, city: nil) }
      let_it_be(:connector2) { AreaConnector.create(region: region1, prefecture: prefecture1, city: nil) }
      let_it_be(:region2) { Region.create(name: '東海') }
      let_it_be(:prefecture2) { Prefecture.create(name: '愛知県') }
      let_it_be(:connector3) { AreaConnector.create(region: region2, prefecture: nil, city: nil) }
      let_it_be(:connector4) { AreaConnector.create(region: region2, prefecture: prefecture2, city: nil) }
      let_it_be(:region3) { Region.create(name: '近畿') }
      let_it_be(:prefecture3) { Prefecture.create(name: '京都府') }
      let_it_be(:connector5) { AreaConnector.create(region: region3, prefecture: nil, city: nil) }
      let_it_be(:connector6) { AreaConnector.create(region: region3, prefecture: prefecture3, city: nil) }

      describe 'URLからドメイン変換' do
        let(:domain) { 'example.com' }

        context 'URLが登録されている時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'url_to_domain1.xlsx').to_s }

          it { expect{subject}.to change(described_class, :count).by(1) }
          it 'ドメインに変更されること' do
            subject
            company = Company.find_by(domain: domain)
            expect(company).to be_present
          end
        end

        context 'ドメイン＋パスが記載されてる時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'url_to_domain2.xlsx').to_s }

          it { expect{subject}.to change(described_class, :count).by(1) }
          it 'ドメインに変更されること' do
            subject
            company = Company.find_by(domain: domain)
            expect(company).to be_present
          end
        end
      end

      describe '企業に関して' do
        context '存在しない企業ドメイン' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:domain) { 'example.com' }

          it { expect{subject}.to change(described_class, :count).by(1) }
          it do
            subject
            company = Company.find_by(domain: domain)
            expect(company).to be_present
          end
        end

        context '存在する企業ドメイン' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:domain) { 'example.com' }

          before { create(:company, domain: domain) }

          it { expect{subject}.to change(described_class, :count).by(0) }
          it do
            subject
            company = Company.find_by(domain: domain)
            expect(company).to be_present
          end
        end
      end

      describe '企業グループに関して' do
        let(:domain) { 'example.com' }

        context '関連づいてない企業グループ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }

          before do
            company_group1
            company_group2
          end

          it { expect{subject}.to change(CompanyCompanyGroup, :count).by(2) }
          it do
            subject
            company = Company.find_by(domain: domain)
            expect(CompanyCompanyGroup.where(company: company, company_group: company_group1)).to be_present
            expect(CompanyCompanyGroup.where(company: company, company_group: company_group2)).to be_present
          end
        end

        context '関連づいているグループ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:company) { create(:company, domain: domain) }

          before do
            create(:company_company_group, company: company, company_group: company_group1)
            create(:company_company_group, company: company, company_group: company_group2)
          end

          it '関連づけが増えないこと' do
            expect{subject}.to change(CompanyCompanyGroup, :count).by(0)
          end
        end

        context '関連づいているグループ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct3.xlsx').to_s }
          let(:domain) { 'example2.com' }
          let(:company) { create(:company, domain: 'example.com') }

          before do
            Region.create(name: '東北')
            Prefecture.create(name: '宮城県')
            create(:company_company_group, company: company, company_group: company_group1)
            create(:company_company_group, company: company, company_group: company_group2)
            company_group3
            company_group4
          end

          it { expect{subject}.to change(CompanyCompanyGroup, :count).by(2) }
          it do
            subject
            company2 = Company.find_by(domain: domain)
            expect(CompanyCompanyGroup.where(company: company2, company_group: company_group3)).to be_present
            expect(CompanyCompanyGroup.where(company: company2, company_group: company_group4)).to be_present
          end
        end
      end

      describe '業種に関して' do
        context '新しいカテゴリ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:domain) { 'example.com' }

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(1) }
          it { expect{subject}.to change(MiddleCategory, :count).by(1) }
          it { expect{subject}.to change(SmallCategory, :count).by(1) }
          it { expect{subject}.to change(DetailCategory, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(3) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(1) }

          it do
            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: nil, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)).to be_present

            connector = CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)
            expect(Company.find_by(domain: domain).category_connectors[0]).to eq connector
            expect(Company.find_by(domain: domain).category_connectors.size).to eq 1
          end
        end

        context '複数のsurfix付きの新しいカテゴリ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct_with_surfix.xlsx').to_s }
          let(:domain) { 'example.com' }

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(3) }
          it { expect{subject}.to change(MiddleCategory, :count).by(3) }
          it { expect{subject}.to change(SmallCategory, :count).by(3) }
          it { expect{subject}.to change(DetailCategory, :count).by(1) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(10) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(3) }

          it do
            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: nil, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)).to be_present

            connector = CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)
            expect(Company.find_by(domain: domain).category_connectors[0]).to eq connector

            large1 = LargeCategory.find_by(name: '金融')
            middle1 = MiddleCategory.find_by(name: '銀行')
            small1 = SmallCategory.find_by(name: '地方銀行')
            expect(large1).to be_present
            expect(middle1).to be_present
            expect(small1).to be_present
            expect(CategoryConnector.find_by(large_category: large1, middle_category: nil, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large1, middle_category: middle1, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large1, middle_category: middle1, small_category: small1, detail_category: nil)).to be_present

            connector = CategoryConnector.find_by(large_category: large1, middle_category: middle1, small_category: small1, detail_category: nil)
            expect(Company.find_by(domain: domain).category_connectors[1]).to eq connector

            large2 = LargeCategory.find_by(name: '小売')
            middle2 = MiddleCategory.find_by(name: '食品')
            small2 = SmallCategory.find_by(name: '小麦粉')
            detail2 = DetailCategory.find_by(name: 'パン')
            expect(large2).to be_present
            expect(middle2).to be_present
            expect(small2).to be_present
            expect(detail2).to be_present
            expect(CategoryConnector.find_by(large_category: large2, middle_category: nil, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large2, middle_category: middle2, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large2, middle_category: middle2, small_category: small2, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large2, middle_category: middle2, small_category: small2, detail_category: detail2)).to be_present

            connector = CategoryConnector.find_by(large_category: large2, middle_category: middle2, small_category: small2, detail_category: detail2)
            expect(Company.find_by(domain: domain).category_connectors[2]).to eq connector
            expect(Company.find_by(domain: domain).category_connectors.size).to eq 3
          end
        end

        context '新しいカテゴリ、地域がない時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct_only_category.xlsx').to_s }
          let(:domain) { 'example.com' }

          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(0) }
          it { expect{subject}.to change(AreaConnector, :count).by(0) }
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(0) }

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(1) }
          it { expect{subject}.to change(MiddleCategory, :count).by(1) }
          it { expect{subject}.to change(SmallCategory, :count).by(1) }
          it { expect{subject}.to change(DetailCategory, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(3) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(1) }

          it do
            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: nil, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)).to be_present

            connector = CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)
            expect(Company.find_by(domain: domain).category_connectors[0]).to eq connector
            expect(Company.find_by(domain: domain).category_connectors.size).to eq 1
          end
        end

        context '存在している企業、追加で詳細カテゴリ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct2.xlsx').to_s }
          let(:domain) { 'example.com' }
          let(:company) { create(:company, domain: domain) }
          let(:large) { create(:large_category, name: '製造業') }
          let(:middle) { create(:middle_category, name: '金属') }
          let(:small) { create(:small_category, name: 'アルミ') }
          let(:connector1) { create(:category_connector, large_category: large, middle_category: nil, small_category: nil, detail_category: nil) }
          let(:connector2) { create(:category_connector, large_category: large, middle_category: middle, small_category: nil, detail_category: nil) }
          let(:connector3) { create(:category_connector, large_category: large, middle_category: middle, small_category: small, detail_category: nil) }
          let(:company_connector) { create(:company_category_connector, company: company, category_connector: connector3) }

          before do
            connector1
            connector2
            connector3
            company_connector
          end

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(0) }
          it { expect{subject}.to change(MiddleCategory, :count).by(0) }
          it { expect{subject}.to change(SmallCategory, :count).by(0) }
          it { expect{subject}.to change(DetailCategory, :count).by(1) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(1) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(1) }

          it { expect{subject}.to change{ company.reload.category_connectors.size }.by(1) }

          it do
            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            detail = DetailCategory.find_by(name: 'アルミ缶')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(detail).to be_present
            expect(connector1.reload).to be_present
            expect(connector2.reload).to be_present
            expect(connector3.reload).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: detail)).to be_present

            connector = CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: detail)
            expect(company.reload.category_connectors[1]).to eq connector
            expect(company.reload.category_connectors.size).to eq 2
          end
        end

        context '存在している企業、すでに紐づいているカテゴリ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:domain) { 'example.com' }
          let(:company) { create(:company, domain: domain) }
          let(:large) { create(:large_category, name: '製造業') }
          let(:middle) { create(:middle_category, name: '金属') }
          let(:small) { create(:small_category, name: 'アルミ') }
          let(:connector1) { create(:category_connector, large_category: large, middle_category: nil, small_category: nil, detail_category: nil) }
          let(:connector2) { create(:category_connector, large_category: large, middle_category: middle, small_category: nil, detail_category: nil) }
          let(:connector3) { create(:category_connector, large_category: large, middle_category: middle, small_category: small, detail_category: nil) }
          let(:company_connector) { create(:company_category_connector, company: company, category_connector: connector3) }

          before do
            connector1
            connector2
            connector3
            company_connector
          end

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(0) }
          it { expect{subject}.to change(MiddleCategory, :count).by(0) }
          it { expect{subject}.to change(SmallCategory, :count).by(0) }
          it { expect{subject}.to change(DetailCategory, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(0) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(0) }

          it { expect{subject}.to change{ company.reload.category_connectors.size }.by(0) }

          it do
            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(connector1.reload).to be_present
            expect(connector2.reload).to be_present
            expect(connector3.reload).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)).to be_present

            connector = CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)
            expect(company.reload.category_connectors[0]).to eq connector
            expect(company.reload.category_connectors.size).to eq 1
          end
        end

        context '新しい企業、全く同じカテゴリ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:domain) { 'example.com' }
          let(:company) { Company.find_by(domain: domain) }
          let(:large) { create(:large_category, name: '製造業') }
          let(:middle) { create(:middle_category, name: '金属') }
          let(:small) { create(:small_category, name: 'アルミ') }
          let(:connector1) { create(:category_connector, large_category: large, middle_category: nil, small_category: nil, detail_category: nil) }
          let(:connector2) { create(:category_connector, large_category: large, middle_category: middle, small_category: nil, detail_category: nil) }
          let(:connector3) { create(:category_connector, large_category: large, middle_category: middle, small_category: small, detail_category: nil) }

          before do
            connector1
            connector2
            connector3
          end

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(0) }
          it { expect{subject}.to change(MiddleCategory, :count).by(0) }
          it { expect{subject}.to change(SmallCategory, :count).by(0) }
          it { expect{subject}.to change(DetailCategory, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(0) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(1) }

          it do
            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(connector1.reload).to be_present
            expect(connector2.reload).to be_present
            expect(connector3.reload).to be_present

            expect(company.reload.category_connectors[0]).to eq connector3
            expect(company.reload.category_connectors.size).to eq 1
          end
        end

        context '存在している企業で新しいカテゴリ、新しい企業で存在しているカテゴリ' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct3.xlsx').to_s }
          let(:domain) { 'example.com' }
          let(:domain2) { 'example2.com' }
          let(:company) { create(:company, domain: domain) }
          let(:company2) { Company.find_by(domain: domain2) }
          let(:large) { create(:large_category, name: '製造業') }
          let(:middle) { create(:middle_category, name: '金属') }
          let(:small) { create(:small_category, name: 'アルミ') }
          let(:connector1) { create(:category_connector, large_category: large, middle_category: nil, small_category: nil, detail_category: nil) }
          let(:connector2) { create(:category_connector, large_category: large, middle_category: middle, small_category: nil, detail_category: nil) }
          let(:connector3) { create(:category_connector, large_category: large, middle_category: middle, small_category: small, detail_category: nil) }
          let(:company_connector) { create(:company_category_connector, company: company, category_connector: connector3) }

          before do
            company
            connector1
            connector2
            connector3
            company_connector

            region = Region.create(name: '東北')
            prefecture = Prefecture.create(name: '宮城県')
            AreaConnector.create(region: region, prefecture: nil, city: nil)
            AreaConnector.create(region: region, prefecture: prefecture, city: nil)
          end

          # 業種が作られること
          it { expect{subject}.to change(LargeCategory, :count).by(1) }
          it { expect{subject}.to change(MiddleCategory, :count).by(1) }
          it { expect{subject}.to change(SmallCategory, :count).by(0) }
          it { expect{subject}.to change(DetailCategory, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(CategoryConnector, :count).by(2) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(2) }

          it { expect{subject}.to change{ company.reload.category_connectors.size }.by(1) }

          it do
            expect(Company.find_by(domain: domain2)).to be_nil

            subject
            large = LargeCategory.find_by(name: '製造業')
            middle = MiddleCategory.find_by(name: '金属')
            small = SmallCategory.find_by(name: 'アルミ')
            expect(large).to be_present
            expect(middle).to be_present
            expect(small).to be_present
            expect(connector1.reload).to be_present
            expect(connector2.reload).to be_present
            expect(connector3.reload).to be_present
            expect(CategoryConnector.find_by(large_category: large, middle_category: middle, small_category: small, detail_category: nil)).to be_present


            large2 = LargeCategory.find_by(name: '小売')
            middle2 = MiddleCategory.find_by(name: '食品')
            expect(large2).to be_present
            expect(middle2).to be_present
            expect(CategoryConnector.find_by(large_category: large2, middle_category: nil, small_category: nil, detail_category: nil)).to be_present
            expect(CategoryConnector.find_by(large_category: large2, middle_category: middle2, small_category: nil, detail_category: nil)).to be_present


            connector = CategoryConnector.find_by(large_category: large2, middle_category: middle2, small_category: nil, detail_category: nil)
            expect(company.reload.category_connectors[0]).to eq connector3
            expect(company.reload.category_connectors[1]).to eq connector
            expect(company.reload.category_connectors.size).to eq 2

            expect(company2.reload.category_connectors[0]).to eq connector3
            expect(company2.reload.category_connectors.size).to eq 1
          end
        end
      end

      describe '地域に関して' do
        context '新しい地域' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct.xlsx').to_s }
          let(:domain) { 'example.com' }

          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }
          let(:city) { City.find_by(name: '新宿区') }

          # 地域が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(1) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(1) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(1) }

          it do
            subject
            expect(region).to be_present
            expect(prefecture).to be_present
            expect(city).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: city)).to be_present

            connector = AreaConnector.find_by(region: region, prefecture: prefecture, city: city)
            expect(Company.find_by(domain: domain).area_connectors[0]).to eq connector
            expect(Company.find_by(domain: domain).area_connectors.size).to eq 1
          end
        end

        context '複数のsurfix付きの新しい地域' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct_with_surfix.xlsx').to_s }
          let(:domain) { 'example.com' }

          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }
          let(:city) { City.find_by(name: '新宿区') }

          # 地域が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(2) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(2) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(3) }

          it do
            subject
            expect(region).to be_present
            expect(prefecture).to be_present
            expect(city).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: city)).to be_present

            connector = AreaConnector.find_by(region: region, prefecture: prefecture, city: city)
            expect(Company.find_by(domain: domain).area_connectors[1]).to eq connector

            region1 = Region.find_by(name: '東海')
            prefecture1 = Prefecture.find_by(name: '愛知県')
            city1 = City.find_by(name: '名古屋市')

            expect(AreaConnector.find_by(region: region1, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region1, prefecture: prefecture1, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region1, prefecture: prefecture1, city: city1)).to be_present

            connector = AreaConnector.find_by(region: region1, prefecture: prefecture1, city: city1)
            expect(Company.find_by(domain: domain).area_connectors[2]).to eq connector

            region2 = Region.find_by(name: '近畿')
            prefecture2 = Prefecture.find_by(name: '京都府')

            expect(AreaConnector.find_by(region: region2, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region2, prefecture: prefecture2, city: nil)).to be_present

            connector = AreaConnector.find_by(region: region2, prefecture: prefecture2, city: nil)
            expect(Company.find_by(domain: domain).area_connectors[0]).to eq connector
            expect(Company.find_by(domain: domain).area_connectors.size).to eq 3
          end
        end

        context '地方が補完される' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'complement_region.xlsx').to_s }
          let(:domain) { 'example.com' }

          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }
          let(:city) { City.find_by(name: '新宿区') }

          before do
            region = Region.create(name: '中国')
            prefecture = Prefecture.create(name: '広島県')
            AreaConnector.create(region: region, prefecture: nil, city: nil)
            AreaConnector.create(region: region, prefecture: prefecture, city: nil)
          end

          # 地域が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(2) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(2) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(2) }

          it do
            subject
            expect(region).to be_present
            expect(prefecture).to be_present
            expect(city).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: city)).to be_present

            connector = AreaConnector.find_by(region: region, prefecture: prefecture, city: city)
            expect(Company.find_by(domain: domain).area_connectors[0]).to eq connector

            region1 = Region.find_by(name: '中国')
            prefecture1 = Prefecture.find_by(name: '広島県')
            city1 = City.find_by(name: '広島市')

            expect(AreaConnector.find_by(region: region1, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region1, prefecture: prefecture1, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region1, prefecture: prefecture1, city: city1)).to be_present

            connector = AreaConnector.find_by(region: region1, prefecture: prefecture1, city: city1)
            expect(Company.find_by(domain: domain).area_connectors[1]).to eq connector

            expect(Company.find_by(domain: domain).area_connectors.size).to eq 2
          end
        end

        context '新しい地域、カテゴリーがない時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct_only_area.xlsx').to_s }
          let(:domain) { 'example.com' }

          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }
          let(:city) { City.find_by(name: '新宿区') }

          # 業種が作られないこと
          it { expect{subject}.to change(LargeCategory, :count).by(0) }
          it { expect{subject}.to change(MiddleCategory, :count).by(0) }
          it { expect{subject}.to change(SmallCategory, :count).by(0) }
          it { expect{subject}.to change(DetailCategory, :count).by(0) }
          it { expect{subject}.to change(CategoryConnector, :count).by(0) }
          it { expect{subject}.to change(CompanyCategoryConnector, :count).by(0) }

          # 地域が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(1) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(1) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(1) }

          it do
            subject
            expect(region).to be_present
            expect(prefecture).to be_present
            expect(city).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: city)).to be_present

            connector = AreaConnector.find_by(region: region, prefecture: prefecture, city: city)
            expect(Company.find_by(domain: domain).area_connectors[0]).to eq connector
            expect(Company.find_by(domain: domain).area_connectors.size).to eq 1
          end
        end

        context '存在している企業、すでに紐づいている地域' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct2.xlsx').to_s }
          let(:domain) { 'example.com' }

          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }

          let(:company) { create(:company, domain: domain) }
          let(:connector) { AreaConnector.find_by(region: region, prefecture: prefecture, city: nil) }
          let(:company_connector) { create(:company_area_connector, company: company, area_connector: connector) }

          before do
            company_connector
          end

          # 地域が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(0) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(0) }

          it do
            subject
            expect(region).to be_present
            expect(prefecture).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: nil)).to be_present

            expect(company.reload.area_connectors[0]).to eq connector
            expect(company.reload.area_connectors.size).to eq 1
          end
        end

        context '新しい企業、全く同じ地域' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct2.xlsx').to_s }
          let(:domain) { 'example.com' }
          let(:company) { Company.find_by(domain: domain) }

          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }

          let(:connector) { AreaConnector.find_by(region: region, prefecture: prefecture, city: nil) }

          # 地域が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(0) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(0) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(1) }

          it do
            subject
            expect(region).to be_present
            expect(prefecture).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: nil, city: nil)).to be_present
            expect(AreaConnector.find_by(region: region, prefecture: prefecture, city: nil)).to be_present

            expect(company.reload.area_connectors[0]).to eq connector
            expect(company.reload.area_connectors.size).to eq 1
          end
        end

        context '存在している企業で新しい地域、新しい企業で存在している地域' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct3.xlsx').to_s }
          let(:domain) { 'example.com' }
          let(:domain2) { 'example2.com' }
          let(:company) { create(:company, domain: domain) }
          let(:company2) { Company.find_by(domain: domain2) }
          let(:region) { Region.find_by(name: '関東') }
          let(:prefecture) { Prefecture.find_by(name: '東京都') }
          let(:city) { create(:city, name: '新宿区') }
          let(:region2) { create(:region, name: '東北') }
          let(:prefecture2) { create(:prefecture, name: '宮城県') }
          let(:city2) { City.find_by(name: '仙台市') }
    
          let(:connector1) { create(:area_connector, region: region, prefecture: prefecture, city: city) }
          let(:connector2) { create(:area_connector, region: region2, prefecture: nil, city: nil) }
          let(:connector3) { create(:area_connector, region: region2, prefecture: prefecture2, city: nil) }

          before do
            company
            connector1
            connector2
            connector3
          end

          # 業種が作られること
          it { expect{subject}.to change(Region, :count).by(0) }
          it { expect{subject}.to change(Prefecture, :count).by(0) }
          it { expect{subject}.to change(City, :count).by(1) }

          # コネクターが作られること
          it { expect{subject}.to change(AreaConnector, :count).by(1) }

          # 企業コネクターが作られること
          it { expect{subject}.to change(CompanyAreaConnector, :count).by(2) }

          it { expect{subject}.to change{ company.reload.area_connectors.size }.by(1) }

          it do
            expect(Company.find_by(domain: domain2)).to be_nil

            subject
            expect(region.reload).to be_present
            expect(prefecture.reload).to be_present
            expect(city.reload).to be_present
            expect(region2.reload).to be_present
            expect(prefecture2.reload).to be_present
            expect(city2.reload).to be_present
   
            expect(AreaConnector.find_by(region: region2, prefecture: prefecture2, city: city2)).to be_present

            connector = AreaConnector.find_by(region: region2, prefecture: prefecture2, city: city2)
            expect(company.reload.area_connectors[0]).to eq connector
            expect(company.reload.area_connectors.size).to eq 1

            expect(company2.reload.area_connectors[0]).to eq connector1
            expect(company2.reload.area_connectors.size).to eq 1
          end
        end

      end

      describe 'レンジグループに関して' do
        let(:domain1) { 'example.com' }
        let(:domain2) { 'example2.com' }
        let(:domain3) { 'example3.com' }
        let(:domain4) { 'example4.com' }
        let(:domain5) { 'example5.com' }
        let(:domain6) { 'example6.com' }

        let_it_be(:capital_group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
        let_it_be(:capital_group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10_000_000, lower: 0) }
        let_it_be(:capital_group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 100_000_000, lower: 10_000_001) }
        let_it_be(:capital_group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 100_000_001) }
        let_it_be(:employee_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: nil) }
        let_it_be(:employee_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 50, lower: 0) }
        let_it_be(:employee_group3) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 100, lower: 51) }
        let_it_be(:employee_group4) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 101) }
        let_it_be(:sales_group1) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: nil) }
        let_it_be(:sales_group2) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 10_000_000, lower: 0) }
        let_it_be(:sales_group3) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 1_000_000_000, lower: 10_000_001) }
        let_it_be(:sales_group4) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: 1_000_000_001) }

        before { Timecop.freeze }
        after  { Timecop.return }

        context '新規作成の時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct_range1.xlsx').to_s }

          let!(:company6) { create(:company, domain: domain6) }
          let!(:capital_ccg6)  { create(:company_company_group, company: company6, company_group: capital_group3, source: 'corporate_site', expired_at: Time.zone.now - 10.day) }
          let!(:employee_ccg6) { create(:company_company_group, company: company6, company_group: employee_group2, source: 'corporate_site') }
          let!(:sales_ccg6)    { create(:company_company_group, company: company6, company_group: sales_group1, source: 'corporate_site') }

          it { expect{subject}.to change(CompanyCompanyGroup, :count).by(15) }
          it { expect{subject}.to change(Company, :count).by(5) }
          it do
            em_updated_at6 = employee_ccg6.updated_at

            subject
            company = Company.find_by(domain: domain1)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.month).iso8601

            company = Company.find_by(domain: domain2)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.month).iso8601

            company = Company.find_by(domain: domain3)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601

            company = Company.find_by(domain: domain4)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601

            company = Company.find_by(domain: domain5)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601

            company = Company.find_by(domain: domain6)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'corporate_site'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).updated_at).to eq em_updated_at6

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601
          end
        end

        context '更新の時' do
          let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', 'correct_range1.xlsx').to_s }

          let!(:company1) { create(:company, domain: domain1) }
          let!(:company2) { create(:company, domain: domain2) }
          let!(:company3) { create(:company, domain: domain3) }
          let!(:company4) { create(:company, domain: domain4) }
          let!(:company5) { create(:company, domain: domain5) }
          let!(:company6) { create(:company, domain: domain6) }

          let!(:capital_ccg1)  { create(:company_company_group, company: company1, company_group: capital_group1, source: 'corporate_site') }
          let!(:employee_ccg1) { create(:company_company_group, company: company1, company_group: employee_group2, source: 'corporate_site') }
          let!(:sales_ccg1)    { create(:company_company_group, company: company1, company_group: sales_group1, source: 'corporate_site') }
          let!(:capital_ccg2)  { create(:company_company_group, company: company2, company_group: capital_group3, source: 'biz_map', expired_at: Time.zone.now - 10.day) }
          let!(:employee_ccg2) { create(:company_company_group, company: company2, company_group: employee_group1, source: 'biz_map') }
          let!(:sales_ccg2)    { create(:company_company_group, company: company2, company_group: sales_group2, source: 'biz_map') }
          let!(:capital_ccg3)  { create(:company_company_group, company: company3, company_group: capital_group3, source: 'biz_map', expired_at: Time.zone.now - 10.day) }
          let!(:employee_ccg3) { create(:company_company_group, company: company3, company_group: employee_group1, source: 'biz_map') }
          let!(:sales_ccg3)    { create(:company_company_group, company: company3, company_group: sales_group2, source: 'biz_map') }
          let!(:capital_ccg4)  { create(:company_company_group, company: company4, company_group: capital_group3, source: 'only_register') }
          let!(:employee_ccg4) { create(:company_company_group, company: company4, company_group: employee_group1, source: 'only_register') }
          let!(:sales_ccg4)    { create(:company_company_group, company: company4, company_group: sales_group2, source: 'only_register') }
          let!(:capital_ccg5)  { create(:company_company_group, company: company5, company_group: capital_group3, source: 'corporate_site', expired_at: Time.zone.now - 1.day) }
          let!(:employee_ccg5) { create(:company_company_group, company: company5, company_group: employee_group1, source: 'corporate_site') }
          let!(:sales_ccg5)    { create(:company_company_group, company: company5, company_group: sales_group2, source: 'corporate_site') }
          let!(:capital_ccg6)  { create(:company_company_group, company: company6, company_group: capital_group3, source: 'corporate_site', expired_at: Time.zone.now + 10.day) }
          let!(:employee_ccg6) { create(:company_company_group, company: company6, company_group: employee_group1, source: 'corporate_site') }
          let!(:sales_ccg6)    { create(:company_company_group, company: company6, company_group: sales_group2, source: 'corporate_site') }

          it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
          it { expect{subject}.to change(Company, :count).by(0) }
          it do
            em_updated_at1 = employee_ccg1.updated_at
            cp_updated_at2 = capital_ccg2.updated_at
            em_updated_at2 = employee_ccg2.updated_at
            sa_updated_at2 = sales_ccg2.updated_at
            cp_updated_at4 = capital_ccg4.updated_at
            em_updated_at5 = employee_ccg5.updated_at
            sa_updated_at5 = sales_ccg5.updated_at
            cp_updated_at6 = capital_ccg6.updated_at
            sa_updated_at6 = sales_ccg6.updated_at

            subject
            company = Company.find_by(domain: domain1)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.month).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'corporate_site'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).updated_at).to eq em_updated_at1

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.month).iso8601

            company = Company.find_by(domain: domain2)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).updated_at).to eq cp_updated_at2

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).updated_at).to eq em_updated_at2

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).updated_at).to eq sa_updated_at2

            company = Company.find_by(domain: domain3)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601

            company = Company.find_by(domain: domain4)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'only_register'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).updated_at).to eq cp_updated_at4

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group4
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).expired_at).to eq (Time.zone.now + 1.year).iso8601

            company = Company.find_by(domain: domain5)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group1
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'corporate_site'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).updated_at).to eq em_updated_at5

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'corporate_site'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).updated_at).to eq sa_updated_at5

            company = Company.find_by(domain: domain6)
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).company_group).to eq capital_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).source).to eq 'corporate_site'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::CAPITAL).updated_at).to eq cp_updated_at6

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).company_group).to eq employee_group3
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).source).to eq 'biz_map'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::EMPLOYEE).expired_at).to eq (Time.zone.now + 1.year).iso8601

            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).company_group).to eq sales_group2
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).source).to eq 'corporate_site'
            expect(CompanyCompanyGroup.find_by_reserved_group(company, CompanyGroup::SALES).updated_at).to eq sa_updated_at6
          end
        end
      end
    end
  end
end

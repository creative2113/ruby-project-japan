require 'rails_helper'

RSpec.feature "企業HP情報の取得：企業DB検索", type: :feature do
  let_it_be(:master_standard_plan) { create(:master_billing_plan, :standard) }

  before do
    allow(Billing).to receive(:plan_list).and_return(['standard'])
  end

  let_it_be(:public_user) { create(:user_public) }
  let_it_be(:user) { create(:user, billing: :credit) }
  let_it_be(:plan) { create(:billing_plan, name: master_standard_plan.name, billing: user.billing) }

  let_it_be(:region1) { Region.create(name: '関東') }
  let_it_be(:prefecture1) { Prefecture.create(name: '東京都') }
  let_it_be(:city1) { City.create(name: '新宿区') }
  let_it_be(:city2) { City.create(name: '渋谷区') }
  let_it_be(:prefecture2) { Prefecture.create(name: '埼玉県') }
  let_it_be(:prefecture3) { Prefecture.create(name: '千葉県') }
  let_it_be(:city5) { City.create(name: '千葉市') }
  let_it_be(:city6) { City.create(name: '浦安市') }
  let_it_be(:prefecture4) { Prefecture.create(name: '神奈川県') }
  let_it_be(:city7) { City.create(name: '横浜市') }
  let_it_be(:city8) { City.create(name: '川崎市') }
  let_it_be(:region2) { Region.create(name: '東海') }
  let_it_be(:prefecture5) { Prefecture.create(name: '愛知県') }
  let_it_be(:city9) { City.create(name: '名古屋市') }
  let_it_be(:city10) { City.create(name: '春日井市') }
  let_it_be(:prefecture6) { Prefecture.create(name: '静岡県') }
  let_it_be(:prefecture7) { Prefecture.create(name: '三重県') }
  let_it_be(:city13) { City.create(name: '四日市市') }
  let_it_be(:city14) { City.create(name: '鈴鹿市') }
  let_it_be(:region3) { Region.create(name: '近畿') }
  let_it_be(:prefecture8) { Prefecture.create(name: '大阪府') }
  let_it_be(:prefecture9) { Prefecture.create(name: '京都府') }
  let_it_be(:city17) { City.create(name: '京都市') }
  let_it_be(:city18) { City.create(name: '宇治市') }
  let_it_be(:prefecture10) { Prefecture.create(name: '兵庫県') }
  let_it_be(:city19) { City.create(name: '神戸市') }
  let_it_be(:city20) { City.create(name: '姫路市') }

  let_it_be(:area_connector1)  { AreaConnector.create(region: region1, prefecture: nil, city: nil) }
  let_it_be(:area_connector2)  { AreaConnector.create(region: region1, prefecture: prefecture1, city: nil) }
  let_it_be(:area_connector3)  { AreaConnector.create(region: region1, prefecture: prefecture1, city: city1) }
  let_it_be(:area_connector4)  { AreaConnector.create(region: region1, prefecture: prefecture1, city: city2) }
  let_it_be(:area_connector5)  { AreaConnector.create(region: region1, prefecture: prefecture2, city: nil) }
  let_it_be(:area_connector8)  { AreaConnector.create(region: region1, prefecture: prefecture3, city: nil) }
  let_it_be(:area_connector9)  { AreaConnector.create(region: region1, prefecture: prefecture3, city: city5) }
  let_it_be(:area_connector10) { AreaConnector.create(region: region1, prefecture: prefecture3, city: city6) }
  let_it_be(:area_connector11) { AreaConnector.create(region: region1, prefecture: prefecture4, city: nil) }
  let_it_be(:area_connector12) { AreaConnector.create(region: region1, prefecture: prefecture4, city: city7) }
  let_it_be(:area_connector13) { AreaConnector.create(region: region1, prefecture: prefecture4, city: city8) }
  let_it_be(:area_connector14) { AreaConnector.create(region: region2, prefecture: nil, city: nil) }
  let_it_be(:area_connector15) { AreaConnector.create(region: region2, prefecture: prefecture5, city: nil) }
  let_it_be(:area_connector16) { AreaConnector.create(region: region2, prefecture: prefecture5, city: city9) }
  let_it_be(:area_connector17) { AreaConnector.create(region: region2, prefecture: prefecture5, city: city10) }
  let_it_be(:area_connector18) { AreaConnector.create(region: region2, prefecture: prefecture6, city: nil) }
  let_it_be(:area_connector21) { AreaConnector.create(region: region2, prefecture: prefecture7, city: nil) }
  let_it_be(:area_connector22) { AreaConnector.create(region: region2, prefecture: prefecture7, city: city13) }
  let_it_be(:area_connector23) { AreaConnector.create(region: region2, prefecture: prefecture7, city: city14) }
  let_it_be(:area_connector24) { AreaConnector.create(region: region3, prefecture: nil, city: nil) }
  let_it_be(:area_connector25) { AreaConnector.create(region: region3, prefecture: prefecture8, city: nil) }
  let_it_be(:area_connector28) { AreaConnector.create(region: region3, prefecture: prefecture9, city: nil) }
  let_it_be(:area_connector29) { AreaConnector.create(region: region3, prefecture: prefecture9, city: city17) }
  let_it_be(:area_connector30) { AreaConnector.create(region: region3, prefecture: prefecture9, city: city18) }
  let_it_be(:area_connector31) { AreaConnector.create(region: region3, prefecture: prefecture10, city: nil) }
  let_it_be(:area_connector32) { AreaConnector.create(region: region3, prefecture: prefecture10, city: city19) }
  let_it_be(:area_connector33) { AreaConnector.create(region: region3, prefecture: prefecture10, city: city20) }

  let_it_be(:large1) { LargeCategory.create(name: '製造業') }
  let_it_be(:middle1) { MiddleCategory.create(name: '金属') }
  let_it_be(:small1) { SmallCategory.create(name: 'アルミ') }
  let_it_be(:small2) { SmallCategory.create(name: '鉄鋼') }
  let_it_be(:middle2) { MiddleCategory.create(name: '食品') }
  let_it_be(:small3) { SmallCategory.create(name: '缶詰') }
  let_it_be(:small4) { SmallCategory.create(name: 'パン') }
  let_it_be(:middle3) { MiddleCategory.create(name: '衣料') }

  let_it_be(:large2) { LargeCategory.create(name: '小売') }
  let_it_be(:small5) { SmallCategory.create(name: '魚') }
  let_it_be(:middle4) { MiddleCategory.create(name: '家電製品') }

  let_it_be(:large3) { LargeCategory.create(name: '金融') }
  let_it_be(:middle5) { MiddleCategory.create(name: '銀行') }
  let_it_be(:small6) { SmallCategory.create(name: '地方銀行') }
  let_it_be(:middle6) { MiddleCategory.create(name: '保険') }
  let_it_be(:large4) { LargeCategory.create(name: '通信') }

  let_it_be(:category_connector1)  { create(:category_connector, large_category: large1, middle_category: nil, small_category: nil) }
  let_it_be(:category_connector2)  { create(:category_connector, large_category: large1, middle_category: middle1, small_category: nil) }
  let_it_be(:category_connector3)  { create(:category_connector, large_category: large1, middle_category: middle1, small_category: small1) }
  let_it_be(:category_connector4)  { create(:category_connector, large_category: large1, middle_category: middle1, small_category: small2) }

  let_it_be(:category_connector6)  { create(:category_connector, large_category: large1, middle_category: middle2, small_category: nil) }
  let_it_be(:category_connector7)  { create(:category_connector, large_category: large1, middle_category: middle2, small_category: small3) }
  let_it_be(:category_connector8)  { create(:category_connector, large_category: large1, middle_category: middle2, small_category: small4) }
  let_it_be(:category_connector9)  { create(:category_connector, large_category: large1, middle_category: middle3, small_category: nil) }

  let_it_be(:category_connector10)  { create(:category_connector, large_category: large2, middle_category: nil, small_category: nil) }
  let_it_be(:category_connector11)  { create(:category_connector, large_category: large2, middle_category: middle2, small_category: nil) }
  let_it_be(:category_connector12)  { create(:category_connector, large_category: large2, middle_category: middle2, small_category: small3) }
  let_it_be(:category_connector13)  { create(:category_connector, large_category: large2, middle_category: middle2, small_category: small5) }
  let_it_be(:category_connector14)  { create(:category_connector, large_category: large2, middle_category: middle4, small_category: nil) }

  let_it_be(:category_connector15)  { create(:category_connector, large_category: large3, middle_category: nil, small_category: nil) }
  let_it_be(:category_connector16)  { create(:category_connector, large_category: large3, middle_category: middle5, small_category: nil) }
  let_it_be(:category_connector17)  { create(:category_connector, large_category: large3, middle_category: middle5, small_category: small6) }
  let_it_be(:category_connector18)  { create(:category_connector, large_category: large3, middle_category: middle6, small_category: nil) }
  let_it_be(:category_connector19)  { create(:category_connector, large_category: large4, middle_category: nil, small_category: nil) }


  let_it_be(:company1)  { create(:company, domain: 'sinjuku_1, almi_1,     cap_1, emp_2, sal_4') }
  let_it_be(:company2)  { create(:company, domain: 'sinjuku_2, tekko_1,    cap_2, emp_3, sal_4') }
  let_it_be(:company3)  { create(:company, domain: 'shibuya_1, syokuhin_1, cap_1, emp_4, sal_3') }
  let_it_be(:company4)  { create(:company, domain: 'shibuya_2, pan_1,      cap_4, emp_3, sal_1') }
  let_it_be(:company5)  { create(:company, domain: 'shibuya_3, iryo_1,     cap_1, emp_2, sal_1') }
  let_it_be(:company6)  { create(:company, domain: 'chiba_1, sakana_1,     cap_2, emp_4, sal_4') }
  let_it_be(:company7)  { create(:company, domain: 'chiba_2,               cap_3, emp_2, sal_3') }
  let_it_be(:company8)  { create(:company, domain: 'urayasu_1, chigin_1,   cap_4, emp_2, sal_2') }
  let_it_be(:company9)  { create(:company, domain: 'kyoto_1, hoken_1,      cap_1, emp_3, sal_3') }
  let_it_be(:company10) { create(:company, domain: 'kyoto_2, kinyuu_1,     cap_4, emp_1, sal_3') }
  let_it_be(:company11) { create(:company, domain: 'kobe_1, tsushin_1,     cap_3, emp_4, sal_4') }
  let_it_be(:company12) { create(:company, domain: 'tsushin_2,             cap_4, emp_2, sal_2') }

  let_it_be(:company_area1) { create(:company_area_connector, company: company1, area_connector: area_connector3) }
  let_it_be(:company_area2) { create(:company_area_connector, company: company2, area_connector: area_connector3) }
  let_it_be(:company_area3) { create(:company_area_connector, company: company3, area_connector: area_connector4) }
  let_it_be(:company_area4) { create(:company_area_connector, company: company4, area_connector: area_connector4) }
  let_it_be(:company_area5) { create(:company_area_connector, company: company5, area_connector: area_connector4) }
  let_it_be(:company_area6) { create(:company_area_connector, company: company6, area_connector: area_connector8) }
  let_it_be(:company_area7) { create(:company_area_connector, company: company7, area_connector: area_connector8) }
  let_it_be(:company_area8) { create(:company_area_connector, company: company8, area_connector: area_connector10) }
  let_it_be(:company_area9) { create(:company_area_connector, company: company9, area_connector: area_connector28) }
  let_it_be(:company_area10) { create(:company_area_connector, company: company10, area_connector: area_connector28) }
  let_it_be(:company_area11) { create(:company_area_connector, company: company11, area_connector: area_connector32) }

  let_it_be(:company_category1) { create(:company_category_connector, company: company1, category_connector: category_connector3) }
  let_it_be(:company_category2) { create(:company_category_connector, company: company2, category_connector: category_connector4) }
  let_it_be(:company_category3) { create(:company_category_connector, company: company3, category_connector: category_connector6) }
  let_it_be(:company_category4) { create(:company_category_connector, company: company4, category_connector: category_connector8) }
  let_it_be(:company_category5) { create(:company_category_connector, company: company5, category_connector: category_connector9) }
  let_it_be(:company_category6) { create(:company_category_connector, company: company6, category_connector: category_connector13) }
  let_it_be(:company_category7) { create(:company_category_connector, company: company8, category_connector: category_connector17) }
  let_it_be(:company_category8) { create(:company_category_connector, company: company9, category_connector: category_connector18) }
  let_it_be(:company_category9) { create(:company_category_connector, company: company10, category_connector: category_connector15) }
  let_it_be(:company_category10) { create(:company_category_connector, company: company11, category_connector: category_connector19) }
  let_it_be(:company_category11) { create(:company_category_connector, company: company12, category_connector: category_connector19) }

  let_it_be(:capital_group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
  let_it_be(:capital_group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10_000_000, lower: 0) }
  let_it_be(:capital_group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 100_000_000, lower: 10_000_001) }
  let_it_be(:capital_group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 100_000_001) }
  let_it_be(:employee_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: nil) }
  let_it_be(:employee_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 50, lower: 0) }
  let_it_be(:employee_group3) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 1_000, lower: 51) }
  let_it_be(:employee_group4) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 1_001) }
  let_it_be(:sales_group1) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: nil) }
  let_it_be(:sales_group2) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 1_000_000_000, lower: 0) }
  let_it_be(:sales_group3) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 100_000_000_000, lower: 1_000_000_001) }
  let_it_be(:sales_group4) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: 100_000_000_001) }

  let_it_be(:company_capital_group1)  { create(:company_company_group, company: company1,  company_group: capital_group1) }
  let_it_be(:company_capital_group2)  { create(:company_company_group, company: company2,  company_group: capital_group2) }
  let_it_be(:company_capital_group3)  { create(:company_company_group, company: company3,  company_group: capital_group1) }
  let_it_be(:company_capital_group4)  { create(:company_company_group, company: company4,  company_group: capital_group4) }
  let_it_be(:company_capital_group5)  { create(:company_company_group, company: company5,  company_group: capital_group1) }
  let_it_be(:company_capital_group6)  { create(:company_company_group, company: company6,  company_group: capital_group2) }
  let_it_be(:company_capital_group7)  { create(:company_company_group, company: company7,  company_group: capital_group3) }
  let_it_be(:company_capital_group8)  { create(:company_company_group, company: company8,  company_group: capital_group4) }
  let_it_be(:company_capital_group9)  { create(:company_company_group, company: company9,  company_group: capital_group1) }
  let_it_be(:company_capital_group10) { create(:company_company_group, company: company10, company_group: capital_group4) }
  let_it_be(:company_capital_group11) { create(:company_company_group, company: company11, company_group: capital_group3) }
  let_it_be(:company_capital_group12) { create(:company_company_group, company: company12, company_group: capital_group4) }

  let_it_be(:company_employee_group1)  { create(:company_company_group, company: company1,  company_group: employee_group2) }
  let_it_be(:company_employee_group2)  { create(:company_company_group, company: company2,  company_group: employee_group3) }
  let_it_be(:company_employee_group3)  { create(:company_company_group, company: company3,  company_group: employee_group4) }
  let_it_be(:company_employee_group4)  { create(:company_company_group, company: company4,  company_group: employee_group3) }
  let_it_be(:company_employee_group5)  { create(:company_company_group, company: company5,  company_group: employee_group2) }
  let_it_be(:company_employee_group6)  { create(:company_company_group, company: company6,  company_group: employee_group4) }
  let_it_be(:company_employee_group7)  { create(:company_company_group, company: company7,  company_group: employee_group2) }
  let_it_be(:company_employee_group8)  { create(:company_company_group, company: company8,  company_group: employee_group2) }
  let_it_be(:company_employee_group9)  { create(:company_company_group, company: company9,  company_group: employee_group3) }
  let_it_be(:company_employee_group10) { create(:company_company_group, company: company10, company_group: employee_group1) }
  let_it_be(:company_employee_group11) { create(:company_company_group, company: company11, company_group: employee_group4) }
  let_it_be(:company_employee_group12) { create(:company_company_group, company: company12, company_group: employee_group2) }

  let_it_be(:company_sales_group1)  { create(:company_company_group, company: company1,  company_group: sales_group4) }
  let_it_be(:company_sales_group2)  { create(:company_company_group, company: company2,  company_group: sales_group4) }
  let_it_be(:company_sales_group3)  { create(:company_company_group, company: company3,  company_group: sales_group3) }
  let_it_be(:company_sales_group4)  { create(:company_company_group, company: company4,  company_group: sales_group1) }
  let_it_be(:company_sales_group5)  { create(:company_company_group, company: company5,  company_group: sales_group1) }
  let_it_be(:company_sales_group6)  { create(:company_company_group, company: company6,  company_group: sales_group4) }
  let_it_be(:company_sales_group7)  { create(:company_company_group, company: company7,  company_group: sales_group3) }
  let_it_be(:company_sales_group8)  { create(:company_company_group, company: company8,  company_group: sales_group2) }
  let_it_be(:company_sales_group9)  { create(:company_company_group, company: company9,  company_group: sales_group3) }
  let_it_be(:company_sales_group10) { create(:company_company_group, company: company10, company_group: sales_group3) }
  let_it_be(:company_sales_group11) { create(:company_company_group, company: company11, company_group: sales_group4) }
  let_it_be(:company_sales_group12) { create(:company_company_group, company: company12, company_group: sales_group2) }


  before { Timecop.freeze }
  after  { Timecop.return }

  context 'ログインユーザ' do
    before { sign_in user }

    let(:mail_address) { 'test@request.com' }
    let(:list_name) { 'リクエスト名 テスト' }

    scenario '企業DB検索画面の表示', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path

      click_link '企業HP情報の取得'

      expect(page).to have_content '企業HP情報の取得'
      expect(page).to have_content '企業HP情報の取得リクエスト送信'


      within "#request_form" do
        within('h3') { expect(page).to have_content 'URLリストをアップロード' }
        within('h3') { expect(page).not_to have_content 'URLリスト作成' }
        within('h3') { expect(page).not_to have_content 'キーワード検索' }
        within('h3') { expect(page).not_to have_content '企業DBから検索' }
      end

      expect(page).not_to have_content 'リスト名(作成するリストに名前をつけてください)'

      within('#swich_type') { click_link '企業DBから検索' }

      within "#request_form" do
        within('h3') { expect(page).not_to have_content 'URLリストをアップロード' }
        within('h3') { expect(page).not_to have_content 'URLリスト作成' }
        within('h3') { expect(page).not_to have_content 'キーワード検索' }
        within('h3') { expect(page).to have_content '企業DBから検索' }
      end

      expect(page).to have_content 'リスト名(作成するリストに名前をつけてください)'

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '現在の企業数 : 12' }

        within "#area_list" do
          within('h5') { expect(page).to have_content '地域選択' }
          expect(page).to have_content '関東'
          expect(page).to have_content '東京都'
          expect(page).to have_content '埼玉県'
          expect(page).to have_content '千葉県'
          expect(page).to have_content '神奈川県'
          expect(page).to have_content '東海'
          expect(page).to have_content '愛知県'
          expect(page).to have_content '静岡県'
          expect(page).to have_content '三重県'
          expect(page).to have_content '近畿'
          expect(page).to have_content '大阪府'
          expect(page).to have_content '京都府'
          expect(page).to have_content '兵庫県'

          expect(page).not_to have_content '新宿区'
          expect(page).not_to have_content '渋谷区'
          expect(page).not_to have_content '千葉市'
          expect(page).not_to have_content '浦安市'
          expect(page).not_to have_content '横浜市'
          expect(page).not_to have_content '川崎市'
          expect(page).not_to have_content '名古屋市'
          expect(page).not_to have_content '春日井市'
          expect(page).not_to have_content '四日市市'
          expect(page).not_to have_content '鈴鹿市'
          expect(page).not_to have_content '宇治市'
          expect(page).not_to have_content '京都市'
          expect(page).not_to have_content '神戸市'
          expect(page).not_to have_content '姫路市'
          expect(page).not_to have_content '浜松市'

        end

        within "#category_list" do
          within('h5') { expect(page).to have_content '業種選択' }

          expect(page).to have_content '製造業'
          expect(page).to have_content '小売'
          expect(page).to have_content '金融'
          expect(page).to have_content '通信'

          expect(page).not_to have_content '金属'
          expect(page).not_to have_content 'アルミ'
          expect(page).not_to have_content '鉄鋼'
          expect(page).not_to have_content '食品'
          expect(page).not_to have_content '缶詰'
          expect(page).not_to have_content 'パン'
          expect(page).not_to have_content '衣料'
          expect(page).not_to have_content '魚'
          expect(page).not_to have_content '家電製品'
          expect(page).not_to have_content '銀行'
          expect(page).not_to have_content '地方銀行'
          expect(page).not_to have_content '保険'
        end

        within "#other_conditions" do
          within('h5') { expect(page).to have_content 'その他の条件' }

          within "#capital_list" do
            within('h6') { expect(page).to have_content '資本金選択' }

            expect(page).to have_content '〜 1,000万'
            expect(page).to have_content '〜 1億'
            expect(page).to have_content 'それ以上'
            expect(page).to have_content '不明'
          end

          within "#employee_list" do
            within('h6') { expect(page).to have_content '従業員選択' }

            expect(page).to have_content '〜 50'
            expect(page).to have_content '〜 1,000'
            expect(page).to have_content 'それ以上'
            expect(page).to have_content '不明'
          end

          within "#sales_list" do
            within('h6') { expect(page).to have_content '売上選択' }

            expect(page).to have_content '〜 10億'
            expect(page).to have_content '〜 1,000億'
            expect(page).to have_content 'それ以上'
            expect(page).to have_content '不明'
          end
        end
      end
    end

    scenario '地域選択のチェックボックスの開閉操作', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path

      within('#swich_type') { click_link '企業DBから検索' }

      within "#area_list" do
        expect(find("label", text:'関東').find(:xpath, "..").find('a').text).to eq 'remove_circle'
        find("label", text:'関東').find(:xpath, "..").find('a').click

        expect(page).not_to have_content '東京都'
        expect(page).not_to have_content '埼玉県'
        expect(page).not_to have_content '千葉県'
        expect(page).not_to have_content '神奈川県'

        expect(find("label", text:'関東').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'関東').find(:xpath, "..").find('a').click

        expect(page).to have_content '東京都'
        expect(page).to have_content '埼玉県'
        expect(page).to have_content '千葉県'
        expect(page).to have_content '神奈川県'

        expect(find("label", text:'関東').find(:xpath, "..").find('a').text).to eq 'remove_circle'


        expect(find("label", text:'東京都').find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content '新宿区'
        expect(page).not_to have_content '渋谷区'
        find("label", text:'東京都').find(:xpath, "..").find('a').click

        expect(page).to have_content '新宿区'
        expect(page).to have_content '渋谷区'
        expect(find("label", text:'新宿区').find(:xpath, "..").text).to eq '新宿区' #開閉トグルアイコンがないことを確認している
        expect(find("label", text:'渋谷区').find(:xpath, "..").text).to eq '渋谷区' #開閉トグルアイコンがないことを確認している


        expect(find("label", text:'東京都').find(:xpath, "..").find('a').text).to eq 'remove_circle'
        find("label", text:'東京都').find(:xpath, "..").find('a').click

        expect(page).not_to have_content '新宿区'
        expect(page).not_to have_content '渋谷区'

        expect(find("label", text:'東京都').find(:xpath, "..").find('a').text).to eq 'add_circle'

        expect(find("label", text:'埼玉県').find(:xpath, "..").text).to eq '埼玉県' #開閉トグルアイコンがないことを確認している


        expect(find("label", text:'東海').find(:xpath, "..").find('a').text).to eq 'remove_circle'
        find("label", text:'東海').find(:xpath, "..").find('a').click

        expect(page).not_to have_content '愛知県'
        expect(page).not_to have_content '三重県'
        expect(page).not_to have_content '静岡県'

        expect(find("label", text:'東海').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'東海').find(:xpath, "..").find('a').click

        expect(page).to have_content '愛知県'
        expect(page).to have_content '三重県'
        expect(page).to have_content '静岡県'

        expect(find("label", text:'東海').find(:xpath, "..").find('a').text).to eq 'remove_circle'


        expect(find("label", text:'三重県').find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content '四日市市'
        expect(page).not_to have_content '鈴鹿市'
        find("label", text:'三重県').find(:xpath, "..").find('a').click

        expect(page).to have_content '四日市市'
        expect(page).to have_content '鈴鹿市'
        expect(find("label", text:'四日市市').find(:xpath, "..").text).to eq '四日市市' #開閉トグルアイコンがないことを確認している
        expect(find("label", text:'鈴鹿市').find(:xpath, "..").text).to eq '鈴鹿市' #開閉トグルアイコンがないことを確認している

        expect(find("label", text:'三重県').find(:xpath, "..").find('a').text).to eq 'remove_circle'
        find("label", text:'三重県').find(:xpath, "..").find('a').click

        expect(page).not_to have_content '四日市市'
        expect(page).not_to have_content '鈴鹿市'

        expect(find("label", text:'三重県').find(:xpath, "..").find('a').text).to eq 'add_circle'

        expect(find("label", text:'静岡県').find(:xpath, "..").text).to eq '静岡県' #開閉トグルアイコンがないことを確認している


        expect(find("label", text:'近畿').find(:xpath, "..").find('a').text).to eq 'remove_circle'
        find("label", text:'近畿').find(:xpath, "..").find('a').click

        expect(page).not_to have_content '京都府'
        expect(page).not_to have_content '大阪府'
        expect(page).not_to have_content '兵庫県'

        expect(find("label", text:'近畿').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'近畿').find(:xpath, "..").find('a').click

        expect(page).to have_content '京都府'
        expect(page).to have_content '大阪府'
        expect(page).to have_content '兵庫県'

        expect(find("label", text:'近畿').find(:xpath, "..").find('a').text).to eq 'remove_circle'


        expect(find("label", text:'京都府').find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content '京都市'
        expect(page).not_to have_content '宇治市'
        find("label", text:'京都府').find(:xpath, "..").find('a').click

        expect(page).to have_content '京都市'
        expect(page).to have_content '宇治市'
        expect(find("label", text:'京都市').find(:xpath, "..").text).to eq '京都市' #開閉トグルアイコンがないことを確認している
        expect(find("label", text:'宇治市').find(:xpath, "..").text).to eq '宇治市' #開閉トグルアイコンがないことを確認している

        expect(find("label", text:'京都府').find(:xpath, "..").find('a').text).to eq 'remove_circle'
        find("label", text:'京都府').find(:xpath, "..").find('a').click

        expect(page).not_to have_content '京都市'
        expect(page).not_to have_content '宇治市'

        expect(find("label", text:'京都府').find(:xpath, "..").find('a').text).to eq 'add_circle'

        expect(find("label", text:'大阪府').find(:xpath, "..").text).to eq '大阪府' #開閉トグルアイコンがないことを確認している

      end
    end

    scenario '業種選択のチェックボックスの開閉操作', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path

      within('#list_upload_form') { click_link '企業DBから検索' }

      within "#category_list" do

        expect(find("label", text:'製造業').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'製造業').find(:xpath, "..").find('a').click
        expect(find("label", text:'製造業').find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content '金属'
        expect(page).to have_content '食品'
        expect(page).to have_content '衣料'

        expect(find("label", text:'金属').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'金属').find(:xpath, "..").find('a').click
        expect(find("label", text:'金属').find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content 'アルミ'
        expect(page).to have_content '鉄鋼'
        expect(find("label", text:'アルミ').find(:xpath, "..").text).to eq 'アルミ' #開閉トグルアイコンがないことを確認している
        expect(find("label", text:'鉄鋼').find(:xpath, "..").text).to eq '鉄鋼' #開閉トグルアイコンがないことを確認している

        find("label", text:'金属').find(:xpath, "..").find('a').click
        expect(find("label", text:'金属').find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content 'アルミ'
        expect(page).not_to have_content '鉄鋼'

        expect(find("label", text:'食品').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'食品').find(:xpath, "..").find('a').click
        expect(find("label", text:'食品').find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content '缶詰'
        expect(page).to have_content 'パン'
        expect(find("label", text:'缶詰').find(:xpath, "..").text).to eq '缶詰' #開閉トグルアイコンがないことを確認している
        expect(find("label", text:'パン').find(:xpath, "..").text).to eq 'パン' #開閉トグルアイコンがないことを確認している

        find("label", text:'食品').find(:xpath, "..").find('a').click
        expect(find("label", text:'食品').find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content '缶詰'
        expect(page).not_to have_content 'パン'

        expect(find("label", text:'衣料').find(:xpath, "..").text).to eq '衣料' #開閉トグルアイコンがないことを確認している

        find("label", text:'製造業').find(:xpath, "..").find('a').click
        expect(find("label", text:'製造業').find(:xpath, "..").find('a').text).to eq 'add_circle'

        expect(page).not_to have_content '金属'
        expect(page).not_to have_content '食品'
        expect(page).not_to have_content '衣料'


        expect(page).not_to have_content '食品'
        expect(page).not_to have_content '家電製品'

        expect(find("label", text:'小売').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'小売').find(:xpath, "..").find('a').click
        expect(find("label", text:'小売').find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content '食品'
        expect(page).to have_content '家電製品'

        expect(find("label", text:'食品').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'食品').find(:xpath, "..").find('a').click
        expect(find("label", text:'食品').find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content '缶詰'
        expect(page).to have_content '魚'
        expect(find("label", text:'缶詰').find(:xpath, "..").text).to eq '缶詰' #開閉トグルアイコンがないことを確認している
        expect(find("label", text:'魚').find(:xpath, "..").text).to eq '魚' #開閉トグルアイコンがないことを確認している

        find("label", text:'食品').find(:xpath, "..").find('a').click
        expect(find("label", text:'食品').find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content '缶詰'
        expect(page).not_to have_content '魚'

        expect(find("label", text:'家電製品').find(:xpath, "..").text).to eq '家電製品' #開閉トグルアイコンがないことを確認している

        find("label", text:'小売').find(:xpath, "..").find('a').click
        expect(find("label", text:'小売').find(:xpath, "..").find('a').text).to eq 'add_circle'

        expect(page).not_to have_content '食品'
        expect(page).not_to have_content '家電製品'


        expect(page).not_to have_content '銀行'
        expect(page).not_to have_content '保険'

        expect(find("label", text:'金融').find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text:'金融').find(:xpath, "..").find('a').click
        expect(find("label", text:'金融').find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content '銀行'
        expect(page).to have_content '保険'

        # 地方銀行も引っかかるので、正規表現
        expect(find("label", text: /^銀行$/).find(:xpath, "..").find('a').text).to eq 'add_circle'
        find("label", text: /^銀行$/).find(:xpath, "..").find('a').click
        expect(find("label", text: /^銀行$/).find(:xpath, "..").find('a').text).to eq 'remove_circle'

        expect(page).to have_content '地方銀行'
        expect(find("label", text:'地方銀行').find(:xpath, "..").text).to eq '地方銀行' #開閉トグルアイコンがないことを確認している

        find("label", text: /^銀行$/).find(:xpath, "..").find('a').click
        expect(find("label", text: /^銀行$/).find(:xpath, "..").find('a').text).to eq 'add_circle'
        expect(page).not_to have_content '地方銀行'

        expect(find("label", text:'保険').find(:xpath, "..").text).to eq '保険' #開閉トグルアイコンがないことを確認している

        find("label", text:'金融').find(:xpath, "..").find('a').click
        expect(find("label", text:'金融').find(:xpath, "..").find('a').text).to eq 'add_circle'

        expect(page).not_to have_content '銀行'
        expect(page).not_to have_content '保険'

        expect(find("label", text:'通信').find(:xpath, "..").text).to eq '通信' #開閉トグルアイコンがないことを確認している
      end
    end

    scenario '地域選択の企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#list_upload_form') { click_link '企業DBから検索' }

      within "#search_conditions_result" do

        within('h5#companies_count') { expect(page).to have_content '12' }


        find("label", text:'東海').click
        within('h5#companies_count') { expect(page).to have_content '0' }
        find("label", text:'東海').click
        within('h5#companies_count') { expect(page).to have_content '12' }
        find("label", text:'愛知県').click
        within('h5#companies_count') { expect(page).to have_content '0' }
        find("label", text:'愛知県').click


        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content '8' }
        find("label", text:'東京').click
        within('h5#companies_count') { expect(page).to have_content '8' }
        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content '5' }
        find("label", text:'東京').click

        find("label", text:'東京都').find(:xpath, "..").find('a').click
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content '3' }
        find("label", text:'新宿区').click
        within('h5#companies_count') { expect(page).to have_content '5' }
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content '2' }
        find("label", text:'新宿区').click


        find("label", text:'千葉県').click
        within('h5#companies_count') { expect(page).to have_content '3' }
        find("label", text:'千葉県').click
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'千葉県').find(:xpath, "..").find('a').click
        find("label", text:'千葉市').click
        within('h5#companies_count') { expect(page).to have_content '0' }
        find("label", text:'千葉市').click
        find("label", text:'浦安市').click
        within('h5#companies_count') { expect(page).to have_content '1' }

        find("label", text:'京都府').click
        within('h5#companies_count') { expect(page).to have_content '3' }
        find("label", text:'東海').click
        within('h5#companies_count') { expect(page).to have_content '3' }
        find("label", text:'東海').click
        within('h5#companies_count') { expect(page).to have_content '3' }
        find("label", text:'愛知県').click
        within('h5#companies_count') { expect(page).to have_content '3' }
        find("label", text:'愛知県').click

        find("label", text:'新宿区').click
        within('h5#companies_count') { expect(page).to have_content '5' }
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content '8' }
      end
    end

    scenario '業種選択の企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#swich_type') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'小売').find(:xpath, "..").find('a').click
        find("label", text:'家電製品').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'家電製品').click
        within('h5#companies_count') { expect(page).to have_content '12' }
        find("label", text:'小売').find(:xpath, "..").find('a').click

        find("label", text:'製造業').click
        within('h5#companies_count') { expect(page).to have_content '5' }

        find("label", text:'製造業').find(:xpath, "..").find('a').click
        find("label", text:'金属').click
        within('h5#companies_count') { expect(page).to have_content '5' }
        find("label", text:'食品').click
        within('h5#companies_count') { expect(page).to have_content '5' }
        find("label", text:'製造業').click
        within('h5#companies_count') { expect(page).to have_content '4' }
        find("label", text:'金属').find(:xpath, "..").find('a').click
        sleep 0.5
        find("label", text:'食品').find(:xpath, "..").find('a').click
        find("label", text:'金属').click
        find("label", text:'食品').click
        within('h5#companies_count') { expect(page).to have_content ' 12' }
        find("label", text:'鉄鋼').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'パン').click
        within('h5#companies_count') { expect(page).to have_content ' 2' }

        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }

        find("label", text:'小売').click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'小売').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }

        find("label", text:'小売').find(:xpath, "..").find('a').click
        find("label", text:'家電製品').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:'家電製品').click

        find("label", text:'金融').click
        within('h5#companies_count') { expect(page).to have_content ' 7' }
        find("label", text:'金融').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }

        find("label", text:'金融').find(:xpath, "..").find('a').click
        find("label", text:/^銀行$/).find(:xpath, "..").find('a').click

        find("label", text:/^銀行$/).click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:/^銀行$/).click
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:/^地方銀行$/).click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'保険').click
        within('h5#companies_count') { expect(page).to have_content ' 6' }

        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }

        find("label", text:'鉄鋼').click
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        find("label", text:'パン').click
        within('h5#companies_count') { expect(page).to have_content ' 2' }

        find("label", text:'製造業').click
        within('h5#companies_count') { expect(page).to have_content ' 7' }
      end
    end

    scenario '資本金グループの企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#swich_type') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        within("#capital_list") { find("label", text:'〜 1,000万').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 6' }
        within("#capital_list") { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 10' }
        within("#capital_list") { find("label", text:'〜 1億').click }
        within('h5#companies_count') { expect(page).to have_content ' 12' }
        within("#capital_list") { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        within("#capital_list") { find("label", text:'〜 1,000万').click }
        within('h5#companies_count') { expect(page).to have_content ' 6' }
        within("#capital_list") { find("label", text:'〜 1億').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 12' }
      end
    end

    scenario '従業員グループの企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#swich_type') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        within('#employee_list') { find("label", text:'〜 50').click }
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        within('#employee_list') { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 6' }
        within('#employee_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 9' }
        within('#employee_list') { find("label", text:'〜 1,000').click }
        within('h5#companies_count') { expect(page).to have_content ' 12' }
        within('#employee_list') { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 11' }
        within('#employee_list') { find("label", text:'〜 50').click }
        within('h5#companies_count') { expect(page).to have_content ' 6' }
        within('#employee_list') { find("label", text:'〜 1,000').click }
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        within('#employee_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 12' }
      end
    end

    scenario '売上グループの企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#swich_type') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        within('#sales_list') { find("label", text:'〜 10億').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within('#sales_list') { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        within('#sales_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        within('#sales_list') { find("label", text:'〜 1,000億').click }
        within('h5#companies_count') { expect(page).to have_content ' 12' }
        within('#sales_list') { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 10' }
        within('#sales_list') { find("label", text:'〜 10億').click }
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        within('#sales_list') { find("label", text:'〜 1,000億').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        within('#sales_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 12' }
      end
    end

    scenario '地域と業種の両方の企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#list_upload_form') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        find("label", text:'小売').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'小売').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'製造業').click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'愛知県').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'愛知県').click
        find("label", text:'東京都').click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'東京都').click

        find("label", text:'東京都').find(:xpath, "..").find('a').click
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'製造業').click

        find("label", text:'千葉県').click
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'通信').click
        find("label", text:'千葉県').click
        within('h5#companies_count') { expect(page).to have_content '12' }
      end
    end

    scenario '地域と業種、グループ(資本金)を混ぜた企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#list_upload_form') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        within("#capital_list") { find("label", text:'〜 1,000万').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'小売').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        within("#capital_list") { find("label", text:'〜 1,000万').click }
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        within("#capital_list") { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'小売').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        within("#capital_list") { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content '12' }

        within("#capital_list") { find("label", text:'〜 1億').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within("#capital_list") { find("label", text:'〜 1,000万').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:'製造業').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'愛知県').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'愛知県').click
        find("label", text:'東京都').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        within("#capital_list") { find("label", text:'不明').click }  # ON
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:'東京都').click

        find("label", text:'東京都').find(:xpath, "..").find('a').click
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        find("label", text:'渋谷区').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:'製造業').click # OFF
        within("#capital_list") { find("label", text:'〜 1,000万').click } # OFF
        within("#capital_list") { find("label", text:'それ以上').click } # ON

        find("label", text:'千葉県').click # ON
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        find("label", text:'通信').click # ON
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'金融').click # ON
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'千葉県').click # OFF
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        within("#capital_list") { find("label", text:'〜 1億').click } # OFF
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        find("label", text:'金融').click
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        within("#capital_list") { find("label", text:'それ以上').click }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content '12' }
      end
    end

    scenario '地域と業種、グループ(資本金、従業員、売上)を混ぜた企業件数', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#list_upload_form') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content '12' }

        find("label", text:'関東').click
        within('h5#companies_count') { expect(page).to have_content ' 8' }
        within("#capital_list") { find("label", text:'〜 1,000万').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 5' }
        within('#employee_list') { find("label", text:'〜 50').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within('#employee_list') { find("label", text:'〜 1,000').click }
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        within('#sales_list') { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        within('#sales_list') { find("label", text:'〜 1,000億').click }
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        within('#sales_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        within('#employee_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 5' }

        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 0' }
        find("label", text:'通信').click
        within('h5#companies_count') { expect(page).to have_content ' 5' }

        find("label", text:'製造業').find(:xpath, "..").find('a').click
        find("label", text:'衣料').click
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        find("label", text:'食品').click
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        find("label", text:'金属').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }

        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 1' }
        within("#capital_list") { find("label", text:'不明').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        within('#employee_list') { find("label", text:'〜 1,000').click }
        within('h5#companies_count') { expect(page).to have_content ' 3' }
        within('#employee_list') { find("label", text:'〜 1,000').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        within('#sales_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        within('#sales_list') { find("label", text:'それ以上').click }
        within('h5#companies_count') { expect(page).to have_content ' 4' }

        find("label", text:'関東').click # OFF
        within('h5#companies_count') { expect(page).to have_content ' 4' }
        find("label", text:'東京').find(:xpath, "..").find('a').click
        find("label", text:'新宿').click
        within('h5#companies_count') { expect(page).to have_content ' 2' }
        find("label", text:'渋谷').click
        within('h5#companies_count') { expect(page).to have_content ' 4' }
      end
    end

    scenario '地域も業種もグループもチェックしない', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit request_multiple_path
      within('#swich_type') { click_link '企業DBから検索' }

      click_button 'request' # リクエスト送信

      # ダイアログの確認
      expect(page.driver.browser.switch_to.alert.text).to eq "地域か業種かその他の条件のいずれかをチェックしてください。"

      page.driver.browser.switch_to.alert.accept

      expect(page).not_to have_content 'リクエスト受領'
    end

    scenario '地域のみチェックする → リクエスト送信', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業HP情報の取得'
      within('#swich_type') { click_link '企業DBから検索' }

      within "#search_conditions_result" do
        find("label", text:'神奈川県').click
        find("label", text:'近畿').click
      end

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count

      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 3

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content 'DB検索'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content 'DB検索'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '3')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end

      #------------
      #
      #   リクエスト詳細確認
      #
      #------------
      within "#requests" do
        find('i', text: 'find_in_page').click
      end

      within '#confirm_request_form_crawl_config_list_area' do
        expect(page).to have_selector('h5', text: '地域の設定')
        expect(page).to have_selector('h5', text: '業種の設定')
        expect(page).to have_selector('h5', text: 'その他の設定')

        expect(page).to have_content '近畿'
        expect(page).to have_content '関東 > 神奈川県'

        expect(page).not_to have_content '東海'
        expect(page).not_to have_content '製造業'
        expect(page).not_to have_content '小売'
        expect(page).not_to have_content '金融'
        expect(page).not_to have_content '通信'
        expect(page).not_to have_content '不明'
        expect(page).not_to have_content '〜 1,000万'
        expect(page).not_to have_content '〜 1億'
        expect(page).not_to have_content 'それ以上'

        expect(page).not_to have_selector('h6', text: '資本金の設定')
        expect(page).not_to have_selector('h6', text: '従業員数の設定')
        expect(page).not_to have_selector('h6', text: '売上の設定')

        expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
      end
    end

    scenario '業種のみチェックする → リクエスト送信', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業DBを利用'

      within "#search_conditions_result" do
        find("label", text:'製造業').click
        find("label", text:'小売').click
      end

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count

      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 6

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content 'DB検索'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content 'DB検索'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '6')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end

      #------------
      #
      #   リクエスト詳細確認
      #
      #------------
      within "#requests" do
        find('i', text: 'find_in_page').click
      end

      within '#confirm_request_form_crawl_config_list_area' do
        expect(page).to have_selector('h5', text: '地域の設定')
        expect(page).to have_selector('h5', text: '業種の設定')
        expect(page).to have_selector('h5', text: 'その他の設定')

        expect(page).to have_content '製造業'
        expect(page).to have_content '小売'

        expect(page).not_to have_content '近畿'
        expect(page).not_to have_content '関東'
        expect(page).not_to have_content '東海'
        expect(page).not_to have_content '金融'
        expect(page).not_to have_content '通信'
        expect(page).not_to have_content '不明'
        expect(page).not_to have_content '〜 1,000万'
        expect(page).not_to have_content '〜 1億'
        expect(page).not_to have_content 'それ以上'

        expect(page).not_to have_selector('h6', text: '資本金の設定')
        expect(page).not_to have_selector('h6', text: '従業員数の設定')
        expect(page).not_to have_selector('h6', text: '売上の設定')

        expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
      end
    end

    scenario '資本金のみチェックする → リクエスト送信', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業DBを利用'

      within "#search_conditions_result" do
        within("#capital_list") do
          find("label", text:'不明').click
          find("label", text:'〜 1,000万').click
        end
      end

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count

      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 6

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content 'DB検索'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content 'DB検索'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '6')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end

      #------------
      #
      #   リクエスト詳細確認
      #
      #------------
      within "#requests" do
        find('i', text: 'find_in_page').click
      end

      within '#confirm_request_form_crawl_config_list_area' do
        expect(page).to have_selector('h5', text: '地域の設定')
        expect(page).to have_selector('h5', text: '業種の設定')
        expect(page).to have_selector('h5', text: 'その他の設定')

        expect(page).not_to have_content '東海'
        expect(page).not_to have_content '関東'
        expect(page).not_to have_content '近畿'
        expect(page).not_to have_content '製造業'
        expect(page).not_to have_content '小売'
        expect(page).not_to have_content '金融'
        expect(page).not_to have_content '通信'

        expect(page).to have_selector('h6', text: '資本金の設定')
        expect(page).to have_content '不明'
        expect(page).to have_content '〜 1,000万'
        expect(page).not_to have_content '〜 1億'
        expect(page).not_to have_content 'それ以上'

        expect(page).not_to have_selector('h6', text: '従業員数の設定')
        expect(page).not_to have_selector('h6', text: '売上の設定')
        expect(page).not_to have_selector('.employee_area')
        expect(page).not_to have_selector('.sales_area')

        expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
      end
    end

    scenario '従業員、売上をチェックする → リクエスト送信', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業DBを利用'

      within "#search_conditions_result" do
        within("#employee_list") do
          find("label", text:'〜 50').click
          find("label", text:'〜 1,000').click
        end

        within("#sales_list") do
          find("label", text:'〜 1,000億').click
          find("label", text:'不明').click
        end
      end

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count

      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 4

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content 'DB検索'
          expect(page).not_to have_content '完了通知メールアドレス'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content 'DB検索'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '4')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end

      #------------
      #
      #   リクエスト詳細確認
      #
      #------------
      within "#requests" do
        find('i', text: 'find_in_page').click
      end

      within '#confirm_request_form_crawl_config_list_area' do
        expect(page).to have_selector('h5', text: '地域の設定')
        expect(page).to have_selector('h5', text: '業種の設定')
        expect(page).to have_selector('h5', text: 'その他の設定')

        expect(page).not_to have_content '東海'
        expect(page).not_to have_content '関東'
        expect(page).not_to have_content '近畿'
        expect(page).not_to have_content '製造業'
        expect(page).not_to have_content '小売'
        expect(page).not_to have_content '金融'
        expect(page).not_to have_content '通信'

        expect(page).not_to have_selector('h6', text: '資本金の設定')
        expect(page).not_to have_selector('.capital_area')

        expect(page).to have_selector('h6', text: '従業員数の設定')
        within '.employee_area' do
          expect(page).to have_content '〜 50'
          expect(page).to have_content '〜 1,000'
          expect(page).not_to have_content '不明'
          expect(page).not_to have_content 'それ以上'
        end

        expect(page).to have_selector('h6', text: '売上の設定')
        within '.sales_area' do
          expect(page).to have_content '〜 1,000億'
          expect(page).to have_content '不明'
          expect(page).not_to have_content '〜 10億'
          expect(page).not_to have_content 'それ以上'
        end

        expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
      end
    end


    scenario '複合リクエスト作成 -> 詳細確認', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業DBを利用'

      within "#search_conditions_result" do

        find("label", text:'東京都').find(:xpath, "..").find('a').click
        find("label", text:'兵庫県').find(:xpath, "..").find('a').click

        find("label", text:'新宿区').click
        find("label", text:'神奈川県').click
        find("label", text:'東海').click
        find("label", text:'京都府').click
        find("label", text:'神戸').click
        find("label", text:'姫路').click

        find("label", text:'製造業').find(:xpath, "..").find('a').click
        find("label", text:'食品').find(:xpath, "..").find('a').click
        find("label", text:'金融').find(:xpath, "..").find('a').click

        find("label", text:'製造業').click
        find("label", text:'缶詰').click
        find("label", text:'衣料').click
        find("label", text:'小売').click
        find("label", text:'金融').click

        within("#capital_list") do
          find("label", text:'不明').click
          find("label", text:'それ以上').click
        end
      end

      # 最初は空
      expect(find_field('list_name').value).to be_blank

      fill_in 'request_mail_address', with: mail_address
      fill_in 'list_name', with: list_name

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count


      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 3

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content list_name
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
        end
      end

      within '#request_form' do
        expect(page).to have_selector('input#request_mail_address')
        expect(page).to have_content 'メールアドレス'
        expect(page).to have_content '保存されているデータがあれば使う'

        expect(page).to have_selector('button#request', text: 'リクエスト送信')

        within('h3') { expect(page).to have_content 'URLリストをアップロード' }
        within('h3') { expect(page).not_to have_content 'URLリスト作成' }
        within('h3') { expect(page).not_to have_content 'キーワード検索' }
        within('h3') { expect(page).not_to have_content '企業DBから検索' }
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content list_name
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '3')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end



      #------------
      #
      #   リクエスト詳細確認
      #
      #------------

      within "#requests" do
        find('i', text: 'find_in_page').click # 確認ボタン
      end

      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'

        expect(page).not_to have_selector('h3', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within 'table.request_result_summary tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content list_name
          expect(page).not_to have_content '企業一覧サイトのURL'
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).not_to have_content '実行の種類'
          expect(page).not_to have_content 'テスト実行'
          expect(page).not_to have_content '本実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
          expect(page).to have_content '全体数'
          expect(page).to have_selector('.total_count', text: '3')
          expect(page).to have_content '完了数'
          expect(page).to have_selector('.completed_count', text: '0')
          expect(page).to have_content '未完了数'
          expect(page).to have_selector('.waiting_count', text: '3')
        end

        expect(page).to have_selector('h3', text: '設定')

        expect(page).to have_selector('h5', text: '地域の設定')

        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '地域の設定')
          expect(page).to have_selector('h5', text: '業種の設定')
          expect(page).to have_selector('h5', text: 'その他の設定')

          within '.areas_config_area' do
            expect(page).to have_content '東海'
            expect(page).to have_content '関東 > 神奈川県'
            expect(page).to have_content '関東 > 東京都 > 新宿区'
            expect(page).to have_content '近畿 > 京都府'
            expect(page).to have_content '近畿 > 兵庫県 > 神戸市'
            expect(page).to have_content '近畿 > 兵庫県 > 姫路市'
          end

          within '.categories_config_area' do
            expect(page).to have_content '製造業'
            expect(page).to have_content '小売'
            expect(page).to have_content '金融'
            expect(page).to have_content '製造業 > 食品 > 缶詰'
            expect(page).to have_content '製造業 > 衣料'
          end

          expect(page).to have_selector('h6', text: '資本金の設定')
          within '.capital_area' do
            expect(page).to have_content '不明'
            expect(page).not_to have_content '〜 1,000万'
            expect(page).not_to have_content '〜 1億'
            expect(page).to have_content 'それ以上'
          end

          expect(page).not_to have_selector('h6', text: '従業員数の設定')
          expect(page).not_to have_selector('.employee_area')

          expect(page).not_to have_selector('h6', text: '売上の設定')
          expect(page).not_to have_selector('.sales_area')

          expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
        end
      end

      within '#request_form' do
        expect(page).to have_selector('input#request_mail_address')
        expect(page).to have_content 'メールアドレス'
        expect(page).to have_content '保存されているデータがあれば使う'

        expect(page).to have_selector('button#request', text: 'リクエスト送信')

        within('h3') { expect(page).to have_content 'URLリストをアップロード' }
        within('h3') { expect(page).not_to have_content 'URLリスト作成' }
        within('h3') { expect(page).not_to have_content 'キーワード検索' }
        within('h3') { expect(page).not_to have_content '企業DBから検索' }
      end


      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content list_name
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '3')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end
    end


    # let_it_be(:company1)  { create(:company, domain: 'sinjuku_1, almi_1,     cap_1, emp_2, sal_4') }^
    # let_it_be(:company2)  { create(:company, domain: 'sinjuku_2, tekko_1,    cap_2, emp_3, sal_4') }-^
    # let_it_be(:company3)  { create(:company, domain: 'shibuya_1, syokuhin_1, cap_1, emp_4, sal_3') }#%-^
    # let_it_be(:company4)  { create(:company, domain: 'shibuya_2, pan_1,      cap_4, emp_3, sal_1') }#%-^
    # let_it_be(:company5)  { create(:company, domain: 'shibuya_3, iryo_1,     cap_1, emp_2, sal_1') }#%^
    # let_it_be(:company6)  { create(:company, domain: 'chiba_1, sakana_1,     cap_2, emp_4, sal_4') }-^
    # let_it_be(:company7)  { create(:company, domain: 'chiba_2,               cap_3, emp_2, sal_3') }^
    # let_it_be(:company8)  { create(:company, domain: 'urayasu_1, chigin_1,   cap_4, emp_2, sal_2') }#%
    # let_it_be(:company9)  { create(:company, domain: 'kyoto_1, hoken_1,      cap_1, emp_3, sal_3') }#-^
    # let_it_be(:company10) { create(:company, domain: 'kyoto_2, kinyuu_1,     cap_4, emp_1, sal_3') }#^
    # let_it_be(:company11) { create(:company, domain: 'kobe_1, tsushin_1,     cap_3, emp_4, sal_4') }#%-^
    # let_it_be(:company12) { create(:company, domain: 'tsushin_2,             cap_4, emp_2, sal_2') }%

    scenario '複合リクエスト作成その２ -> 詳細確認', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業DBを利用'

      within "#search_conditions_result" do

        find("label", text:'東京都').find(:xpath, "..").find('a').click
        find("label", text:'千葉県').find(:xpath, "..").find('a').click

        find("label", text:'渋谷区').click
        find("label", text:'浦安市').click
        find("label", text:'京都府').click
        find("label", text:'兵庫県').click

        find("label", text:'製造業').find(:xpath, "..").find('a').click
        find("label", text:'金融').find(:xpath, "..").find('a').click
        find("label", text:'銀行').find(:xpath, "..").find('a').click

        find("label", text:'食品').click
        find("label", text:'衣料').click
        find("label", text:'地方銀行').click
        find("label", text:'通信').click

        within("#employee_list") do
          find("label", text:'〜 1,000').click
          find("label", text:'それ以上').click
        end

        within("#sales_list") do
          find("label", text:'不明').click
          find("label", text:'〜 1,000億').click
          find("label", text:'それ以上').click
        end
      end

      # 最初は空
      expect(find_field('list_name').value).to be_blank

      fill_in 'request_mail_address', with: mail_address
      fill_in 'list_name', with: list_name

      expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count


      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 3

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content list_name
          expect(page).to have_content '完了通知メールアドレス'
          expect(page).to have_content mail_address
        end
      end

      within '#request_form' do
        expect(page).to have_selector('input#request_mail_address')
        expect(page).to have_content 'メールアドレス'
        expect(page).to have_content '保存されているデータがあれば使う'

        expect(page).to have_selector('button#request', text: 'リクエスト送信')

        within('h3') { expect(page).to have_content 'URLリストをアップロード' }
        within('h3') { expect(page).not_to have_content 'URLリスト作成' }
        within('h3') { expect(page).not_to have_content 'キーワード検索' }
        within('h3') { expect(page).not_to have_content '企業DBから検索' }
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content list_name
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '3')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end



      #------------
      #
      #   リクエスト詳細確認
      #
      #------------

      within "#requests" do
        find('i', text: 'find_in_page').click # 確認ボタン
      end

      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      expect(page).not_to have_content 'リクエスト受領'

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'

        expect(page).not_to have_selector('h3', text: '結果')
        expect(page).to have_selector('h3', text: 'リクエスト')
        within 'table.request_result_summary tbody' do
          expect(page).to have_content 'リクエスト名'
          expect(page).to have_content list_name
          expect(page).not_to have_content '企業一覧サイトのURL'
          expect(page).to have_content 'リクエスト日時'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).not_to have_content '実行の種類'
          expect(page).not_to have_content 'テスト実行'
          expect(page).not_to have_content '本実行'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
          expect(page).to have_content '全体数'
          expect(page).to have_selector('.total_count', text: '3')
          expect(page).to have_content '完了数'
          expect(page).to have_selector('.completed_count', text: '0')
          expect(page).to have_content '未完了数'
          expect(page).to have_selector('.waiting_count', text: '3')
        end

        expect(page).to have_selector('h3', text: '設定')

        expect(page).to have_selector('h5', text: '地域の設定')

        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '地域の設定')
          expect(page).to have_selector('h5', text: '業種の設定')
          expect(page).to have_selector('h5', text: 'その他の設定')

          within '.areas_config_area' do
            expect(page).to have_content '関東 > 東京都 > 渋谷区'
            expect(page).to have_content '関東 > 千葉県 > 浦安市'
            expect(page).to have_content '近畿 > 京都府'
            expect(page).to have_content '近畿 > 兵庫県'
            expect(page).not_to have_content '東海'
            expect(page).not_to have_content '大阪'
            expect(page).not_to have_content '神奈川'
            expect(page).not_to have_content '新宿'
          end

          within '.categories_config_area' do
            expect(page).to have_content '通信'
            expect(page).to have_content '金融 > 銀行 > 地方銀行'
            expect(page).to have_content '製造業 > 食品'
            expect(page).to have_content '製造業 > 衣料'
            expect(page).not_to have_content '小売'
            expect(page).not_to have_content '保険'
            expect(page).not_to have_content '金属'
          end

          expect(page).not_to have_selector('h6', text: '資本金の設定')
          expect(page).not_to have_selector('.capital_area')

          expect(page).to have_selector('h6', text: '従業員数の設定')
          within '.employee_area' do
            expect(page).not_to have_content '不明'
            expect(page).not_to have_content '〜 50'
            expect(page).to have_content '〜 1,000'
            expect(page).to have_content 'それ以上'
          end

          expect(page).to have_selector('h6', text: '売上の設定')
          within '.sales_area' do
            expect(page).to have_content '不明'
            expect(page).not_to have_content '〜 10億'
            expect(page).to have_content '〜 1,000億'
            expect(page).to have_content 'それ以上'
          end

          expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
        end
      end

      within '#request_form' do
        expect(page).to have_selector('input#request_mail_address')
        expect(page).to have_content 'メールアドレス'
        expect(page).to have_content '保存されているデータがあれば使う'

        expect(page).to have_selector('button#request', text: 'リクエスト送信')

        within('h3') { expect(page).to have_content 'URLリストをアップロード' }
        within('h3') { expect(page).not_to have_content 'URLリスト作成' }
        within('h3') { expect(page).not_to have_content 'キーワード検索' }
        within('h3') { expect(page).not_to have_content '企業DBから検索' }
      end


      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content list_name
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '3')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end
    end
  end

  describe 'まだ資本金調査を終えてないデータに限る' do
    let_it_be(:company13) { create(:company, domain: 'sinjuku_3') }
    let_it_be(:company14) { create(:company, domain: 'sinjuku_4, kinzoku') }

    let_it_be(:company_area11) { create(:company_area_connector, company: company13, area_connector: area_connector3) }
    let_it_be(:company_area11) { create(:company_area_connector, company: company14, area_connector: area_connector3) }
    let_it_be(:company_category1) { create(:company_category_connector, company: company14, category_connector: category_connector2) }

    let(:admin_user) { create(:admin_user) }
    before { sign_in admin_user }

    scenario 'リクエスト作成 -> 詳細確認', js: true do
      Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

      visit root_path
      click_link '企業DBを利用'

      expect(page).to have_content 'まだ資本金調査を終えてないデータに限る'

      within "#search_conditions_result" do
        find("label", text:'東京都').click
        within('h5#companies_count') { expect(page).to have_content ' 7' }
 
        find("label", text:'製造業').find(:xpath, "..").find('a').click

        find("label", text:'金属').click
        within('h5#companies_count') { expect(page).to have_content ' 3' }
      end

      find("label", text:'まだ資本金調査を終えてないデータに限る').click

      within "#search_conditions_result" do
        within('h5#companies_count') { expect(page).to have_content ' 1' }

        find("label", text:'金属').click

        within('h5#companies_count') { expect(page).to have_content ' 2' }
      end

      req_cnt = Request.count
      req_url_cnt = SearchRequest::CompanyInfo.count


      #------------
      #
      #   リクエスト送信
      #
      #------------
      click_button 'request' # リクエスト送信

      expect(page).to have_content 'リクエスト受領'
      expect(page).to have_content '検索リクエストを受付ました。'
      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      req = Request.last

      expect(req.db_groups).to eq({ CompanyGroup::NOT_OWN_CAPITALS => true }.to_json)

      expect(Request.count).to eq req_cnt + 1
      expect(SearchRequest::CompanyInfo.count).to eq req_url_cnt + 2

      within "#accept" do
        within 'table tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content 'DB検索'
        end
      end

      within "#requests" do
        expect(page).to have_content 'リクエスト一覧'

        within 'table tbody tr:nth-child(2)' do
          expect(page).not_to have_selector('i', text: 'file_download')
          expect(page).to have_content 'DB検索'
          expect(page).to have_content Time.zone.now.strftime("%Y年%m月%d日 %H:%M:%S")
          expect(page).to have_content '未完了'
          expect(page).to have_selector('i', text: 'find_in_page')
          expect(page).to have_selector('i', text: 'stop')
          expect(page).to have_selector('.accepted_count', text: '2')
          expect(page).to have_selector('.completed_count', text: '0')
        end
      end



      #------------
      #
      #   リクエスト詳細確認
      #
      #------------

      within "#requests" do
        find('i', text: 'find_in_page').click # 確認ボタン
      end

      within('h1') { expect(page).to have_content '企業HP情報の取得' }

      within "#confirm_request_form" do
        expect(page).to have_content 'リクエスト確認'

        expect(page).to have_selector('h3', text: 'リクエスト')
        within 'table.request_result_summary tbody' do
          expect(page).to have_content 'リスト名'
          expect(page).to have_content 'DB検索'
          expect(page).to have_content '現在のステータス'
          expect(page).to have_content '未完了'
          expect(page).to have_content '全体数'
          expect(page).to have_selector('.total_count', text: '2')
          expect(page).to have_content '完了数'
          expect(page).to have_selector('.completed_count', text: '0')
          expect(page).to have_content '未完了数'
          expect(page).to have_selector('.waiting_count', text: '2')
        end

        expect(page).to have_selector('h3', text: '設定')

        expect(page).to have_selector('h5', text: '地域の設定')

        within '#confirm_request_form_crawl_config_list_area' do
          expect(page).to have_selector('h5', text: '地域の設定')
          expect(page).to have_selector('h5', text: '業種の設定')
          expect(page).to have_selector('h5', text: 'その他の設定')

          within '.areas_config_area' do
            expect(page).to have_content '関東 > 東京都'
          end

          within '.other_settings_area' do
            expect(page).to have_content 'まだ資本金調査を終えてないデータに限る'
          end

          expect(page).not_to have_selector('h6', text: '資本金の設定')
          expect(page).not_to have_selector('h6', text: '従業員数の設定')
          expect(page).not_to have_selector('h6', text: '売上の設定')
        end
      end
    end
  end

  describe 'グループ条件の制限' do
    context '有料プランユーザ' do
      before { sign_in user }

      scenario '【対象実験】グループをクリックできることを確認', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit request_multiple_path
        within('#swich_type') { click_link '企業DBから検索' }

        within "#search_conditions_result" do
          within('h5#companies_count') { expect(page).to have_content ' 12' }

          within('#capital_list') { find("label", text:'不明').click }
          within("#capital_list") { find("label", text:'〜 1,000万').click }
          within('#employee_list') { find("label", text:'それ以上').click }
          within('#employee_list') { find("label", text:'〜 50').click }
          within('#sales_list') { find("label", text:'不明').click }
          within('#sales_list') { find("label", text:'〜 1,000億').click }

          sleep 1

          within('h5#companies_count') { expect(page).to have_content ' 2' }

          expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
        end
      end
    end

    context '非ログインユーザ' do
      scenario 'グループをクリックできないことを確認', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit request_multiple_path
        within('#swich_type') { click_link '企業DBから検索' }

        within "#search_conditions_result" do
          within('h5#companies_count') { expect(page).to have_content ' 12' }

          within('#capital_list') { find("label", text:'不明').click }
          within("#capital_list") { find("label", text:'〜 1,000万').click }
          within('#employee_list') { find("label", text:'それ以上').click }
          within('#employee_list') { find("label", text:'〜 50').click }
          within('#sales_list') { find("label", text:'不明').click }
          within('#sales_list') { find("label", text:'〜 1,000億').click }

          sleep 1

          within('h5#companies_count') { expect(page).to have_content ' 12' }

          expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
        end
      end
    end

    context '無料プランユーザ' do
      let(:free_user) { create(:user, billing: :free) }
      before { sign_in free_user }

      scenario 'グループをクリックできないことを確認', js: true do
        Capybara.current_session.driver.browser.manage.window.resize_to(1680, 1000)

        visit request_multiple_path
        within('#swich_type') { click_link '企業DBから検索' }

        within "#search_conditions_result" do
          within('h5#companies_count') { expect(page).to have_content ' 12' }

          within('#capital_list') { find("label", text:'不明').click }
          within("#capital_list") { find("label", text:'〜 1,000万').click }
          within('#employee_list') { find("label", text:'それ以上').click }
          within('#employee_list') { find("label", text:'〜 50').click }
          within('#sales_list') { find("label", text:'不明').click }
          within('#sales_list') { find("label", text:'〜 1,000億').click }

          sleep 1

          within('h5#companies_count') { expect(page).to have_content ' 12' }

          expect(page).not_to have_content 'まだ資本金調査を終えてないデータに限る'
        end
      end
    end
  end
end
require 'rails_helper'

RSpec.describe CompanyController, type: :controller do
  # let_it_be(:public_user) { create(:user_public) }

  # let_it_be(:region1) { Region.create(name: '関東') }
  # let_it_be(:prefecture1) { Prefecture.create(name: '東京都') }
  # let_it_be(:city1) { City.create(name: '新宿区') }
  # let_it_be(:city2) { City.create(name: '渋谷区') }
  # let_it_be(:prefecture2) { Prefecture.create(name: '埼玉県') }
  # let_it_be(:prefecture3) { Prefecture.create(name: '千葉県') }
  # let_it_be(:city5) { City.create(name: '千葉市') }
  # let_it_be(:city6) { City.create(name: '浦安市') }
  # let_it_be(:prefecture4) { Prefecture.create(name: '神奈川県') }
  # let_it_be(:city7) { City.create(name: '横浜市') }
  # let_it_be(:city8) { City.create(name: '川崎市') }
  # let_it_be(:region2) { Region.create(name: '東海') }
  # let_it_be(:prefecture5) { Prefecture.create(name: '愛知県') }
  # let_it_be(:city9) { City.create(name: '名古屋市') }
  # let_it_be(:city10) { City.create(name: '春日井市') }
  # let_it_be(:prefecture6) { Prefecture.create(name: '静岡県') }
  # let_it_be(:prefecture7) { Prefecture.create(name: '三重県') }
  # let_it_be(:city13) { City.create(name: '四日市市') }
  # let_it_be(:city14) { City.create(name: '鈴鹿市') }
  # let_it_be(:region3) { Region.create(name: '近畿') }
  # let_it_be(:prefecture8) { Prefecture.create(name: '大阪府') }
  # let_it_be(:prefecture9) { Prefecture.create(name: '京都府') }
  # let_it_be(:city17) { City.create(name: '京都市') }
  # let_it_be(:city18) { City.create(name: '宇治市') }
  # let_it_be(:prefecture10) { Prefecture.create(name: '兵庫県') }
  # let_it_be(:city19) { City.create(name: '神戸市') }
  # let_it_be(:city20) { City.create(name: '姫路市') }

  # let_it_be(:area_connector1)  { AreaConnector.create(region: region1, prefecture: nil, city: nil) }
  # let_it_be(:area_connector2)  { AreaConnector.create(region: region1, prefecture: prefecture1, city: nil) }
  # let_it_be(:area_connector3)  { AreaConnector.create(region: region1, prefecture: prefecture1, city: city1) }
  # let_it_be(:area_connector4)  { AreaConnector.create(region: region1, prefecture: prefecture1, city: city2) }
  # let_it_be(:area_connector5)  { AreaConnector.create(region: region1, prefecture: prefecture2, city: nil) }
  # let_it_be(:area_connector8)  { AreaConnector.create(region: region1, prefecture: prefecture3, city: nil) }
  # let_it_be(:area_connector9)  { AreaConnector.create(region: region1, prefecture: prefecture3, city: city5) }
  # let_it_be(:area_connector10) { AreaConnector.create(region: region1, prefecture: prefecture3, city: city6) }
  # let_it_be(:area_connector11) { AreaConnector.create(region: region1, prefecture: prefecture4, city: nil) }
  # let_it_be(:area_connector12) { AreaConnector.create(region: region1, prefecture: prefecture4, city: city7) }
  # let_it_be(:area_connector13) { AreaConnector.create(region: region1, prefecture: prefecture4, city: city8) }
  # let_it_be(:area_connector14) { AreaConnector.create(region: region2, prefecture: nil, city: nil) }
  # let_it_be(:area_connector15) { AreaConnector.create(region: region2, prefecture: prefecture5, city: nil) }
  # let_it_be(:area_connector16) { AreaConnector.create(region: region2, prefecture: prefecture5, city: city9) }
  # let_it_be(:area_connector17) { AreaConnector.create(region: region2, prefecture: prefecture5, city: city10) }
  # let_it_be(:area_connector18) { AreaConnector.create(region: region2, prefecture: prefecture6, city: nil) }
  # let_it_be(:area_connector21) { AreaConnector.create(region: region2, prefecture: prefecture7, city: nil) }
  # let_it_be(:area_connector22) { AreaConnector.create(region: region2, prefecture: prefecture7, city: city13) }
  # let_it_be(:area_connector23) { AreaConnector.create(region: region2, prefecture: prefecture7, city: city14) }
  # let_it_be(:area_connector24) { AreaConnector.create(region: region3, prefecture: nil, city: nil) }
  # let_it_be(:area_connector25) { AreaConnector.create(region: region3, prefecture: prefecture8, city: nil) }
  # let_it_be(:area_connector28) { AreaConnector.create(region: region3, prefecture: prefecture9, city: nil) }
  # let_it_be(:area_connector29) { AreaConnector.create(region: region3, prefecture: prefecture9, city: city17) }
  # let_it_be(:area_connector30) { AreaConnector.create(region: region3, prefecture: prefecture9, city: city18) }
  # let_it_be(:area_connector31) { AreaConnector.create(region: region3, prefecture: prefecture10, city: nil) }
  # let_it_be(:area_connector32) { AreaConnector.create(region: region3, prefecture: prefecture10, city: city19) }
  # let_it_be(:area_connector33) { AreaConnector.create(region: region3, prefecture: prefecture10, city: city20) }

  # let_it_be(:large1) { LargeCategory.create(name: '製造業') }
  # let_it_be(:middle1) { MiddleCategory.create(name: '金属') }
  # let_it_be(:small1) { SmallCategory.create(name: 'アルミ') }
  # let_it_be(:small2) { SmallCategory.create(name: '鉄鋼') }
  # let_it_be(:middle2) { MiddleCategory.create(name: '食品') }
  # let_it_be(:small3) { SmallCategory.create(name: '缶詰') }
  # let_it_be(:small4) { SmallCategory.create(name: 'パン') }
  # let_it_be(:middle3) { MiddleCategory.create(name: '衣料') }

  # let_it_be(:large2) { LargeCategory.create(name: '小売') }
  # let_it_be(:small5) { SmallCategory.create(name: '魚') }
  # let_it_be(:middle4) { MiddleCategory.create(name: '家電製品') }

  # let_it_be(:large3) { LargeCategory.create(name: '金融') }
  # let_it_be(:middle5) { MiddleCategory.create(name: '銀行') }
  # let_it_be(:small6) { SmallCategory.create(name: '地方銀行') }
  # let_it_be(:middle6) { MiddleCategory.create(name: '保険') }
  # let_it_be(:large4) { LargeCategory.create(name: '通信') }

  # let_it_be(:category_connector1)  { create(:category_connector, large_category: large1, middle_category: nil, small_category: nil) }
  # let_it_be(:category_connector2)  { create(:category_connector, large_category: large1, middle_category: middle1, small_category: nil) }
  # let_it_be(:category_connector3)  { create(:category_connector, large_category: large1, middle_category: middle1, small_category: small1) }
  # let_it_be(:category_connector4)  { create(:category_connector, large_category: large1, middle_category: middle1, small_category: small2) }

  # let_it_be(:category_connector6)  { create(:category_connector, large_category: large1, middle_category: middle2, small_category: nil) }
  # let_it_be(:category_connector7)  { create(:category_connector, large_category: large1, middle_category: middle2, small_category: small3) }
  # let_it_be(:category_connector8)  { create(:category_connector, large_category: large1, middle_category: middle2, small_category: small4) }
  # let_it_be(:category_connector9)  { create(:category_connector, large_category: large1, middle_category: middle3, small_category: nil) }

  # let_it_be(:category_connector10)  { create(:category_connector, large_category: large2, middle_category: nil, small_category: nil) }
  # let_it_be(:category_connector11)  { create(:category_connector, large_category: large2, middle_category: middle2, small_category: nil) }
  # let_it_be(:category_connector12)  { create(:category_connector, large_category: large2, middle_category: middle2, small_category: small3) }
  # let_it_be(:category_connector13)  { create(:category_connector, large_category: large2, middle_category: middle2, small_category: small5) }
  # let_it_be(:category_connector14)  { create(:category_connector, large_category: large2, middle_category: middle4, small_category: nil) }

  # let_it_be(:category_connector15)  { create(:category_connector, large_category: large3, middle_category: nil, small_category: nil) }
  # let_it_be(:category_connector16)  { create(:category_connector, large_category: large3, middle_category: middle5, small_category: nil) }
  # let_it_be(:category_connector17)  { create(:category_connector, large_category: large3, middle_category: middle5, small_category: small6) }
  # let_it_be(:category_connector18)  { create(:category_connector, large_category: large3, middle_category: middle6, small_category: nil) }
  # let_it_be(:category_connector19)  { create(:category_connector, large_category: large4, middle_category: nil, small_category: nil) }


  # let_it_be(:company1)  { create(:company, domain: 'sinjuku_1, almi_1,     cap_1, emp_2, sal_4') }
  # let_it_be(:company2)  { create(:company, domain: 'sinjuku_2, tekko_1,    cap_2, emp_3, sal_4') }
  # let_it_be(:company3)  { create(:company, domain: 'shibuya_1, syokuhin_1, cap_1, emp_4, sal_3') }
  # let_it_be(:company4)  { create(:company, domain: 'shibuya_2, pan_1,      cap_4, emp_3, sal_1') }
  # let_it_be(:company5)  { create(:company, domain: 'shibuya_3, iryo_1,     cap_1, emp_2, sal_1') }
  # let_it_be(:company6)  { create(:company, domain: 'chiba_1, sakana_1,     cap_2, emp_4, sal_4') }
  # let_it_be(:company7)  { create(:company, domain: 'chiba_2,               cap_3, emp_2, sal_3') }
  # let_it_be(:company8)  { create(:company, domain: 'urayasu_1, chigin_1,   cap_4, emp_2, sal_2') }
  # let_it_be(:company9)  { create(:company, domain: 'kyoto_1, hoken_1,      cap_1, emp_3, sal_3') }
  # let_it_be(:company10) { create(:company, domain: 'kyoto_2, kinyuu_1,     cap_4, emp_1, sal_3') }
  # let_it_be(:company11) { create(:company, domain: 'kobe_1, tsushin_1,     cap_3, emp_4, sal_4') }
  # let_it_be(:company12) { create(:company, domain: 'tsushin_2,             cap_4, emp_2, sal_2') }

  # let_it_be(:company_area1) { create(:company_area_connector, company: company1, area_connector: area_connector3) }
  # let_it_be(:company_area2) { create(:company_area_connector, company: company2, area_connector: area_connector3) }
  # let_it_be(:company_area3) { create(:company_area_connector, company: company3, area_connector: area_connector4) }
  # let_it_be(:company_area4) { create(:company_area_connector, company: company4, area_connector: area_connector4) }
  # let_it_be(:company_area5) { create(:company_area_connector, company: company5, area_connector: area_connector4) }
  # let_it_be(:company_area6) { create(:company_area_connector, company: company6, area_connector: area_connector8) }
  # let_it_be(:company_area7) { create(:company_area_connector, company: company7, area_connector: area_connector8) }
  # let_it_be(:company_area8) { create(:company_area_connector, company: company8, area_connector: area_connector10) }
  # let_it_be(:company_area9) { create(:company_area_connector, company: company9, area_connector: area_connector28) }
  # let_it_be(:company_area10) { create(:company_area_connector, company: company10, area_connector: area_connector28) }
  # let_it_be(:company_area11) { create(:company_area_connector, company: company11, area_connector: area_connector32) }

  # let_it_be(:company_category1) { create(:company_category_connector, company: company1, category_connector: category_connector3) }
  # let_it_be(:company_category2) { create(:company_category_connector, company: company2, category_connector: category_connector4) }
  # let_it_be(:company_category3) { create(:company_category_connector, company: company3, category_connector: category_connector6) }
  # let_it_be(:company_category4) { create(:company_category_connector, company: company4, category_connector: category_connector8) }
  # let_it_be(:company_category5) { create(:company_category_connector, company: company5, category_connector: category_connector9) }
  # let_it_be(:company_category6) { create(:company_category_connector, company: company6, category_connector: category_connector13) }
  # let_it_be(:company_category7) { create(:company_category_connector, company: company8, category_connector: category_connector17) }
  # let_it_be(:company_category8) { create(:company_category_connector, company: company9, category_connector: category_connector18) }
  # let_it_be(:company_category9) { create(:company_category_connector, company: company10, category_connector: category_connector15) }
  # let_it_be(:company_category10) { create(:company_category_connector, company: company11, category_connector: category_connector19) }
  # let_it_be(:company_category11) { create(:company_category_connector, company: company12, category_connector: category_connector19) }

  # let_it_be(:capital_group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
  # let_it_be(:capital_group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10_000_000, lower: 0) }
  # let_it_be(:capital_group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 100_000_000, lower: 10_000_001) }
  # let_it_be(:capital_group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 100_000_001) }
  # let_it_be(:employee_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: nil) }
  # let_it_be(:employee_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 50, lower: 0) }
  # let_it_be(:employee_group3) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 1_000, lower: 51) }
  # let_it_be(:employee_group4) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 1_001) }
  # let_it_be(:sales_group1) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: nil) }
  # let_it_be(:sales_group2) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 1_000_000_000, lower: 0) }
  # let_it_be(:sales_group3) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 100_000_000_000, lower: 1_000_000_001) }
  # let_it_be(:sales_group4) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: 100_000_000_001) }

  # let_it_be(:company_capital_group1)  { create(:company_company_group, company: company1,  company_group: capital_group1) }
  # let_it_be(:company_capital_group2)  { create(:company_company_group, company: company2,  company_group: capital_group2) }
  # let_it_be(:company_capital_group3)  { create(:company_company_group, company: company3,  company_group: capital_group1) }
  # let_it_be(:company_capital_group4)  { create(:company_company_group, company: company4,  company_group: capital_group4) }
  # let_it_be(:company_capital_group5)  { create(:company_company_group, company: company5,  company_group: capital_group1) }
  # let_it_be(:company_capital_group6)  { create(:company_company_group, company: company6,  company_group: capital_group2) }
  # let_it_be(:company_capital_group7)  { create(:company_company_group, company: company7,  company_group: capital_group3) }
  # let_it_be(:company_capital_group8)  { create(:company_company_group, company: company8,  company_group: capital_group4) }
  # let_it_be(:company_capital_group9)  { create(:company_company_group, company: company9,  company_group: capital_group1) }
  # let_it_be(:company_capital_group10) { create(:company_company_group, company: company10, company_group: capital_group4) }
  # let_it_be(:company_capital_group11) { create(:company_company_group, company: company11, company_group: capital_group3) }
  # let_it_be(:company_capital_group12) { create(:company_company_group, company: company12, company_group: capital_group4) }

  # let_it_be(:company_employee_group1)  { create(:company_company_group, company: company1,  company_group: employee_group2) }
  # let_it_be(:company_employee_group2)  { create(:company_company_group, company: company2,  company_group: employee_group3) }
  # let_it_be(:company_employee_group3)  { create(:company_company_group, company: company3,  company_group: employee_group4) }
  # let_it_be(:company_employee_group4)  { create(:company_company_group, company: company4,  company_group: employee_group3) }
  # let_it_be(:company_employee_group5)  { create(:company_company_group, company: company5,  company_group: employee_group2) }
  # let_it_be(:company_employee_group6)  { create(:company_company_group, company: company6,  company_group: employee_group4) }
  # let_it_be(:company_employee_group7)  { create(:company_company_group, company: company7,  company_group: employee_group2) }
  # let_it_be(:company_employee_group8)  { create(:company_company_group, company: company8,  company_group: employee_group2) }
  # let_it_be(:company_employee_group9)  { create(:company_company_group, company: company9,  company_group: employee_group3) }
  # let_it_be(:company_employee_group10) { create(:company_company_group, company: company10, company_group: employee_group1) }
  # let_it_be(:company_employee_group11) { create(:company_company_group, company: company11, company_group: employee_group4) }
  # let_it_be(:company_employee_group12) { create(:company_company_group, company: company12, company_group: employee_group2) }

  # let_it_be(:company_sales_group1)  { create(:company_company_group, company: company1,  company_group: sales_group4) }
  # let_it_be(:company_sales_group2)  { create(:company_company_group, company: company2,  company_group: sales_group4) }
  # let_it_be(:company_sales_group3)  { create(:company_company_group, company: company3,  company_group: sales_group3) }
  # let_it_be(:company_sales_group4)  { create(:company_company_group, company: company4,  company_group: sales_group1) }
  # let_it_be(:company_sales_group5)  { create(:company_company_group, company: company5,  company_group: sales_group1) }
  # let_it_be(:company_sales_group6)  { create(:company_company_group, company: company6,  company_group: sales_group4) }
  # let_it_be(:company_sales_group7)  { create(:company_company_group, company: company7,  company_group: sales_group3) }
  # let_it_be(:company_sales_group8)  { create(:company_company_group, company: company8,  company_group: sales_group2) }
  # let_it_be(:company_sales_group9)  { create(:company_company_group, company: company9,  company_group: sales_group3) }
  # let_it_be(:company_sales_group10) { create(:company_company_group, company: company10, company_group: sales_group3) }
  # let_it_be(:company_sales_group11) { create(:company_company_group, company: company11, company_group: sales_group4) }
  # let_it_be(:company_sales_group12) { create(:company_company_group, company: company12, company_group: sales_group2) }

  describe '#find_areas_categories' do
  end
end
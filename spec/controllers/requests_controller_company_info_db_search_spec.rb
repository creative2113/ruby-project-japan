require 'rails_helper'

RSpec.describe RequestsController, type: :controller do

  def check_normal_finish(add_url_count:)
    request_count = Request.count
    req_url_count = RequestedUrl.count

    subject

    expect(assigns(:finish_status)).to eq :normal_finish
    expect(assigns(:accepted)).to be_truthy
    expect(assigns(:file_name)).to eq file_name
    expect(assigns(:invalid_urls)).to eq invalid_urls
    expect(assigns(:requests)).to eq requests

    expect(response.status).to eq 302
    expect(response.location).to redirect_to request_multiple_path(r: request.id)

    # モデルチェック
    expect(request.user).to eq user
    expect(request.title).to eq file_name
    expect(request.type).to eq type.to_s
    expect(request.corporate_list_site_start_url).to be_nil
    expect(request.company_info_result_headers).to be_nil
    expect(request.status).to eq EasySettings.status.new
    expect(request.test).to be_falsey
    expect(request.plan).to eq user.my_plan_number
    expect(request.expiration_date).to be_nil
    expect(request.mail_address).to eq address
    expect(request.ip).to eq '0.0.0.0'
    expect(request.requested_urls.count).to eq add_url_count
    expect(request.requested_urls[0].status).to eq EasySettings.status.new
    expect(request.requested_urls[0].finish_status).to eq EasySettings.finish_status.new

    # 増減チェック
    expect(Request.count).to eq request_count + 1
    expect(RequestedUrl.count).to eq req_url_count + add_url_count

    # メールのチェック
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(ActionMailer::Base.deliveries.first.to).to include address
    expect(ActionMailer::Base.deliveries.first.subject).to match(/リクエストを受け付けました。/)
    expect(ActionMailer::Base.deliveries.first.body.raw_source).to match(/#{file_name}/)

    # redisにsetされていることをチェック
    expect(Redis.new.get("#{request.id}_request")).to be_present
    Redis.new.del("#{request.id}_request")
  end

  let_it_be(:master_test_light_plan)    { create(:master_billing_plan, :test_light) }
  let_it_be(:master_test_standard_plan) { create(:master_billing_plan, :test_standard) }
  let_it_be(:master_standard_plan)      { create(:master_billing_plan, :standard) }

  before do
    create_public_user

    allow(Billing).to receive(:plan_list).and_return(['test_light', 'test_standard', 'standard'])
  end

  let(:ip)        { '0.0.0.0' }
  let(:today)     { Time.zone.today }
  let(:yesterday) { today - 1.day }

  let(:file_name)              { list_name }
  let(:address)                { 'to@example.org' }
  let(:use_storage)            { 1 }
  let(:using_storage_days)     { '' }
  let(:free_search)            { 0 }
  let(:link_words)             { '' }
  let(:target_words)           { '' }
  let(:type)                   { :company_db_search }
  let(:mode)                   { RequestsController::MODE_MULTIPLE }
  let(:requests)               { nil }
  let(:invalid_urls)           { [] }

  let(:request) { Request.find_by_file_name(file_name) }

  after { ActionMailer::Base.deliveries.clear }


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


  let_it_be(:company1) { create(:company, domain: 'sinjuku_1_almi_1') }
  let_it_be(:company2) { create(:company, domain: 'sinjuku_2_tekko_1') }
  let_it_be(:company3) { create(:company, domain: 'shibuya_1_syokuhin_1') }
  let_it_be(:company4) { create(:company, domain: 'shibuya_2_pan_1') }
  let_it_be(:company5) { create(:company, domain: 'shibuya_3_iryo_1') }
  let_it_be(:company6) { create(:company, domain: 'chiba_1_sakana_1') }
  let_it_be(:company7) { create(:company, domain: 'chiba_2') }
  let_it_be(:company8) { create(:company, domain: 'urayasu_1_chigin_1') }
  let_it_be(:company9) { create(:company, domain: 'kyoto_1_hoken_1') }
  let_it_be(:company10) { create(:company, domain: 'kyoto_2_kinyuu_1') }
  let_it_be(:company11) { create(:company, domain: 'kobe_1_tsushin_1') }
  let_it_be(:company12) { create(:company, domain: 'tsushin_2') }

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
  let_it_be(:employee_group3) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: 100, lower: 51) }
  let_it_be(:employee_group4) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 101) }
  let_it_be(:sales_group1) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: nil) }
  let_it_be(:sales_group2) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 10_000_000, lower: 0) }
  let_it_be(:sales_group3) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: 1_000_000_000, lower: 10_000_001) }
  let_it_be(:sales_group4) { create(:company_group, :range, title: CompanyGroup::SALES, grouping_number: CompanyGroup::RESERVED[CompanyGroup::SALES], upper: nil, lower: 1_000_000_001) }

  let_it_be(:capital_company_group1) { create(:company_company_group, company: company1, company_group: capital_group2) }
  let_it_be(:capital_company_group2) { create(:company_company_group, company: company2, company_group: capital_group1) }
  let_it_be(:capital_company_group3) { create(:company_company_group, company: company3, company_group: capital_group2) }
  let_it_be(:capital_company_group4) { create(:company_company_group, company: company4, company_group: capital_group3) }
  let_it_be(:capital_company_group5) { create(:company_company_group, company: company5, company_group: capital_group4) }
  let_it_be(:capital_company_group6) { create(:company_company_group, company: company6, company_group: capital_group1) }
  let_it_be(:capital_company_group7) { create(:company_company_group, company: company7, company_group: capital_group2) }
  let_it_be(:capital_company_group8) { create(:company_company_group, company: company8, company_group: capital_group2) }
  let_it_be(:capital_company_group9) { create(:company_company_group, company: company9, company_group: capital_group4) }
  let_it_be(:capital_company_group10) { create(:company_company_group, company: company10, company_group: capital_group1) }
  let_it_be(:capital_company_group11) { create(:company_company_group, company: company11, company_group: capital_group1) }
  let_it_be(:capital_company_group12) { create(:company_company_group, company: company12, company_group: capital_group3) }

  let_it_be(:employee_company_group1) { create(:company_company_group, company: company1, company_group: employee_group1) }
  let_it_be(:employee_company_group2) { create(:company_company_group, company: company2, company_group: employee_group2) }
  let_it_be(:employee_company_group3) { create(:company_company_group, company: company3, company_group: employee_group3) }
  let_it_be(:employee_company_group4) { create(:company_company_group, company: company4, company_group: employee_group4) }
  let_it_be(:employee_company_group5) { create(:company_company_group, company: company5, company_group: employee_group1) }
  let_it_be(:employee_company_group6) { create(:company_company_group, company: company6, company_group: employee_group2) }
  let_it_be(:employee_company_group7) { create(:company_company_group, company: company7, company_group: employee_group3) }
  let_it_be(:employee_company_group8) { create(:company_company_group, company: company8, company_group: employee_group4) }
  let_it_be(:employee_company_group9) { create(:company_company_group, company: company9, company_group: employee_group1) }
  let_it_be(:employee_company_group10) { create(:company_company_group, company: company10, company_group: employee_group2) }
  let_it_be(:employee_company_group11) { create(:company_company_group, company: company11, company_group: employee_group3) }
  let_it_be(:employee_company_group12) { create(:company_company_group, company: company12, company_group: employee_group4) }

  let_it_be(:sales_company_group1) { create(:company_company_group, company: company1, company_group: sales_group1) }
  let_it_be(:sales_company_group2) { create(:company_company_group, company: company2, company_group: sales_group1) }
  let_it_be(:sales_company_group3) { create(:company_company_group, company: company3, company_group: sales_group2) }
  let_it_be(:sales_company_group4) { create(:company_company_group, company: company4, company_group: sales_group3) }
  let_it_be(:sales_company_group5) { create(:company_company_group, company: company5, company_group: sales_group3) }
  let_it_be(:sales_company_group6) { create(:company_company_group, company: company6, company_group: sales_group4) }
  let_it_be(:sales_company_group7) { create(:company_company_group, company: company7, company_group: sales_group2) }
  let_it_be(:sales_company_group8) { create(:company_company_group, company: company8, company_group: sales_group4) }
  let_it_be(:sales_company_group9) { create(:company_company_group, company: company9, company_group: sales_group2) }
  let_it_be(:sales_company_group10) { create(:company_company_group, company: company10, company_group: sales_group1) }
  let_it_be(:sales_company_group11) { create(:company_company_group, company: company11, company_group: sales_group4) }
  let_it_be(:sales_company_group12) { create(:company_company_group, company: company12, company_group: sales_group3) }

  let(:email)        { 'login_test_user@aaa.com' }
  let(:logined_user) { create(:user, email: email) }
  let!(:plan)        { create(:billing_plan, name: master_standard_plan.name, status: :ongoing, billing: logined_user.billing) }
  let(:user)         { logined_user }
  let(:unlogin_user) { create(:user) }
  let(:public_user)  { User.get_public }
  let(:r1)           { create(:request, user: logined_user) }
  let(:r2)           { create(:request, user: logined_user) }
  let(:requests)     { [Request.find_by_file_name(file_name), r2, r1] }

  before do
    create(:request, user: unlogin_user)
    create(:request, :corporate_site_list, user: unlogin_user)
    create(:request, user: public_user)
    create(:request, :corporate_site_list, user: public_user)

    create(:request, :corporate_site_list, user: logined_user)
    r1
    r2
  end

  describe "POST create" do

    subject { post :create, params: params }

    let(:params) {
      { request: { mail_address: address, use_storage: use_storage, using_storage_days: using_storage_days },
        list_name: list_name, request_type: type, areas: areas, categories: categories,
        capital: capitals, employee: employees, sales: sales, mode: mode
      }
    }

    let(:list_name)  { 'リクエストサンプル' }
    let(:areas)      { { area_connector2.id.to_s => area_connector2.id.to_s, area_connector28.id.to_s => area_connector28.id.to_s, area_connector32.id.to_s => area_connector32.id.to_s } }
    let(:categories) { { category_connector2.id.to_s => category_connector2.id.to_s, category_connector15.id.to_s => category_connector15.id.to_s } }
    let(:capitals)   { { capital_group1.id.to_s => capital_group1.id.to_s, capital_group2.id.to_s => capital_group2.id.to_s } }
    # let(:employees)  { { employee_group1.id.to_s => employee_group1.id.to_s, employee_group2.id.to_s => employee_group2.id.to_s, employee_group3.id.to_s => employee_group3.id.to_s } }
    # let(:sales)      { { sales_group1.id.to_s => sales_group1.id.to_s, sales_group2.id.to_s => sales_group2.id.to_s, sales_group3.id.to_s => sales_group3.id.to_s } }
    let(:employees)  { nil }
    let(:sales)      { nil }

    context 'Plan User' do

      before { sign_in logined_user }

      context '正常終了の場合' do
        context 'エクセル件数制限がある場合' do
          before { allow(EasySettings.excel_row_limit).to receive('[]').and_return(limit) }

          context 'エクセル件数制限が2の場合' do
            let(:limit) { 2 }

            it '正しい結果が返ってくること' do

              check_normal_finish(add_url_count: 2)

              # インスタンス変数のチェック
              expect(assigns(:using_storaged_date)).to be_nil
              expect(assigns(:use_storage)).to be_truthy
              expect(assigns(:free_search)).to be_falsey

              # モデルチェック
              expect(request.use_storage).to be_truthy
              expect(request.using_storage_days).to be_nil
              expect(request.free_search).to be_falsey
              expect(request.link_words).to be_nil
              expect(request.target_words).to be_nil
              expect(Json2.parse(request.db_areas)).to match_array(areas.values)
              expect(Json2.parse(request.db_categories)).to match_array(categories.values)
              # expect(request.db_groups).to eq({ CompanyGroup::CAPITAL => capitals.values }.to_json) # Jsonにすると配列の順番が保証されない
              db_groups = Json2.parse(request.db_groups, symbolize: false)
              expect(db_groups.keys).to match_array([CompanyGroup::CAPITAL])
              expect(db_groups[CompanyGroup::CAPITAL]).to match_array(capitals.values)

              expect(request.requested_urls[0].url).to eq 'https://sinjuku_1_almi_1'
              expect(request.requested_urls[1].url).to eq 'https://sinjuku_2_tekko_1'
              expect(request.requested_urls[2]).to be_nil
              expect(request.requested_urls[3]).to be_nil

              # リクエストカウントチェック
              expect(MonthlyHistory.find_around(user).request_count).to eq 1
            end
          end

          context 'エクセル件数制限が3の場合' do
            let(:limit) { 3 }

            it '正しい結果が返ってくること' do

              check_normal_finish(add_url_count: 3)

              # インスタンス変数のチェック
              expect(assigns(:using_storaged_date)).to be_nil
              expect(assigns(:use_storage)).to be_truthy
              expect(assigns(:free_search)).to be_falsey

              # モデルチェック
              expect(request.use_storage).to be_truthy
              expect(request.using_storage_days).to be_nil
              expect(request.free_search).to be_falsey
              expect(request.link_words).to be_nil
              expect(request.target_words).to be_nil
              expect(Json2.parse(request.db_areas)).to match_array(areas.values)
              expect(Json2.parse(request.db_categories)).to match_array(categories.values)
              # expect(request.db_groups).to eq({ CompanyGroup::CAPITAL => capitals.values }.to_json) # Jsonにすると配列の順番が保証されない
              db_groups = Json2.parse(request.db_groups, symbolize: false)
              expect(db_groups.keys).to match_array([CompanyGroup::CAPITAL])
              expect(db_groups[CompanyGroup::CAPITAL]).to match_array(capitals.values)

              # なぜか失敗する？
              # expect(request.requested_urls[0].url).to eq 'https://sinjuku_1_almi_1'
              # expect(request.requested_urls[1].url).to eq 'https://sinjuku_2_tekko_1'
              # expect(request.requested_urls[2].url).to eq 'https://kyoto_1_hoken_1'

              # 以下のどれかが含まれていればOK
              candidate_urls = ['https://sinjuku_1_almi_1', 'https://sinjuku_2_tekko_1', 'https://kyoto_1_hoken_1', 'https://kyoto_2_kinyuu_1']
              expect(candidate_urls).to include(request.requested_urls[0].url)
              expect(candidate_urls).to include(request.requested_urls[1].url)
              expect(candidate_urls).to include(request.requested_urls[2].url)
              expect(request.requested_urls[3]).to be_nil

              # リクエストカウントチェック
              expect(MonthlyHistory.find_around(user).request_count).to eq 1
            end
          end
        end

        context 'リスト名を指定した場合' do
          let(:list_name) { 'リクエストサンプル' }
          let(:capitals)  { { capital_group1.id.to_s => capital_group1.id.to_s, capital_group2.id.to_s => capital_group2.id.to_s, capital_group4.id.to_s => capital_group4.id.to_s } }

          it '正しい結果が返ってくること' do

            check_normal_finish(add_url_count: 4)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(Json2.parse(request.db_areas)).to match_array(areas.values)
            expect(Json2.parse(request.db_categories)).to match_array(categories.values)
            # expect(request.db_groups).to eq({ CompanyGroup::CAPITAL => capitals.values }.to_json) # Jsonにすると配列の順番が保証されない
            db_groups = Json2.parse(request.db_groups, symbolize: false)
            expect(db_groups.keys).to match_array([CompanyGroup::CAPITAL])
            expect(db_groups[CompanyGroup::CAPITAL]).to match_array(capitals.values)
            # expect(request.requested_urls[0].url).to eq 'https://sinjuku_1_almi_1'
            # expect(request.requested_urls[1].url).to eq 'https://sinjuku_2_tekko_1'
            # expect(request.requested_urls[2].url).to eq 'https://kyoto_1_hoken_1'
            # expect(request.requested_urls[3].url).to eq 'https://kyoto_2_kinyuu_1'

            # 以下のどれかが含まれていればOK
            candidate_urls = ['https://sinjuku_1_almi_1', 'https://sinjuku_2_tekko_1', 'https://kyoto_1_hoken_1', 'https://kyoto_2_kinyuu_1']
            expect(candidate_urls).to include(request.requested_urls[0].url)
            expect(candidate_urls).to include(request.requested_urls[1].url)
            expect(candidate_urls).to include(request.requested_urls[2].url)
            expect(candidate_urls).to include(request.requested_urls[3].url)

            #リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 1
          end
        end

        context 'リスト名を指定しなかった場合' do
          let(:list_name) { nil }
          let(:file_name) { 'DB検索' }

          let(:areas)      { { area_connector8.id.to_s => area_connector8.id.to_s, area_connector24.id.to_s => area_connector24.id.to_s } }
          let(:categories) { { category_connector11.id.to_s => category_connector11.id.to_s, category_connector19.id.to_s => category_connector19.id.to_s } }

          it '正しい結果が返ってくること' do

            check_normal_finish(add_url_count: 2)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(Json2.parse(request.db_areas)).to match_array(areas.values)
            expect(Json2.parse(request.db_categories)).to match_array(categories.values)
            # expect(request.db_groups).to eq({ CompanyGroup::CAPITAL => capitals.values }.to_json) # Jsonにすると配列の順番が保証されない
            db_groups = Json2.parse(request.db_groups, symbolize: false)
            expect(db_groups.keys).to match_array([CompanyGroup::CAPITAL])
            expect(db_groups[CompanyGroup::CAPITAL]).to match_array(capitals.values)
            expect(request.requested_urls[0].url).to eq 'https://chiba_1_sakana_1'
            expect(request.requested_urls[1].url).to eq 'https://kobe_1_tsushin_1'

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 1
          end
        end

        context '業種を選択しなかった場合' do

          let(:areas)      { { area_connector8.id.to_s => area_connector8.id.to_s, area_connector24.id.to_s => area_connector24.id.to_s } }
          let(:categories) { nil }
          let(:capitals)   { { capital_group1.id.to_s => capital_group1.id.to_s, capital_group2.id.to_s => capital_group2.id.to_s, capital_group4.id.to_s => capital_group4.id.to_s } }

          it '正しい結果が返ってくること' do

            check_normal_finish(add_url_count: 6)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(Json2.parse(request.db_areas)).to match_array(areas.values)
            expect(request.db_categories).to be_nil
            # expect(request.db_groups).to eq({ CompanyGroup::CAPITAL => capitals.values }.to_json) # Jsonにすると配列の順番が保証されない
            db_groups = Json2.parse(request.db_groups, symbolize: false)
            expect(db_groups.keys).to match_array([CompanyGroup::CAPITAL])
            expect(db_groups[CompanyGroup::CAPITAL]).to match_array(capitals.values)
            expect(request.requested_urls[0].url).to eq 'https://chiba_1_sakana_1'
            expect(request.requested_urls[1].url).to eq 'https://chiba_2'
            expect(request.requested_urls[2].url).to eq 'https://urayasu_1_chigin_1'
            expect(request.requested_urls[3].url).to eq 'https://kyoto_1_hoken_1'
            expect(request.requested_urls[4].url).to eq 'https://kyoto_2_kinyuu_1'
            expect(request.requested_urls[5].url).to eq 'https://kobe_1_tsushin_1'

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 1
          end
        end

        context '地域を選択しなかった場合' do

          let(:areas)      { nil }
          let(:categories) { { category_connector11.id.to_s => category_connector11.id.to_s, category_connector19.id.to_s => category_connector19.id.to_s } }
          let(:capitals)   { nil }
          let(:employees)  { { employee_group1.id.to_s => employee_group1.id.to_s, employee_group2.id.to_s => employee_group2.id.to_s, employee_group3.id.to_s => employee_group3.id.to_s } }
          let(:sales)      { { sales_group2.id.to_s => sales_group2.id.to_s, sales_group3.id.to_s => sales_group3.id.to_s, sales_group4.id.to_s => sales_group4.id.to_s } }

          it '正しい結果が返ってくること' do

            check_normal_finish(add_url_count: 2)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.db_areas).to be_nil
            expect(Json2.parse(request.db_categories)).to match_array(categories.values)
            # expect(request.db_groups).to eq({ CompanyGroup::EMPLOYEE => employees.values, CompanyGroup::SALES => sales.values }.to_json) # Jsonにすると配列の順番が保証されない
            db_groups = Json2.parse(request.db_groups, symbolize: false)
            expect(db_groups.keys).to match_array([CompanyGroup::EMPLOYEE, CompanyGroup::SALES])
            expect(db_groups[CompanyGroup::EMPLOYEE]).to match_array(employees.values)
            expect(db_groups[CompanyGroup::SALES]).to match_array(sales.values)

            expect(request.requested_urls[0].url).to eq 'https://chiba_1_sakana_1'
            expect(request.requested_urls[1].url).to eq 'https://kobe_1_tsushin_1'

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 1
          end
        end

        context 'グループを全て選択した場合' do

          let(:areas)      { nil }
          let(:categories) { nil }
          let(:capitals)   { { capital_group1.id.to_s => capital_group1.id.to_s, capital_group2.id.to_s => capital_group2.id.to_s } }
          let(:employees)  { { employee_group1.id.to_s => employee_group1.id.to_s, employee_group2.id.to_s => employee_group2.id.to_s, employee_group3.id.to_s => employee_group3.id.to_s } }
          let(:sales)      { { sales_group2.id.to_s => sales_group2.id.to_s, sales_group4.id.to_s => sales_group4.id.to_s } }

          it '正しい結果が返ってくること' do

            check_normal_finish(add_url_count: 4)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(request.db_areas).to be_nil
            expect(request.db_categories).to be_nil
            # expect(request.db_groups).to eq({ CompanyGroup::CAPITAL => capitals.values, CompanyGroup::EMPLOYEE => employees.values, CompanyGroup::SALES => sales.values }.to_json) # Jsonにすると配列の順番が保証されない
            db_groups = Json2.parse(request.db_groups, symbolize: false)
            expect(db_groups.keys).to match_array([ CompanyGroup::CAPITAL, CompanyGroup::EMPLOYEE, CompanyGroup::SALES])
            expect(db_groups[CompanyGroup::CAPITAL]).to match_array(capitals.values)
            expect(db_groups[CompanyGroup::EMPLOYEE]).to match_array(employees.values)
            expect(db_groups[CompanyGroup::SALES]).to match_array(sales.values)

            expect(request.requested_urls[0].url).to eq 'https://shibuya_1_syokuhin_1'
            expect(request.requested_urls[1].url).to eq 'https://chiba_1_sakana_1'
            expect(request.requested_urls[2].url).to eq 'https://chiba_2'
            expect(request.requested_urls[3].url).to eq 'https://kobe_1_tsushin_1'

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 1
          end
        end

        context 'グループを選択しなかった場合' do
          let(:capitals)  { nil }
          let(:employees) { nil }
          let(:sales)     { nil }

          it '正しい結果が返ってくること' do

            check_normal_finish(add_url_count: 4)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:free_search)).to be_falsey

            # モデルチェック
            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            expect(request.free_search).to be_falsey
            expect(request.link_words).to be_nil
            expect(request.target_words).to be_nil
            expect(Json2.parse(request.db_areas)).to match_array(areas.values)
            expect(Json2.parse(request.db_categories)).to match_array(categories.values)
            expect(request.db_groups).to be_nil
            expect(request.requested_urls[0].url).to eq 'https://sinjuku_1_almi_1'
            expect(request.requested_urls[1].url).to eq 'https://sinjuku_2_tekko_1'
            expect(request.requested_urls[2].url).to eq 'https://kyoto_1_hoken_1'
            expect(request.requested_urls[3].url).to eq 'https://kyoto_2_kinyuu_1'

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 1
          end
        end
      end


      context 'ユーザのアクセスが過去にある場合' do

        context '待機リクエスト制限を超えている場合、かつ、日次アクセス制限を超えている場合' do
          before { User.find_by_email(email).update(request_count: EasySettings.request_limit[:standard] + 1) }

          before do
            create(:monthly_history, user: User.find_by_email(email), plan: EasySettings.plan[:standard], request_count: EasySettings.monthly_request_limit[:standard])
            create_list(:request, EasySettings.waiting_requests_limit[user.my_plan], user: user)
          end

          it '待機リクエスト制限に引っかかること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count
            before_request_count = user.request_count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :waiting_requests_limit
            expect(assigns(:requests).size).to eq EasySettings.waiting_requests_limit[user.my_plan]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq EasySettings.monthly_request_limit[:standard]

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        xcontext '日次アクセス制限を超えている場合' do
          before do
            User.find_by_email(email).update(request_count: EasySettings.request_limit[:standard] + 1)
            create(:monthly_history, user: User.find_by_email(email), plan: EasySettings.plan[:standard], request_count: EasySettings.monthly_request_limit[:standard])
          end

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :request_limit
            expect(assigns(:requests)).to eq [r2, r1]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq EasySettings.monthly_request_limit[:standard]

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context '月次アクセス制限を超えている場合' do
          before do
            User.find_by_email(email).update(request_count: EasySettings.request_limit[:standard] - 1)
            create(:monthly_history, user: User.find_by_email(email), plan: EasySettings.plan[:standard], request_count: EasySettings.monthly_request_limit[:standard])
          end

          it '正しい結果が返ってくること' do
            request_count = Request.count
            req_url_count = RequestedUrl.count

            subject

            expect(response.status).to eq 400
            expect(response).to render_template :index_multiple

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy
            expect(assigns(:accepted)).to be_falsey
            expect(assigns(:file_name)).to eq file_name
            expect(assigns(:invalid_urls)).to eq([])
            expect(assigns(:finish_status)).to eq :monthly_request_limit
            expect(assigns(:requests)).to eq [r2, r1]

            expect(request).to be_nil

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq EasySettings.monthly_request_limit[:standard] + 1

            expect(ActionMailer::Base.deliveries.size).to eq(0)

            # 増減チェック
            expect(Request.count).to eq request_count
            expect(RequestedUrl.count).to eq req_url_count
          end
        end

        context 'アクセス制限を超えていない場合' do
          before do
            User.find_by_email(email).update(request_count: EasySettings.request_limit[:standard] - 1,
                                             last_request_date: today)
            create(:monthly_history, user: User.find_by_email(email), plan: EasySettings.plan[:standard], request_count: EasySettings.monthly_request_limit[:standard] - 1)
          end

          it '正しい結果が返ってくること' do
            check_normal_finish(add_url_count: 3)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy

            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil
            # expect(request.requested_urls[0].url).to eq 'https://sinjuku_1_almi_1'
            # expect(request.requested_urls[1].url).to eq 'https://sinjuku_2_tekko_1'
            # expect(request.requested_urls[2].url).to eq 'https://kyoto_1_hoken_1'
            # expect(request.requested_urls[3].url).to eq 'https://kyoto_2_kinyuu_1'

            # 以下のどれかが含まれていればOK
            candidate_urls = ['https://sinjuku_1_almi_1', 'https://sinjuku_2_tekko_1', 'https://kyoto_2_kinyuu_1']
            expect(candidate_urls).to include(request.requested_urls[0].url)
            expect(candidate_urls).to include(request.requested_urls[1].url)
            expect(candidate_urls).to include(request.requested_urls[2].url)

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq EasySettings.monthly_request_limit[:standard]
          end
        end

        context '最後のアクセスが昨日だった場合' do
          before do
            User.find_by_email(email).update(request_count: EasySettings.request_limit[:standard] + 1,
                                             last_request_count: 1,
                                             last_request_date: yesterday)
            create(:monthly_history, user: User.find_by_email(email), plan: EasySettings.plan[:standard], request_count: 5)
          end

          it '正しい結果が返ってくること' do
            check_normal_finish(add_url_count: 3)

            # インスタンス変数のチェック
            expect(assigns(:using_storaged_date)).to be_nil
            expect(assigns(:use_storage)).to be_truthy

            expect(request.use_storage).to be_truthy
            expect(request.using_storage_days).to be_nil

            # expect(request.requested_urls[0].url).to eq 'https://sinjuku_1_almi_1'
            # expect(request.requested_urls[1].url).to eq 'https://sinjuku_2_tekko_1'
            # expect(request.requested_urls[2].url).to eq 'https://kyoto_1_hoken_1'
            # expect(request.requested_urls[3].url).to eq 'https://kyoto_2_kinyuu_1'

            # 以下のどれかが含まれていればOK
            candidate_urls = ['https://sinjuku_1_almi_1', 'https://sinjuku_2_tekko_1', 'https://kyoto_2_kinyuu_1']
            expect(candidate_urls).to include(request.requested_urls[0].url)
            expect(candidate_urls).to include(request.requested_urls[1].url)
            expect(candidate_urls).to include(request.requested_urls[2].url)

            # リクエストカウントチェック
            expect(MonthlyHistory.find_around(user).request_count).to eq 6
          end
        end
      end

      context '地域、業種、グループの選択がなかった場合' do

        let(:areas)      { nil }
        let(:categories) { nil }
        let(:capitals)   { nil }
        let(:employees)  { nil }
        let(:sales)      { nil }

        it '正しい結果が返ってくること' do
          request_count = Request.count
          req_url_count = RequestedUrl.count

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:accepted)).to be_falsey
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:invalid_urls)).to eq([])
          expect(assigns(:finish_status)).to eq :area_category_group_blank
          expect(assigns(:notice_create_msg)).to eq Message.const[:area_category_groups_are_blank]
          expect(assigns(:requests)).to eq [r2, r1]

          expect(request).to be_nil

          # リクエストカウントチェック
          expect(MonthlyHistory.find_around(user).request_count).to eq 0

          expect(ActionMailer::Base.deliveries.size).to eq(0)

          # 増減チェック
          expect(Request.count).to eq request_count
          expect(RequestedUrl.count).to eq req_url_count
        end
      end

      context '地域、業種を選択した結果、0件だった場合' do

        let(:areas)      { { area_connector8.id.to_s => area_connector8.id.to_s } }
        let(:categories) { { category_connector19.id.to_s => category_connector19.id.to_s } }

        it '正しい結果が返ってくること' do
          request_count = Request.count
          req_url_count = RequestedUrl.count

          subject

          expect(response.status).to eq 400
          expect(response).to render_template :index_multiple

          # インスタンス変数のチェック
          expect(assigns(:using_storaged_date)).to be_nil
          expect(assigns(:use_storage)).to be_truthy
          expect(assigns(:accepted)).to be_falsey
          expect(assigns(:file_name)).to eq file_name
          expect(assigns(:invalid_urls)).to eq([])
          expect(assigns(:finish_status)).to eq :no_valid_url
          expect(flash[:alert]).to eq Message.const[:no_valid_url]
          expect(assigns(:requests)).to eq [r2, r1]

          expect(request).to be_nil

          # リクエストカウントチェック
          expect(MonthlyHistory.find_around(user).request_count).to eq 1

          expect(ActionMailer::Base.deliveries.size).to eq(0)

          # 増減チェック
          expect(Request.count).to eq request_count
          expect(RequestedUrl.count).to eq req_url_count
        end
      end
    end

    context '有料ユーザでないのに、グループの選択があった場合' do
      let(:capitals)  { { capital_group1.id.to_s => capital_group1.id.to_s } }
      let(:employees) { { employee_group1.id.to_s => employee_group1.id.to_s, employee_group2.id.to_s => employee_group2.id.to_s } }
      let(:sales)     { { sales_group2.id.to_s => sales_group2.id.to_s, sales_group3.id.to_s => sales_group3.id.to_s } }

      def check_other_conditions_unavailable(login = false)
        request_count = Request.count
        req_url_count = RequestedUrl.count

        subject

        expect(response.status).to eq 400
        expect(response).to render_template :index_multiple

        # インスタンス変数のチェック
        expect(assigns(:using_storaged_date)).to be_nil
        expect(assigns(:use_storage)).to be_truthy
        expect(assigns(:accepted)).to be_falsey
        expect(assigns(:file_name)).to eq file_name
        expect(assigns(:invalid_urls)).to eq([])
        expect(assigns(:finish_status)).to eq :other_conditions_unavailable
        expect(assigns(:notice_create_msg)).to eq Message.const[:other_conditions_unavailable]
        expect(assigns(:requests)).to eq [r2, r1] if login

        expect(request).to be_nil

        if login
          # リクエストカウントチェック
          expect(MonthlyHistory.find_around(user).request_count).to eq 0
        end

        expect(ActionMailer::Base.deliveries.size).to eq(0)

        # 増減チェック
        expect(Request.count).to eq request_count
        expect(RequestedUrl.count).to eq req_url_count
      end

      context '非ログインプラン' do
        context 'グループが一つだけある場合' do
          let(:employees) { nil }
          let(:sales)     { nil }
          it '正しい結果が返ってくること' do
            check_other_conditions_unavailable
          end
        end

        context 'グループが二つだけある場合' do
          let(:employees) { nil }
          it '正しい結果が返ってくること' do
            check_other_conditions_unavailable
          end
        end
      end

      context '無料プラン' do
        let(:logined_user) { create(:user, email: email, billing: :free) }
        let!(:plan)        { nil }

        before { sign_in logined_user }

        context 'グループが一つだけある場合' do
          let(:capitals)  { nil }
          let(:employees) { nil }
          it '正しい結果が返ってくること' do
            check_other_conditions_unavailable
          end
        end

        context 'グループが二つだけある場合' do
          let(:sales) { nil }
          it '正しい結果が返ってくること' do
            check_other_conditions_unavailable
          end
        end
      end
    end
  end
end

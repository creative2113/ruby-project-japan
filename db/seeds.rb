# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

if User.find_by(email: Rails.application.credentials.user[:admin][:email]).blank?
  administrator = User.create!(email:                Rails.application.credentials.user[:admin][:email],
                               password:             Rails.application.credentials.user[:admin][:password],
                               company_name:         Rails.application.credentials.user[:admin][:company_name],
                               family_name:          '管理者',
                               given_name:           '太郎',
                               department:           '管理部',
                               position:             'ceo',
                               tel:                  '010-0000-0000',
                               language:             Crawler::Country.languages[:japanese],
                               confirmed_at:         Time.zone.now,
                               confirmation_sent_at: Time.zone.now - 30.seconds,
                               role:                 :administrator)

  administrator.create_billing!(status: Billing.statuses[:paid])
end

if User.find_by(email: Rails.application.credentials.user[:public][:email]).blank?
  public_user = User.create!(email:                Rails.application.credentials.user[:public][:email],
                             password:             Rails.application.credentials.user[:public][:password],
                             company_name:         Rails.application.credentials.user[:public][:company_name],
                             family_name:          'パブリックユーザ',
                             given_name:           '太郎',
                             department:           '管理部',
                             position:             'general_employee',
                             tel:                  '010-0000-0000',
                             language:             Crawler::Country.languages[:japanese],
                             confirmed_at:         Time.zone.now,
                             confirmation_sent_at: Time.zone.now - 30.seconds,
                             role:                 :public_user)

  public_user.create_billing!(status: Billing.statuses[:unpaid])
end


if User.find_by(email: Rails.application.credentials.user[:sample1][:email]).blank?
  sample_user = User.create!(email:                Rails.application.credentials.user[:sample1][:email],
                             password:             Rails.application.credentials.user[:sample1][:password],
                             company_name:         Rails.application.credentials.user[:sample1][:company_name],
                             family_name:          'ユーザ',
                             given_name:           '１',
                             department:           '管理部',
                             position:             'general_employee',
                             tel:                  '010-0000-0000',
                             language:             Crawler::Country.languages[:japanese],
                             confirmed_at:         Time.zone.now,
                             confirmation_sent_at: Time.zone.now - 30.seconds)

  sample_user.create_billing!(status: Billing.statuses[:unpaid])
end

if User.find_by(email: Rails.application.credentials.user[:sample2][:email]).blank?
  sample_user2 = User.create!(email:                Rails.application.credentials.user[:sample2][:email],
                              password:             Rails.application.credentials.user[:sample2][:password],
                              company_name:         Rails.application.credentials.user[:sample2][:company_name],
                              family_name:          'ユーザ',
                              given_name:           '２',
                              department:           '管理部',
                              position:             'general_employee',
                              tel:                  '010-0000-0000',
                              language:             Crawler::Country.languages[:japanese],
                              confirmed_at:         Time.zone.now,
                              confirmation_sent_at: Time.zone.now - 30.seconds)

  sample_user2.create_billing!(status: Billing.statuses[:unpaid])
end

if User.find_by(email: Rails.application.credentials.user[:sample3][:email]).blank?
  sample_user3 = User.create!(email:                Rails.application.credentials.user[:sample3][:email],
                              password:             Rails.application.credentials.user[:sample3][:password],
                              company_name:         Rails.application.credentials.user[:sample3][:company_name],
                              family_name:          'ユーザ',
                              given_name:           '３',
                              department:           '管理部',
                              position:             'general_employee',
                              tel:                  '010-0000-0000',
                              language:             Crawler::Country.languages[:japanese],
                              confirmed_at:         Time.zone.now,
                              confirmation_sent_at: Time.zone.now - 30.seconds)

  sample_user3.create_billing!(status: Billing.statuses[:unpaid])
end


if AllowIp.where(name: 'Admin IP', user_id: User.find_by(email: Rails.application.credentials.user[:admin][:email]).id).blank?
  allow_ip = AllowIp.create!(name: 'Admin IP',
                             user_id: User.find_by(email: Rails.application.credentials.user[:admin][:email]).id)

  if Rails.env.development?
     allow_ip.add!('localhost')
     allow_ip.add!('::1')
  end
end

if Coupon.find_by(title: Coupon::TRIAL_REFERRER_TITLE).blank?
  Coupon.create!(title: Coupon::TRIAL_REFERRER_TITLE, description: 'standard トライアル', limit: 1, category: Coupon.categories[:trial_plan])
end

if Referrer.find_by(name: 'オーナー', email: Rails.application.credentials.error_email_address).blank?

  ref = Referrer.create!(name: 'オーナー',
                         email: Rails.application.credentials.error_email_address)

  if Rails.env.development?
    ref.update!(code: 'asdf')
  end
end

# MasterBillingPlan.create!(name: 'β版無料プラン', price: 0, start_at: Time.zone.now - 3.years, enable: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版無料プラン').blank?
MasterBillingPlan.create!(name: 'β版スタンダードプラン', price: 1_000, type: :monthly, start_at: Time.zone.now - 3.years, enable: true, application_start_at: Time.zone.now - 3.years, application_available: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版スタンダードプラン').blank?
MasterBillingPlan.create!(name: 'β版ゴールドプラン', price: 3_000, type: :monthly, start_at: Time.zone.now - 3.years, enable: true, application_start_at: Time.zone.now - 3.years, application_available: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版ゴールドプラン').blank?
MasterBillingPlan.create!(name: 'β版プラチナムプラン', price: 10_000, type: :monthly, start_at: Time.zone.now - 3.years, enable: true, application_start_at: Time.zone.now - 3.years, application_available: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版プラチナムプラン').blank?
# MasterBillingPlan.create!(name: 'β版スタンダード年間契約プラン', price: 12_000, type: :annually, start_at: Time.zone.now - 3.years, enable: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版スタンダードプラン').blank?
# MasterBillingPlan.create!(name: 'β版ゴールド年間契約プラン', price: 36_000, type: :annually, start_at: Time.zone.now - 3.years, enable: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版ゴールドプラン').blank?
# MasterBillingPlan.create!(name: 'β版プラチナム年間契約プラン', price: 120_000, type: :annually, start_at: Time.zone.now - 3.years, enable: true, tax_included: true, tax_rate: 10) if MasterBillingPlan.find_by_name('β版プラチナムプラン').blank?


area = AreaConnector::AREAS

sort_i = 0
area.each_with_index do |(region, prefectures), i2|

  region = Region.find_or_create_by(name: region, sort: i2)
  AreaConnector.find_or_create_by(region: region)

  prefectures.each do |prefecture|
    sort_i += 1
    prefecture = Prefecture.find_or_create_by(name: prefecture, sort: sort_i)
    AreaConnector.find_or_create_by(region: region, prefecture: prefecture)
  end
end

CompanyGroup.seed

AccessRecord.add_supporting_urls('www.starbucks.co.jp', ['http://www.starbucks.co.jp/faq/inquiry.html'])
AccessRecord.add_supporting_urls('www.csmweb.co.jp', ['http://www.csmweb.co.jp/corporate.html'])
AccessRecord.add_supporting_urls('www.oriental-curry.co.jp', ['http://www.oriental-curry.co.jp/company/company_info.html'])
AccessRecord.add_supporting_urls('global.toyota', ['https://global.toyota/jp/company/profile/overview/'])
AccessRecord.add_supporting_urls('www.gotounyu.co.jp', ['http://www.gotounyu.co.jp/k_gaiyou.html'])

SealedPage.add_safe_flag('www.yahoo.co.jp')




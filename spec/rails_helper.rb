# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'factory_bot'
require 'devise'
require 'capybara/rspec'
require 'stab_maker'
require 'test_prof/recipes/rspec/let_it_be'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # to cut namespace in Factory Bot
  config.include FactoryBot::Syntax::Methods

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :feature

  if Bullet.enable?
    config.before(:each) do
      Bullet.start_request
    end

    config.after(:each) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
  end
end

# 時間を扱うのに役に立つ(秒以下を削除できる)
def fix_time(time)
  Time.at(time.to_i)
end

def create_public_user(email = Rails.application.credentials.user[:public][:email])
  User.find_by_email(email).nil? ? create(:user_public) : User.find_by_email(email)
end

def update_public_user(attributes = {})
  user = User.find_by_email(Rails.application.credentials.user[:public][:email])
  if user.nil?
    create(:user_public, attributes)
  else
    user.update!(attributes)
  end
end

def register_card(user)
  card_token = Billing.create_dummy_card_token

  user.billing.create_customer(card_token.id)
  user.billing.save
  card_token
end

def register_subscription(user, plan_name)
  sub_create_res = if user.trial?
    user.billing.create_subscription_with_trial(EasySettings.payjp_plan_id[plan_name], (Time.zone.now + 10.days).end_of_day)
  else
    user.billing.create_subscription(EasySettings.payjp_plan_id[plan_name])
  end
  user.billing.create_new_subscription(EasySettings.plan[plan_name], sub_create_res)
  sub_create_res
end

def make_response(hash)
  DummyResponse.new(hash)
end

class DummyResponse
  attr_reader :status, :customer, :id, :current_period_end

  def initialize(hash)
    @status             = hash[:status] || hash['status']
    @customer           = hash[:customer] || hash['customer']
    @id                 = hash[:id] || hash['id']
    @current_period_end = hash[:current_period_end] || hash['current_period_end']
  end
end

def get_test_env_num
  return '' unless ENV['RAILS_ENV'] == 'test'
  if ENV['TEST_ENV_NUMBER'].nil?
    '1'
  else
    ENV['TEST_ENV_NUMBER'].to_s
  end
end

def prepare_crawler_stub(crawl_force_instance)
  prepare_safe_stub
  allow(Crawler::Corporate).to receive(:new).and_return( crawl_force_instance )
  allow_any_instance_of(Crawler::Corporate).to receive(:start).and_return( nil )
  allow_any_instance_of(Crawler::Corporate).to receive(:release).and_return( nil )
end

def prepare_safe_stub
  allow(SealedPage).to receive(:check_safety).and_return( :probably_safe )
end

def prepare_url_searcher_stub(num)
  res        = []
  domains    = []
  double_cnt = 0

  while res.size - double_cnt < num

    dummy_domain = 'a' + SecureRandom.alphanumeric(rand(2..30))

    unless domains.include?(dummy_domain)
      domains << dummy_domain
      res  << {title: dummy_domain, url: "http://#{dummy_domain}.com"}

      if rand(7) == 0
        double_cnt += 1
        res  << {title: dummy_domain, url: "http://#{dummy_domain}.com"}
      end
    end
  end

  allow_any_instance_of(Crawler::UrlSearcher).to receive(:get_search_result).and_return(res)
end

def check_s3_uploaded(s3_path, exist = true)
  currret_dummy_time = Time.zone.now.dup
  Timecop.return

  expect(S3Handler.new.exist_object?(s3_path: s3_path)).to eq exist

  Timecop.travel currret_dummy_time
  Timecop.freeze
end

def check_invoice_pdf(path, user, time)
  texts = PDF::Reader.new(path).pages.map { |page| page.text }.join("\n\n\n")

  expect(texts).to match(/請求書\n/)
  expect(texts).to match(/#{user.company_name} 御中\n/)
  expect(texts).to match(/請求日 #{time.next_month.beginning_of_month.strftime("%Y/%-m/%-d")}\n/)
  expect(texts).to match(/下記の通りご請求申し上げます。\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:company_name]}\n/)
  expect(texts).to match(/〒#{Rails.application.credentials.invoice_issuer[:post_code]}\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:address]}\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:email]}\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:person_in_charge]}\n/)
  expect(texts).to match(/適格事業者登録番号 #{Rails.application.credentials.invoice_issuer[:qualified_invoice_issuer_number]}\n/)
  expect(texts).to match(/振込先\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:bank_name]}　#{Rails.application.credentials.invoice_issuer[:bank_branch_name]}\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:bank_account_type]} #{Rails.application.credentials.invoice_issuer[:bank_account_number]}\n/)
  expect(texts).to match(/#{Rails.application.credentials.invoice_issuer[:bank_account_name]}\n/)

  expect(texts).to match(/#{time.month}月分 企業リスト収集のプロ使用料/)
  expect(texts).to match(/お支払期限 #{time.next_month.end_of_month.strftime("%Y/%-m/%-d")}\n/)

  sum = 0
  user.billing.histories.by_month(time).each do |his|
    if his.invoice?
      expect(texts).to match(/#{his.billing_date.strftime("%Y/%-m/%-d")}\s*#{his.item_name}/)
      expect(texts).to match(/#{his.item_name}\s+#{his.unit_price.to_s(:delimited)}\s*#{his.number}\s+0\s+#{his.price.to_s(:delimited)}\n/)
      sum += his.price
    else
      expect(texts).not_to match(/#{his.billing_date.strftime("%Y/%-m/%-d")}/)
      expect(texts).not_to match(/#{his.item_name}/)
      expect(texts).not_to match(/#{his.item_name}\s+#{his.unit_price.to_s(:delimited)}\s*#{his.number}\s+0\s+#{his.price.to_s(:delimited)}\n/)
    end
  end
  tax = (sum * 0.1).to_i
  total_amount = sum + tax
  expect(texts).to match(/小計\s+#{sum.to_s(:delimited)}\n/)
  expect(texts).to match(/消費税\s+#{tax.to_s(:delimited)}\n/)
  expect(texts).to match(/\n 合計金額\(税込\)\s+¥ #{total_amount.to_s(:delimited)} -/)
  expect(texts).to match(/備考\n/)
  expect(texts).to match(/お振込手数料は御社にて御社にてご負担いただけますようお願いいたします。/)
end

def download_invoice_pdf_and_check(s3_path, user, time)
  currret_dummy_time = Time.zone.now.dup
  Timecop.return

  Dir.mktmpdir do |dir|
    path = "#{dir}/invoice_#{user.id}_#{Time.zone.now.to_i}.pdf"
    # puts "S3: #{s3_path} => DL: #{path}"

    S3Handler.new.download(s3_path: s3_path, output_path: path)

    check_invoice_pdf(path, user, time)
  end

  Timecop.travel currret_dummy_time
  Timecop.freeze
end

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.5.1'
# Use mysql as the database for Active Record
gem 'mysql2', '>= 0.4.4', '< 0.6.0'
# Use Puma as the app server
gem 'puma', '< 6.0'
# Use SCSS for stylesheets
gem 'sassc-rails'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
group :production, :dev do
  # gem 'mini_racer', '~> 0.6.2', platforms: :ruby
  gem 'execjs'
end

# Use CoffeeScript for .coffee assets and views
# gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
# gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
group :development do
  gem 'capistrano-rbenv'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano3-puma', '~> 5.2' # 公式のリポジトリを確認してバージョンを上げること。自動で最新に上げるのではなく、逐一、公式でバージョンを確認して、バージョン制限をしながら上げていくのが良さそう。
  gem 'capistrano3-nginx', '~> 3.0' # 公式のリポジトリを確認してバージョンを上げること。自動で最新に上げるのではなく、逐一、公式でバージョンを確認して、バージョン制限をしながら上げていくのが良さそう。
  gem 'capistrano-sidekiq'

  gem 'ed25519'
  gem 'bcrypt_pbkdf'
end

# User authorization
gem 'devise'

# Japanese
gem 'rails-i18n'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# JQuery
gem 'jquery-rails'

# 全角数字、漢数字を半角数字に変える
gem 'zen_to_i'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen'
  gem 'spring-commands-rspec'
end

# Adds support for Capybara system testing and selenium driver
gem 'capybara'
gem 'selenium-webdriver'
# Easy installation and use of chromedriver to run system tests with Chrome
gem 'webdrivers'
gem 'launchy'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# HAML
gem 'haml-rails'
gem 'erb2haml'

# LOGGING
gem 'lograge'

# EXCEL
gem 'rubyXL'
# ZIP
gem 'rubyzip'

# pagination
gem 'pagy'

gem 'faker'

# Payment System
gem 'payjp'

# PRY
group :development, :test do
  # 高機能コンソール
  gem 'pry-rails'

  # デバッガ
  gem 'pry-byebug'
  gem 'pry-stack_explorer'

  # pryの入出力に色付け
  gem 'pry-coolline'
  gem 'awesome_print'

  # PryでのSQLの結果を綺麗に表示
  gem 'hirb'
  gem 'hirb-unicode'
end

# Constants Controller
gem 'easy_settings'

# これがあると、EasySettingsが使えなくなる。EasySettingsをconfig_forに置き換えてから、削除。
gem 'psych', '< 4.0.0'

# File Upload
gem 'carrierwave'
gem 'fog-aws'

# Test Gems
group :development, :test, :dev do
  gem 'rspec-rails'
  gem 'rails-controller-testing'
  gem "factory_bot_rails"
  gem 'database_cleaner'

  # テストの並列処理
  gem 'test-queue'

  # N + 1 問題解消
  gem 'bullet'
end

group :test do
  gem 'test-prof' # let_it_be
end

group :test, :dev do
  gem 'timecop'
end

# AWS SDK
gem 'aws-sdk'
gem 'aws-sdk-rails'
gem 'aws-sdk-s3'

# Virus Check
# gem 'clam_chowder' # ruby ~> 2.0 なので、諦める。

# Email Address Check
gem 'validates_email_format_of'

# Sidekiq
gem 'sinatra', require: false
gem 'sidekiq'
gem 'redis-namespace'
gem 'redis-client'

gem 'parallel'

# regular execution
gem 'whenever'

gem 'annotate'

# maintenance page
# https://github.com/biola/turnout
# bundle exec rake maintenance:start reason='ご迷惑をおかけしています。終了時刻は13:00を予定しております。' RAILS_ENV=production
# bundle exec rake maintenance:end RAILS_ENV=production
gem 'turnout'

gem 'meta-tags'

gem 'sitemap_generator'

gem 'google-analytics-rails'

# 警告表示を制御できる
gem 'warning'

gem "administrate"

# 脆弱性チェック
group :development do
  gem 'brakeman', require: false
end

gem 'net-http', require: false

gem 'recaptcha'

# enumで定義した値をI18n化させる
gem 'enum_help'

# PDF作成
gem 'prawn'
gem 'prawn-table'

# PDF読み込み
gem 'pdf-reader'

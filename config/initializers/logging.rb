def log_time(time)
  time.strftime("%Y-%m-%d %H:%M:%S %:z")
end

def make_log_text(level, log_data)
  "[#{log_time(Time.zone.now)}][#{level.upcase}] #{log_data.to_key_value}"
end

def make_error_log_text(level, log_data, err_message)
  text = "[#{log_time(Time.zone.now)}][#{level.upcase}][#{err_message}] #{log_data.to_key_value}"
  text.gsub(':err_msg', '              :err_msg').gsub(':backtrace', '              :backtrace')
end

def make_key(class_method, err_message, backtrace)
  "#{class_method} #{err_message} #{backtrace[0]}"
end

def permitted?(key, class_name = nil)
  return true if Rails.env.test?

  # 必須メール
  return true if class_name.present? && ['PaymentsController'].include?(class_name)

  redis = Redis.new
  res = redis.get(key)

  if res.blank? || res.to_i <= 2
    val = res.blank? ? 1 : res.to_i + 1
    set_err_mail_record_to_redis(key, val)
    return true
  else
    return false
  end
end

def set_err_mail_record_to_redis(key, value = 1)
  redis = Redis.new
  redis.multi do |pipeline|
    pipeline.set(key, value)
    pipeline.expire(key, 60*60)
  end
end

def add_error_log(text)
  File.open("log/error_#{Time.zone.now.strftime("%Y%m%d")}.log", mode = "a") do |f|
    f.write(text + "\n")
  end
end

def exec_error_log(level, class_name, method_name, log_data, err_message, backtrace)

  return if level.downcase != 'fatal' && level.downcase != 'error'

  title = "#{class_name}##{method_name}"
  key   = make_key(title, err_message, backtrace)

  NoticeMailer.deliver_later(NoticeMailer.notice_error(make_log_text(level, log_data), title, level.downcase)) if permitted?(key, class_name)
  add_error_log(make_error_log_text(level, log_data, err_message))
end


class Lograge::Formatters::CustomFormatters < Lograge::Formatters::KeyValue
  def call(data)
    result = super(data)
    "[#{log_time(data[:time])}][#{data[:level].upcase}] #{result}"
  end
end

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.keep_original_rails_log = false
  config.lograge.logger = ActiveSupport::Logger.new("#{Rails.root}/log/lograge_#{Rails.env}.log", 'daily')
  config.lograge.formatter = Lograge::Formatters::CustomFormatters.new

  config.lograge.custom_options = lambda do |event|
    exceptions = %w(controller action format authenticity_token)
    data = {
      level: 'info',
      session_id: event.payload[:session_id],
      uuid: event.payload[:uuid],
      ip: event.payload[:ip],
      user_id: event.payload[:current_user]&.id,
      public: !event.payload[:user_signed_in],
      referer: event.payload[:referer],
      user_agent: event.payload[:user_agent],
      time: Time.zone.now,
      params: event.payload[:params].except(*exceptions)
    }
    if event.payload[:exception]
      data[:level] = 'fatal'
      data[:exception] = event.payload[:exception]
      data[:exception_backtrace] = event.payload[:exception_object].try(:backtrace)
    end
    data
  end
end

def logging(level, request, message = nil)
  user = current_user.nil? ? User.get_public : current_user

  log_data = {
                method: request.method,
                path: request.path,
                format: request.format.to_s,
                controller: self.class.to_s,
                action: request.params[:action],
                status: nil,
                duration: nil,
                view: nil,
                db: nil,
                session_id: request.session[:session_id],
                uuid: request.uuid,
                ip: request.remote_ip,
                user_id: user.id,
                public: !user_signed_in?,
                referer: request.referer,
                user_agent: request.user_agent,
                params: request.params.to_s.force_encoding('UTF-8'),
                message: message
              }

  Lograge.logger.info(make_log_text(level, log_data))

  exec_error_log(level, self.class.to_s, request.params[:action], log_data, message[:err_msg], message[:backtrace])
end

module Lograge
  def self.logging(level, data = {})

    self.logger.info(make_log_text(level, data))

    exec_error_log(level, data[:class], data[:method], data, data[:err_msg], data[:backtrace])
  end

  def self.job_logging(player, level, class_name, method_name, data = {}, message = nil)
    log_data = {
      player: player,
      class: class_name,
      method: method_name
    }
    .merge(data)
    .merge({message: message})

    self.logger.info(make_log_text(level, log_data))

    exec_error_log(level, class_name, method_name, log_data, data[:err_msg], data[:backtrace])
  end
end

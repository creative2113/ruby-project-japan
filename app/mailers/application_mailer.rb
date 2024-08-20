class ApplicationMailer < ActionMailer::Base
  default from: "#{EasySettings.service_name} <notifications@corp-list-pro.com>"
  layout 'mailer'
end

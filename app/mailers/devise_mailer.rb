class DeviseMailer < Devise::Mailer
 
  def confirmation_instructions(record, token, opts={})
    mail = super
    mail.subject = t('devise.mailer.confirmation_instructions.subject', service_name: EasySettings.service_name)
    mail
  end
 
  def reset_password_instructions(record, token, opts={})
    mail = super
    mail.subject = t('devise.mailer.reset_password_instructions.subject', service_name: EasySettings.service_name)
    mail
  end
 
  def unlock_instructions(record, token, opts={})
    mail = super
    mail.subject = t('devise.mailer.unlock_instructions.subject', service_name: EasySettings.service_name)
    mail
  end

  def password_change(record, token, opts={})
    mail = super
    mail.subject = t('devise.mailer.password_change.subject', service_name: EasySettings.service_name)
    mail
  end

  def email_changed(record, token, opts={})
    mail = super
    mail.subject = t('devise.mailer.email_changed.subject', service_name: EasySettings.service_name)
    mail
  end
end
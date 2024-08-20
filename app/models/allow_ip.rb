class AllowIp < ApplicationRecord
  belongs_to :user

  def add!(ip, expiration_h = nil)
    tmp_ips = get_ips

    expiration = expiration_h.present? ? Time.zone.now + expiration_h.to_i.hours : nil

    tmp_ips[ip] = expiration

    self.ips = tmp_ips.to_json
    self.save!
  end

  def get_ips
    tmp_ips = Json2.parse(self.ips, symbolize: false)
    return {} if tmp_ips.blank?

    before_cnt = tmp_ips.size
    tmp_ips.delete_if { |tmp_ip, exp| exp.present? && exp < Time.zone.now }

    if before_cnt > tmp_ips.size
      self.ips = tmp_ips.to_json
      self.save!
    end

    tmp_ips
  end

  def allow?(ip)
    get_ips.keys.include?(ip)
  end
end

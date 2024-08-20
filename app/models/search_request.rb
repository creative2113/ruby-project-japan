class SearchRequest < ApplicationRecord
  include BaseRequest

  belongs_to :user

  scope :current_activate_count, -> (user) { where(user: user, status: EasySettings.status.new..EasySettings.status.working).count }

  def complete?
    self.status == EasySettings.status.completed
  end

  def error?
    self.complete? && !self.success?
  end

  def free_search_option
   { link_words: link_words, target_words: target_words }
  end

  def to_log
    "#{self.class.to_s}:: id:#{id} accept_id:#{accept_id} status:#{status_mean} finish_status:#{finish_status_mean} url:#{url} user:#{user_id}"
  end

  class << self

    def have_same_accept_id?(accept_id)
      self.find_by_accept_id(accept_id).present?
    end
  end
end

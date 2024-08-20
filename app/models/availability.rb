class Availability
  def initialize(user_or_plan_code, function)
    if user_or_plan_code.class == User
      @user   = user_or_plan_code
      @plan   = @user.my_plan_number
    else
      @plan   = EasySettings.plan[user_or_plan_code]
    end
    @rank     = get_rank
    @function = function
  end

  def how?
    case @function
    when :download_made_url_list
      download_made_url_list
    when :free_search
      free_search
    when :first_page_all_get
      first_page_all_get
    when :other_conditions_on_db_search
      other_conditions_on_db_search
    end
  end

  private

  def get_rank
    0
  end

  # 複数リクエストの作成したリストダウンロード
  def download_made_url_list
    if public_user?
      false
    else
      true
    end
    # if paid_user?
    #   true
    # else
    #   false
    # end
  end

  # オリジナルクロール
  def free_search
    false
  end

  def first_page_all_get
    if paid_user?
      true
    else
      false
    end
  end

  def other_conditions_on_db_search
    paid_user?
  end

  private

  def public_user?
    @plan == EasySettings.plan[:public] ? true : false
  end

  def paid_user?
    if @plan == EasySettings.plan[:public] || @plan == EasySettings.plan[:free] || @plan == EasySettings.plan[:testerC]
      false
    else
      true
    end
  end

  class << self
    def available_user(function)
      case function
      when :download_made_url_list
        'ログインユーザ'
        # '課金ユーザ'
      when :free_search
        'なし'
      when :first_page_all_get
        '課金ユーザ'
      end
    end
  end
end

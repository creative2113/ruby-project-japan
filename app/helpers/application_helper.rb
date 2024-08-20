module ApplicationHelper
  def display_date(time)
    time&.strftime("%Y年%-m月%-d日")
  end

  def display_datetime(time)
    time&.strftime("%Y年%-m月%-d日 %H:%M:%S")
  end

  def val(default = '', *keys)
    pal = params.dup

    keys.each { |key| pal = pal[key] }
    pal
  rescue NoMethodError => e
    default
  end

  def display(res)
    res ? 'display: block;' : 'display: none;'
  end

  def disabled(res)
    res ? 'disabled' : ''
  end

  def add_icon(res)
    res ? 'add_circle_outline' : 'remove_circle_outline'
  end

  def get_current_user
    current_user.nil? ? User.get_public : current_user
  end

  def make_submit_button(display_button, action_path, http_method = :get, params = {}, btn_id = '', btn_class = '', data = '')
    inner_html = nil
    display_button.each do |k, v|
      if k == :text
        data = data.empty? ? {} : {confirm: data}
        inner_html = button_tag v, name: "action", id: btn_id, class: btn_class, data: data
      else k == :icon
        btn_class = ['btn', 'waves-effect', 'waves-light'].concat(btn_class.split(' ')).uniq.join(' ')
        data = data.empty? ? '' : "data-confirm=\"#{data}\""
        inner_html = ActiveSupport::SafeBuffer.new("<button class=\"#{btn_class}\" #{data}><i class=\"material-icons\">#{v}</i></button>")
      end
    end

    form_tag(action_path, method: http_method) do
      params.each do |k, v|
        inner_html += hidden_field_tag k.to_sym, v
      end
      inner_html
    end
  end

  def resource_name
   :user
  end

  def resource
     @resource ||= User.new
  end

  def devise_mapping
     @devise_mapping ||= Devise.mappings[:user]
  end

  def default_meta_tags
    {
      site: EasySettings.service_name,
      title: 'もっともシンプルな企業情報収集ツール',
      # description: 'コーポレーサイトから企業情報をとってもお手軽に取得することができるWEBクローラのサービスです。URLを指定すると、その場でそのURLのコーポレイトサイトをクロールし、住所、電話番号などの最新の企業情報を取得してきます。',
      description: '企業リストサイトから企業情報をとってもお手軽に取得することができるWEBクローラのサービスです。リストサイトのURLを指定するだけで、そのURLのリストサイトをクロールし、住所、電話番号などの企業情報を取得し、リストをエクセル化します。',
      keywords: '企業情報,企業情報の取得,スクレイピング,クロール,クローラ,クローリング,WEBクロール,WEBクローラ,WEBクローリング,会社情報,会社情報の取得,資本金,住所,電話番号,crawl,crawler,scraping,コーポレイトサイト',
      reverse: true,
      separator: '|',
      og: defalut_og
      # twitter: default_twitter_card
    }
  end

  def single_hp_search_meta_tags
    {
      site: EasySettings.service_name,
      title: 'もっともシンプルな企業情報収集ツール',
      description: 'コーポレーサイトから企業情報をとってもお手軽に取得することができるWEBクローラのサービスです。URLを指定すると、その場でそのURLのコーポレイトサイトをクロールし、住所、電話番号などの最新の企業情報を取得してきます。',
      keywords: '企業情報,企業情報の取得,スクレイピング,クロール,クローラ,クローリング,WEBクロール,WEBクローラ,WEBクローリング,会社情報,会社情報の取得,資本金,住所,電話番号,crawl,crawler,scraping,コーポレイトサイト',
      reverse: true,
      separator: '|',
      og: defalut_og
      # twitter: default_twitter_card
    }
  end

  private

  def defalut_og
    {
      title: :full_title,
      description: :description,
      url: request.url,
      image: asset_path('main_design.png')
    }
  end

  # def default_twitter_card
  #   {
  #     card: 'summary_large_image', # または summary
  #     site: '@hogehoge'            # twitter ID
  #   }
  # end
end

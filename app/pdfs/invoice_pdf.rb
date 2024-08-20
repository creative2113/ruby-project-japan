class InvoicePdf < Prawn::Document

  class BillingHistoryBlankError < StandardError; end

  def initialize(user_name, billing_histories, month = Time.zone.now)
    raise BillingHistoryBlankError, '渡したbilling_historiesが空です。' if billing_histories.blank?

    super(
      page_size:     'A4',
      top_margin:    35,
      bottom_margin: 35,
      left_margin:   50.14,
      right_margin:  50.14
    )
    # stroke_axis # 座標を表示

    font_families.update('JP' => { 
                                   normal: 'app/assets/fonts/ipaexm.ttf', 
                                   bold: 'app/assets/fonts/ipaexg.ttf' 
                                 })
    font 'JP'

    sum = 0
    billing_items = [['項番', '課金日', '項目名', '単価', '数量', '割引額', '金額']]
    total_amount = billing_histories.each.with_index(1) do |history, i|
      history.price
      billing_items << [i.to_s, history.billing_date.strftime("%Y/%-m/%-d"), history.item_name, history.unit_price.to_s(:delimited), history.number.to_s(:delimited), '0', history.price.to_s(:delimited)]
      sum += history.price
    end

    tax = ( sum * 0.1 ).to_i
    total_amount = sum + tax


    #-------- ↓ここにコードを記述する ----------
    text "請求書", size: 14, align: :center
    move_down 20
    text "#{user_name} 御中", size: 12
    text "請求日  #{month.next_month.beginning_of_month.strftime("%Y/%-m/%-d")}", size: 8, align: :right
    move_down 20
    text "下記の通りご請求申し上げます。", size: 8, align: :center
    move_down 10

    company_name = Rails.application.credentials.invoice_issuer[:company_name]
    post_code = "〒#{Rails.application.credentials.invoice_issuer[:post_code]}"
    address = Rails.application.credentials.invoice_issuer[:address]
    email = Rails.application.credentials.invoice_issuer[:email]
    person_in_charge = Rails.application.credentials.invoice_issuer[:person_in_charge]
    qualified_invoice_issuer_number = "適格事業者登録番号 #{Rails.application.credentials.invoice_issuer[:qualified_invoice_issuer_number]}"

    bank_name = Rails.application.credentials.invoice_issuer[:bank_name]
    bank_branch_name = Rails.application.credentials.invoice_issuer[:bank_branch_name]
    bank_account_type = Rails.application.credentials.invoice_issuer[:bank_account_type]
    bank_account_number = Rails.application.credentials.invoice_issuer[:bank_account_number]
    bank_account_name = Rails.application.credentials.invoice_issuer[:bank_account_name]

    block_items = [
      ['', '', company_name],
      ['', '', "#{post_code}\n#{address}\n#{email}\n#{person_in_charge}\n#{qualified_invoice_issuer_number}"],
      ['', '', '振込先'],
      ["#{month.month}月分 企業リスト収集のプロ使用料", '', "#{bank_name}　#{bank_branch_name}\n#{bank_account_type} #{bank_account_number}\n#{bank_account_name}"],
    ]
    table block_items, column_widths: [257, 20, 217] do
      columns(0..2).borders = []
      columns(0).size = 10
      columns(0).valign = :bottom
      columns(2).size = 8
      columns(1).font_style = :bold
      columns(1).align = :right

      columns(2).row(0).valign = :bottom
      columns(2).row(2).valign = :bottom
    end

    # text "5月分 企業リスト収集のプロ使用料", size: 10
    move_down 15
    total_amount_table = [["合計金額(税込)", "¥ #{total_amount.to_s(:delimited)} -", '', 'お支払期限', month.next_month.end_of_month.strftime("%Y/%-m/%-d")]]
    table total_amount_table, cell_style: { height: 30 }, column_widths: [100, 150, 100] do
      columns(0..1).borders = [:bottom]
      columns(0..1).border_bottom_width = 2
      columns(0..1).background_color = 'f0f0f0'
      columns(0..1).size = 12
      columns(0..1).valign = :center
      columns(1).font_style = :bold
      columns(1).align = :right

      columns(2).borders = []
      columns(3..4).borders = [:bottom]
      columns(2..4).valign = :bottom
      columns(2..4).size = 10
    end
    move_down 20

    billing_items_footer = [
      ['', '', '', '', '', '小計', sum.to_s(:delimited)],
      ['', '', '', '', '', '消費税', tax.to_s(:delimited)],
      ['', '', '', '', '', '合計', total_amount.to_s(:delimited)],
    ]

    billing_items.concat(billing_items_footer)

    table billing_items, cell_style: {height: 18, width: 495, valign: :center, size: 6, border_width: 0.6},
    # column_widths: [25, 53, 222, 50, 25, 50, 70] do # RSPECテストのPDFのテキスト化で項目が潰れてしまい、自動テストできない。
    column_widths: [25, 72, 193, 50, 35, 50, 70] do # <- 見た目は悪いが、セルの幅を広げる
      columns(0..6).borders = []
      columns(-2..-1).row(-3..-1).borders = [:top, :bottom, :left, :right]
      row(0..-4).borders = [:top, :bottom, :left, :right]

      columns(0..6).row(0).align = :center
      columns(0).align = :center
      columns(3..6).align = :right
      row(0).align = :center
      row(0).background_color = 'f0f0f0'
      row(0).size = 8

      columns(-2).row(-3..-1).size = 8
      columns(-2).row(-3..-1).align = :center
      columns(-2).row(-3..-1).background_color = 'f0f0f0'

    end
    move_down 20

    remarks_items = [['備考'],['お振込手数料は御社にて御社にてご負担いただけますようお願いいたします。']]
    table remarks_items, cell_style: {width: 495, size: 6, border_width: 0.6},
    column_widths: [495] do
      columns(0).row(0).borders = []
      columns(0).row(1).borders = [:top, :bottom, :left, :right]
      columns(0).row(1).borders = [:top, :bottom, :left, :right]

      row(0).size = 8
      row(1).size = 6
      row(0).height = 20
      row(1).height = 70
    end
  end
end

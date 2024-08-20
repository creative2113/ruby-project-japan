window.onload = function(){
  $(function() {

    $('.payment_histories_by_month').on("ajax:beforeSend", (evt) => {
      var month_str = evt.detail[1]['url'].split('/')[2];

      // ストックにデータがある場合、通信しない
      if ( $(`#billing_data_stock #stock_data_${month_str}`).length) {
        var invoice = $(`#billing_data_stock #stock_data_${month_str}`).data('invoice');
        var year_month = $(`#billing_data_stock #stock_data_${month_str}`).data('year-month');
        var end_of_month = $(`#billing_data_stock #stock_data_${month_str}`).data('end-of-month');
        var title_html   = $(`#billing_data_stock #stock_data_${month_str}`).data('title');
        var billing_html = $(`#billing_data_stock #stock_data_${month_str}`).data('billing');
        toggle_invoice_button(invoice, year_month, end_of_month);

        $('#billing_data .card-title-band').text(title_html);
        $('#billing_data_table').html(billing_html);
        return false;
      }
    }).on("ajax:success", (evt) => {
      var data = evt.detail[0];

      $('#billing_data .card-title-band').text(data['title']);

      toggle_invoice_button(data['invoice'], data['year_month'], null, data['invoice_file_exist']);

      var html  = '<tr><th class="date">課金日</th><th>項目名</th><th>支払方法</th><th class="price_cel">単価</th><th class="number_cel">個数</th><th class="price_cel">金額</th></tr>';
      data['data'].forEach(function(history_data) {
        html += '<tr>'
        html +=   `<td>${history_data['billing_date']}</td>`
        html +=   `<td>${history_data['item_name']}</td>`
        html +=   `<td class="payment_method_cel">${history_data['payment_method']}</td>`
        html +=   `<td class="price_cel">${history_data['unit_price']}</td>`
        html +=   `<td class="number_cel">${history_data['number']}</td>`
        html +=   `<td class="price_cel">${history_data['price']}</td>`
        html += '</tr>'
      });
      $('#billing_data_table').html(html);

      // ストックデータに保存
      $('#billing_data_stock').append(`<span id='stock_data_${data['year_month']}' data-invoice='${data['invoice']}' data-year-month='${data['year_month']}' data-end-of-month='${data['end_of_month']}' data-title='${data['title']}' data-billing='${html}'></span>`)
    }).on("ajax:error", (evt) => {
      var data = evt.detail[0];
      var html = `<div>${data['error']}</div>`;
      $('#billing_data_table').html(html);
    });
  });
}

function toggle_invoice_button(invoice, year_month, end_of_month = null, invoice_file_exist = null) {
  if ( !invoice ) {
    $('#invoice_download').hide();
  } else if ( invoice_file_exist != null && invoice_file_exist ) {
    $('#invoice_download').show();
  } else if ( end_of_month != null && new Date(end_of_month) < new Date() ) {
    $('#invoice_download').show();
  } else {
    $('#invoice_download').hide();
  }
  $('#invoice_download').attr('href',`/payment_histories/${year_month}/download.pdf`);
}

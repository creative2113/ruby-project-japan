
$(document).ready(function(){

  var init = $('#swich_type').data('init');
  if ( init == 4 ) {
    $('#switch_file_type').removeClass('active');
    $('#switch_db_search_type').addClass('active');

    selectDbSearchType();
    getAllAreaCategories();
  }

  $('.tabs').tabs();

  var pagy_elements = $('nav.pagination > span.page > a');

  for (var i = 0; i < pagy_elements.length; i++) {
    var href = pagy_elements[i].href;
    pagy_elements[i].href = href + '#requests';
  }

});

window.onload = function(){
  $(function() {

    // 簡易調査のフォームのレスポンスを受け取り
    let form = document.getElementById('simple_investigation_form');
    if ( form ) {
      form.addEventListener('ajax:before', (evt) => {
        $('#simple_investigation_submit').prop('disabled', true);
      });
      form.addEventListener('ajax:success', (evt) => {
        $('#simple_investigation_submit').prop('disabled', true);
        var data = evt.detail[0];

        var html  = '<div class="card-panel notice light-green lighten-5">';
        html     +=   '簡易調査と簡易設定の依頼を受け付けました。<br><br>';
        html     +=   '調査の結果はご登録のメールアドレスにご連絡致します。３営業日経っても連絡がない場合は、お手数ですがお問合せください。<br>';
        html     +=   'また、弊社から調査依頼の内容に関して、質問をさせて頂くことがございます。その場合もご登録のメールアドレスにご連絡致します。<br>';
        html     +=   '調査した結果、取得できないという結果になることもございますので、ご了承くださいませ。<br>';
        html     += '</div>';

        $('#simple_investigation_response').html('');
        $('#simple_investigation_response').append(html);

      });
      form.addEventListener('ajax:error', (evt) => {
        if(evt.detail[2].status != 200) {
          $('#simple_investigation_submit').prop('disabled', true);
          var data = evt.detail[0];
          var html  = '<div class="card-panel alert_card">';
          html     +=   `${data['error']}<br>`;
          html     += '</div>';

          $('#simple_investigation_response').html('');
          $('#simple_investigation_response').append(html);
        }
      });
    }

    $('#request').click(function (){

      var form = $(this).parents('form');

      if ( $('#request_mail_address').data('signed-in') === 0 && $('#request_mail_address').val() === '' ) {
        $('#validate_msg').text('メールアドレスを入力してください。');
        alert('メールアドレスを入力してください。');
        return false;
      }

      if($('#list_upload_form').hasClass('selected')) {
        if(!selectedFile()){
          $('#upload_validate_msg').text('アップロードファイルを選択して下さい。');
          return false;
        }

        if(overFileSize()){
          return false;
        }

        $('<input>', {type: 'hidden', name: 'request_type', value: 'file'}).appendTo('#upload_form');

      } else if($('#request_form_making_url_list').hasClass('selected')) {
        if ( !ExistUrlList() ) { return false; }

        $('<input>', {type: 'hidden', name: 'header', value: '1'}).appendTo('#upload_form');
        $('<input>', {type: 'hidden', name: 'col_select', value: '1'}).appendTo('#upload_form');
        $('<input>', {type: 'hidden', name: 'file_name', value: getUrlListFileName('csv')}).appendTo('#upload_form');
        $('<input>', {type: 'hidden', name: 'csv_str', value: makeUrlListCsv()}).appendTo('#upload_form');
        $('<input>', {type: 'hidden', name: 'request_type', value: 'csv_string'}).appendTo('#upload_form');

      } else if($('#request_form_word_search').hasClass('selected')) {
        if ( !ExistSearchWord() ) { return false; }

        $('<input>', {type: 'hidden', name: 'request_type', value: 'word_search'}).appendTo('#upload_form');

      } else if($('#request_form_company_db_search').hasClass('selected')) {
        if ( !CheckedAnyCheckbox() ) { return false; }

        $('<input>', {type: 'hidden', name: 'request_type', value: 'company_db_search'}).appendTo('#upload_form');

      } else {
        return false;
      }

      $('#request').prop('disabled', true);
      startLoading();
      form.submit();
    });

    $('#request_test').click(function (){
      var form = $(this).parents('form');

      if ( !ExistCorporateListSiteUrl() ||
           !validRequestedUrlCorporateListConfig() ||
           !validRequestedUrlCorporateIndividualConfig()
         ) { return false; }

      $('<input>', {type: 'hidden', name: 'execution_type', value: 'test'}).appendTo('#request_form');

      $('#request_test').prop('disabled', true);
      startLoading();
      form.submit();
    });

    $('#request_main').click(function (){
      var form = $(this).parents('form');

      if ( !ExistCorporateListSiteUrl() ||
           !validRequestedUrlCorporateListConfig() ||
           !validRequestedUrlCorporateIndividualConfig()
         ) { return false; }

      $('<input>', {type: 'hidden', name: 'execution_type', value: 'main'}).appendTo('#request_form');

      $('#request_main').prop('disabled', true);
      startLoading();
      form.submit();
    });

    $('#file_upload').change(function (){

      $('#request').prop('disabled', false);
      $('#upload_validate_msg').text('');

      var file = $('#file_upload')[0].files[0];

      if(!selectedFile()) {
        $('#excel_display').hide();
        $('#sheet_select_area').html('');
        $('#col_select_area').html('');
        $('#request').prop('disabled', false);

      } else if(invalidExtension()){

        $('#request').prop('disabled', true);
        $('#upload_validate_msg').text('xlsxファイルかcsvファイルをアップロードしてください。');

      } else if(overFileSize()) {

        $('#request').prop('disabled', true);

      } else {

        if ( getExtension() == 'csv' ) {
          csvRead();
        } else if ( getExtension() == 'xlsx' ) {
          xlsxRead();
        }
      }
    });

    $('#request_using_storage_days').blur(function (){
      checkStorageDays();
    });

    $('input[name="request[free_search]"]:checkbox').change(function(){
      checkFreeSearch();
    });

    $('#sheet_select').on('change', '#sheet_selectbox', function (e){

      xlsxRead(e.target.value);

    });

    $('input[name="request[use_storage]"]:checkbox').change(function(){
      checkUsingStorage();
    });

    $('#all_invalid_urls_display').click(function (){
      displayAllInvalidUrls();
    });

    $('#all_invalid_urls_downlad').click(function (){
      downloadInvalidUrlsExcel();
    });

    var KeyUpStack = [];

    $('#keyword').keyup(function (){
      KeyUpStack.push(1);

      setTimeout(function() {
        KeyUpStack.pop();
        if(KeyUpStack.length == 0) {
          $("#finding_candidate_urls").show();
          getCandidateUrls();
        }
      },1000)

    });

    $('#candidate_urls').on('click', '.candidate_url', function (){
      var url   = $(this).find('.url').text();
      var title = $(this).find('.title').text();
      var html  = '<tr class="additional_url">';
      html     +=   '<td>';
      html     +=     '<button class="remove_url btn waves-effect waves-light"><i class="material-icons">delete</i></button>';
      html     +=   '</td>';
      html     +=   `<td>${url}</td>`;
      html     +=   `<td>${title}</td>`;
      html     += '</tr>';

      $('#list_table_part').append(html);
      calcurateMakableCount();
    });

    $('#list_table_part').on('click', '.remove_url', function (){
      $(this).parent().parent().remove();
      calcurateMakableCount();
    });

    $('#made_url_list_downlad').click(function (){
      downloadUrlListExcel();
    });

    $('#result_downlad').click(function (){
      $('#result_downlad').addClass('disabled');
    });

    $('.result_downlad').click(function (){
      startLoading();
      $(this).addClass('disabled');
    });

    $('#switch_file_type').click(function (){
      selectFileType();
    });

    $('#switch_make_list_type').click(function (){
      selectMakeListType();
    });

    $('#switch_word_search_type').click(function (){
      selectWordSearchType();
    });

    $('#switch_db_search_type').click(function (){
      selectDbSearchType();

      if ( $('#search_conditions_result').attr('data') != 1 ) {
        getAllAreaCategories();
      }
    });

    $('#add_unget_page_url').click(function (){
      var next_num = Number($('#field_unget_page_url_row .input-field:last').attr('data_num')) + 1;

      var html  =   `<div class="input-field col s6 shrink_margin_bottom" data_num="${next_num}">`;
      html     +=     `<input type="text" name="request[unget_page_url][${next_num}]" id="request_unget_page_url_${next_num}">`;
      html     +=     `<label for="request_unget_page_url_${next_num}">取得(クロール)しないページのURL</label>`;
      html     +=   `</div>`;
      $('#field_unget_page_url_row').append(html);
    });

    $('#delete_unget_page_url').click(function (){
      if ( Number($('#field_unget_page_url_row .input-field:last').attr('data_num')) == 1 ) { return false; }
      $('#field_unget_page_url_row .input-field:last').remove();
    });

    $('#add_deteil_configuration').click(function (){
      $('#detail_configuration').slideToggle();
      if ( $('#detail_off').val() == '0' ){
        $('#detail_configuration_off').show();
        $('#add_deteil_configuration i').text('add_circle');
        $('#detail_off').val('1');
      } else {
        $('#detail_configuration_off').hide();
        $('#add_deteil_configuration i').text('remove_circle');
        $('#detail_off').val('0');
      }
    });

    // 企業一覧ページの設定

    $('#toggle_corporate_list_config').click(function (){
      $('#corporate_list_config').slideToggle();
      if ( $('#request_corporate_list_config_off').val() == '0' ){
        $('#corporate_list_config_off').show();
        $('#request_corporate_list_config_off').val('1');
        $('#toggle_corporate_list_config i').text('add_circle_outline');
      } else {
        $('#corporate_list_config_off').hide();
        $('#toggle_corporate_list_config i').text('remove_circle_outline');
        $('#request_corporate_list_config_off').val('0');
      }
    });

    $(document).on('click', '.toggle_corporate_list_url_details' , function() {
      var target = $(this).parent().nextAll(".corporate_list_url_details_config:first");
      var off_target = $(this).nextAll(".corporate_list_url_details_off");
      var url_num = $(this).parent().parent().attr('url_num');
      $(target).slideToggle();
      if ( $(`#request_corporate_list_${url_num}_details_off`).val() == '0' ){
        $(this).children('div').children('span').text('詳細設定を開く');
        $(off_target).show();
        $(`#request_corporate_list_${url_num}_details_off`).val('1');
        $(this).children('div').children('i').text('add_circle_outline');
      } else {
        $(this).children('div').children('span').text('詳細設定を閉じる');
        $(off_target).hide();
        $(this).children('div').children('i').text('remove_circle_outline');
        $(`#request_corporate_list_${url_num}_details_off`).val('0');
      }
    });

    $(document).on('click', '.add_corporate_list_url_contents_config' , function() {
      var target = $(this).parent().prev('.field_corporate_list_url_contents_configs').children('.field_corporate_list_url_contents_config:last');
      var next_num = Number($(target).attr('data_num')) + 1;
      var url_num  = Number($(target).attr('url_num'));
      if ( next_num >= 20 ) { $(this).addClass('disabled'); }
      if ( next_num >= 21 ) { return false; }

      var html = HTML_field_corporate_list_url_contents_config(next_num, url_num);

      $(target).parent().append(html);
      $(this).nextAll('.remove_corporate_list_url_contents_config').removeClass('disabled');
    });

    $(document).on('click', '.remove_corporate_list_url_contents_config' , function() {
      var target = $(this).parent().prev('.field_corporate_list_url_contents_configs').children('.field_corporate_list_url_contents_config:last');
      if ( Number($(target).attr('data_num')) == 1 ) { return false; }
      if ( Number($(target).attr('data_num')) == 2 ) { $(this).addClass('disabled'); }
      $(target).remove();
      $(this).prevAll('.add_corporate_list_url_contents_config').removeClass('disabled');
    });

    $('#add_corporate_list_url_config').click(function (){
      var url_num = Number($('#corporate_list_config .field_corporate_list_config:last').attr('url_num')) + 1;
      if ( url_num >= 5 ) { $(this).addClass('disabled'); }
      if ( url_num >= 6 ) { return false; }

      var html  = HTML_field_corporate_list_config(url_num);

      $('#corporate_list_config .field_corporate_list_config:last').after(html);
      $('#remove_corporate_list_url_config').removeClass('disabled');
    });

    $('#remove_corporate_list_url_config').click(function (){
      if ( Number($('#corporate_list_config .field_corporate_list_config:last').attr('url_num')) == 1 ) { return false; }
      if ( Number($('#corporate_list_config .field_corporate_list_config:last').attr('url_num')) == 2 ) { $(this).addClass('disabled'); }
      $('#corporate_list_config .field_corporate_list_config:last').remove();
      $('#add_corporate_list_url_config').removeClass('disabled');
    });


    // 企業個別ページの設定

    $('#toggle_corporate_individual_config').click(function (){
      $('#corporate_individual_config').slideToggle();
      if ( $('#request_corporate_individual_config_off').val() == '0' ){
        $('#corporate_individual_config_off').show();
        $('#request_corporate_individual_config_off').val('1');
        $('#toggle_corporate_individual_config i').text('add_circle_outline');
      } else {
        $('#corporate_individual_config_off').hide();
        $('#toggle_corporate_individual_config i').text('remove_circle_outline');
        $('#request_corporate_individual_config_off').val('0');
      }
    });

    $(document).on('click', '.toggle_corporate_individual_url_details' , function() {
      var target = $(this).parent().nextAll(".corporate_individual_url_details_config:first");
      var off_target = $(this).nextAll(".corporate_individual_url_details_off");
      var url_num = $(this).parent().parent().attr('url_num');
      $(target).slideToggle();
      if ( $(`#request_corporate_individual_${url_num}_details_off`).val() == '0' ){
        $(this).children('div').children('span').text('詳細設定を開く');
        $(off_target).show();
        $(`#request_corporate_individual_${url_num}_details_off`).val('1');
        $(this).children('div').children('i').text('add_circle_outline');
      } else {
        $(this).children('div').children('span').text('詳細設定を閉じる');
        $(off_target).hide();
        $(this).children('div').children('i').text('remove_circle_outline');
        $(`#request_corporate_individual_${url_num}_details_off`).val('0');
      }
    });

    $(document).on('click', '.add_corporate_individual_url_contents_config' , function() {
      var target = $(this).parent().prev('.field_corporate_individual_url_contents_configs').children('.field_corporate_individual_url_contents_config:last');
      var next_num = Number($(target).attr('data_num')) + 1;
      var url_num  = Number($(target).attr('url_num'));
      if ( next_num >= 20 ) { $(this).addClass('disabled'); }
      if ( next_num >= 21 ) { return false; }

      var html = HTML_field_corporate_individual_url_contents_config(next_num, url_num);

      $(target).parent().append(html);
      $(this).nextAll('.remove_corporate_individual_url_contents_config').removeClass('disabled');
    });

    $(document).on('click', '.remove_corporate_individual_url_contents_config' , function() {
      var target = $(this).parent().prev('.field_corporate_individual_url_contents_configs').children('.field_corporate_individual_url_contents_config:last');
      if ( Number($(target).attr('data_num')) == 1 ) { return false; }
      if ( Number($(target).attr('data_num')) == 2 ) { $(this).addClass('disabled'); }
      $(target).remove();
      $(this).prevAll('.add_corporate_individual_url_contents_config').removeClass('disabled');
    });

    $('#add_corporate_individual_url_config').click(function (){
      var url_num = Number($('#corporate_individual_config .field_corporate_individual_config:last').attr('url_num')) + 1;
      if ( url_num >= 5 ) { $(this).addClass('disabled'); }
      if ( url_num >= 6 ) { return false; }

      var html  = HTML_field_corporate_individual_config(url_num);

      $('#corporate_individual_config .field_corporate_individual_config:last').after(html);
      $('#remove_corporate_individual_url_config').removeClass('disabled');
    });

    $('#remove_corporate_individual_url_config').click(function (){
      if ( Number($('#corporate_individual_config .field_corporate_individual_config:last').attr('url_num')) == 1 ) { return false; }
      if ( Number($('#corporate_individual_config .field_corporate_individual_config:last').attr('url_num')) == 2 ) { $(this).addClass('disabled'); }
      $('#corporate_individual_config .field_corporate_individual_config:last').remove();
      $('#add_corporate_individual_url_config').removeClass('disabled');
    });


    $('.expand_toggle_switch').click(function (){
      $(this).next('.expand_toggle_area').slideToggle();
      if ( $(this).find('i.expand_toggle_icon').text() === 'expand_more' ){
        $(this).find('i.expand_toggle_icon').text('expand_less');
        $(this).addClass('focus');
      } else {
        $(this).find('i.expand_toggle_icon').text('expand_more');
        $(this).removeClass('focus');
      }
    });

    $('.exec_sample').click(function (){
      var title = $(this).parent().find('a').eq(1).text();
      $('#request_title').val(title);

      var url = $(this).attr('data');
      $('#request_corporate_list_site_start_url').val(url);
      $('<input>', {type: 'hidden', name: 'execution_type', value: 'main'}).appendTo('#request_form');

      $('#request_main').prop('disabled', true);
      startLoading();
      var form = $(this).parents('form');
      form.submit();
    });

    $(document).on('click', '.smaller_dividions_toggle' , function() {
      $(this).parent().parent().children('.smaller_dividions').slideToggle();
      if ( $(this).children('i').text() == 'add_circle' ){
        $(this).children('i').text('remove_circle');
      } else {
        $(this).children('i').text('add_circle');
      }
    });

    $(document).on('click', '.area_checkbox' , function() {
      addConnectorId(this, '#selected_area_connector_ids');
      getCompaniesCount();
    });

    $(document).on('click', '.category_checkbox' , function() {
      addConnectorId(this, '#selected_category_connector_ids');
      getCompaniesCount();
    });

    $(document).on('click', '.capital_checkbox' , function() {
      addConnectorId(this, '#selected_capital_ids');
      getCompaniesCount();
    });

    $(document).on('click', '.employee_checkbox' , function() {
      addConnectorId(this, '#selected_employee_ids');
      getCompaniesCount();
    });

    $(document).on('click', '.sales_checkbox' , function() {
      addConnectorId(this, '#selected_sales_ids');
      getCompaniesCount();
    });

    $(document).on('click', '#request_not_own_capitals' , function() {
      getCompaniesCount();
    });

    $('#to_db_search').click(function (){
      $('#switch_file_type').removeClass('active');
      $('#switch_db_search_type').addClass('active');
      $('.tabs').tabs();

      selectDbSearchType();
      getAllAreaCategories();
      return false;
    });

    $('#resize_table').click(function (){
      resizeTestResultTable();
    });

    // 画面をスクロールをしたら動かしたい場合の記述
    $(window).scroll(function () {
      FixedAnime();/* スクロール途中からヘッダーを出現させる関数を呼ぶ*/
    });

    // ページが読み込まれたらすぐに動かしたい場合の記述
    $(window).on('load', function () {
      FixedAnime();/* スクロール途中からヘッダーを出現させる関数を呼ぶ*/
    });

  });
}

//スクロールすると上部に固定させるための設定を関数でまとめる
function FixedAnime() {

  if ( !$('#companies_count_position').length ) { return; }

  var companies_count_offset = $('#companies_count_position').offset()['top'];
  var bottom_limit_offset = 99999999;
  if ( document.getElementById('requests') != null ) {
    bottom_limit_offset = $('#requests').offset()['top'];
  } else if ( document.getElementById('confirm_request_form') != null ) {
    bottom_limit_offset = $('#confirm_request_form').offset()['top'];
  }
  var scroll = $(window).scrollTop();

  if ( scroll >= companies_count_offset && scroll <= bottom_limit_offset ) { //headerの高さ以上になったら
    $('#companies_count').addClass('fixed');
    $('#companies_count_position').addClass('fixed'); // ヘッダーを固定しても、要素の高さを変更させないために、消えた分を確保する
  } else {
    $('#companies_count').removeClass('fixed');
    $('#companies_count_position').removeClass('fixed'); // ヘッダーを固定しても、要素の高さを変更させないために、消えた分を確保する
  }
}


function getAllAreaCategories() {

  $.ajax({type: 'GET',
      url:  '/areas_categories',
      dataType: 'json'}

    )
    .done( function(res){
      if (res.status != 200 ){
        var message = `<div id="error_message">${res.message}<div>`;
        $('#areas_categories_field').html(message);
        return;
      }

      var resCheckboxesDom = '<div id="search_conditions_result" data="1">';
      resCheckboxesDom += '<div id="companies_count_position"></div>'; // スクロール固定の基準を確保するため
      resCheckboxesDom += `<h5 id="companies_count" class="center">現在の企業数 : ${res.categories_count}</h5>`;

      resCheckboxesDom += '<div id="area_list">';
      resCheckboxesDom += '<h5>地域選択</h5>';
      resCheckboxesDom += '<span id="selected_area_connector_ids" style="display: none;"></span>';
      var totalSize = res.areas.length;
      var firstSize = Math.floor( res.areas.length / 4 );
      var secondSize = Math.floor( res.areas.length * 2 / 4 );
      var thirdSize = Math.floor( res.areas.length * 3 / 4 );

      resCheckboxesDom += '<div class="row">';
      resCheckboxesDom += '<div class="col s3">';
      for ( var i = 0; i < firstSize; i++ ) {
        resCheckboxesDom += areas_checkboxies_dom(res.areas[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '<div class="col s3">';
      for ( var i = firstSize; i < secondSize; i++ ) {
        resCheckboxesDom += areas_checkboxies_dom(res.areas[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '<div class="col s3">';
      for ( var i = secondSize; i < thirdSize; i++ ) {
        resCheckboxesDom += areas_checkboxies_dom(res.areas[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '<div class="col s3">';
      for ( var i = thirdSize; i < totalSize; i++ ) {
        resCheckboxesDom += areas_checkboxies_dom(res.areas[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';

      resCheckboxesDom += '<div id="category_list">';
      resCheckboxesDom += `<h5>業種選択</h5>`;
      resCheckboxesDom += `<div class="col s12 mb-1">※ 複数の情報ソースを元に業種インデックスを作成してます。綺麗に業種整理ができてない点があることをご了承ください。</div>`;
      resCheckboxesDom += '<span id="selected_category_connector_ids" style="display: none;"></span>';
      totalSize = res.categories.length;
      firstSize = Math.floor( res.categories.length / 3 );
      secondSize = Math.floor( res.categories.length * 2 / 3 );

      resCheckboxesDom += '<div class="row">';
      resCheckboxesDom += '<div class="col s4">';
      for ( var i = 0; i < firstSize; i++ ) {
        resCheckboxesDom += categories_checkboxies_dom(res.categories[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '<div class="col s4">';
      for ( var i = firstSize; i < secondSize; i++ ) {
        resCheckboxesDom += categories_checkboxies_dom(res.categories[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '<div class="col s4">';
      for ( var i = secondSize; i < totalSize; i++ ) {
        resCheckboxesDom += categories_checkboxies_dom(res.categories[i]);
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';

      var enabled = $('#plan_user_flag').data('plan-user') === 1;

      resCheckboxesDom += '<div id="other_conditions">';
      resCheckboxesDom += `<h5>その他の条件</h5>`;
      if ( !enabled ) {
        resCheckboxesDom += '<div class="ml-2 alert-msg">以下の条件指定は有料プランの方がご利用できます。</div>'
      }
      resCheckboxesDom += '<div class="row">';
      resCheckboxesDom += '<div id="capital_list" class="col s4">';
      resCheckboxesDom += `<h6 class='${ enabled ? '' : 'disabled-text' }'>資本金選択</h6>`;
      resCheckboxesDom += '<span id="selected_capital_ids" style="display: none;"></span>';
      resCheckboxesDom += '<div class="ml-2">';
      for ( var i = 0; i < res.capital_ranges.length; i++ ) {
        resCheckboxesDom += ranges_checkboxies_dom('capital', res.capital_ranges[i])
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';

      resCheckboxesDom += '<div id="employee_list" class="col s4">';
      resCheckboxesDom += `<h6 class='${ enabled ? '' : 'disabled-text' }'>従業員選択</h6>`;
      resCheckboxesDom += '<span id="selected_employee_ids" style="display: none;"></span>';
      resCheckboxesDom += '<div class="ml-2">';
      for ( var i = 0; i < res.employee_ranges.length; i++ ) {
        resCheckboxesDom += ranges_checkboxies_dom('employee', res.employee_ranges[i])
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';

      resCheckboxesDom += '<div id="sales_list" class="col s4">';
      resCheckboxesDom += `<h6 class='${ enabled ? '' : 'disabled-text' }'>売上選択</h6>`;
      resCheckboxesDom += '<span id="selected_sales_ids" style="display: none;"></span>';
      resCheckboxesDom += '<div class="ml-2">';
      for ( var i = 0; i < res.sales_ranges.length; i++ ) {
        resCheckboxesDom += ranges_checkboxies_dom('sales', res.sales_ranges[i])
      }
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';
      resCheckboxesDom += '</div>';

      $('#areas_categories_field').html(resCheckboxesDom);
    })
    .fail( function(res){
      console.log('企業DBから値を取得できませんでした。');
      var message = `<div id="error_message">エラー発生。企業DBから値を取得できませんでした。<div>`;
      $('#areas_categories_field').html(message);
    });
}

function areas_checkboxies_dom(regionValue) {

  resCategories = ''
  resCategories += `<div>`;
  resCategories += `<div class="icon-with-text mt-3">`;
  resCategories += `<label>`;
  resCategories += `<input type="checkbox" class="area_checkbox" value="${regionValue.connector_id}" name="areas[${regionValue.connector_id}]" data="${regionValue.connector_id}">`;
  resCategories += `<span>${regionValue.name}</span>`;
  resCategories += `</label>`;
  if ( regionValue.prefecture.length != 0 ) { resCategories +=`<a class="ml-2 smaller_dividions_toggle icon-with-text cursor-pointer"><i class="material-icons smaller">remove_circle</i></a>`; }
  resCategories += `</div>`;

  resCategories += `<div class="smaller_dividions prefecture_collection ml-6">`;
  regionValue.prefecture.forEach(function( prefectureValue ) {

    if ( prefectureValue.prefecture_id == null ) { return; }

    resCategories += `<div>`;
    resCategories += `<div class="prefecture icon-with-text mt-2">`;
    resCategories += `<label>`;
    resCategories += `<input type="checkbox" class="area_checkbox" value="${prefectureValue.connector_id}" name="areas[${prefectureValue.connector_id}]" data="${prefectureValue.connector_id}">`;
    resCategories += `<span>${prefectureValue.name}</span>`;
    resCategories += `</label>`;
    if ( prefectureValue.city.length != 0 ) { resCategories += `<a class="ml-2 smaller_dividions_toggle icon-with-text cursor-pointer"><i class="material-icons smaller">add_circle</i></a>`; }
    resCategories += `</div>`;

    resCategories += `<div class="smaller_dividions small_collection ml-6" style="display: none;">`;
    prefectureValue.city.forEach(function( cityValue ) {

      if ( cityValue.city_id == null ) { return; }

      resCategories += `<div class="city mt-1">`;
      resCategories += `<label>`;
      resCategories += `<input type="checkbox" class="area_checkbox" value="${cityValue.connector_id}" name="areas[${cityValue.connector_id}]" data="${cityValue.connector_id}">`;
      resCategories += `<span>${cityValue.name}</span>`;
      resCategories += `</label>`;
      resCategories += `</div>`;

    });
    resCategories += `</div>`;
    resCategories += `</div>`;
  });
  resCategories += `</div>`;
  resCategories += `</div>`;

  return resCategories;
}

function categories_checkboxies_dom(largeValue) {

  resCategories = ''
  resCategories += `<div>`;
  resCategories += `<div class="icon-with-text mt-3">`;
  resCategories += `<label>`;
  resCategories += `<input type="checkbox" class="category_checkbox" value="${largeValue.connector_id}" name="categories[${largeValue.connector_id}]" data="${largeValue.connector_id}">`;
  resCategories += `<span>${largeValue.name}</span>`;
  resCategories += `</label>`;
  if ( largeValue.middle.length != 0 ) { resCategories +=`<a class="ml-2 smaller_dividions_toggle icon-with-text cursor-pointer"><i class="material-icons smaller">add_circle</i></a>`; }
  resCategories += `</div>`;

  resCategories += `<div class="smaller_dividions middle_collection ml-6" style="display: none;">`;
  largeValue.middle.forEach(function( mValue ) {

    if ( mValue.middle_id == null ) { return; }

    resCategories += `<div>`;
    resCategories += `<div class="middl icon-with-text mt-2">`;
    resCategories += `<label>`;
    resCategories += `<input type="checkbox" class="category_checkbox" value="${mValue.connector_id}" name="categories[${mValue.connector_id}]" data="${mValue.connector_id}">`;
    resCategories += `<span>${mValue.name}</span>`;
    resCategories += `</label>`;
    if ( mValue.small.length != 0 ) { resCategories += `<a class="ml-2 smaller_dividions_toggle icon-with-text cursor-pointer"><i class="material-icons smaller">add_circle</i></a>`; }
    resCategories += `</div>`;

    resCategories += `<div class="smaller_dividions small_collection ml-6" style="display: none;">`;
    mValue.small.forEach(function( sValue ) {

      if ( sValue.small_id == null ) { return; }

      resCategories += `<div class="small mt-1">`;
      resCategories += `<label>`;
      resCategories += `<input type="checkbox" class="category_checkbox" value="${sValue.connector_id}" name="categories[${sValue.connector_id}]" data="${sValue.connector_id}">`;
      resCategories += `<span>${sValue.name}</span>`;
      resCategories += `</label>`;
      resCategories += `</div>`;

    });
    resCategories += `</div>`;
    resCategories += `</div>`;
  });
  resCategories += `</div>`;
  resCategories += `</div>`;

  return resCategories;
}

function ranges_checkboxies_dom(title, value) {

  var enabled = $('#plan_user_flag').data('plan-user') === 1;

  res = '';
  res += `<div>`;
  res += `<div class="icon-with-text mt-1">`;
  res += `<label>`;
  res += `<input type="checkbox" class="${title}_checkbox" value="${value.id}" name="${title}[${value.id}]" data="${value.id}" ${ enabled ? '' : 'disabled="disabled"'}>`;
  res += `<span>${value.label}</span>`;
  res += `</label>`;
  res += `</div>`;
  res += `</div>`;

  return res;
}

function addConnectorId(check_target, id) {

  var ids_str = $(id).text();
  if ( check_target.checked ) {
    ids_str = `${ids_str},${check_target.value}`;
  } else {
    ids_str = ids_str.replace(`,${check_target.value}`,``);
  }

  $(id).text(ids_str);

}

function getCompaniesCount() {

  $.ajax({type: 'GET',
      url:  '/company_count',
      data: { areas_connector_id: $('#selected_area_connector_ids').text().slice(1),
              categories_connector_id: $('#selected_category_connector_ids').text().slice(1),
              capitals_id: $('#selected_capital_ids').text().slice(1),
              employees_id: $('#selected_employee_ids').text().slice(1),
              sales_id: $('#selected_sales_ids').text().slice(1),
              not_own_capitals: $('#request_not_own_capitals').prop('checked') },
      dataType: 'json'}

    )
    .done( function(res){
      if (res.status != 200 ){
        $('#companies_count').text(`現在の企業数 : ${res.message}`);
        return;
      }

      $('#companies_count').text(`現在の企業数 : ${res.categories_count}`);

    })
    .fail( function(res){
      console.log('企業数を取得できませんでした。');
      $('#companies_count').text(`現在の企業数 : 企業数を取得できませんでした。`);
    });
}

function startLoading() {
  $('.loader').fadeIn();
}

function checkStorageDays() {
  var days = $('#request_using_storage_days').val();
  if(days.match(/[^\d]/)) {
    $('#storage_condition_validate_msg').text('数値を入力して下さい。');
  } else if(days.match(/^0/)) {
    $('#storage_condition_validate_msg').text('1から9999までの値を指定してください');
  } else if(Number(days) > 0 && Number(days) > 9999) {
    $('#storage_condition_validate_msg').text('1から9999までの値を指定してください');
  } else {
    $('#storage_condition_validate_msg').text('');
    return true;
  }
  return false;
}

function overFileSize() {
  if($('#file_upload')[0].files.length == 0){
    $('#upload_validate_msg').text('');
    return false;
  }

  var ext = $('#file_upload')[0].files[0].name.split('.').pop();

  if ( ext == 'xlsx' ) {
    var limit = 5000000;
  } else if ( ext == 'csv' ) {
    var limit = 10000000;
  }

  var fileSize = $('#file_upload')[0].files[0].size;

  if ( fileSize > limit ) {
    $('#upload_validate_msg').text('ファイルサイズが大きすぎます。お手数ですが、エクセルの場合は5M、CSVの場合は10Mバイト以内にしてください。');
    $('#excel_display').hide();
    return true;
  } else {
    $('#upload_validate_msg').text('');
    return false;
  }
}

function selectedFile() {
  if($('#file_upload')[0].files.length == 0){
    return false;
  } else {
    return true;
  }
}

function checkUsingStorage() {
  if($('#request_use_storage').prop('checked')) {
    $('#using_storaged_date_condition').show();
  } else {
    $('#using_storaged_date_condition').hide();
  }
}

function checkFreeSearch() {
  if($('#request_free_search').prop('checked')) {
    $('#using_free_search_condition').show();
  } else {
    $('#using_free_search_condition').hide();
  }
}

function selectFileType() {
  $('#list_upload_form').addClass('selected');
  $('#request_form_making_url_list').removeClass('selected');
  $('#request_form_word_search').removeClass('selected');
  $('#request_form_company_db_search').removeClass('selected');
}

function selectMakeListType() {
  $('#list_upload_form').removeClass('selected');
  $('#request_form_making_url_list').addClass('selected');
  $('#request_form_word_search').removeClass('selected');
  $('#request_form_company_db_search').removeClass('selected');
}

function selectWordSearchType() {
  $('#list_upload_form').removeClass('selected');
  $('#request_form_making_url_list').removeClass('selected');
  $('#request_form_word_search').addClass('selected');
  $('#request_form_company_db_search').removeClass('selected');
}

function selectDbSearchType() {
  $('#list_upload_form').removeClass('selected');
  $('#request_form_making_url_list').removeClass('selected');
  $('#request_form_word_search').removeClass('selected');
  $('#request_form_company_db_search').addClass('selected');
}

function resizeTestResultTable() {
  if ( $('#test_result').hasClass('request_result_table_summary_fixed') ) {
    $('#test_result').removeClass('request_result_table_summary_fixed');
    $('#test_result').addClass('request_result_table_summary');
    $('#resize_table').text('部分表示');

  } else {
    $('#test_result').removeClass('request_result_table_summary');
    $('#test_result').addClass('request_result_table_summary_fixed');
    $('#resize_table').text('全表示');
  }
}

function csvRead(){

  var file   = $('#file_upload')[0].files[0];
  var reader = new FileReader();

  reader.onload = function() {

    $('#excel_display').show();
    $('#sheet_select').hide();

    var arr = CSVToArray(reader.result);
    $('#col_select_area').html(createTable(arr.slice(0, 5)));
  }

  reader.readAsText( file );

}

function xlsxRead(designatedSheetName = ''){
  var file = $('#file_upload')[0].files[0];
  var reader = new FileReader();

  reader.onload = function() {
      var data = new Uint8Array(reader.result);
      var wb = XLSX.read(data, { type: 'array' });

      if ( designatedSheetName == '' ) {
        var sheetNames = wb.SheetNames;
        var sheet = wb.Sheets[sheetNames[0]];
        $('#sheet_select_area').html(createSelectbox(sheetNames));
        $('select').formSelect();

      } else {
        var sheet = wb.Sheets[designatedSheetName];
      }

      var xlsRows = extractRows(sheet, 5);

      $('#excel_display').show();
      $('#sheet_select').show();
      $('#col_select_area').html(createTable(xlsRows));
  }

  reader.readAsArrayBuffer(file);
}


var   rowNums = {   A:  1,  B:  2,  C:  3,  D:  4,  E:  5,  F:  6,  G:  7,  H:  8,  I:  9,  J: 10,
                    K: 11,  L: 12,  M: 13,  N: 14,  O: 15,  P: 16,  Q: 17,  R: 18,  S: 19,  T: 20,
                    U: 21,  V: 22,  W: 23,  X: 24,  Y: 25,  Z: 26, AA: 27, AB: 28, AC: 29, AD: 30,
                   AE: 31, AF: 32, AG: 33, AH: 34, AI: 35, AJ: 36, AK: 37, AL: 38, AM: 39, AN: 40,
                   AO: 41, AP: 42, AQ: 43, AR: 44, AS: 45, AT: 46, AU: 47, AV: 48, AW: 49, AX: 50};


function numToAlph(num) {
  var val = '';
  const keys = Object.keys(rowNums);
  keys.forEach( function( key ) {
    if ( rowNums[key] == num ) {
      val = key;
    }
  });
  return val;
}


function extractRows(sheet, row) {
  var range  = sheet["!ref"];
  var maxCol = range.split(':')[1].match(/[A-Z]+/)[0]; // 50は'AX'
  var maxRow = Number( range.split(':')[1].match(/[0-9]+/)[0] );
  var readRow;
  var readCol;

  if (maxRow > row) {
    readRow = row;
  } else {
    readRow = maxRow;
  }

  if ( rowNums[maxCol] == undefined ) {
    readCol = 'AX';
  } else {
    readCol = maxCol;
  }

  var data = [];

  for( var i = 1; i < readRow + 1; i++ ) {
    var ar = [];
    for( var j = 1; j < rowNums[readCol] + 1; j++ ) {

      var val = sheet[`${numToAlph(j)}${i}`];
      if ( val == undefined ) val = { v: '' };
      ar.push(val['v']);

    }
    data.push(ar);
  }
  return data;
}

function createTable(tableData) {
  var table = document.createElement('table');
  table.setAttribute('id', 'col_select_table');
  var tableBody = document.createElement('tbody');

  var checkFlg = false;
  var checkboxRow = document.createElement('tr');

  if (tableData[0].length > 50) {
    var columnSize = 50;
  } else {
    var columnSize = tableData[0].length;
  }

  for (var i = 0; i < columnSize; i++ ) {
    var checkboxCell = document.createElement('td');
    checkboxCell.setAttribute('class', 'first_row_cell');
    var labelTag = document.createElement('label');
    var divTag = document.createElement('div');
    var spanTag = document.createElement('span');
    spanTag.appendChild(document.createTextNode('click'));
    var input = document.createElement('input');
    input.setAttribute('type', 'radio');
    input.setAttribute('name', 'col_select');
    input.setAttribute('id', 'col_select');
    input.setAttribute('value', i + 1);
    if ( tableData[0].length == 1 ) {
      input.setAttribute('checked', 'checked');
      checkFlg = true;
    }
    if ( urlColumn(tableData[0][i]) && !checkFlg ) {
      input.setAttribute('checked', 'checked');
      checkFlg = true;
    }
    divTag.appendChild(input);
    divTag.appendChild(spanTag);
    labelTag.appendChild(divTag);
    checkboxCell.appendChild(labelTag);
    checkboxRow.appendChild(checkboxCell);
  }
  tableBody.appendChild(checkboxRow);


  tableData.forEach(function(rowData) {
    var row = document.createElement('tr');

    for (var i = 0; i < columnSize; i++ ) {
      var cell = document.createElement('td');
      cell.appendChild(document.createTextNode(rowData[i]));
      row.appendChild(cell);

    };

    tableBody.appendChild(row);
  });

  table.appendChild(tableBody);
  return table;
}

function downloadInvalidUrlsExcel() {
  var tbl = $('#all_invalid_url_table')[0];
  var workbook = XLSX.utils.table_to_book(tbl);
  XLSX.writeFile(workbook, 'invalid_urls.xlsx');
}

function urlColumn(col_val) {
  var val = String(col_val).substr(0, 4).toLowerCase();
  if ( val == 'url' || val == 'uri' || val == 'http'){
    return true;
  } else {
    return false;
  }
}

function createSelectbox(sheetArray){
  var div = document.createElement('div');
  div.setAttribute('class', 'input-field');
  var select = document.createElement('select');
  select.setAttribute('id', 'sheet_selectbox');
  select.setAttribute('name', 'sheet_select');

  sheetArray.forEach(function(sheetName) {
    var option = document.createElement('option');
    option.setAttribute('value', sheetName);
    option.appendChild(document.createTextNode(sheetName));
    select.appendChild(option);
  });
  div.appendChild(select);
  return div;
}

function invalidExtension(){
  var ext = getExtension();
  if ( ext == 'xlsx' || ext == 'csv' ){
    return false;
  } else {
    return true;
  }
}

function getExtension() {
  return $('#file_upload')[0].files[0].name.split('.').pop().toLowerCase();
}

function displayAllInvalidUrls() {
  if ($('#all_invalid_urls_display').hasClass('display_part')) {
    $('#all_invalid_url_table').show();
    $('#part_invalid_urls_table').hide();
    $('#all_invalid_urls_display').removeClass('display_part');
    $('#all_invalid_urls_display').addClass('display_all');
    $('#all_invalid_urls_display').text('全無効URL非表示');
  } else {
    $('#all_invalid_url_table').hide();
    $('#part_invalid_urls_table').show();
    $('#all_invalid_urls_display').addClass('display_part');
    $('#all_invalid_urls_display').removeClass('display_all');
    $('#all_invalid_urls_display').text('全無効URL表示');
  }
}

function getCandidateUrls() {
  var word = $('#keyword').val();
  if (word == '') $('#candidate_urls').html('');

  $.ajax({type: 'GET',
      url:  '/candidate_urls',
      data: { word: word },
      dataType: 'json'}

    )
    .done( function(res){
      if (res.status != 200 ){
        var message = `<div id="error_message">${res.message}<div>`;
        $('#candidate_urls').html(message);
        return;
      }

      if ( res.urls == '' ) { return; }
      if ( word != $('#keyword').val() ) { return; }

      var resUrls = '<div class="collection">';
      res.urls.forEach(function( value ) {
        resUrls += '<a class="candidate_url collection-item">';
        resUrls +=   '<table>';
        resUrls +=     `<tr><td rowspan="2" class="icon"><i class="material-icons">add_box</i><span>click!</span></td><td class='title'>${value.title}</td></tr>`;
        resUrls +=     `<tr><td class='url'>${value.url}</td></tr>`;
        resUrls +=   '</table>';
        resUrls += '</a>';
      });
      resUrls += '</div>'
      $("#finding_candidate_urls").hide();
      $('#candidate_urls').html(resUrls);
    })
    .fail( function(res){
      console.log('URLを取得できませんでした。');
      $("#find_candidate_urls_msg").text('URLを取得できませんでした。');
      $("#finding_candidate_urls").hide();
    });
}

function downloadUrlListExcel() {

  if ( !ExistUrlList() ) { return; }

  XLSX.writeFile(makeUrlListWorkbook(), getUrlListFileName('xlsx'));

}

function getUrlListFileName(extension_without_dot){

  var fileName = $('#file_name').val();
  if ( fileName === undefined ) { fileName = ''; }
  fileName = fileName.trim();
  if ( fileName == '' ) { fileName = 'made_url_list'; }

  return fileName + '.' + extension_without_dot;
}

function makeUrlListWorkbook() {

  $('#hidden_url_table').empty();
  $('#hidden_url_table').html($('#urls_table').html());

  var tbl    = $('#hidden_url_table').children()[0];
  var rowCnt = tbl.rows.length;

  for ( var i = 0; i < rowCnt; i++ ){
    tbl.rows[i].deleteCell(0);
  }

  var workbook = XLSX.utils.table_to_book(tbl);
  $('#hidden_url_table').empty();

  return workbook;

}

function ExistUrlList(){
  if ( $('#urls_table')[0].rows.length <= 1 ){
    alert('リストを作成して下さい。');
    return false;
  } else {
    return true;
  }
}

function ExistSearchWord(){
  if ( $('#keyword_for_word_search').val() == '' ){
    alert('検索キーワードを入力してください。');
    return false;
  } else {
    return true;
  }
}

function CheckedAnyCheckbox(){

  if ( $('#selected_area_connector_ids').text() == ''     &&
       $('#selected_category_connector_ids').text() == '' &&
       $('#selected_capital_ids').text() == ''            &&
       $('#selected_employee_ids').text() == ''           &&
       $('#selected_sales_ids').text() == ''                 ){
    alert('地域か業種かその他の条件のいずれかをチェックしてください。');
    return false;
  } else {
    return true;
  }
}

function ExistCorporateListSiteUrl(){
  if ( $('#url_of_corporate_list_site').val() == '' ){
    alert('企業一覧サイトのURLを入力してください。');
    return false;
  } else {
    return true;
  }
}

function makeUrlListCsv(){

  if ( !ExistUrlList() ) { return; }

  var workbook = makeUrlListWorkbook();
  var sheet    = workbook.Sheets[workbook.SheetNames[0]];
  return XLSX.utils.sheet_to_csv(sheet);
}

function calcurateMakableCount() {
  var maxCnt     = Number($('#excel_row_limit').text());
  var currentCnt = $('#urls_table').children()[0].rows.length - 1;
  var restCnt    = maxCnt - currentCnt;
  $('#rest_cout_to_limit').text(restCnt);
  if ( maxCnt < currentCnt ) {
    $('#making_url_list_invalid_msg').text('超過した行はリクエスト時に削除されます。');
    $('#listCounter').addClass('alert-msg');
  } else {
    $('#making_url_list_invalid_msg').text('');
    $('#listCounter').removeClass('alert-msg');
  }
}

// Validation

function validRequestedUrlCorporateListConfig() {
  var res = true;
  if ( $('#request_corporate_list_config_off').val() == '1' ) { return true; }

  $('.validate_msg__corporate_list_url').each(function() {
    var num = Number( $(this).parent().parent().attr('url_num') );
    var urlText = $(`#request_corporate_list_${num}_url`).val();
    var toggle_btn = $(`#corporate_list_${num}_details_toggle_btn`);

    $(this).text('');
    $(`#validate_msg__corporate_list_${num}_org_name`).text('');

    if ( urlText != '' && !urlText.match(/^http:\/\/|^https:\/\//) ) {
      $(this).text('URLの形式で入力して下さい。');
      res = false;
    }

    if ( $(`#request_corporate_list_${num}_details_off`).val() == '1' ) { return true; }

    var orgName1 = $(`#request_corporate_list_${num}_organization_name_1`).val();
    var orgName2 = $(`#request_corporate_list_${num}_organization_name_2`).val();
    var orgName3 = $(`#request_corporate_list_${num}_organization_name_3`).val();
    var orgName4 = $(`#request_corporate_list_${num}_organization_name_4`).val();

    if ( urlText == '' && ( orgName1 != '' || orgName2 != '' || orgName3 != '' || orgName4 != '' ) ) {
      $(this).text('URLを入力してください。');
      res = false;
    }

    if ( countInputText(orgName1, orgName2, orgName3, orgName4) == 1 ) {
      $(`#validate_msg__corporate_list_${num}_org_name`).text('会社名は２つ以上入力してください。');
      res = false;
    }

    for ( var i = 1; i < 23; i++ ) {
      if (typeof $(`#request_corporate_list_${num}_contents_${i}_title`).val() === "undefined") { break; }

      $(`#validate_msg__corporate_list_${num}_contents_${i}`).text('');

      var contentsTitle = $(`#request_corporate_list_${num}_contents_${i}_title`).val();
      var contentsText1 = $(`#request_corporate_list_${num}_contents_${i}_text_1`).val();
      var contentsText2 = $(`#request_corporate_list_${num}_contents_${i}_text_2`).val();
      var contentsText3 = $(`#request_corporate_list_${num}_contents_${i}_text_3`).val();

      if ( urlText == '' && ( contentsTitle != '' || contentsText1 != '' || contentsText2 != '' || contentsText3 != '' ) ) {
        $(this).text('URLを入力してください。');
        res = false;
      }

      if ( countInputText(contentsText1, contentsText2, contentsText3) == 1 ) {
        if ( contentsTitle == '' ) {
          $(`#validate_msg__corporate_list_${num}_contents_${i}`).text('種別名は必ず入力してください。内容文字列は２つ以上入力してください。');
          res = false;
        } else {
          $(`#validate_msg__corporate_list_${num}_contents_${i}`).text('内容文字列は２つ以上入力してください。');
          res = false;
        }
      } else if ( contentsTitle == '' && countInputText(contentsText1, contentsText2, contentsText3) >= 2 ) {
        $(`#validate_msg__corporate_list_${num}_contents_${i}`).text('種別名は必ず入力してください。');
        res = false;
      } else if ( contentsTitle != '' && countInputText(contentsText1, contentsText2, contentsText3) == 0 ) {
        $(`#validate_msg__corporate_list_${num}_contents_${i}`).text('内容文字列は２つ以上入力してください。');
        res = false;
      }
    }
  });

  if ( !res ) { alert('入力内容に誤りがあります。再度、ご確認下さい。'); }
  return res;
}

function countInputText(text1, text2, text3, text4 = null){
  var cnt = 0;

  if ( text1 != '' ) { cnt++; }
  if ( text2 != '' ) { cnt++; }
  if ( text3 != '' ) { cnt++; }
  if ( text4 !== null && text4 != '' ) { cnt++; }

  return cnt;
}

function validRequestedUrlCorporateIndividualConfig() {
  var res = true;
  if ( $('#request_corporate_individual_config_off').val() == '1' ) { return true; }

  $('.validate_msg__corporate_individual_url').each(function() {
    var num = Number( $(this).parent().parent().attr('url_num') );
    var urlText = $(`#request_corporate_individual_${num}_url`).val();
    var toggle_btn = $(`#corporate_individual_${num}_details_toggle_btn`);

    $(this).text('');
    $(`#validate_msg__corporate_individual_${num}_org_name`).text('');

    if ( urlText != '' && !urlText.match(/^http:\/\/|^https:\/\//) ) {
      $(this).text('URLの形式で入力して下さい。');
      res = false;
    }

    if ( $(`#request_corporate_individual_${num}_details_off`).val() == '1' ) { return true; }

    var orgName = $(`#request_corporate_individual_${num}_organization_name`).val();

    if ( urlText == '' && orgName != '' ) {
      $(this).text('URLを入力してください。');
      res = false;
    }

    for ( var i = 1; i < 23; i++ ) {
      if (typeof $(`#request_corporate_individual_${num}_contents_${i}_title`).val() === "undefined") { break; }

      $(`#validate_msg__corporate_individual_${num}_contents_${i}`).text('');

      var contentsTitle = $(`#request_corporate_individual_${num}_contents_${i}_title`).val();
      var contentsText  = $(`#request_corporate_individual_${num}_contents_${i}_text`).val();

      if ( urlText == '' && ( contentsTitle != '' || contentsText != '' ) ) {
        $(this).text('URLを入力してください。');
        res = false;
      }

      if ( contentsTitle == '' && contentsText != '' ) {
        $(`#validate_msg__corporate_individual_${num}_contents_${i}`).text('種別名は必ず入力してください。');
        res = false;
      } else if ( contentsTitle != '' && contentsText == '' ) {
        $(`#validate_msg__corporate_individual_${num}_contents_${i}`).text('内容文字列は必ず入力してください。');
        res = false;
      }
    }
  });

  if ( !res ) { alert('入力内容に誤りがあります。再度、ご確認下さい。'); }
  return res;
}

// HTML

function HTML_field_corporate_list_url_contents_config(next_num, url_num) {
html = `
<div class="field_corporate_list_url_contents_config" data_num="${next_num}" url_num="${url_num}">
  <div class="row">
    <div class="alert-msg ml-2" id="validate_msg__corporate_list_${url_num}_contents_${next_num}"></div>
  </div>
  <div class="row">
    <div class="input-field col s3 shrink_margin_bottom">
      <input type="text" name="request[corporate_list][${url_num}][contents][${next_num}][title]" id="request_corporate_list_${url_num}_contents_${next_num}_title">
      <label for="request_corporate_list_${url_num}_contents_${next_num}_title">種別名 または そのXパス</label>
    </div>
    <div class="input-field col s3 shrink_margin_bottom">
      <input type="text" name="request[corporate_list][${url_num}][contents][${next_num}][text][1]" id="request_corporate_list_${url_num}_contents_${next_num}_text_1">
      <label for="request_corporate_list_${url_num}_contents_${next_num}_text_1">サンプル文字1 または そのXパス</label>
    </div>
    <div class="input-field col s3 shrink_margin_bottom">
      <input type="text" name="request[corporate_list][${url_num}][contents][${next_num}][text][2]" id="request_corporate_list_${url_num}_contents_${next_num}_text_2">
      <label for="request_corporate_list_${url_num}_contents_${next_num}_text_2">サンプル文字2 または そのXパス</label>
    </div>
    <div class="input-field col s3 shrink_margin_bottom">
      <input type="text" name="request[corporate_list][${url_num}][contents][${next_num}][text][3]" id="request_corporate_list_${url_num}_contents_${next_num}_text_3">
      <label for="request_corporate_list_${url_num}_contents_${next_num}_text_3">サンプル文字3 または そのXパス</label>
    </div>
  </div>
</div>
`
  return html;
}

function HTML_field_corporate_list_config(url_num) {
html = `
<div class="field_corporate_list_config" url_num="${url_num}">
  <div class="row">
    <div class="validate_msg__corporate_list_url alert-msg ml-2"></div>
  </div>
  <div class="row">
    <div class="input-field col s6 shrink_margin_bottom">
      <input type="text" name="request[corporate_list][${url_num}][url]" id="request_corporate_list_${url_num}_url">
      <label for="request_corporate_list_${url_num}_url">企業一覧ページのサンプルURL</label>
    </div>
    <span class="input-field col s2 btn-toggle toggle_corporate_list_url_details cursor-pointer shrink_margin_bottom" id="corporate_list_${url_num}_details_toggle_btn">
      <div class="ptb-8">
        <i class="material-icons left">add_circle_outline</i>
        <span>詳細設定を開く</span>
      </div>
    </span>
    <div class="input-field col s2 corporate_list_url_details_off shrink_margin_bottom" style="display: block;">
     <div class="ptb-8">詳細設定なし</div>
     <input type="hidden" name="request[corporate_list][${url_num}][details_off]" id="request_corporate_list_${url_num}_details_off" value="1">
    </div>
  </div>
  <div class="corporate_list_url_details_config" style="display: none;">
    <div class="row">
      <div class="ml-2">① ページに記載されている会社名のサンプル(または、 サンプル会社名のXパス)を２つ以上、入力してください。</div>
    </div>
    <div class="row">
      <div class="alert-msg ml-2" id="validate_msg__corporate_list_${url_num}_org_name">
    </div>
    <div class="row">
      <div class="input-field col s3 shrink_margin_bottom">
        <input type="text" name="request[corporate_list][${url_num}][organization_name][1]" id="request_corporate_list_${url_num}_organization_name_1">
        <label for="request_corporate_list_${url_num}_organization_name_1">会社名1 または そのXパス</label>
      </div>
      <div class="input-field col s3 shrink_margin_bottom">
        <input type="text" name="request[corporate_list][${url_num}][organization_name][2]" id="request_corporate_list_${url_num}_organization_name_2">
        <label for="request_corporate_list_${url_num}_organization_name_2">会社名2 または そのXパス</label>
      </div>
      <div class="input-field col s3 shrink_margin_bottom">
        <input type="text" name="request[corporate_list][${url_num}][organization_name][3]" id="request_corporate_list_${url_num}_organization_name_3">
        <label for="request_corporate_list_${url_num}_organization_name_3">会社名3 または そのXパス</label>
      </div>
      <div class="input-field col s3 shrink_margin_bottom">
        <input type="text" name="request[corporate_list][${url_num}][organization_name][4]" id="request_corporate_list_${url_num}_organization_name_4">
        <label for="request_corporate_list_${url_num}_organization_name_4">会社名4 または そのXパス</label>
      </div>
    </div>
    <div class="row">
      <div class="ml-2">② 取得したい情報の種別名とページに記載されているサンプル文字(または、 そのXパス)を２つ以上、入力してください。ヘッダ項目の内容は含めないように気をつけてください。</div>
    </div>
    <div class="field_corporate_list_url_contents_configs">
      ${HTML_field_corporate_list_url_contents_config(1, url_num)}
    </div>
    <div class="row input-field">
      <button class="add_corporate_list_url_contents_config btn-small oppose waves-effect waves-light col s1 offset-s1" type="button">
        <i class="material-icons left">add_circle_outline</i>
        追加
      </button>
    <div class="col s1"></div>
      <button class="remove_corporate_list_url_contents_config btn-small oppose waves-effect waves-light disabled col s1" type="button">
        <i class="material-icons left">remove_circle_outline</i>
        削除
      </button>
    </div>
    <br>
    <div class="divider"></div>
  </div>
</div>
`
  return html;
}

function HTML_field_corporate_individual_url_contents_config(next_num, url_num) {
html = `
<div class="field_corporate_individual_url_contents_config" data_num="${next_num}" url_num="${url_num}">
  <div class="row">
    <div class="alert-msg ml-2" id="validate_msg__corporate_individual_${url_num}_contents_${next_num}"></div>
  </div>
  <div class="row">
    <div class="input-field col s6 shrink_margin_bottom">
      <input type="text" name="request[corporate_individual][${url_num}][contents][${next_num}][title]" id="request_corporate_individual_${url_num}_contents_${next_num}_title">
      <label for="request_corporate_individual_${url_num}_contents_${next_num}_title">種別名 または そのXパス</label>
    </div>
    <div class="input-field col s6 shrink_margin_bottom">
      <input type="text" name="request[corporate_individual][${url_num}][contents][${next_num}][text]" id="request_corporate_individual_${url_num}_contents_${next_num}_text">
      <label for="request_corporate_individual_${url_num}_contents_${next_num}_text">サンプル文字 または そのXパス</label>
    </div>
  </div>
</div>
`
  return html;
}

function HTML_field_corporate_individual_config(url_num) {
html = `
<div class="field_corporate_individual_config" url_num="${url_num}">
  <div class="row">
    <div class="validate_msg__corporate_individual_url alert-msg ml-2"></div>
  </div>
  <div class="row">
    <div class="input-field col s6 shrink_margin_bottom">
      <input type="text" name="request[corporate_individual][${url_num}][url]" id="request_corporate_individual_${url_num}_url">
      <label for="request_corporate_individual_${url_num}_url">企業個別ページのサンプルURL</label>
    </div>
    <span class="input-field col s2 btn-toggle toggle_corporate_individual_url_details cursor-pointer shrink_margin_bottom" id="corporate_individual_${url_num}_details_toggle_btn">
      <div class="ptb-8">
        <i class="material-icons left">add_circle_outline</i>
        <span>詳細設定を開く</span>
      </div>
    </span>
    <div class="input-field col s2 corporate_individual_url_details_off shrink_margin_bottom" style="display: block;">
     <div class="ptb-8">詳細設定なし</div>
     <input type="hidden" name="request[corporate_individual][${url_num}][details_off]" id="request_corporate_individual_${url_num}_details_off" value="1">
    </div>
  </div>
  <div class="corporate_individual_url_details_config" style="display: none;">
    <div class="row">
      <div class="ml-2">① ページに記載されている会社名のサンプル(または、 サンプル会社名のXパス)を入力してください。</div>
    </div>
    <div class="row">
      <div class="alert-msg ml-2" id="validate_msg__corporate_individual_${url_num}_org_name">
    </div>
    <div class="row">
      <div class="input-field col s12 shrink_margin_bottom">
        <input type="text" name="request[corporate_individual][${url_num}][organization_name]" id="request_corporate_individual_${url_num}_organization_name">
        <label for="request_corporate_individual_${url_num}_organization_name">会社名 または そのXパス</label>
      </div>
    </div>
    <div class="row">
      <div class="ml-2">② 取得したい情報の種別名とページに記載されているサンプル文字(または、 そのXパス)を入力してください。</div>
    </div>
    <div class="field_corporate_individual_url_contents_configs">
      ${HTML_field_corporate_individual_url_contents_config(1, url_num)}
    </div>
    <div class="row input-field">
      <button class="add_corporate_individual_url_contents_config btn-small oppose waves-effect waves-light col s1 offset-s1" type="button">
        <i class="material-icons left">add_circle_outline</i>
        追加
      </button>
    <div class="col s1"></div>
      <button class="remove_corporate_individual_url_contents_config btn-small oppose waves-effect waves-light disabled col s1" type="button">
        <i class="material-icons left">remove_circle_outline</i>
        削除
      </button>
    </div>
    <br>
    <div class="divider"></div>
  </div>
</div>
`
  return html;
}

$(function() {
  $('#search').click(function (){

    if(!checkURL()) {
      return false;
    }
    if($('#config_use_storage').prop('checked') && !checkStorageDays()) {
      return false;
    }
    $('#search').addClass('disabled');
    startLoading();

    order_request();
  });

  $('#config_url').blur(function (){
    checkURL();
  });


  var KeyUpStack = [];

  $('#config_url').keyup(function (){
    KeyUpStack.push(1);

    setTimeout(function() {
      KeyUpStack.pop();
      if(KeyUpStack.length == 0) {
        $("#finding_candidate_urls").show();
        getCandidateUrls();
      }
    },1000)

  });

  $('input[name="output_format"]:radio').change(function(){
    changeOutput();
  });

  $('input[name="config[use_storage]"]:checkbox').change(function(){
    checkUsingStorage();
  });

  $('input[name="config[free_search]"]:checkbox').change(function(){
    checkFreeSearch();
  });

  $('#config_using_storaged_date').blur(function (){
    checkStorageDays();
  });

  $('#candidate_urls').on('click', '.candidate_url', function (){
    var url = $(this).find('.url').text()
    $('#config_url').val(url);
    $('#candidate_urls').find('#hidden_search_word').text(url);
    $("#candidate_urls").empty();
    $('#validate_msg').text('');
  });

  $('#candidate_urls').on(
    {
      'mouseenter' : function(){
        $('#config_url').val($(this).find('.url').text());
      },
      'mouseleave' : function(){
        $('#config_url').val($('#candidate_urls').find('#hidden_search_word').text());
      }
    },
    '.candidate_url'
  );

  $('.sample_list_toggle_title').click(function (){
    $('.sample_list_area').slideToggle();
    if ( $('.sample_list_toggle_title i').text() == 'add_circle' ){
      $('.sample_list_toggle_title i').text('remove_circle');
    } else {
      $('.sample_list_toggle_title i').text('add_circle');
    }
  });

  $('.exec_sample').click(function (){
    var url = $(this).attr('data');
    $('#config_url').val(url);

    $('#search').prop('disabled', true);
    startLoading();
    order_request();
  });
});


function startLoading() {
  $('.loader').fadeIn();
  $('.search-announce').fadeIn();
}

function stopLoading() {
  $('.loader').fadeOut();
  $('.search-announce').fadeOut();
}

function checkURL() {
  if($('#config_url').val() == '') {
    $('#validate_msg').text('URLを入力して下さい。');
  } else if(!$('#config_url').val().match(/^http:\/\/|^https:\/\//)) {
    $('#validate_msg').text('URLの形式で入力して下さい。');
  } else {
    $('#validate_msg').text('');
    return true;
  }
  return false;
}

function changeOutput() {
  if($('#output_format_table').prop('checked')) {
    $('#output_table').show();
    $('#output_json').hide();
  } else {
    $('#output_table').hide();
    $('#output_json').show();
  }
}

function checkUsingStorage() {
  if($('#config_use_storage').prop('checked')) {
    $('#using_storaged_date_condition').show();
  } else {
    $('#using_storaged_date_condition').hide();
  }
}

function checkFreeSearch() {
  if($('#config_free_search').prop('checked')) {
    $('#using_free_search_condition').show();
  } else {
    $('#using_free_search_condition').hide();
  }
}

function checkStorageDays() {
  var days = $('#config_using_storaged_date').val();
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

function getCandidateUrls() {
  var word = $('#config_url').val();

  if( word == '' ) {
    $("#candidate_urls").empty();
  }

  if( word == '' ||
      ( word.toLowerCase() == 'h' ) ||
      ( word.toLowerCase() == 'ht' ) ||
      ( word.toLowerCase() == 'htt' ) ||
      ( word.substr(0, 4).toLowerCase() == 'http' )
    ) {
    $("#finding_candidate_urls").hide();
    return;
  }

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
      if ( word != $('#config_url').val() ) { return; }

      var resUrls = '<div class="collection">';
      resUrls += `<div id='hidden_search_word' style="display:none;">${word}</div>`;
      res.urls.forEach(function( value ) {
        resUrls += '<a class="candidate_url collection-item">';
        resUrls +=   '<table>';
        resUrls +=     `<tr><td rowspan="2" class="icon"><i class="material-icons">add_box</i><span>click!</span></td><td class='title'>${value.title}</td></tr>`;
        resUrls +=     `<tr><td class='url'>${value.url}</td></tr>`;
        resUrls +=   '</table>';
        resUrls += '</a>';
      });
      resUrls += '</div>'

      $('#candidate_urls').html(resUrls);
      $("#finding_candidate_urls").hide();
    })
    .fail( function(res){
      console.log('URLを取得できませんでした。');
      $("#validate_msg").text('URLを取得できませんでした。');
      $("#finding_candidate_urls").hide();
    });

}

function order_request() {
  var url = $('#config_url').val();

  if($('#config_use_storage').prop('checked')) {
    var use_storage = 1;
    var using_storaged_date = $('#config_using_storaged_date').val();
  } else {
    var use_storage = 0;
    var using_storaged_date = '';
  }

  if($('#config_free_search').prop('checked')) {
    var free_search = 1;
    var free_search_link_words = $('#config_free_search_link_words').val();
    var free_search_target_words = $('#config_free_search_target_words').val();
  } else {
    var free_search = 0;
    var free_search_link_words = '';
    var free_search_target_words = '';
  }

  if($('#config_agree_terms_of_service').prop('checked')) {
    var agree_terms_of_service = 1;
  } else {
    var agree_terms_of_service = 0;
  }


  $.ajax({type: 'POST',
          url:  '/search_request',
          data: { url: url,
                  use_storage: use_storage,
                  using_storaged_date: using_storaged_date,
                  free_search: free_search,
                  free_search_link_words: free_search_link_words,
                  free_search_target_words: free_search_target_words,
                  agree_terms_of_service: agree_terms_of_service
           },
          dataType: 'json'}
    )
    .done( function(res){
      if (res.status != 200 ){
        display_error_message(url, res.message);
        return;
      }

      if (res.complete) {

        location.href = `/search?id=${res.accept_id}`;

      } else {

        var count     = 0;
        var accept_id = res.accept_id;

        var id = setInterval( function() {

          confirm_request(url, accept_id, id);

          console.log(count);

          count++;

          if(count > 720){ // 60分で止める
            clearInterval(id);
          }

        }, 5000);

      }


    })
    .fail( function(res){
      console.log('URLを取得できませんでした。');
      display_error_message(url, 'URLを取得できませんでした。');
      return;
    });

}

function confirm_request(url, accept_id, polling_stop_id) {

  $.ajax({type: 'GET',
          url:  '/confirm_search',
          data: { accept_id: accept_id },
          dataType: 'json'}
    )
    .done( function(res){
      if ( res.complete && !res.success ) {
        display_error_message(url, res.message);
        clearInterval(polling_stop_id);
      } else if ( res.complete && res.success) {
        location.href = `/search?id=${accept_id}`;
      }
    })
    .fail( function(res){
      return false;
    });

}

function display_error_message(url, message) {
  var message = `<div>${url}<br>${message}<div>`;
  $('#notice-msg').html(message);
  $('#search').removeClass('disabled');
  stopLoading();
}
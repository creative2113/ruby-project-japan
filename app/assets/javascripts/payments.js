window.onload = function(){
  $(function() {
    $('head style').empty();

    $('#password_for_card_change').on('keyup', function() {
      if($('#password_for_card_change').val() === '') {
        $('#payjp_checkout_box input').removeClass('enabled');
      } else {
        $('#payjp_checkout_box input').addClass('enabled');
      }
    });

    $('input[name=plan]:radio').change( function() {
      if ( !$("input[name='plan']:checked").val() ) {
        $('#change_plan').addClass('disabled');
      } else {
        getChargeInfo();
        if($('#password_for_plan_change').val() === '') {
          $('#change_plan').addClass('disabled');
        } else {
          $('#change_plan').removeClass('disabled');
        }
      }
    });

    $('#password_for_plan_change').keyup( function() {
      if($('#password_for_plan_change').val() === '') {
        $('#change_plan').addClass('disabled');
      } else {
        if ( !$("input[name='plan']:checked").val() ) {
          $('#change_plan').addClass('disabled');
        } else {
          $('#change_plan').removeClass('disabled');
        }
      }
    });

    $('#change_plan').click( function() {
      var result = window.confirm("プランを変更してもよろしいですか？\nプランをアップグレードする場合、今回課金された金額は払い戻しできませんので、ご注意ください。");
      if ( result ) {
        startLoading();
        $('#change_plan').addClass('disabled');
      } else {
        return false;
      }
    });

    $('#password_for_plan_stop').keyup( function() {
      if($('#password_for_plan_stop').val() === '') {
        $('#stop_subscription').addClass('disabled');
      } else {
        $('#stop_subscription').removeClass('disabled');
      }
    });

    $('#stop_subscription').click( function() {
      var result = window.confirm('課金を停止してもよろしいですか？');
      if ( result ) {
        startLoading();
        $('#stop_subscription').addClass('disabled');
      } else {
        return false;
      }
    });

    $('#change_plan_for_admin').click( function() {
      var result = window.confirm("変更してもよろしいですか？");
      if ( result ) {
        $('#change_plan_for_admin').addClass('disabled');
      } else {
        return false;
      }
    });

    $('#check').keyup( function() {
      var str = $('#check').val();
      if(str.length === 2 && str[0] === str[1] && str[0] !== ' ') {
        $('#change_plan_for_admin').removeClass('disabled');
      } else {
        $('#change_plan_for_admin').addClass('disabled');
      }
    });

  });
}

// マテリアルデザインのセレクトボックス
$(document).ready(function(){
  $('select').formSelect();
});

function startLoading() {
  $('.loader').fadeIn();
}

function getChargeInfo() {
  var radio_val = $('input[name=plan]:checked').val();


  $.ajax({type: 'GET',
    url:  '/payment_info',
    data: { plan: radio_val },
    dataType: 'json',
    success: function(res){
      console.log(res);

      $('#payment_info').show();
      $('#price_this_time').text(res.price.toLocaleString() + '円(税込)')
      $('#new_price').text(res.new_price.toLocaleString() + '円/月(税込)')

    }
  });
}
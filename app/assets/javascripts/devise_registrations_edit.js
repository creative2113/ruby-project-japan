window.onload = function(){
  $(function() {
    $('head style').empty();

    $("input[name='plan']").change(function (){
      if ( !$("input[name='plan']:checked").val() ) {
        $('#payjp_checkout_box input').removeClass('enabled');
      } else {
        $('#payjp_checkout_box input').addClass('enabled');
        if($('#password_for_plan_registration').val() === '') {
          $('#payjp_checkout_box input').removeClass('enabled');
        } else {
          $('#payjp_checkout_box input').addClass('enabled');
        }
      }
    });

    $('#password_for_plan_registration').keyup( function() {
      if($('#password_for_plan_registration').val() === '') {
        $('#payjp_checkout_box input').removeClass('enabled');
      } else {
        if ( !$("input[name='plan']:checked").val() ) {
          $('#payjp_checkout_box input').removeClass('enabled');
        } else {
          $('#payjp_checkout_box input').addClass('enabled');
        }
      }
    });

    $('#cancel_account').click( function() {
      var result = window.confirm("退会してもよろしいですか？");
      if ( result ) {
        $('#cancel_account').addClass('disabled');
      } else {
        return false;
      }
    });
  });

  $(document).ready(function(){
    $('select').formSelect();
  });
}

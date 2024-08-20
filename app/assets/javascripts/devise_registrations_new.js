window.onload = function(){
  $(function() {
    $('label#label_terms_of_service .field_with_errors').after('<input type="checkbox" value="1" name="user[terms_of_service]" id="user_terms_of_service" class="field_with_errors">');
    $('label#label_terms_of_service div.field_with_errors').remove();
  });

  $(document).ready(function(){
    $('select').formSelect();
  });
}

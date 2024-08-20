module Admin
  class RequestsController < Admin::ApplicationController
    # Overwrite any of the RESTful controller actions to implement custom behavior
    # For example, you may want to send an email after a foo is updated.
    #
    # def update
    #   super
    #   send_foo_updated_email(requested_resource)
    # end

    # Override this method to specify custom lookup behavior.
    # This will be used to set the resource for the `show`, `edit`, and `update`
    # actions.
    #
    # def find_resource(param)
    #   Foo.find_by!(slug: param)
    # end

    # The result of this lookup will be available as `requested_resource`

    # Override this if you have certain roles that require a subset
    # this will be used to set the records shown on the `index` action.
    #
    # def scoped_resource
    #   if current_user.super_admin?
    #     resource_class
    #   else
    #     resource_class.with_less_stuff
    #   end
    # end

    def copy
      if (req = Request.find_by_id(params[:id])).blank?
        redirect_to(
          admin_requests_path,
          alert: "ID: #{params[:id]}のリクエストは存在しません。"
        ) and return
      end

      if (user = User.find_by_id(params[:user_id])).blank?
        redirect_to(
          admin_request_path(params[:id]),
          alert: "ID: #{params[:user_id]}のユーザは存在しません。"
        ) and return
      end

      new_req = req.copy_to(user.id)

      redirect_to(
        admin_request_path(new_req.id),
        notice: 'コピーに成功しました。'
      )
    rescue => e
      logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
      redirect_to(
        admin_request_path(params[:id]),
        alert: "コピーに失敗しました。Alert: #{e.message}"
      ) and return
    end

    def update_list_site_analysis_result
      if (req = Request.find_by_id(params[:id])).blank?
        redirect_to(
          admin_requests_path,
          alert: "ID: #{params[:id]}のリクエストは存在しません。"
        ) and return
      end

      analysis_result = params[:analysis_result].delete_line_brake

      # JSONとしてエラーが出ないかチェック
      JSON.parse(analysis_result).to_json

      req.update!(list_site_analysis_result: analysis_result)

      redirect_to(
        admin_request_path(params[:id]),
        notice: '更新に成功しました。'
      )
    rescue => e
      logging('error', request, { finish: 'Error Occurred', err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
      redirect_to(
        admin_request_path(params[:id]),
        alert: "更新に失敗しました。Alert: #{e.message[0..200]}"
      ) and return
    end

    def default_sorting_attribute
      :id
    end

    def default_sorting_direction
      :desc
    end

    # Override `resource_params` if you want to transform the submitted
    # data before it's persisted. For example, the following would turn all
    # empty values into nil values. It uses other APIs such as `resource_class`
    # and `dashboard`:
    #
    # def resource_params
    #   params.require(resource_class.model_name.param_key).
    #     permit(dashboard.permitted_attributes).
    #     transform_values { |value| value == "" ? nil : value }
    # end

    # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
    # for more information
  end
end

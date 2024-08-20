module Admin
  class CompaniesController < Admin::ApplicationController
    # Overwrite any of the RESTful controller actions to implement custom behavior
    # For example, you may want to send an email after a foo is updated.
    #
    # def update
    #   super
    #   send_foo_updated_email(requested_resource)
    # end

    def import_company_file

      if params[:companies_file].blank?
        redirect_to(
          admin_companies_path,
          alert: 'ファイルが存在しません。'
        ) and return
      end

      file_name = params[:companies_file].original_filename

      unless Company.import(params[:companies_file].path)
        NoticeMailer.deliver_later(NoticeMailer.notice_simple("異常終了\n企業インポートに失敗しました。\n#{file_name}", "異常終了 企業インポートに失敗しました。#{file_name}", '企業インポート'))

        redirect_to(
          admin_companies_path,
          alert: 'ファイルのインポートに失敗しました。'
        ) and return
      end

      Lograge.logging('info', {class: 'CompaniesController', method: 'import_company_file', issue: '企業インポートに成功しました。', file_name: file_name })
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("正常終了\n企業インポートに成功しました。\n#{file_name}", "企業インポートに成功しました。#{file_name}", '企業インポート'))

      redirect_to(
        admin_companies_path,
        notice: 'インポートが成功しました'
      )
    rescue => e
      NoticeMailer.deliver_later(NoticeMailer.notice_simple("異常終了\n企業インポートに失敗しました。\n#{file_name}\n#{e.class}\n#{e.message}\n#{e.backtrace.join("\n")}", "異常終了 企業インポートに失敗しました。#{file_name}", '企業インポート'))
      logging('error', request, { finish: 'Error Occurred', file_name: file_name, err_class: e.class, err_msg: e.message, backtrace: e.backtrace })
      redirect_to(
        admin_companies_path,
        alert: "インポートに失敗しました。Alert: #{e.message}"
      ) and return
    end

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

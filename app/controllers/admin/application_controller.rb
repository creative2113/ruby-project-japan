# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_admin

    def authenticate_admin
      _render_404 and return unless user_signed_in?
      _render_404 and return unless allow_admin?
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end

    def _render_404(e = nil)
      if request.format.to_sym == :json
        render json: { error: '404 Not Found' }, status: 404
      else
        render template: 'errors/error_404', status: 404, layout: 'application', content_type: 'text/html'
      end
    end

    def allow_admin?
      current_user.administrator? && current_user.allow_ip&.allow?(request.remote_ip)
    end
  end
end

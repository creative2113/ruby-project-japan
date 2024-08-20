class AdminConstraint
  def matches?(request)
    user_id = request.session["warden.user.user.key"][0][0]

    admin = User.find_by_id(user_id)
    admin&.allow_ip&.allow?(request.remote_ip)
  end
end

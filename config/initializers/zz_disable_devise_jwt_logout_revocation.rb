Rails.application.config.after_initialize do
  Warden::JWTAuth.config.revocation_requests.reject! do |method, path|
    method == "DELETE" &&
      path.is_a?(Regexp) &&
      path.match?("/auth/logout")
  end
end

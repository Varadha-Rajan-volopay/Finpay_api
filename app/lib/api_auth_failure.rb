class ApiAuthFailure
  def self.call(env)
    body = {
      error: "Unauthorized",
      message: "Invalid, expired, or revoked token"
    }.to_json

    [
      401,
      {
        "Content-Type" => "application/json",
        "Content-Length" => body.bytesize.to_s
      },
      [body]
    ]
  end
end
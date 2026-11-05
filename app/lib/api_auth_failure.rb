
# frozen_string_literal: true

class ApiAuthFailure
  def self.call(_env)
    body = {
      error: {
        code: "unauthorized",
        message: "Invalid, expired, or revoked token",
        details: []
      }
    }.to_json

    [
      401,
      {
        "Content-Type" => "application/json",
        "Content-Length" => body.bytesize.to_s
      },
      [ body ]
    ]
  end
end


module Cursor
  def self.encode(expense)
    Base64.urlsafe_encode64(
      {
        created_at: expense.created_at.iso8601(6),
        id: expense.id
      }.to_json
    )
  end

  def self.decode(token)
    data = JSON.parse(
      Base64.urlsafe_decode64(token)
    )

    unless data.is_a?(Hash) &&
           data["created_at"].is_a?(String) &&
           data["id"].to_s.match?(/\A[1-9]\d*\z/)
      raise ActionController::BadRequest, "invalid cursor"
    end

    {
      created_at: Time.iso8601(data["created_at"]),
      id: data["id"].to_i
    }
  rescue ArgumentError, JSON::ParserError, TypeError
    raise ActionController::BadRequest, "invalid cursor"
  end
end

# frozen_string_literal: true

module NeonAPI
  # Base class for every error raised by this library.
  class Error < StandardError; end

  # Raised when the client is misconfigured (e.g. a missing API key).
  class ConfigurationError < Error; end

  # Raised when the Neon API returns a non-success (4xx/5xx) HTTP response.
  #
  # The original response is preserved so callers can inspect the status code,
  # parsed body, and any request id Neon returned for support purposes.
  class APIError < Error
    # @return [Integer] the HTTP status code
    attr_reader :status
    # @return [Object, nil] the parsed response body (Hash/Array) when JSON
    attr_reader :body
    # @return [String, nil] the request the call was made against, "METHOD /path"
    attr_reader :request
    # @return [String, nil] Neon's request id, useful when contacting support
    attr_reader :request_id

    def initialize(message, status:, body: nil, request: nil, request_id: nil)
      @status = status
      @body = body
      @request = request
      @request_id = request_id
      super(build_message(message))
    end

    private

    def build_message(message)
      parts = []
      parts << "[#{request}]" if request
      parts << "HTTP #{status}"
      parts << message if message && !message.empty?
      parts << "(request_id: #{request_id})" if request_id
      parts.join(" ")
    end
  end

  # 400 Bad Request — the request was malformed or failed validation.
  class BadRequestError < APIError; end

  # 401 Unauthorized — the API key is missing, invalid, or expired.
  class AuthenticationError < APIError; end

  # 403 Forbidden — the API key is valid but lacks permission for the resource.
  class ForbiddenError < APIError; end

  # 404 Not Found — the requested resource does not exist.
  class NotFoundError < APIError; end

  # 409 Conflict — the request conflicts with the current state of the resource.
  class ConflictError < APIError; end

  # 422 Unprocessable Entity — semantically invalid request.
  class UnprocessableEntityError < APIError; end

  # 429 Too Many Requests — you have hit Neon's rate limit.
  class RateLimitError < APIError; end

  # 5xx — something went wrong on Neon's side.
  class ServerError < APIError; end

  # Maps an HTTP status code to the most specific {APIError} subclass.
  module ErrorFactory
    STATUS_MAP = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => ForbiddenError,
      404 => NotFoundError,
      409 => ConflictError,
      422 => UnprocessableEntityError,
      429 => RateLimitError
    }.freeze

    module_function

    # @param status [Integer]
    # @return [Class<APIError>]
    def klass_for(status)
      return STATUS_MAP[status] if STATUS_MAP.key?(status)
      return ServerError if status >= 500

      APIError
    end
  end
end

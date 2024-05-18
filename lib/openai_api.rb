# frozen_string_literal: true

require "faraday"

require_relative "openai_api/version"
require_relative "openai_api/completion"
require_relative "openai_api/completion_multi_model"
require_relative "openai_api/embedding"
require_relative "openai_api/helper"
require_relative "openai_api/stream_merger"

module OpenAIAPI
  class Error < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
  class DeploymentNotFoundError < Error; end
  class NotFoundError < Error; end

  class ContentFilterError < Error
    attr_reader :content_filters

    def initialize(message, content_filters)
      super(message)
      @content_filters = content_filters
    end
  end

  class InvalidRequestError < Error; end
  class UnexpectedResponseError < Error; end
end

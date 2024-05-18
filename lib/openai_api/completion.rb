# frozen_string_literal: true

module OpenAIAPI
  # A class to call the OpenAI API with a single model
  class Completion # rubocop:disable Metrics/ClassLength
    attr_reader :name, :api_key, :api_url
    attr_accessor :stream, :raw

    END_OF_STREAM_MARKER = "[DONE]"

    def initialize(model, stream: nil, raw: false)
      @name = model.name
      @api_key = model.configuration["api_key"]
      @api_url = "https://api.openai.com/v1/chat/completions"
      @stream = stream
      @raw = raw
    end

    def chat(parameters)
      # Rails.logger.info("Chatting with \"#{@name}\" model with URL: #{@api_url}.")
      if @stream.nil?
        single_request_chat(parameters)
      else
        stream_chat(parameters)
      end
    rescue Faraday::ConnectionFailed => e
      # Rails.logger.error("API connection failed: #{e.message}")
      raise OpenAIAPI::ConnectionError, "Connection to API failed: #{e}"
    rescue Faraday::TimeoutError => e
      # Rails.logger.error("API request timed out: #{e.message}")
      raise OpenAIAPI::TimeoutError, "API request timed out: #{e}"
    end

    private

    def connection
      @connection ||= Faraday.new(url: @api_url, headers: request_headers) do |faraday|
        faraday.options.open_timeout = 60    # set connection timeout
        faraday.options.timeout = 300        # set read timeout
      end
    end

    def request_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }
    end

    def single_request_chat(parameters)
      response = connection.post do |request|
        request.body = parameters.to_json
      end

      return response if @raw

      handle_response(response)
    end

    def handle_response(response)
      return JSON.parse(response.body) if response.status == 200

      handle_error(response.status, response.body)
    end

    def stream_chat(parameters)
      parameters = parameters.merge(stream: true)
      parser = EventStreamParser::Parser.new

      connection.post do |request|
        request.options.on_data = proc do |chunk, _, env|
          handle_stream_chunk(chunk, env, parser)
        end
        request.body = parameters.to_json
      end
    end

    def handle_stream_chunk(chunk, env, parser)
      handle_error(env.status, chunk) unless env.status == 200

      parser.feed(chunk) do |_type, data, _id|
        next if data == END_OF_STREAM_MARKER

        @stream&.call(JSON.parse(data), env)
      end
    end

    def handle_error(status, response_body = nil)
      error_response = parse_error_response(response_body)
      case status
      when 400 then handle_error400(error_response)
      when 401 then raise OpenAIAPI::AuthenticationError, "Invalid API key: \n#{error_response}"
      when 404 then handle_error404(error_response)
      when 429 then raise OpenAIAPI::RateLimitError, "Rate limit exceeded: \n#{error_response}"
      else handle_unknown_error(status, error_response)
      end
    end

    def handle_error404(error_response)
      case error_response["code"]
      when "DeploymentNotFound"
        raise OpenAIAPI::DeploymentNotFoundError, "Deployment not found: \n#{error_response}"
      else
        raise OpenAIAPI::NotFoundError, "Resource not found: \n#{error_response}"
      end
    end

    def handle_error400(error_response)
      case error_response["code"]
      when "content_filter"
        raise OpenAIAPI::ContentFilterError, "Content filter triggered: \n#{error_response}"
      else
        raise OpenAIAPI::InvalidRequestError, "Invalid request: \n#{error_response}"
      end
    end

    def handle_unknown_error(status, error_response)
      error_message = "Unexpected response from API: \n#{status}"
      error_message += " - #{error_response}" unless error_response.empty?
      raise OpenAIAPI::UnexpectedResponseError, error_message
    end

    def parse_error_response(body)
      return "" if body.nil? || body.empty?

      begin
        JSON.parse(body)["error"]
      rescue OpenAIAPI::Error
        "Error details not available"
      end
    end
  end
end

# frozen_string_literal: true

module OpenAIAPI
  # Call the OpenAI API with multiple models
  class CompletionMultiModel
    attr_reader :models
    attr_accessor :stream

    def initialize(models, stream: nil)
      @models = models
      @stream = stream
    end

    def chat(parameters) # rubocop:disable Metrics/MethodLength
      return if @models.empty?

      @models.each do |model|
        openai_client = OpenAIAPI::Completion.new(model, stream: @stream)
        return openai_client.chat(parameters)
      rescue OpenAIAPI::NotFoundError,
             OpenAIAPI::DeploymentNotFoundError,
             OpenAIAPI::AuthenticationError,
             OpenAIAPI::RateLimitError,
             OpenAIAPI::InvalidRequestError,
             OpenAIAPI::UnexpectedResponseError => e
        puts "Model #{model.name} not available"
        puts e.message
        puts "Trying next model..."
        next
      end

      raise OpenAIAPI::NotFoundError, "No models available"
    end
  end
end

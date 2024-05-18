# frozen_string_literal: true

require "test_helper"
require "json"
require "dotenv/load"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :faraday
end

class LanguageModel
  attr_accessor :name, :kind, :provider, :configuration

  def initialize(name:, kind:, provider:, configuration:)
    @name = name
    @kind = kind
    @provider = provider
    @configuration = configuration
  end

  def self.all # rubocop:disable Metrics/MethodLength
    ada2 = LanguageModel.new(
      name: "Ada2",
      kind: "embedding",
      provider: "openai",
      configuration: {
        "api_key" => ENV.fetch("OPENAI_API_KEY"),
        "model" => "text-embedding-ada-002"
      }
    )

    gpt4turbo = LanguageModel.new(
      name: "GPT-4-Turbo",
      kind: "completion",
      provider: "openai",
      configuration: {
        "api_key" => ENV.fetch("OPENAI_API_KEY"),
        "model" => "gpt-4-turbo"
      }
    )

    [ada2, gpt4turbo]
  end
end

class TestOpenAIAPI < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::OpenAIAPI::VERSION
  end

  def test_helper_clean_body # rubocop:disable Metrics/MethodLength
    response = File.read(File.expand_path("fixtures/response.json", __dir__))
    json = JSON.parse(response)

    result = {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => "Why don't scientists trust atoms?\n\nBecause they make up everything!"
          }
        }
      ],
      "usage" => {
        "prompt_tokens" => 11,
        "completion_tokens" => 13,
        "total_tokens" => 24
      }
    }

    assert_equal result, OpenAIAPI::Helper.clean_body(json)
  end

  def test_stream_merger_content
    kind = "content"
    test_stream_merger(kind)
  end

  def test_stream_merger_tool_calls
    kind = "tool_calls"
    test_stream_merger(kind)
  end

  def test_chat # rubocop:disable Metrics/MethodLength
    first_completion_model = LanguageModel.all.find { |model| model.kind == "completion" }
    client = OpenAIAPI::Completion.new(first_completion_model)
    parameters = {
      "messages" => [
        {
          "role" => "system",
          "content" => "Tell me a joke"
        }
      ],
      "model": "gpt-4o"
    }

    VCR.use_cassette("test_chat") do
      response = client.chat(parameters)
      completion_text = response.dig("choices", 0, "message", "content")

      assert_instance_of String, completion_text
    end
  end

  def test_chat_content_filter # rubocop:disable Metrics/MethodLength
    first_completion_model = LanguageModel.all.find { |model| model.kind == "completion" }
    client = OpenAIAPI::Completion.new(first_completion_model)
    parameters = {
      "messages" => [
        {
          "role" => "system",
          "content" => "You are a nice bot."
        },
        {
          "role" => "user",
          "content" => "FUCK SHIT PISS."
        }
      ],
      "model": "gpt-4o"
    }

    VCR.use_cassette("test_chat_content_filter") do
      response = client.chat(parameters)
      completion_text = response.dig("choices", 0, "message", "content")

      assert_instance_of String, completion_text
    end
  end

  def test_embedding
    first_embedding_model = LanguageModel.all.find { |model| model.kind == "embedding" }
    client = OpenAIAPI::Embedding.new(first_embedding_model)
    parameters = {
      "input" => "Once upon a time",
      "model": "text-embedding-ada-002",
    }

    VCR.use_cassette("test_embedding") do
      response = client.embed(parameters)
      embedding = response.dig("data", 0, "embedding")

      assert_instance_of Array, embedding
    end
  end

  private

  def test_stream_merger(kind) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    input_file_path = "stream_#{kind}.jsonl"
    reference_file_path = "stream_#{kind}_result.json"

    merger = OpenAIAPI::StreamMerger.new

    stream_data = File
                  .read(File.expand_path("fixtures/#{input_file_path}", __dir__))
                  .each_line
                  .map { |line| JSON.parse(line) unless line.strip.empty? }
                  .compact

    stream_data.each do |stream_chunk|
      merger.merge(stream_chunk)
    end

    merged_stream_data = merger.merged

    # Ensuring choices are sorted by index for consistency
    merged_stream_data["choices"].sort_by! { |choice| choice["index"] }

    reference = JSON.parse(File.read(File.expand_path("fixtures/#{reference_file_path}", __dir__)))

    assert_equal reference, merged_stream_data, "Stream merger failed for #{kind}"
  end
end

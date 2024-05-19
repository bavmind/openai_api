# OpenAI API

## Installation

Install the gem and add to the application's Gemfile by executing:

```sh
bundle add openai_api
```

If bundler is not being used to manage dependencies, install the gem by executing:

```sh
gem install openai_api
```

## Usage

```ruby
class LanguageModel
  attr_accessor :name, :kind, :provider, :configuration

  def initialize(name:, kind:, provider:, configuration:)
    @name = name
    @kind = kind
    @provider = provider
    @configuration = configuration
  end

  def self.all
    gpt_4o = LanguageModel.new(
      name: "GPT-4o",
      kind: "completion",
      provider: "openai",
      configuration: {
        "api_key" => "your_key",
        "model" => "gpt-4o"
      }
    )

    ada2 = LanguageModel.new(
      name: "Ada2",
      kind: "embedding",
      provider: "openai",
      configuration: {
        "api_key" => "your_key",
        "model" => "text-embedding-ada-002"
      }
    )

    [gpt_4o, ada2]
  end
end

first_completion_model = LanguageModel.all.find { |model| model.kind == "completion" }

parameters = {
  "messages" => [
    {
      "role" => "system",
      "content" => "Tell me a joke"
    }
  ]
}
response = OpenAIAPI::Completion
  .new(first_completion_model)
  .chat(parameters)
puts response


first_embedding_model = LanguageModel.all.find { |model| model.kind == "embedding" }

parameters = {
  "input" => "Once upon a time"
}
response = OpenAIAPI::Embedding
  .new(first_embedding_model)
  .embed(parameters)
puts response
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

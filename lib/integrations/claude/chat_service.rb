# One chat completion against the Anthropic Messages API with the account's Claude
# integration key, returning the reply text. Raises the same Faraday errors the
# ruby-openai client raises, so callers keep their existing error handling.
class Integrations::Claude::ChatService
  API_BASE = 'https://api.anthropic.com/v1'.freeze
  # Required by the Anthropic API on every request.
  ANTHROPIC_VERSION = '2023-06-01'.freeze
  DEFAULT_MODEL = 'claude-haiku-4-5'.freeze
  # Keep in sync with the model options in config/integration/apps.yml.
  MODELS = %w[claude-haiku-4-5 claude-sonnet-4-5 claude-opus-4-5].freeze
  MAX_TOKENS = 2048
  TIMEOUT_SECONDS = 60

  pattr_initialize [:api_key!, :messages!, { model: DEFAULT_MODEL }]

  # The model chosen in the integration settings, or the default when the hook
  # was connected before the setting existed or holds an unknown value.
  def self.selected_model(settings)
    model = settings&.dig('model') || settings&.dig(:model)
    MODELS.include?(model) ? model : DEFAULT_MODEL
  end

  def perform
    text = response_body.fetch('content', []).filter_map do |block|
      block['text'] if block['type'] == 'text'
    end.join
    text.presence
  end

  private

  def response_body
    response = connection.post("#{API_BASE}/messages") do |req|
      req.headers['x-api-key'] = api_key
      req.headers['anthropic-version'] = ANTHROPIC_VERSION
      req.headers['Content-Type'] = 'application/json'
      req.body = request_body.to_json
    end
    JSON.parse(response.body)
  end

  def connection
    Faraday.new do |f|
      f.response :raise_error
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
    end
  end

  # The Anthropic API takes the system prompt outside the message list.
  def request_body
    {
      model: model,
      max_tokens: MAX_TOKENS,
      system: system_content,
      messages: conversation_messages
    }.compact
  end

  def system_content
    system_messages = messages.select { |message| role_of(message) == 'system' }
    system_messages.map { |message| content_of(message) }.join("\n").presence
  end

  def conversation_messages
    messages.reject { |message| role_of(message) == 'system' }
            .map { |message| { role: role_of(message), content: content_of(message) } }
  end

  def role_of(message)
    (message[:role] || message['role']).to_s
  end

  def content_of(message)
    message[:content] || message['content']
  end
end

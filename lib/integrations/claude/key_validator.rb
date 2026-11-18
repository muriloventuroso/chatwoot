module Integrations::Claude::KeyValidator
  API_BASE = 'https://api.anthropic.com/v1'.freeze
  # Required by the Anthropic API on every request.
  ANTHROPIC_VERSION = '2023-06-01'.freeze
  TIMEOUT_SECONDS = 5

  def self.valid?(api_key)
    return false if api_key.blank?

    connection = Faraday.new do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
    end

    response = connection.get("#{API_BASE}/models") do |req|
      req.headers['x-api-key'] = api_key
      req.headers['anthropic-version'] = ANTHROPIC_VERSION
    end

    response.status != 401
  rescue Faraday::Error => e
    Rails.logger.warn("[claude-key-validator] #{e.class}: #{e.message}")
    true
  end
end

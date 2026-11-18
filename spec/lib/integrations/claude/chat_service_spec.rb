require 'rails_helper'

RSpec.describe Integrations::Claude::ChatService do
  let(:messages_url) { 'https://api.anthropic.com/v1/messages' }
  let(:messages) do
    [
      { role: 'system', content: 'You summarize conversations.' },
      { role: 'user', content: 'Customer: my order never arrived' }
    ]
  end

  it 'returns the text blocks of the Anthropic reply' do
    stub_request(:post, messages_url).to_return(
      status: 200,
      body: { content: [{ type: 'text', text: 'Order is missing.' }] }.to_json
    )

    expect(described_class.new(api_key: 'sk-ant-key', messages: messages).perform).to eq('Order is missing.')
  end

  it 'sends the system prompt outside the messages and authenticates with the api key' do
    stub_request(:post, messages_url).to_return(status: 200, body: { content: [] }.to_json)

    described_class.new(api_key: 'sk-ant-key', messages: messages).perform

    expect(WebMock).to have_requested(:post, messages_url)
      .with(
        headers: { 'X-Api-Key' => 'sk-ant-key', 'Anthropic-Version' => '2023-06-01' },
        body: {
          model: 'claude-haiku-4-5',
          max_tokens: described_class::MAX_TOKENS,
          system: 'You summarize conversations.',
          messages: [{ role: 'user', content: 'Customer: my order never arrived' }]
        }.to_json
      )
  end

  it 'raises the same Faraday error the OpenAI client raises for a revoked key' do
    stub_request(:post, messages_url).to_return(status: 401)

    expect do
      described_class.new(api_key: 'sk-ant-bad', messages: messages).perform
    end.to raise_error(Faraday::UnauthorizedError)
  end

  it 'returns nil when the reply has no text' do
    stub_request(:post, messages_url).to_return(status: 200, body: { content: [] }.to_json)

    expect(described_class.new(api_key: 'sk-ant-key', messages: messages).perform).to be_nil
  end
end

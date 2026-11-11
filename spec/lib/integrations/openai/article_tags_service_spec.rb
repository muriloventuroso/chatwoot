require 'rails_helper'

RSpec.describe Integrations::Openai::ArticleTagsService do
  let(:account) { create(:account) }
  let(:portal) { create(:portal, account: account) }
  let(:article) do
    create(:article, account: account, portal: portal, title: 'Paying an invoice', content: 'Open the billing page.',
                     draft_content: 'Open the billing page and pick a card.')
  end
  let(:openai_client) { instance_double(OpenAI::Client) }

  before do
    allow(Integrations::Openai::KeyValidator).to receive(:valid?).and_return(true)
    create(:integrations_hook, :openai, account: account, settings: { 'api_key' => 'account-key' })
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(openai_client).to receive(:chat).and_return(
      { 'choices' => [{ 'message' => { 'content' => '{"tags": [" Billing ", "billing", "Invoices", ""]}' } }] }
    )
  end

  it 'returns the suggested tags stripped and without case-insensitive duplicates' do
    expect(described_class.new(article: article).perform).to eq(%w[Billing Invoices])
    expect(OpenAI::Client).to have_received(:new).with(hash_including(access_token: 'account-key'))
  end

  it 'sends the draft content and offers the tags already used in the portal locale' do
    create(:article, account: account, portal: portal, meta: { 'tags' => ['Payments'] })
    create(:article, account: account, portal: portal, locale: 'es', meta: { 'tags' => ['Pagos'] })

    described_class.new(article: article).perform

    expect(openai_client).to have_received(:chat) do |parameters:|
      system_prompt, article_text = parameters[:messages].pluck(:content)
      expect(system_prompt).to include('Payments')
      expect(system_prompt).not_to include('Pagos')
      expect(article_text).to include('Paying an invoice', 'pick a card')
    end
  end
end

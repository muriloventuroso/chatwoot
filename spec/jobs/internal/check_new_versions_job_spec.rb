require 'rails_helper'

RSpec.describe Internal::CheckNewVersionsJob do
  it 'clears a stored latest version without asking GitHub, so no update notice shows' do
    Redis::Alfred.set(Redis::Alfred::LATEST_CHATWOOT_VERSION, '99.0.0')

    described_class.perform_now

    expect(Redis::Alfred.get(Redis::Alfred::LATEST_CHATWOOT_VERSION)).to be_nil
    expect(a_request(:get, /api\.github\.com/)).not_to have_been_made
  end
end

# An agent asks for the conversation to be summarized with the account's AI integration
# key (Claude preferred over OpenAI). The work runs in a job and the summary reaches the
# thread as a private note, through the message's creation event.
class Api::V1::Accounts::Conversations::SummariesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_llm_integration
  before_action :ensure_summarizable

  def create
    Integrations::Openai::ConversationSummaryJob.perform_later(@conversation, Current.user)
    head :accepted
  end

  private

  def ensure_llm_integration
    return if Integrations::Hook.preferred_llm_hook(Current.account)

    render json: { error: 'AI integration is not enabled' }, status: :unprocessable_entity
  end

  def ensure_summarizable
    return if Integrations::Openai::ConversationSummaryService.summarizable?(@conversation)

    render json: { error: 'Conversation has no messages to summarize' }, status: :unprocessable_entity
  end
end

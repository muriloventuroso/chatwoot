# Summarizes a conversation with the account's AI integration key (Claude preferred over
# OpenAI), on an agent's request, and saves the result as a private note in the conversation.
# Used both by the manual "summarize" action, by the automatic handoff summary when a
# conversation changes agent, and on every resolution (HookListener). Without a user, as on
# an unassigned resolution, the note has no sender.
#
# Captain's SummaryService does a similar call, but it runs on Captain's installation key and
# credits and is stripped from CE images; this one only needs the AI integration hook.
class Integrations::Openai::ConversationSummaryService
  MESSAGE_LIMIT = 50

  pattr_initialize [:conversation!, :user]

  def self.summarizable?(conversation)
    conversation.messages.exists?(message_type: [:incoming, :outgoing], private: false)
  end

  def perform
    # The integration can be turned off between the request and the job.
    return if llm_hook.blank?
    return unless self.class.summarizable?(conversation)

    summary = summarize
    return if summary.blank?

    Messages::MessageBuilder.new(user, conversation, note_params(summary)).perform
  end

  private

  def note_params(summary)
    {
      content: "**#{I18n.t('integrations.openai.summary_note_title', locale: conversation.account.locale)}**\n\n#{summary}",
      private: true,
      content_attributes: { ai_summary: true }
    }
  end

  def summarize
    return openai_summary(llm_hook) unless llm_hook.claude?

    claude_summary
  rescue Faraday::Error => e
    raise unless llm_hook.claude? && openai_hook

    Rails.logger.warn("[claude] Conversation summary failed (#{e.class}), falling back to OpenAI")
    openai_summary(openai_hook)
  end

  def claude_summary
    Integrations::Claude::ChatService.new(
      api_key: llm_hook.settings['api_key'],
      model: Integrations::Claude::ChatService.selected_model(llm_hook.settings),
      messages: prompt_messages
    ).perform
  end

  def openai_summary(hook)
    response = client_for(hook).chat(parameters: { model: Llm::Config::DEFAULT_MODEL, messages: prompt_messages })
    response.dig('choices', 0, 'message', 'content')
  end

  def prompt_messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: transcript }
    ]
  end

  def system_prompt
    prompt = Rails.root.join('lib/integrations/openai/openai_prompts/summary.liquid').read
    "#{prompt}\nReply in #{conversation.account.locale_english_name}."
  end

  def transcript
    conversation.messages
                .where(message_type: [:incoming, :outgoing], private: false)
                .reorder(id: :desc)
                .limit(MESSAGE_LIMIT)
                .filter_map { |message| transcript_entry(message) }
                .reverse
                .join("\n")
  end

  def transcript_entry(message)
    text = message.content_for_llm
    "#{message.incoming? ? 'Customer' : 'Agent'}: #{text}" if text.present?
  end

  def llm_hook
    @llm_hook ||= Integrations::Hook.preferred_llm_hook(conversation.account)
  end

  def openai_hook
    @openai_hook ||= conversation.account.hooks.enabled.find_by(app_id: 'openai')
  end

  def client_for(hook)
    OpenAI::Client.new(
      access_token: hook.settings['api_key'],
      uri_base: InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    )
  end
end

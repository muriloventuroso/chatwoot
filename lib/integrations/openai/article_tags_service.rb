# Suggests tags for a help center article with the account's OpenAI integration key. The tags already used
# in the portal are offered to the model first, because related articles are matched on shared tags.
class Integrations::Openai::ArticleTagsService
  EXISTING_TAGS_LIMIT = 200
  CONTENT_LIMIT = 20_000

  pattr_initialize [:article!]

  def perform
    response = client.chat(
      parameters: {
        model: Llm::Config::DEFAULT_MODEL,
        response_format: { type: 'json_object' },
        messages: [{ role: 'system', content: system_prompt }, { role: 'user', content: article_text }]
      }
    )
    tags = JSON.parse(response.dig('choices', 0, 'message', 'content'))['tags']
    Array(tags).map { |tag| tag.to_s.strip }.compact_blank.uniq(&:downcase)
  end

  private

  def system_prompt
    <<~PROMPT
      You tag help center articles so that readers can find related articles.
      Return 3 to 6 short tags (one to three words each) describing the main topics of the article,
      written in the article's language (#{article.locale}).
      Prefer reusing these tags already used in the help center when they fit: #{existing_tags.join(', ').presence || 'none'}.
      Reply only with JSON in the format {"tags": ["tag 1", "tag 2"]}.
    PROMPT
  end

  def article_text
    title = article.draft_title || article.title
    content = article.draft_content || article.content
    "# #{title}\n\n#{content.to_s.first(CONTENT_LIMIT)}"
  end

  def existing_tags
    article.portal.articles.where(locale: article.locale).where.not(id: article.id)
           .pluck(:meta).flat_map { |meta| meta['tags'] || [] }.uniq(&:downcase).first(EXISTING_TAGS_LIMIT)
  end

  def client
    OpenAI::Client.new(
      access_token: article.account.hooks.find_by!(app_id: 'openai', status: 'enabled').settings['api_key'],
      uri_base: InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    )
  end
end

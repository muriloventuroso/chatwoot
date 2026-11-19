FactoryBot.define do
  factory :article_slug_redirect do
    article
    account { article.account }
    slug { "old-#{SecureRandom.hex(4)}" }
  end
end

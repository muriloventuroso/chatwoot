# == Schema Information
#
# Table name: article_slug_redirects
#
#  id         :bigint           not null, primary key
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  article_id :bigint           not null
#
# Indexes
#
#  index_article_slug_redirects_on_account_id  (account_id)
#  index_article_slug_redirects_on_article_id  (article_id)
#  index_article_slug_redirects_on_slug        (slug) UNIQUE
#
class ArticleSlugRedirect < ApplicationRecord
  belongs_to :account
  belongs_to :article

  validates :slug, presence: true,
                   uniqueness: true,
                   format: { with: /\A[a-zA-Z0-9_-]+\z/ },
                   exclusion: { in: Article::RESERVED_SLUGS }
  validate :slug_not_taken_by_article

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id ||= article&.account_id
  end

  def slug_not_taken_by_article
    return if slug.blank?
    return unless Article.exists?(slug: slug)

    errors.add(:slug, :taken)
  end
end

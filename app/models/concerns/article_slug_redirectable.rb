module ArticleSlugRedirectable
  extend ActiveSupport::Concern

  included do
    has_many :slug_redirects, class_name: 'ArticleSlugRedirect', dependent: :destroy, inverse_of: :article

    # When true on update, the previous slug is kept as a 301 redirect target.
    attr_accessor :create_redirect

    validate :slug_not_taken_by_redirect, if: :will_save_change_to_slug?
    after_update :record_slug_redirect, if: :saved_change_to_slug?
  end

  private

  def slug_not_taken_by_redirect
    return if slug.blank?
    # Reclaiming this article's own redirect is fine — record_slug_redirect drops it.
    return unless ArticleSlugRedirect.where(slug: slug).where.not(article_id: id).exists?

    errors.add(:slug, :taken)
  end

  def record_slug_redirect
    previous_slug = slug_before_last_save
    slug_redirects.where(slug: slug).destroy_all

    return unless ActiveModel::Type::Boolean.new.cast(create_redirect)
    return if previous_slug.blank?
    return if slug_redirects.exists?(slug: previous_slug)

    slug_redirects.create!(slug: previous_slug, account_id: account_id)
  end
end

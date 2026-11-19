require 'rails_helper'

RSpec.describe ArticleSlugRedirect do
  let(:account) { create(:account) }
  let(:portal) { create(:portal, account: account) }
  let(:author) { create(:user, account: account) }
  let(:article) { create(:article, account: account, portal: portal, author: author) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:article) }

    it 'rejects reserved slugs' do
      redirect = build(:article_slug_redirect, article: article, account: account, slug: 'articles')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:slug]).to include('is reserved')
    end

    it 'rejects a slug already used by an article' do
      redirect = build(:article_slug_redirect, article: article, account: account, slug: article.slug)
      expect(redirect).not_to be_valid
      expect(redirect.errors[:slug]).to include('has already been taken')
    end

    it 'rejects duplicate redirect slugs' do
      create(:article_slug_redirect, article: article, account: account, slug: 'old-slug')
      other_article = create(:article, account: account, portal: portal, author: author)
      duplicate = build(:article_slug_redirect, article: other_article, account: account, slug: 'old-slug')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end
  end
end

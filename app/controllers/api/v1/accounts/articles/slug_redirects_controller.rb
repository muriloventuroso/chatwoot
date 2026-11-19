class Api::V1::Accounts::Articles::SlugRedirectsController < Api::V1::Accounts::BaseController
  before_action :portal
  before_action :fetch_article
  before_action :check_authorization
  before_action :fetch_slug_redirect, only: :destroy

  def destroy
    @slug_redirect.destroy!
    head :ok
  end

  private

  def portal
    @portal ||= Current.account.portals.find_by!(slug: params[:portal_id])
  end

  def fetch_article
    @article = @portal.articles.find(params[:article_id])
  end

  def fetch_slug_redirect
    @slug_redirect = @article.slug_redirects.find(params[:id])
  end

  def check_authorization
    authorize(@article, :update?)
  end
end

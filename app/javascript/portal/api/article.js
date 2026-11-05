import axios from 'axios';

const SEARCH_SUGGESTIONS_LIMIT = 8;

class ArticlesAPI {
  constructor() {
    this.baseUrl = '';
  }

  searchArticles(portalSlug, locale, query) {
    let baseUrl = `${this.baseUrl}/hc/${portalSlug}/${locale}/articles.json?query=${query}&per_page=${SEARCH_SUGGESTIONS_LIMIT}`;
    return axios.get(baseUrl);
  }
}

export default new ArticlesAPI();

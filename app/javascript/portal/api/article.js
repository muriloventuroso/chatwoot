import axios from 'axios';

const SEARCH_SUGGESTIONS_LIMIT = 8;

class ArticlesAPI {
  constructor() {
    this.baseUrl = '';
  }

  searchArticles(portalSlug, locale, query, { signal } = {}) {
    return axios.get(
      `${this.baseUrl}/hc/${portalSlug}/${locale}/articles.json`,
      {
        params: { query, per_page: SEARCH_SUGGESTIONS_LIMIT },
        signal,
      }
    );
  }
}

export default new ArticlesAPI();

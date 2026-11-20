<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { PORTALS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import {
  buildPortalArticleURL,
  ARTICLE_STATUSES,
} from 'dashboard/helper/portalHelper';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { rendersIdentically } from 'dashboard/helper/articleDiffHelper';
import allLocales from 'shared/constants/locales.js';
import ArticlesAPI from 'dashboard/api/helpCenter/articles';

import ArticleEditor from 'dashboard/components-next/HelpCenter/Pages/ArticleEditorPage/ArticleEditor.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const articleSlug = computed(() => route.params.articleSlug);
const portalSlug = computed(() => route.params.portalSlug);

const articleById = useMapGetter('articles/articleById');

const article = computed(() => articleById.value(articleSlug.value));

const portalBySlug = useMapGetter('portals/portalBySlug');

const portal = computed(() => portalBySlug.value(portalSlug.value));

const allowedLocales = computed(() =>
  (portal.value?.config.allowed_locales ?? []).map(({ code }) => ({
    code,
    name: allLocales[code],
  }))
);

const isUpdating = ref(false);
const isSaved = ref(false);

const articleLink = computed(() => {
  const { slug: categorySlug, locale: categoryLocale } = article.value.category;
  const { slug: articleSlugValue } = article.value;
  const portalCustomDomain = portal.value?.custom_domain;
  return buildPortalArticleURL(
    portalSlug.value,
    categorySlug,
    categoryLocale,
    articleSlugValue,
    portalCustomDomain
  );
});

// On a published article, title/content edits stage into draft_* columns (kept
// off the live site). Anywhere else they save straight to the live record — and
// we drop any leftover draft (e.g. left behind when the card/bulk menu moved a
// published article to draft) so a later publish can't resurrect stale content.
const stageDraftFields = values => {
  if (article.value?.status !== ARTICLE_STATUSES.PUBLISHED) {
    const hasStaleDraft =
      article.value?.draftTitle != null || article.value?.draftContent != null;
    if (!hasStaleDraft) return values;
    // The editor is showing the staged draft, so promote both fields to the live
    // record (the field being autosaved wins) before dropping the drafts —
    // otherwise saving one field would snap the other back to the old live value.
    return {
      ...values,
      title: values.title ?? article.value.draftTitle ?? article.value.title,
      content:
        values.content ?? article.value.draftContent ?? article.value.content,
      draft_title: null,
      draft_content: null,
    };
  }

  const staged = { ...values };
  ['title', 'content'].forEach(field => {
    if (field in staged) {
      staged[`draft_${field}`] = staged[field];
      delete staged[field];
    }
  });

  // Clear the draft when it matches the live version (a revert, or a body edit
  // the renderer ignores like a blank line) so it doesn't leave a "pending
  // changes" badge with nothing to compare. The title is shown as raw escaped
  // text, so compare it exactly; only the body is Markdown, so compare its render.
  const liveTitle = article.value.title ?? '';
  const liveContent = article.value.content ?? '';
  const nextTitle = staged.draft_title ?? article.value.draftTitle ?? liveTitle;
  const nextContent =
    staged.draft_content ?? article.value.draftContent ?? liveContent;
  if (nextTitle === liveTitle && rendersIdentically(liveContent, nextContent)) {
    staged.draft_title = null;
    staged.draft_content = null;
  }

  return staged;
};

const saveArticle = async ({ ...values }) => {
  isUpdating.value = true;
  try {
    await store.dispatch('articles/update', {
      portalSlug: portalSlug.value,
      articleId: articleSlug.value,
      ...stageDraftFields(values),
    });
    isSaved.value = true;
  } catch (error) {
    const errorMessage =
      error?.message || t('HELP_CENTER.EDIT_ARTICLE_PAGE.API.ERROR');
    useAlert(errorMessage);
  } finally {
    setTimeout(() => {
      isUpdating.value = false;
      isSaved.value = true;
    }, 1500);
  }
};

const isCategoryArticles = computed(() => {
  return (
    route.name === 'portals_categories_articles_index' ||
    route.name === 'portals_categories_articles_edit' ||
    route.name === 'portals_categories_index'
  );
});

const goBackToArticles = () => {
  const { tab, categorySlug, locale } = route.params;
  if (isCategoryArticles.value) {
    router.push({
      name: 'portals_categories_articles_index',
      params: { categorySlug, locale },
    });
  } else {
    router.push({
      name: 'portals_articles_index',
      params: { tab, categorySlug, locale },
    });
  }
};

// Categories in the store may belong to another locale (the article a
// translation was created from), and picking one would move this article there.
const fetchArticleDetails = () => {
  store.dispatch('categories/index', {
    portalSlug: portalSlug.value,
    locale: route.params.locale,
  });
  store.dispatch('articles/show', {
    id: articleSlug.value,
    portalSlug: portalSlug.value,
  });
};

const previewArticle = async () => {
  const status = article.value.status;
  const previewUrl = new URL(articleLink.value);

  // Open during the click so a slow token request cannot trigger popup blocking.
  const previewTab = window.open('about:blank', '_blank');
  if (!previewTab) {
    useAlert(t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.PREVIEW_POPUP_BLOCKED'));
    return;
  }

  previewTab.opener = null;

  try {
    if (status !== ARTICLE_STATUSES.PUBLISHED) {
      const { data } = await ArticlesAPI.getPreviewToken({
        id: articleSlug.value,
        portalSlug: portalSlug.value,
      });
      previewUrl.searchParams.set('preview_token', data.preview_token);
    }

    previewTab.location.replace(previewUrl.toString());
    useTrack(PORTALS_EVENTS.PREVIEW_ARTICLE, { status });
  } catch {
    previewTab.close();
    useAlert(t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.PREVIEW_ERROR'));
  }
};

// fetchArticleDetails follows the new slug and loads the categories of its locale.
const switchTranslation = ({ id, locale }) => {
  router.push({
    name: 'portals_articles_edit',
    params: { portalSlug: portalSlug.value, locale, articleSlug: id },
  });
};

watch(articleSlug, fetchArticleDetails, { immediate: true });
</script>

<template>
  <ArticleEditor
    :article="article"
    :is-updating="isUpdating"
    :is-saved="isSaved"
    :allowed-locales="allowedLocales"
    @save-article="saveArticle"
    @preview-article="previewArticle"
    @go-back="goBackToArticles"
    @switch-translation="switchTranslation"
  />
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { convertToArticleSlug } from 'dashboard/helper/commons';
import { useRoute } from 'vue-router';

import InlineInput from 'dashboard/components-next/inline-input/InlineInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  article: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['saveSlug', 'previewArticle']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const uiFlags = useMapGetter('articles/uiFlags');

// The generated timestamp prefix keeps slugs globally unique, so only the rest is editable.
const slugPrefix = computed(
  () => props.article.slug.match(/^\d{10}-/)?.[0] || ''
);
const slugSuffix = computed(() =>
  props.article.slug.slice(slugPrefix.value.length)
);

const slug = ref('');
const isUpdated = ref(false);
const createRedirect = ref(true);
const deletingRedirectId = ref(null);

const newSlug = computed(() => convertToArticleSlug(slug.value));
const titleSlug = computed(() =>
  convertToArticleSlug(props.article.draftTitle ?? props.article.title)
);
const isChanged = computed(
  () => !!newSlug.value && newSlug.value !== slugSuffix.value
);
const canUseTitle = computed(
  () => !!titleSlug.value && titleSlug.value !== newSlug.value
);
const isUpdating = computed(() => uiFlags.value(props.article.id).isUpdating);
const slugRedirects = computed(() => props.article.slugRedirects || []);

const resetSlug = () => {
  slug.value = slugSuffix.value;
};

watch(
  () => props.article.slug,
  (_slug, previousSlug) => {
    resetSlug();
    isUpdated.value = !!previousSlug;
    createRedirect.value = true;
  },
  { immediate: true }
);

const normalizeSlug = () => {
  slug.value = newSlug.value || slugSuffix.value;
};

const saveSlug = () => {
  if (!isChanged.value || isUpdating.value) return;
  emit('saveSlug', `${slugPrefix.value}${newSlug.value}`, {
    create_redirect: createRedirect.value,
  });
};

const deleteRedirect = async redirectId => {
  if (deletingRedirectId.value) return;
  deletingRedirectId.value = redirectId;
  try {
    await store.dispatch('articles/deleteSlugRedirect', {
      portalSlug: route.params.portalSlug,
      articleId: props.article.id,
      redirectId,
    });
  } catch (error) {
    useAlert(
      error?.message ||
        t(
          'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_REDIRECT_DELETE_ERROR'
        )
    );
  } finally {
    deletingRedirectId.value = null;
  }
};
</script>

<template>
  <div>
    <div class="flex items-center w-full gap-3 py-2">
      <label
        for="article-slug"
        class="mb-0.5 text-sm font-medium whitespace-nowrap min-w-[7.5rem] text-n-slate-12"
      >
        {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG') }}
      </label>
      <div class="flex items-center flex-1 min-w-0">
        <span class="flex-shrink-0 text-sm text-n-slate-10">
          {{ slugPrefix }}
        </span>
        <InlineInput
          id="article-slug"
          v-model="slug"
          :disabled="isUpdating"
          :placeholder="
            t(
              'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_PLACEHOLDER'
            )
          "
          @enter-press="saveSlug"
          @escape-press="resetSlug"
          @blur="normalizeSlug"
        />
        <Button
          v-if="canUseTitle"
          v-tooltip.top="
            t('HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_USE_TITLE')
          "
          icon="i-lucide-refresh-cw"
          size="xs"
          variant="ghost"
          color="slate"
          class="flex-shrink-0"
          :disabled="isUpdating"
          @click="slug = titleSlug"
        />
      </div>
    </div>
    <Banner
      v-if="isChanged"
      color="amber"
      class="mb-2"
      :action-label="
        t('HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_UPDATE')
      "
      :is-loading="isUpdating"
      @action="saveSlug"
    >
      <div class="flex flex-col gap-2">
        <p>
          {{
            createRedirect
              ? t(
                  'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_WARNING_WITH_REDIRECT'
                )
              : t(
                  'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_WARNING'
                )
          }}
        </p>
        <label class="flex items-center gap-2 cursor-pointer">
          <Checkbox v-model="createRedirect" :disabled="isUpdating" />
          <span>
            {{
              t(
                'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_CREATE_REDIRECT'
              )
            }}
          </span>
        </label>
      </div>
    </Banner>
    <Banner
      v-else-if="isUpdated"
      color="teal"
      class="mb-2"
      :action-label="
        t('HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_OPEN')
      "
      @action="emit('previewArticle')"
    >
      {{ t('HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_UPDATED') }}
    </Banner>
    <div
      v-if="slugRedirects.length"
      class="flex flex-col gap-2 py-2 border-t border-n-slate-4"
    >
      <p class="text-sm font-medium text-n-slate-12">
        {{
          t(
            'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_REDIRECTS_TITLE'
          )
        }}
      </p>
      <p class="text-xs text-n-slate-11">
        {{
          t(
            'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_REDIRECTS_HELP'
          )
        }}
      </p>
      <ul class="flex flex-col gap-1">
        <li
          v-for="redirect in slugRedirects"
          :key="redirect.id"
          class="flex items-center justify-between gap-2 py-1"
        >
          <code class="text-xs truncate text-n-slate-11">{{
            redirect.slug
          }}</code>
          <Button
            v-tooltip.top="
              t(
                'HELP_CENTER.EDIT_ARTICLE_PAGE.ARTICLE_PROPERTIES.SLUG_REDIRECT_DELETE'
              )
            "
            icon="i-lucide-trash-2"
            size="xs"
            variant="ghost"
            color="slate"
            :is-loading="deletingRedirectId === redirect.id"
            :disabled="!!deletingRedirectId"
            @click="deleteRedirect(redirect.id)"
          />
        </li>
      </ul>
    </div>
  </div>
</template>

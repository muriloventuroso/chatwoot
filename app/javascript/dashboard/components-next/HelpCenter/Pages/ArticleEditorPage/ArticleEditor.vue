<script setup>
import { ref, computed, watch, onBeforeUnmount, useTemplateRef } from 'vue';
import { useTimeoutFn, useStorage } from '@vueuse/core';
import { onBeforeRouteLeave } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import allLocales from 'shared/constants/locales.js';

import HelpCenterLayout from 'dashboard/components-next/HelpCenter/HelpCenterLayout.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import ArticleEditorHeader from 'dashboard/components-next/HelpCenter/Pages/ArticleEditorPage/ArticleEditorHeader.vue';
import ArticleEditorControls from 'dashboard/components-next/HelpCenter/Pages/ArticleEditorPage/ArticleEditorControls.vue';
import ArticleDiffPanel from 'dashboard/components-next/HelpCenter/Pages/ArticleEditorPage/ArticleDiffPanel.vue';
import AddTranslationDialog from 'dashboard/components-next/HelpCenter/Pages/ArticlePage/AddTranslationDialog.vue';

const props = defineProps({
  article: {
    type: Object,
    default: () => ({}),
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
  isSaved: {
    type: Boolean,
    default: false,
  },
  allowedLocales: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'saveArticle',
  'goBack',
  'setAuthor',
  'setCategory',
  'previewArticle',
  'createArticle',
  'switchTranslation',
]);

const { t } = useI18n();

const isNewArticle = computed(() => !props.article?.id);

// Prefer the draft; `??` keeps a deliberately-cleared empty string instead of
// falling back to the live value.
const effectiveTitle = () =>
  props.article?.draftTitle ?? props.article?.title ?? '';
const effectiveContent = () =>
  props.article?.draftContent ?? props.article?.content ?? '';

const hasPendingChanges = computed(
  () => props.article?.draftTitle != null || props.article?.draftContent != null
);

const localTitle = ref(effectiveTitle());
const localContent = ref(effectiveContent());

const diffPanelRef = ref(null);
const editorRef = useTemplateRef('editorRef');

const hasPendingUploads = () => !!editorRef.value?.hasPendingUploads();

// Content is stored as markdown, so the raw mode edits the same value directly.
const isMarkdownMode = useStorage('help-center:article-markdown-mode', false);

const toggleMarkdownMode = () => {
  // Unmounting the rich editor would drop its in-flight uploads.
  if (hasPendingUploads()) {
    useAlert(t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.UPLOAD_IN_PROGRESS'));
    return;
  }
  isMarkdownMode.value = !isMarkdownMode.value;
};

// The payload carries the whole translation family except this article.
const translations = computed(() => props.article?.associatedArticles ?? []);
const showLocaleMenu = ref(false);

const localeLabel = code => `${allLocales[code] || code} (${code})`;

const addTranslationDialogRef = ref(null);
const ADD_TRANSLATION = 'add-translation';

const canAddTranslation = computed(() => {
  const familyLocales = [props.article, ...translations.value].map(
    ({ locale }) => locale
  );
  return props.allowedLocales.some(({ code }) => !familyLocales.includes(code));
});

const localeMenuItems = computed(() => {
  const items = [props.article, ...translations.value].map(
    ({ id, locale }) => ({
      label: localeLabel(locale),
      value: id,
      action: 'switchTranslation',
      isSelected: id === props.article.id,
    })
  );
  if (!canAddTranslation.value) return items;
  return [
    ...items,
    {
      label: t('HELP_CENTER.ARTICLES_PAGE.ADD_TRANSLATION.TITLE'),
      value: ADD_TRANSLATION,
      action: 'addTranslation',
      icon: 'i-lucide-file-plus-2',
    },
  ];
});

const switchTranslation = ({ value }) => {
  showLocaleMenu.value = false;
  if (value === props.article.id) return;
  // Switching remounts the editor, which would drop its in-flight uploads.
  if (hasPendingUploads()) {
    useAlert(t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.UPLOAD_IN_PROGRESS'));
    return;
  }
  if (value === ADD_TRANSLATION) {
    addTranslationDialogRef.value?.dialogRef?.open();
    return;
  }
  emit(
    'switchTranslation',
    translations.value.find(({ id }) => id === value)
  );
};

// Files picked between the create dispatch and its redirect would die with
// this editor instance; hold them off for that window.
const uploadsBlockedMessage = computed(() =>
  isNewArticle.value && props.isUpdating
    ? t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.CREATE_IN_PROGRESS')
    : ''
);

onBeforeRouteLeave(() => {
  // Always let the post-create redirect through: blocking it strands a "new"
  // page whose article already exists, and the next blur would duplicate it.
  if (isNewArticle.value && props.isUpdating) return true;
  if (!hasPendingUploads()) return true;
  useAlert(t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.UPLOAD_IN_PROGRESS'));
  return false;
});

// Autosave 500ms after the last edit. It sends both title and content so an
// edit to one never drops a recent edit to the other. `stop` cancels a queued
// save; `isPending` tells the header to wait before allowing a publish.
const {
  isPending: isSaving,
  start: debouncedSave,
  stop: cancelSave,
} = useTimeoutFn(
  () =>
    emit('saveArticle', {
      title: localTitle.value,
      content: localContent.value,
    }),
  500,
  { immediate: false }
);

// Definitive reseeds bump the id so the editor reloads instead of guessing echoes.
const editorResets = ref(0);

const syncLocalState = () => {
  cancelSave();
  localTitle.value = effectiveTitle();
  localContent.value = effectiveContent();
  editorResets.value += 1;
};

const editorSessionId = computed(
  () => `${props.article?.id || 'new'}-${editorResets.value}`
);

// Reseed on article switch or once a draft is published/discarded; close the
// diff panel in the latter case since there's nothing left to compare.
watch(
  [() => props.article?.id, hasPendingChanges],
  ([id, pending], [prevId, prevPending]) => {
    if ((id && id !== prevId) || (prevPending && !pending)) syncLocalState();
    if (prevPending && !pending) diffPanelRef.value?.close();
  }
);

const scheduleSave = () => {
  if (isNewArticle.value) return;
  debouncedSave();
};

// A create blocked by uploads re-runs on the next content change once they
// settle — upload completion and card removal both land here as doc changes.
const pendingCreate = ref(false);

const retryPendingCreate = () => {
  if (!pendingCreate.value || hasPendingUploads()) return;
  pendingCreate.value = false;
  if (!localTitle.value.trim()) return;
  emit('createArticle', {
    title: localTitle.value,
    content: localContent.value,
  });
};

// Flush a queued save on unmount so leaving the editor doesn't drop the last edit.
onBeforeUnmount(() => {
  if (isNewArticle.value || !isSaving.value) return;
  cancelSave();
  emit('saveArticle', {
    title: localTitle.value,
    content: localContent.value,
  });
});

const articleTitle = computed({
  get: () => localTitle.value,
  set: value => {
    localTitle.value = value;
    scheduleSave();
  },
});

const articleContent = computed({
  get: () => localContent.value,
  set: content => {
    localContent.value = content;
    retryPendingCreate();
    scheduleSave();
  },
});

const onClickGoBack = () => {
  emit('goBack');
};

const setAuthorId = authorId => {
  emit('setAuthor', authorId);
};

const setCategoryId = categoryId => {
  emit('setCategory', categoryId);
};

const previewArticle = () => {
  emit('previewArticle');
};

const handleCreateArticle = event => {
  if (!isNewArticle.value) return;
  const title = event?.target?.value || '';
  if (!title.trim()) return;
  // Creating navigates to the edit route, which would unmount mid-upload.
  if (hasPendingUploads()) {
    pendingCreate.value = true;
    useAlert(t('HELP_CENTER.EDIT_ARTICLE_PAGE.HEADER.UPLOAD_IN_PROGRESS'));
    return;
  }
  emit('createArticle', { title, content: localContent.value });
};
</script>

<template>
  <HelpCenterLayout :show-header-title="false" :show-pagination-footer="false">
    <template #header-actions>
      <ArticleEditorHeader
        :is-updating="isUpdating"
        :is-saved="isSaved"
        :status="article.status"
        :article-id="article.id"
        :pending-changes="hasPendingChanges"
        :is-saving="isSaving"
        :has-pending-uploads="hasPendingUploads"
        @go-back="onClickGoBack"
        @preview-article="previewArticle"
        @show-diff="diffPanelRef?.open()"
      />
      <ArticleDiffPanel ref="diffPanelRef" :article="article" />
    </template>
    <template #content>
      <div class="flex flex-col gap-3 pl-4 mb-3 rtl:pr-3 rtl:pl-0">
        <TextArea
          v-model="articleTitle"
          auto-height
          min-height="4rem"
          custom-text-area-class="!text-[32px] !leading-[48px] !font-medium !tracking-[0.2px]"
          custom-text-area-wrapper-class="border-0 !bg-transparent dark:!bg-transparent !py-0 !px-0"
          placeholder="Title"
          :autofocus="isNewArticle"
          @blur="handleCreateArticle"
        />
        <div class="flex items-center justify-between gap-4">
          <ArticleEditorControls
            :article="article"
            @save-article="values => emit('saveArticle', values)"
            @set-author="setAuthorId"
            @set-category="setCategoryId"
            @preview-article="previewArticle"
          />
          <div class="flex items-center flex-shrink-0 gap-2">
            <div
              v-if="translations.length || canAddTranslation"
              class="relative"
            >
              <OnClickOutside @trigger="showLocaleMenu = false">
                <Button
                  :label="localeLabel(article.locale)"
                  :title="t('HELP_CENTER.EDIT_ARTICLE_PAGE.SWITCH_LANGUAGE')"
                  icon="i-lucide-languages"
                  variant="ghost"
                  color="slate"
                  size="sm"
                  @click="showLocaleMenu = !showLocaleMenu"
                />
                <DropdownMenu
                  v-if="showLocaleMenu"
                  :menu-items="localeMenuItems"
                  class="w-56 mt-2 z-[100] ltr:right-0 rtl:left-0 top-full"
                  @action="switchTranslation"
                />
              </OnClickOutside>
            </div>
            <Button
              :label="
                isMarkdownMode
                  ? t('HELP_CENTER.ARTICLE_EDITOR.VISUAL_MODE')
                  : t('HELP_CENTER.ARTICLE_EDITOR.MARKDOWN_MODE')
              "
              :icon="isMarkdownMode ? 'i-lucide-pencil-line' : 'i-lucide-code'"
              variant="ghost"
              color="slate"
              size="sm"
              @click="toggleMarkdownMode"
            />
          </div>
        </div>
      </div>
      <TextArea
        v-if="isMarkdownMode"
        v-model="articleContent"
        auto-height
        min-height="60vh"
        max-height="none"
        class="pb-10 pl-4 rtl:pr-4 rtl:pl-0"
        custom-text-area-class="font-mono !text-sm !leading-6"
        :placeholder="
          t('HELP_CENTER.EDIT_ARTICLE_PAGE.EDIT_ARTICLE.EDITOR_PLACEHOLDER')
        "
        :autofocus="!isNewArticle"
      />
      <FullEditor
        v-else
        ref="editorRef"
        v-model="articleContent"
        :editor-id="editorSessionId"
        class="py-0 pb-10 pl-4 rtl:pr-4 rtl:pl-0 h-fit"
        :placeholder="
          t('HELP_CENTER.EDIT_ARTICLE_PAGE.EDIT_ARTICLE.EDITOR_PLACEHOLDER')
        "
        :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
        :uploads-blocked-message="uploadsBlockedMessage"
        :autofocus="!isNewArticle"
      />
      <AddTranslationDialog
        ref="addTranslationDialogRef"
        :article="article"
        :allowed-locales="allowedLocales"
        @translation-created="
          ({ articleId, locale }) =>
            emit('switchTranslation', { id: articleId, locale })
        "
      />
    </template>
  </HelpCenterLayout>
</template>

<style lang="scss" scoped>
:deep(.ProseMirror .empty-node::before) {
  @apply text-n-slate-10 text-base;
}

:deep(.ProseMirror-menubar-wrapper) {
  .ProseMirror-woot-style {
    @apply min-h-[15rem] max-h-full;
  }
}

// Fixed toolbar: always visible and pinned to the top of the scrolling
// editor area, instead of the floating bubble shown on text selection.
:deep(.ProseMirror-menubar) {
  @apply sticky top-0 z-40 flex flex-wrap items-center gap-4 rounded-lg !px-3 !py-1.5 mb-3 bg-n-background shadow-md outline outline-1 outline-n-weak;
  width: 100% !important;

  .ProseMirror-menuitem {
    @apply ltr:mr-0 rtl:ml-0 size-4 flex items-center;

    .ProseMirror-icon {
      @apply p-0.5 flex-shrink-0 ltr:mr-2 rtl:ml-2;
    }
  }

  .ProseMirror-menu-active {
    @apply bg-n-slate-3;
  }
}

:deep(.ProseMirror-menubar:not(:has(*))) {
  display: none !important;
}
</style>

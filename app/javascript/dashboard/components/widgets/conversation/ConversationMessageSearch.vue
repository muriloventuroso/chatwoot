<script setup>
import { ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useDebounceFn, useToggle } from '@vueuse/core';
import SearchAPI from 'dashboard/api/search';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import MessageContent from 'dashboard/modules/search/components/MessageContent.vue';

const props = defineProps({
  // The conversation's display_id, as the dashboard knows it
  conversationId: {
    type: Number,
    required: true,
  },
});

const PER_PAGE = 15;
const SEARCH_DEBOUNCE_MS = 300;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { run, abort, isPending } = useAbortableRequest();

const [isOpen, toggleOpen] = useToggle(false);
const query = ref('');
const messages = ref([]);
const page = ref(1);
const hasMore = ref(false);
const hasError = ref(false);
// Query of the last finished search, so "no results" never shows for a query still being debounced
const searchedQuery = ref('');

const fetchMessages = async () => {
  const q = query.value.trim();
  if (!q) {
    abort();
    messages.value = [];
    hasMore.value = false;
    return;
  }

  hasError.value = false;
  try {
    const data = await run(signal =>
      SearchAPI.messages({
        q,
        page: page.value,
        conversationId: props.conversationId,
        signal,
      }).then(response => response.data)
    );
    if (!data) return;

    const results = useCamelCase(data.payload.messages, { deep: true });
    messages.value =
      page.value === 1 ? results : [...messages.value, ...results];
    hasMore.value = results.length === PER_PAGE;
    searchedQuery.value = q;
  } catch {
    hasError.value = true;
  }
};

const searchFromStart = useDebounceFn(() => {
  page.value = 1;
  fetchMessages();
}, SEARCH_DEBOUNCE_MS);

const loadMore = () => {
  page.value += 1;
  fetchMessages();
};

const reset = () => {
  abort();
  query.value = '';
  searchedQuery.value = '';
  messages.value = [];
  hasMore.value = false;
  hasError.value = false;
};

const close = () => toggleOpen(false);

const openMessage = message => {
  router.push({ query: { ...route.query, messageId: message.id } });
  close();
};

watch(query, searchFromStart);
watch(() => props.conversationId, reset);
watch(isOpen, open => {
  if (!open) reset();
});
</script>

<template>
  <div
    v-on-clickaway="close"
    class="relative flex items-center group"
    @keydown.esc="close"
  >
    <ButtonV4
      v-tooltip="t('CONVERSATION.HEADER.MESSAGE_SEARCH.BUTTON')"
      :aria-label="t('CONVERSATION.HEADER.MESSAGE_SEARCH.BUTTON')"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-search"
      class="rounded-md group-hover:bg-n-alpha-2"
      @click="toggleOpen()"
    />
    <div
      v-if="isOpen"
      class="absolute top-full mt-1 end-0 z-50 flex flex-col w-96 max-w-[calc(100vw-2rem)] max-h-[28rem] rounded-xl shadow-lg overflow-hidden bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-container"
    >
      <div class="relative shrink-0 m-2">
        <span
          class="absolute i-lucide-search size-3.5 top-1/2 -translate-y-1/2 start-3 text-n-slate-11"
        />
        <input
          v-model="query"
          v-focus
          type="search"
          :placeholder="t('CONVERSATION.HEADER.MESSAGE_SEARCH.PLACEHOLDER')"
          class="reset-base w-full h-8 py-2 ps-10 pe-2 text-sm focus:outline-none border-none rounded-lg bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12"
        />
      </div>
      <div
        v-if="query.trim()"
        class="flex flex-col min-h-0 overflow-y-auto px-2 pb-2"
      >
        <p v-if="hasError" class="px-2 py-3 text-sm text-n-ruby-11">
          {{ t('CONVERSATION.HEADER.MESSAGE_SEARCH.ERROR') }}
        </p>
        <p
          v-else-if="searchedQuery === query.trim() && !messages.length"
          class="px-2 py-3 text-sm text-n-slate-11"
        >
          {{ t('CONVERSATION.HEADER.MESSAGE_SEARCH.EMPTY') }}
        </p>
        <ul class="list-none m-0 flex flex-col gap-1">
          <li v-for="message in messages" :key="message.id">
            <button
              type="button"
              class="w-full text-start flex flex-col gap-1 px-2 py-2 rounded-lg hover:bg-n-alpha-2"
              @click="openMessage(message)"
            >
              <span class="text-xs text-n-slate-11">
                {{ dynamicTime(message.createdAt) }}
              </span>
              <MessageContent
                :author="message.sender?.name || t('SEARCH.BOT_LABEL')"
                :message="message"
                :search-term="query.trim()"
              />
            </button>
          </li>
        </ul>
        <div v-if="isPending" class="flex justify-center py-3">
          <Spinner />
        </div>
        <ButtonV4
          v-else-if="hasMore"
          :label="t('CONVERSATION.HEADER.MESSAGE_SEARCH.LOAD_MORE')"
          size="sm"
          variant="ghost"
          color="slate"
          class="self-center mt-1"
          @click="loadMore"
        />
      </div>
    </div>
  </div>
</template>

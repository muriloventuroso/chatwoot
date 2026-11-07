<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { DUE_TONE_CLASS, PRIORITY_CLASS, dueTone } from '../constants';
import { useDueDate } from '../useDueDate';

const props = defineProps({
  task: { type: Object, required: true },
});

const emit = defineEmits(['open']);
const { t } = useI18n();
const { formatDate, relativeDue } = useDueDate();

const isDone = computed(() => props.task.status === 'done');

const due = computed(() => {
  const date = props.task.due_date;
  if (!date) return null;
  return {
    label: formatDate(date),
    title: isDone.value ? '' : relativeDue(date),
    class: DUE_TONE_CLASS[dueTone(date, isDone.value)],
  };
});

const coverImage = computed(() =>
  props.task.attachments?.find(attachment =>
    attachment.file_type?.startsWith('image/')
  )
);
</script>

<template>
  <button
    type="button"
    :data-task-card="task.id"
    class="flex flex-col w-full gap-2 p-3 transition-shadow border shadow-sm select-none text-start rounded-lg bg-n-solid-1 border-n-weak hover:shadow-md hover:border-n-strong cursor-grab active:cursor-grabbing"
    @click="emit('open', task)"
  >
    <img
      v-if="coverImage"
      :src="coverImage.file_url"
      :alt="coverImage.filename"
      loading="lazy"
      class="object-cover w-full rounded-md max-h-32"
    />
    <span class="flex items-start gap-1.5">
      <Icon
        v-if="isDone"
        icon="i-lucide-circle-check"
        class="size-4 shrink-0 mt-0.5 text-n-teal-10"
      />
      <span
        class="text-sm font-medium break-words line-clamp-3"
        :class="isDone ? 'text-n-slate-11' : 'text-n-slate-12'"
      >
        {{ task.title }}
      </span>
    </span>
    <span
      class="flex flex-wrap items-center w-full text-xs gap-x-2.5 gap-y-1.5 text-n-slate-11"
    >
      <span
        class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded font-medium"
        :class="PRIORITY_CLASS[task.priority]"
      >
        <Icon icon="i-lucide-flag" class="size-3" />
        {{ t(`PROJECTS.TASK.PRIORITY.${task.priority.toUpperCase()}`) }}
      </span>
      <span
        v-if="due"
        class="inline-flex items-center gap-1"
        :class="due.class"
        :title="due.title"
      >
        <Icon icon="i-lucide-calendar" class="size-3.5" />
        {{ due.label }}
      </span>
      <span v-if="task.subtasks_count" class="inline-flex items-center gap-1">
        <Icon icon="i-lucide-list-checks" class="size-3.5" />
        {{ `${task.completed_subtasks_count}/${task.subtasks_count}` }}
      </span>
      <span v-if="task.comments_count" class="inline-flex items-center gap-1">
        <Icon icon="i-lucide-message-circle" class="size-3.5" />
        {{ task.comments_count }}
      </span>
      <span
        v-if="task.attachments?.length"
        class="inline-flex items-center gap-1"
      >
        <Icon icon="i-lucide-paperclip" class="size-3.5" />
        {{ task.attachments.length }}
      </span>
      <Avatar
        v-if="task.assignee"
        :name="task.assignee.name"
        :src="task.assignee.thumbnail"
        :size="20"
        :title="task.assignee.name"
        rounded-full
        class="ms-auto"
      />
    </span>
  </button>
</template>

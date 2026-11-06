<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  PRIORITY_BORDER_CLASS,
  PRIORITY_CLASS,
  daysUntilDue,
} from '../constants';

const props = defineProps({
  task: { type: Object, required: true },
});

const emit = defineEmits(['open']);
const { t } = useI18n();

const isOverdue = computed(
  () =>
    !!props.task.due_date &&
    props.task.status !== 'done' &&
    daysUntilDue(props.task.due_date) < 0
);

const coverImage = computed(() =>
  props.task.attachments?.find(attachment =>
    attachment.file_type?.startsWith('image/')
  )
);

const formattedDueDate = computed(() => {
  if (!props.task.due_date) return '';
  return new Date(`${props.task.due_date}T00:00:00`).toLocaleDateString();
});
</script>

<template>
  <button
    type="button"
    class="flex flex-col w-full gap-2 p-3 text-start border border-s-4 rounded-xl bg-n-solid-1 border-n-strong shadow-sm cursor-grab active:cursor-grabbing hover:shadow-md hover:border-y-n-slate-7 hover:border-e-n-slate-7"
    :class="PRIORITY_BORDER_CLASS[task.priority]"
    @click="emit('open', task)"
  >
    <span
      class="text-[11px] font-medium rounded-md self-start px-1.5 py-0.5"
      :class="PRIORITY_CLASS[task.priority]"
    >
      {{ t(`PROJECTS.TASK.PRIORITY.${task.priority.toUpperCase()}`) }}
    </span>
    <span class="text-sm font-medium text-n-slate-12 line-clamp-3">
      {{ task.title }}
    </span>
    <img
      v-if="coverImage"
      :src="coverImage.file_url"
      :alt="coverImage.filename"
      loading="lazy"
      class="object-cover w-full border rounded-lg max-h-40 border-n-weak"
    />
    <span
      class="flex items-center justify-between gap-2 pt-2 border-t border-n-weak"
    >
      <span class="flex items-center gap-3 text-xs text-n-slate-10">
        <span v-if="task.subtasks_count" class="flex items-center gap-1">
          <Icon icon="i-lucide-list-checks" class="size-3.5" />
          {{ task.completed_subtasks_count }}/{{ task.subtasks_count }}
        </span>
        <span v-if="task.comments_count" class="flex items-center gap-1">
          <Icon icon="i-lucide-message-circle" class="size-3.5" />
          {{ task.comments_count }}
        </span>
        <span v-if="task.attachments?.length" class="flex items-center gap-1">
          <Icon icon="i-lucide-paperclip" class="size-3.5" />
          {{ task.attachments.length }}
        </span>
      </span>
      <span class="flex items-center gap-2 ms-auto">
        <span
          v-if="task.due_date"
          class="text-xs"
          :class="isOverdue ? 'text-n-ruby-11 font-medium' : 'text-n-slate-11'"
          :title="isOverdue ? t('PROJECTS.DETAILS.OVERDUE') : undefined"
        >
          {{ formattedDueDate }}
        </span>
        <Avatar
          v-if="task.assignee"
          :name="task.assignee.name"
          :src="task.assignee.thumbnail"
          :size="20"
        />
      </span>
    </span>
  </button>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { PRIORITY_CLASS } from '../constants';

const props = defineProps({
  task: { type: Object, required: true },
});

const emit = defineEmits(['open']);
const { t } = useI18n();

const isOverdue = computed(() => {
  if (!props.task.due_date || props.task.status === 'done') return false;
  // Parse as local midnight: a bare `YYYY-MM-DD` is read as UTC and would flag
  // the due date itself as overdue in timezones west of UTC.
  return (
    new Date(`${props.task.due_date}T00:00:00`) <
    new Date(new Date().toDateString())
  );
});

const formattedDueDate = computed(() => {
  if (!props.task.due_date) return '';
  return new Date(`${props.task.due_date}T00:00:00`).toLocaleDateString();
});
</script>

<template>
  <button
    type="button"
    class="flex flex-col w-full gap-2 p-3 text-left border rounded-xl bg-n-solid-1 border-n-weak hover:border-n-strong"
    @click="emit('open', task)"
  >
    <span class="flex items-start justify-between gap-2">
      <span class="text-sm font-medium text-n-slate-12">{{ task.title }}</span>
      <span
        class="px-1.5 py-0.5 text-[11px] font-medium rounded-md shrink-0"
        :class="PRIORITY_CLASS[task.priority]"
      >
        {{ t(`PROJECTS.TASK.PRIORITY.${task.priority.toUpperCase()}`) }}
      </span>
    </span>
    <span v-if="task.description" class="text-xs text-n-slate-11 line-clamp-2">
      {{ task.description }}
    </span>
    <span class="flex items-center justify-between gap-2">
      <span class="flex items-center gap-3 text-xs text-n-slate-10">
        <span v-if="task.due_date" class="flex items-center gap-1">
          <Icon icon="i-lucide-calendar" class="size-3.5" />
          <span :class="isOverdue ? 'text-n-ruby-11 font-medium' : ''">
            {{ formattedDueDate }}
          </span>
          <span v-if="isOverdue" class="text-n-ruby-11 font-medium">
            {{ t('PROJECTS.DETAILS.OVERDUE') }}
          </span>
        </span>
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
      <Avatar
        v-if="task.assignee"
        :name="task.assignee.name"
        :src="task.assignee.thumbnail"
        :size="20"
      />
    </span>
  </button>
</template>

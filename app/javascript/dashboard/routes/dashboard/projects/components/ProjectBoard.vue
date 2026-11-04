<script setup>
import { reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ProjectTaskCard from './ProjectTaskCard.vue';
import { STATUS_DOT_CLASS, TASK_STATUSES } from '../constants';

const props = defineProps({
  tasks: { type: Array, default: () => [] },
});

const emit = defineEmits(['move', 'openTask', 'createTask']);
const { t } = useI18n();

const columns = reactive({
  todo: [],
  in_progress: [],
  done: [],
});
const drafting = reactive({
  todo: false,
  in_progress: false,
  done: false,
});
const draftTitles = reactive({
  todo: '',
  in_progress: '',
  done: '',
});

const syncColumns = () => {
  TASK_STATUSES.forEach(status => {
    columns[status] = props.tasks
      .filter(task => task.status === status)
      .sort((a, b) => a.position - b.position);
  });
};

watch(() => props.tasks, syncColumns, { immediate: true, deep: true });

const columnCount = status => columns[status]?.length || 0;

const startCreate = status => {
  drafting[status] = true;
};

const submitDraft = status => {
  const title = draftTitles[status].trim();
  drafting[status] = false;
  draftTitles[status] = '';
  if (!title) return;
  emit('createTask', { status, title });
};

const onChange = (status, event) => {
  if (!event.added && !event.moved) return;
  const element = event.added?.element || event.moved?.element;
  const newIndex = event.added?.newIndex ?? event.moved?.newIndex;
  if (!element) return;
  const siblings = columns[status];
  const previous = siblings[newIndex - 1];
  const nextSibling = siblings[newIndex + 1];
  let position;
  if (previous && nextSibling)
    position = (previous.position + nextSibling.position) / 2;
  else if (previous) position = previous.position + 1;
  else if (nextSibling) position = nextSibling.position / 2;
  else position = 1;
  if (element.status === status && element.position === position) return;
  emit('move', { task: element, status, position });
};
</script>

<template>
  <div class="grid flex-1 grid-cols-1 gap-4 overflow-x-auto md:grid-cols-3">
    <section
      v-for="status in TASK_STATUSES"
      :key="status"
      class="flex flex-col min-w-64 gap-3 p-3 rounded-xl bg-n-surface-2"
    >
      <header class="flex items-center justify-between">
        <span
          class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
        >
          <span
            class="w-2 h-2 rounded-full"
            :class="STATUS_DOT_CLASS[status]"
          />
          {{ t(`PROJECTS.TASK.STATUS.${status.toUpperCase()}`) }}
          <span class="text-xs text-n-slate-10">{{ columnCount(status) }}</span>
        </span>
        <Button
          variant="ghost"
          color="slate"
          icon="i-lucide-plus"
          size="xs"
          @click="startCreate(status)"
        />
      </header>
      <Input
        v-if="drafting[status]"
        :key="`draft-${status}`"
        v-model="draftTitles[status]"
        size="sm"
        autofocus
        :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
        @enter="submitDraft(status)"
        @blur="submitDraft(status)"
      />
      <Draggable
        v-model="columns[status]"
        group="project-tasks"
        item-key="id"
        class="flex flex-col flex-1 gap-2 min-h-16"
        @change="onChange(status, $event)"
      >
        <template #item="{ element }">
          <ProjectTaskCard :task="element" @open="emit('openTask', $event)" />
        </template>
      </Draggable>
      <button
        type="button"
        class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12"
        @click="startCreate(status)"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('PROJECTS.DETAILS.ADD_TASK') }}
      </button>
    </section>
  </div>
</template>

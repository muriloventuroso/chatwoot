<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import ProjectSelect from './ProjectSelect.vue';
import {
  PRIORITY_BORDER_CLASS,
  PRIORITY_CLASS,
  STATUS_DOT_CLASS,
  TASK_PRIORITIES,
  daysUntilDue,
  progressWidthClass,
  taskProgress,
} from '../constants';

const props = defineProps({
  tasks: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['openTask', 'updateTask', 'createTask']);
const { t } = useI18n();

// The table clips its overflow, so the menus of the last rows open on top of the page instead.
provideDropdownTeleport();

const TABLE_COLUMN_COUNT = 6;

// Keyed by column id.
const drafting = reactive({});
const draftTitles = reactive({});

const groups = computed(() =>
  props.columns.map(column => ({
    column,
    tasks: props.tasks
      .filter(task => task.project_column_id === column.id)
      .sort((a, b) => a.position - b.position),
  }))
);

const columnOptions = computed(() =>
  props.columns.map(column => ({ value: column.id, label: column.name }))
);

const priorityOptions = computed(() =>
  TASK_PRIORITIES.map(priority => ({
    value: priority,
    label: t(`PROJECTS.TASK.PRIORITY.${priority.toUpperCase()}`),
  }))
);

const assigneeOptions = computed(() => [
  { value: '', label: t('PROJECTS.TASK.FORM.UNASSIGNED') },
  ...props.agents.map(agent => ({ value: agent.id, label: agent.name })),
]);

const updateField = (task, field, value) => {
  emit('updateTask', { task, changes: { [field]: value || null } });
};

const dueLabel = task => {
  if (!task.due_date || task.status === 'done') return null;
  const days = daysUntilDue(task.due_date);
  if (days < 0)
    return {
      text: t('PROJECTS.LIST.DAYS_LATE', -days, { count: -days }),
      class: 'text-n-ruby-11',
    };
  if (days === 0)
    return { text: t('PROJECTS.LIST.DUE_TODAY'), class: 'text-n-amber-11' };
  return {
    text: t('PROJECTS.LIST.DAYS_LEFT', days, { count: days }),
    class: 'text-n-teal-11',
  };
};

const startCreate = columnId => {
  drafting[columnId] = true;
};

const submitDraft = columnId => {
  const title = (draftTitles[columnId] || '').trim();
  drafting[columnId] = false;
  draftTitles[columnId] = '';
  if (!title) return;
  emit('createTask', { columnId, title });
};
</script>

<template>
  <div class="overflow-x-auto border rounded-xl border-n-weak bg-n-solid-1">
    <table class="w-full text-sm min-w-[56rem]">
      <thead>
        <tr class="border-b border-n-weak bg-n-surface-2">
          <th class="px-4 py-2 font-medium text-start text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.TITLE') }}
          </th>
          <th class="px-4 py-2 font-medium text-start text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.STATUS') }}
          </th>
          <th class="px-4 py-2 font-medium text-start text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.PRIORITY') }}
          </th>
          <th class="px-4 py-2 font-medium text-start text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.ASSIGNEE') }}
          </th>
          <th class="px-4 py-2 font-medium text-start text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.DUE_DATE') }}
          </th>
          <th class="px-4 py-2 font-medium text-start text-n-slate-11">
            {{ t('PROJECTS.LIST.PROGRESS') }}
          </th>
        </tr>
      </thead>
      <tbody v-for="group in groups" :key="group.column.id">
        <tr class="border-b border-n-weak bg-n-surface-2">
          <td :colspan="TABLE_COLUMN_COUNT" class="px-4 py-2">
            <span class="flex items-center gap-2 font-medium text-n-slate-12">
              <span
                class="w-2 h-2 rounded-full shrink-0"
                :class="STATUS_DOT_CLASS[group.column.category]"
              />
              {{ group.column.name }}
              <span class="text-xs text-n-slate-10">
                {{ group.tasks.length }}
              </span>
            </span>
          </td>
        </tr>
        <tr
          v-for="task in group.tasks"
          :key="task.id"
          class="border-b border-n-weak hover:bg-n-surface-2"
        >
          <td
            class="px-4 py-2 border-s-4"
            :class="PRIORITY_BORDER_CLASS[task.priority]"
          >
            <button
              type="button"
              class="font-medium text-start text-n-slate-12 hover:text-n-brand"
              @click="emit('openTask', task)"
            >
              {{ task.title }}
            </button>
            <span
              v-if="
                task.subtasks_count ||
                task.comments_count ||
                task.attachments?.length
              "
              class="flex items-center gap-3 mt-0.5 text-xs text-n-slate-10"
            >
              <span v-if="task.subtasks_count" class="flex items-center gap-1">
                <Icon icon="i-lucide-list-checks" class="size-3.5" />
                {{ task.completed_subtasks_count }}/{{ task.subtasks_count }}
              </span>
              <span v-if="task.comments_count" class="flex items-center gap-1">
                <Icon icon="i-lucide-message-circle" class="size-3.5" />
                {{ task.comments_count }}
              </span>
              <span
                v-if="task.attachments?.length"
                class="flex items-center gap-1"
              >
                <Icon icon="i-lucide-paperclip" class="size-3.5" />
                {{ task.attachments.length }}
              </span>
            </span>
          </td>
          <td class="px-4 py-2">
            <ProjectSelect
              :model-value="task.project_column_id"
              :options="columnOptions"
              trigger-class="h-8 bg-n-solid-1 text-n-slate-12"
              @update:model-value="
                updateField(task, 'project_column_id', $event)
              "
            />
          </td>
          <td class="px-4 py-2">
            <ProjectSelect
              :model-value="task.priority"
              :options="priorityOptions"
              :trigger-class="['h-8', PRIORITY_CLASS[task.priority]]"
              @update:model-value="updateField(task, 'priority', $event)"
            />
          </td>
          <td class="px-4 py-2">
            <span class="flex items-center gap-2">
              <Avatar
                v-if="task.assignee"
                :name="task.assignee.name"
                :src="task.assignee.thumbnail"
                :size="20"
              />
              <ProjectSelect
                :model-value="task.assignee_id || ''"
                :options="assigneeOptions"
                trigger-class="h-8 bg-n-solid-1 text-n-slate-12"
                @update:model-value="updateField(task, 'assignee_id', $event)"
              />
            </span>
          </td>
          <td class="px-4 py-2">
            <input
              type="date"
              :value="task.due_date || ''"
              class="h-8 px-2 text-sm border rounded-md bg-n-solid-1 border-n-weak text-n-slate-12"
              @change="updateField(task, 'due_date', $event.target.value)"
            />
            <span
              v-if="dueLabel(task)"
              class="block mt-0.5 text-xs"
              :class="dueLabel(task).class"
            >
              {{ dueLabel(task).text }}
            </span>
          </td>
          <td class="px-4 py-2">
            <span class="flex items-center gap-2">
              <span
                class="w-20 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
              >
                <span
                  class="block h-full rounded-full bg-n-teal-9"
                  :class="progressWidthClass(taskProgress(task))"
                />
              </span>
              <span class="text-xs text-n-slate-11">
                {{ `${taskProgress(task)}%` }}
              </span>
            </span>
          </td>
        </tr>
        <tr class="border-b border-n-weak">
          <td :colspan="TABLE_COLUMN_COUNT" class="px-4 py-2">
            <Input
              v-if="drafting[group.column.id]"
              v-model="draftTitles[group.column.id]"
              size="sm"
              autofocus
              :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
              @enter="submitDraft(group.column.id)"
              @blur="submitDraft(group.column.id)"
            />
            <button
              v-else
              type="button"
              class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12"
              @click="startCreate(group.column.id)"
            >
              <Icon icon="i-lucide-plus" class="size-4" />
              {{ t('PROJECTS.DETAILS.ADD_TASK') }}
            </button>
          </td>
        </tr>
      </tbody>
      <tbody v-if="!columns.length">
        <tr>
          <td
            :colspan="TABLE_COLUMN_COUNT"
            class="px-4 py-8 text-center text-n-slate-10"
          >
            {{ t('PROJECTS.DETAILS.NO_TASKS') }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

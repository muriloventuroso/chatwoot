<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import ProjectSelect from './ProjectSelect.vue';
import ProjectTaskCard from './ProjectTaskCard.vue';
import {
  DUE_TONE_CLASS,
  PRIORITY_CLASS,
  STATUS_DOT_CLASS,
  STATUS_PILL_CLASS,
  TASK_PRIORITIES,
  dueTone,
  progressWidthClass,
  taskProgress,
} from '../constants';
import { useDueDate } from '../useDueDate';

const props = defineProps({
  tasks: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['openTask', 'updateTask', 'createTask']);
const { t } = useI18n();
const { relativeDue } = useDueDate();

// The table clips its overflow, so the menus of the last rows open on top of the page instead.
provideDropdownTeleport();

// Cells read as plain text until hovered, like a spreadsheet.
const CELL_TRIGGER = 'h-8 !border-transparent hover:!border-n-weak';

// Keyed by column id.
const drafting = reactive({});
const draftTitles = reactive({});
const collapsed = reactive({});

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
  return {
    text: relativeDue(task.due_date),
    class: DUE_TONE_CLASS[dueTone(task.due_date)],
  };
};

const startCreate = columnId => {
  drafting[columnId] = true;
};

// Enter keeps the field open for the next task; leaving it closes it.
const submitDraft = (columnId, { keepOpen = false } = {}) => {
  const title = (draftTitles[columnId] || '').trim();
  drafting[columnId] = keepOpen && Boolean(title);
  draftTitles[columnId] = '';
  if (title) emit('createTask', { columnId, title });
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <section
      v-for="group in groups"
      :key="group.column.id"
      class="overflow-hidden border rounded-xl border-n-weak bg-n-solid-1"
    >
      <button
        type="button"
        class="flex items-center w-full gap-2 px-4 py-2.5 text-sm font-medium text-start bg-n-surface-2 text-n-slate-12"
        :aria-expanded="!collapsed[group.column.id]"
        @click="collapsed[group.column.id] = !collapsed[group.column.id]"
      >
        <Icon
          icon="i-lucide-chevron-down"
          class="transition-transform size-4 text-n-slate-11"
          :class="{
            '-rotate-90 rtl:rotate-90': collapsed[group.column.id],
          }"
        />
        <span
          class="rounded-full size-2 shrink-0"
          :class="STATUS_DOT_CLASS[group.column.category]"
        />
        <span class="truncate">{{ group.column.name }}</span>
        <span
          class="px-1.5 text-xs font-normal rounded-full tabular-nums bg-n-alpha-2 text-n-slate-11"
        >
          {{ group.tasks.length }}
        </span>
      </button>

      <template v-if="!collapsed[group.column.id]">
        <!-- Phones get stacked cards; editing happens in the task panel. -->
        <div
          v-if="group.tasks.length"
          class="flex flex-col gap-2 p-2 md:hidden"
        >
          <ProjectTaskCard
            v-for="task in group.tasks"
            :key="task.id"
            :task="task"
            @open="emit('openTask', $event)"
          />
        </div>

        <div v-if="group.tasks.length" class="overflow-x-auto max-md:hidden">
          <table class="w-full text-sm min-w-[48rem]">
            <thead>
              <tr class="border-b border-n-weak">
                <th
                  class="px-4 py-2 text-xs font-medium text-start text-n-slate-11"
                >
                  {{ t('PROJECTS.TASK.FORM.TITLE') }}
                </th>
                <th
                  class="w-40 px-2 py-2 text-xs font-medium text-start text-n-slate-11"
                >
                  {{ t('PROJECTS.TASK.FORM.STATUS') }}
                </th>
                <th
                  class="px-2 py-2 text-xs font-medium w-44 text-start text-n-slate-11"
                >
                  {{ t('PROJECTS.TASK.FORM.ASSIGNEE') }}
                </th>
                <th
                  class="px-2 py-2 text-xs font-medium w-28 text-start text-n-slate-11"
                >
                  {{ t('PROJECTS.TASK.FORM.PRIORITY') }}
                </th>
                <th
                  class="w-40 px-2 py-2 text-xs font-medium text-start text-n-slate-11"
                >
                  {{ t('PROJECTS.TASK.FORM.DUE_DATE') }}
                </th>
                <th
                  class="px-4 py-2 text-xs font-medium w-36 text-start text-n-slate-11"
                >
                  {{ t('PROJECTS.LIST.PROGRESS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="task in group.tasks"
                :key="task.id"
                class="border-b border-n-weak last:border-b-0 hover:bg-n-alpha-1"
              >
                <td class="px-4 py-2">
                  <button
                    type="button"
                    class="font-medium text-start text-n-slate-12 hover:text-n-blue-11 hover:underline"
                    :class="{ '!text-n-slate-11': task.status === 'done' }"
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
                    <span
                      v-if="task.subtasks_count"
                      class="flex items-center gap-1"
                    >
                      <Icon icon="i-lucide-list-checks" class="size-3.5" />
                      {{
                        `${task.completed_subtasks_count}/${task.subtasks_count}`
                      }}
                    </span>
                    <span
                      v-if="task.comments_count"
                      class="flex items-center gap-1"
                    >
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
                <td class="px-2 py-2">
                  <ProjectSelect
                    :model-value="task.project_column_id"
                    :options="columnOptions"
                    :trigger-class="[
                      CELL_TRIGGER,
                      'font-medium',
                      STATUS_PILL_CLASS[group.column.category],
                    ]"
                    @update:model-value="
                      updateField(task, 'project_column_id', $event)
                    "
                  />
                </td>
                <td class="px-2 py-2">
                  <span class="flex items-center gap-1">
                    <Avatar
                      v-if="task.assignee"
                      :name="task.assignee.name"
                      :src="task.assignee.thumbnail"
                      :size="20"
                      rounded-full
                    />
                    <ProjectSelect
                      class="flex-1 min-w-0"
                      :model-value="task.assignee_id || ''"
                      :options="assigneeOptions"
                      :trigger-class="[CELL_TRIGGER, 'text-n-slate-12']"
                      @update:model-value="
                        updateField(task, 'assignee_id', $event)
                      "
                    />
                  </span>
                </td>
                <td class="px-2 py-2">
                  <ProjectSelect
                    :model-value="task.priority"
                    :options="priorityOptions"
                    :trigger-class="[
                      CELL_TRIGGER,
                      'font-medium',
                      PRIORITY_CLASS[task.priority],
                    ]"
                    @update:model-value="updateField(task, 'priority', $event)"
                  />
                </td>
                <td class="px-2 py-2">
                  <input
                    type="date"
                    :value="task.due_date || ''"
                    :aria-label="t('PROJECTS.TASK.FORM.DUE_DATE')"
                    class="w-full h-8 px-2 text-sm bg-transparent border reset-base border-transparent rounded-lg hover:border-n-weak focus:border-n-brand text-n-slate-12"
                    @change="updateField(task, 'due_date', $event.target.value)"
                  />
                  <span
                    v-if="dueLabel(task)"
                    class="block px-2 text-xs"
                    :class="dueLabel(task).class"
                  >
                    {{ dueLabel(task).text }}
                  </span>
                </td>
                <td class="px-4 py-2">
                  <span class="flex items-center gap-2">
                    <span
                      class="flex-1 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
                    >
                      <span
                        class="block h-full rounded-full bg-n-teal-9"
                        :class="progressWidthClass(taskProgress(task))"
                      />
                    </span>
                    <span class="w-8 text-xs text-end text-n-slate-11">
                      {{ `${taskProgress(task)}%` }}
                    </span>
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="px-2 py-1.5 border-t border-n-weak">
          <Input
            v-if="drafting[group.column.id]"
            v-model="draftTitles[group.column.id]"
            size="sm"
            autofocus
            :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
            @enter="submitDraft(group.column.id, { keepOpen: true })"
            @blur="submitDraft(group.column.id)"
          />
          <button
            v-else
            type="button"
            class="flex items-center w-full gap-1.5 px-2 py-1.5 text-sm rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            @click="startCreate(group.column.id)"
          >
            <Icon icon="i-lucide-plus" class="size-4" />
            {{ t('PROJECTS.DETAILS.ADD_TASK') }}
          </button>
        </div>
      </template>
    </section>
    <p
      v-if="!columns.length"
      class="py-8 mb-0 text-center text-sm text-n-slate-10"
    >
      {{ t('PROJECTS.DETAILS.NO_TASKS') }}
    </p>
  </div>
</template>

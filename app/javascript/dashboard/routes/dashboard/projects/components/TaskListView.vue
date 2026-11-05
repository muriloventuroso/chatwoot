<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import ProjectSelect from './ProjectSelect.vue';
import { PRIORITY_CLASS, TASK_PRIORITIES } from '../constants';

const props = defineProps({
  tasks: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['openTask', 'updateTask']);
const { t } = useI18n();

// The table clips its overflow, so the menus of the last rows open on top of the page instead.
provideDropdownTeleport();

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
</script>

<template>
  <div class="overflow-hidden border rounded-xl border-n-weak bg-n-solid-1">
    <table class="w-full text-sm">
      <thead>
        <tr class="border-b border-n-weak bg-n-surface-2">
          <th class="px-4 py-2 font-medium text-left text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.TITLE') }}
          </th>
          <th class="px-4 py-2 font-medium text-left text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.STATUS') }}
          </th>
          <th class="px-4 py-2 font-medium text-left text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.PRIORITY') }}
          </th>
          <th class="px-4 py-2 font-medium text-left text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.ASSIGNEE') }}
          </th>
          <th class="px-4 py-2 font-medium text-left text-n-slate-11">
            {{ t('PROJECTS.TASK.FORM.DUE_DATE') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="task in tasks"
          :key="task.id"
          class="border-b border-n-weak last:border-0 hover:bg-n-surface-2"
        >
          <td class="px-4 py-2">
            <button
              type="button"
              class="font-medium text-left text-n-slate-12 hover:text-n-brand"
              @click="emit('openTask', task)"
            >
              {{ task.title }}
            </button>
            <span
              v-if="task.subtasks_count"
              class="block text-xs text-n-slate-10"
            >
              {{ task.completed_subtasks_count }}/{{ task.subtasks_count }}
              {{ t('PROJECTS.TASK.SUBTASKS.TITLE') }}
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
          </td>
        </tr>
        <tr v-if="!tasks.length">
          <td colspan="5" class="px-4 py-8 text-center text-n-slate-10">
            {{ t('PROJECTS.DETAILS.NO_TASKS') }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

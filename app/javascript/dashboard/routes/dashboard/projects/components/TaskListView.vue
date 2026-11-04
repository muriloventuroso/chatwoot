<script setup>
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { PRIORITY_CLASS, TASK_PRIORITIES, TASK_STATUSES } from '../constants';

defineProps({
  tasks: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['openTask', 'updateTask']);
const { t } = useI18n();

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
            <select
              :value="task.status"
              class="h-8 px-2 text-sm border rounded-md bg-n-solid-1 border-n-weak text-n-slate-12"
              @change="updateField(task, 'status', $event.target.value)"
            >
              <option
                v-for="status in TASK_STATUSES"
                :key="status"
                :value="status"
              >
                {{ t(`PROJECTS.TASK.STATUS.${status.toUpperCase()}`) }}
              </option>
            </select>
          </td>
          <td class="px-4 py-2">
            <select
              :value="task.priority"
              class="h-8 px-2 text-sm border rounded-md border-n-weak"
              :class="PRIORITY_CLASS[task.priority]"
              @change="updateField(task, 'priority', $event.target.value)"
            >
              <option
                v-for="priority in TASK_PRIORITIES"
                :key="priority"
                :value="priority"
              >
                {{ t(`PROJECTS.TASK.PRIORITY.${priority.toUpperCase()}`) }}
              </option>
            </select>
          </td>
          <td class="px-4 py-2">
            <span class="flex items-center gap-2">
              <Avatar
                v-if="task.assignee"
                :name="task.assignee.name"
                :src="task.assignee.thumbnail"
                :size="20"
              />
              <select
                :value="task.assignee_id || ''"
                class="h-8 px-2 text-sm border rounded-md bg-n-solid-1 border-n-weak text-n-slate-12"
                @change="updateField(task, 'assignee_id', $event.target.value)"
              >
                <option value="">
                  {{ t('PROJECTS.TASK.FORM.UNASSIGNED') }}
                </option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
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

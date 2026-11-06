<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { SET_PROJECT_TASK } from 'dashboard/store/modules/projects/types';
import ColumnFormModal from './components/ColumnFormModal.vue';
import ProjectBoard from './components/ProjectBoard.vue';
import ProjectFormModal from './components/ProjectFormModal.vue';
import ProjectSelect from './components/ProjectSelect.vue';
import TaskDetailModal from './components/TaskDetailModal.vue';
import TaskListView from './components/TaskListView.vue';
import {
  PROJECT_COLOR_CLASS,
  TASK_PRIORITIES,
  nextColumnPosition,
  progressWidthClass,
} from './constants';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const view = ref('board');
const searchQuery = ref('');
const assigneeFilter = ref('');
const priorityFilter = ref('');
const onlyMine = ref(false);
const formModalRef = ref(null);
const taskModalRef = ref(null);
const columnModalRef = ref(null);
const deleteColumnDialogRef = ref(null);
const columnToDelete = ref(null);
const isSavingColumn = ref(false);
const isLoading = ref(false);
const loadError = ref(false);

const projectId = computed(() => Number(route.params.projectId));
const project = computed(() =>
  store.getters['projects/getProjectById'](projectId.value)
);
const tasks = computed(() =>
  store.getters['projects/getTasksByProject'](projectId.value)
);
const columns = computed(() =>
  store.getters['projects/getColumnsByProject'](projectId.value)
);
const members = computed(() =>
  store.getters['projects/getMembersByProject'](projectId.value)
);
const agents = useMapGetter('agents/getAgents');
// Tasks can only be assigned to project members.
const memberUsers = computed(() =>
  members.value.map(member => member.user).filter(Boolean)
);
const currentUserId = useMapGetter('getCurrentUserID');

const filteredTasks = computed(() => {
  return tasks.value.filter(task => {
    const query = searchQuery.value.trim().toLowerCase();
    if (query && !task.title?.toLowerCase().includes(query)) return false;
    if (
      assigneeFilter.value &&
      String(task.assignee_id) !== String(assigneeFilter.value)
    ) {
      return false;
    }
    if (priorityFilter.value && task.priority !== priorityFilter.value) {
      return false;
    }
    if (onlyMine.value && task.assignee_id !== currentUserId.value) {
      return false;
    }
    return true;
  });
});

const toAgentOption = agent => ({ value: agent.id, label: agent.name });

const addMemberOptions = computed(() => {
  const memberIds = new Set(members.value.map(member => member.user_id));
  return agents.value
    .filter(agent => !memberIds.has(agent.id))
    .map(toAgentOption);
});

const assigneeOptions = computed(() => [
  { value: '', label: t('PROJECTS.DETAILS.ALL_ASSIGNEES') },
  ...agents.value.map(toAgentOption),
]);

const priorityOptions = computed(() => [
  { value: '', label: t('PROJECTS.DETAILS.ALL_PRIORITIES') },
  ...TASK_PRIORITIES.map(priority => ({
    value: priority,
    label: t(`PROJECTS.TASK.PRIORITY.${priority.toUpperCase()}`),
  })),
]);

const loadProject = async () => {
  isLoading.value = true;
  loadError.value = false;
  try {
    await Promise.all([
      store.dispatch('projects/fetchProject', projectId.value),
      store.dispatch('projects/fetchTasks', { projectId: projectId.value }),
      store.dispatch('projects/fetchColumns', projectId.value),
      store.dispatch('projects/fetchMembers', projectId.value),
      store.dispatch('agents/get'),
    ]);
  } catch (error) {
    loadError.value = true;
    useAlert(t('PROJECTS.DETAILS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

// Task mutations change the project progress, so the header is refetched too.
const refreshProject = () =>
  store.dispatch('projects/fetchProject', projectId.value);

// The server renumbers the positions of the whole column on move, so the
// siblings are refetched to keep the board order in sync.
const refreshBoard = () =>
  Promise.all([
    store.dispatch('projects/fetchTasks', { projectId: projectId.value }),
    refreshProject(),
  ]);

onMounted(loadProject);
watch(projectId, loadProject);

const goBack = () => router.push(accountScopedRoute('projects_list'));

const saveProject = async payload => {
  try {
    await store.dispatch('projects/updateProject', payload);
    formModalRef.value?.close();
    useAlert(t('PROJECTS.MESSAGES.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.UPDATE_ERROR'));
  }
};

const handleMove = async ({ task, columnId, position }) => {
  const previous = { ...task };
  store.commit(`projects/${SET_PROJECT_TASK}`, {
    ...task,
    project_column_id: columnId,
    position,
  });
  try {
    await store.dispatch('projects/moveTask', {
      id: task.id,
      project_column_id: columnId,
      position,
    });
  } catch (error) {
    store.commit(`projects/${SET_PROJECT_TASK}`, previous);
    useAlert(t('PROJECTS.TASK.MESSAGES.MOVE_ERROR'));
    return;
  }
  await refreshBoard();
};

const handleCreateTask = async ({ columnId, title }) => {
  try {
    await store.dispatch('projects/createTask', {
      projectId: projectId.value,
      title,
      project_column_id: columnId,
    });
    await refreshProject();
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.CREATE_ERROR'));
  }
};

const handleUpdateTask = async ({ task, changes }) => {
  try {
    if (changes.project_column_id) {
      const { project_column_id: columnId, ...rest } = changes;
      await store.dispatch('projects/moveTask', {
        id: task.id,
        project_column_id: columnId,
        position: nextColumnPosition(tasks.value, columnId, task.id),
      });
      if (Object.keys(rest).length) {
        await store.dispatch('projects/updateTask', { id: task.id, ...rest });
      }
    } else {
      await store.dispatch('projects/updateTask', { id: task.id, ...changes });
    }
    await refreshProject();
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.UPDATE_ERROR'));
  }
};

const openTask = task => taskModalRef.value?.open({ task });
const openNewTask = () =>
  taskModalRef.value?.open({ columnId: columns.value[0]?.id });

const saveColumn = async ({ id, ...data }) => {
  if (isSavingColumn.value) return;
  isSavingColumn.value = true;
  try {
    if (id) {
      await store.dispatch('projects/updateColumn', {
        projectId: projectId.value,
        id,
        ...data,
      });
      // A new type changes the status of the column's tasks, and so the progress.
      await refreshBoard();
    } else {
      await store.dispatch('projects/createColumn', {
        projectId: projectId.value,
        ...data,
      });
    }
    columnModalRef.value?.close();
  } catch (error) {
    useAlert(t('PROJECTS.COLUMNS.MESSAGES.SAVE_ERROR'));
  } finally {
    isSavingColumn.value = false;
  }
};

// Lands between the neighbour it passes and the one after that.
const moveColumn = async ({ column, direction }) => {
  const list = columns.value;
  const target = list.findIndex(item => item.id === column.id) + direction;
  const neighbour = list[target];
  if (!neighbour) return;
  const beyond = list[target + direction];
  const position = beyond
    ? (neighbour.position + beyond.position) / 2
    : neighbour.position + direction;
  try {
    await store.dispatch('projects/updateColumn', {
      projectId: projectId.value,
      id: column.id,
      position,
    });
  } catch (error) {
    useAlert(t('PROJECTS.COLUMNS.MESSAGES.SAVE_ERROR'));
  }
};

const confirmDeleteColumn = column => {
  if (columns.value.length === 1) {
    useAlert(t('PROJECTS.COLUMNS.MESSAGES.LAST_COLUMN'));
    return;
  }
  if (tasks.value.some(task => task.project_column_id === column.id)) {
    useAlert(t('PROJECTS.COLUMNS.MESSAGES.NOT_EMPTY'));
    return;
  }
  columnToDelete.value = column;
  deleteColumnDialogRef.value?.open();
};

const deleteColumn = async () => {
  try {
    await store.dispatch('projects/deleteColumn', {
      projectId: projectId.value,
      id: columnToDelete.value.id,
    });
    deleteColumnDialogRef.value?.close();
  } catch (error) {
    useAlert(t('PROJECTS.COLUMNS.MESSAGES.DELETE_ERROR'));
  }
};

const addMember = async userId => {
  try {
    await store.dispatch('projects/addMembers', {
      projectId: projectId.value,
      userIds: [userId],
    });
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.UPDATE_ERROR'));
  }
};

const removeMember = async member => {
  try {
    await store.dispatch('projects/removeMember', {
      projectId: projectId.value,
      memberId: member.id,
    });
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.UPDATE_ERROR'));
  }
};

const colorClass = computed(
  () => PROJECT_COLOR_CLASS[project.value?.color] || 'bg-n-brand'
);

const formatDate = date => {
  if (!date) return '';
  return new Date(`${date}T00:00:00`).toLocaleDateString();
};

const projectDates = computed(() => {
  const start = formatDate(project.value?.start_date);
  const end = formatDate(project.value?.end_date);
  if (start && end) return `${start} – ${end}`;
  return start || end;
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <div v-if="!project && isLoading" class="flex justify-center py-16">
      <Spinner />
    </div>
    <div
      v-else-if="!project && loadError"
      class="flex flex-col items-center justify-center gap-3 py-16"
    >
      <p class="text-sm text-n-slate-11">
        {{ t('PROJECTS.DETAILS.LOAD_ERROR') }}
      </p>
      <Button
        variant="faded"
        color="slate"
        :label="t('PROJECTS.DETAILS.RETRY')"
        @click="loadProject"
      />
    </div>
    <template v-else-if="project">
      <header
        class="flex flex-col gap-4 px-6 py-5 border-b border-n-weak shrink-0"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-start gap-3 min-w-0">
            <Button
              variant="ghost"
              color="slate"
              icon="i-lucide-arrow-left"
              :aria-label="t('PROJECTS.DETAILS.BACK')"
              :title="t('PROJECTS.DETAILS.BACK')"
              @click="goBack"
            />
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <span class="w-3 h-3 rounded-full" :class="colorClass" />
                <h1 class="text-xl font-medium truncate text-n-slate-12">
                  {{ project.name }}
                </h1>
              </div>
              <p
                v-if="project.description"
                class="mt-1 text-sm text-n-slate-11"
              >
                {{ project.description }}
              </p>
              <p
                v-if="projectDates"
                class="flex items-center gap-1 mt-1 text-xs text-n-slate-10"
              >
                <Icon icon="i-lucide-calendar" class="size-3.5" />
                {{ projectDates }}
              </p>
            </div>
          </div>
          <Button
            variant="faded"
            color="slate"
            icon="i-lucide-pencil"
            :label="t('PROJECTS.ACTIONS.EDIT')"
            @click="formModalRef?.open(project)"
          />
        </div>
        <div class="flex flex-col gap-3 lg:flex-row lg:items-center">
          <div class="flex items-center flex-1 gap-3">
            <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-n-slate-4">
              <div
                class="h-full bg-n-brand"
                :class="progressWidthClass(project.progress)"
              />
            </div>
            <span class="text-xs text-n-slate-10">{{ project.progress }}%</span>
          </div>
          <div class="flex items-center gap-2">
            <div
              v-for="member in members"
              :key="member.id"
              class="flex items-center gap-1 px-1.5 py-1 rounded-full bg-n-slate-3"
            >
              <Avatar
                :name="member.user?.name || ''"
                :src="member.user?.thumbnail"
                :size="20"
              />
              <span class="text-xs text-n-slate-12">
                {{ member.user?.name }}
              </span>
              <button
                type="button"
                class="text-n-slate-10 hover:text-n-ruby-11"
                :title="t('PROJECTS.MEMBERS.REMOVE')"
                @click="removeMember(member)"
              >
                <Icon icon="i-lucide-x" class="size-3" />
              </button>
            </div>
            <ProjectSelect
              model-value=""
              :options="addMemberOptions"
              :placeholder="t('PROJECTS.MEMBERS.ADD')"
              trigger-class="h-8 bg-n-solid-1 text-n-slate-12"
              @update:model-value="addMember"
            />
          </div>
        </div>
        <div class="flex flex-col gap-3 lg:flex-row lg:items-center">
          <div class="flex gap-2 shrink-0">
            <Button
              :variant="view === 'board' ? 'solid' : 'ghost'"
              :color="view === 'board' ? 'blue' : 'slate'"
              :label="t('PROJECTS.DETAILS.BOARD')"
              @click="view = 'board'"
            />
            <Button
              :variant="view === 'list' ? 'solid' : 'ghost'"
              :color="view === 'list' ? 'blue' : 'slate'"
              :label="t('PROJECTS.DETAILS.LIST')"
              @click="view = 'list'"
            />
          </div>
          <Input
            v-model="searchQuery"
            class="lg:flex-1 lg:min-w-48"
            :placeholder="t('PROJECTS.DETAILS.SEARCH_TASKS')"
          />
          <ProjectSelect
            v-model="assigneeFilter"
            :options="assigneeOptions"
            class="lg:w-44 lg:shrink-0"
          />
          <ProjectSelect
            v-model="priorityFilter"
            :options="priorityOptions"
            class="lg:w-44 lg:shrink-0"
          />
          <label
            class="flex items-center gap-2 text-sm whitespace-nowrap shrink-0 text-n-slate-12"
          >
            <input v-model="onlyMine" type="checkbox" />
            {{ t('PROJECTS.DETAILS.ONLY_MINE') }}
          </label>
          <Button
            color="blue"
            icon="i-lucide-plus"
            class="shrink-0"
            :label="t('PROJECTS.DETAILS.ADD_TASK')"
            @click="openNewTask"
          />
        </div>
      </header>

      <div class="flex-1 p-6 overflow-auto">
        <ProjectBoard
          v-if="view === 'board'"
          :columns="columns"
          :tasks="filteredTasks"
          @move="handleMove"
          @open-task="openTask"
          @create-task="handleCreateTask"
          @add-column="columnModalRef?.open()"
          @edit-column="columnModalRef?.open($event)"
          @move-column="moveColumn"
          @delete-column="confirmDeleteColumn"
        />
        <TaskListView
          v-else
          :tasks="filteredTasks"
          :columns="columns"
          :agents="memberUsers"
          @open-task="openTask"
          @update-task="handleUpdateTask"
        />
      </div>
    </template>

    <ProjectFormModal ref="formModalRef" @save="saveProject" />
    <TaskDetailModal
      ref="taskModalRef"
      :project-id="projectId"
      :columns="columns"
      :agents="memberUsers"
      @close="refreshProject"
      @changed="refreshProject"
    />
    <ColumnFormModal
      ref="columnModalRef"
      :is-saving="isSavingColumn"
      @save="saveColumn"
    />
    <Dialog
      ref="deleteColumnDialogRef"
      type="alert"
      :title="t('PROJECTS.COLUMNS.DELETE_DIALOG.TITLE')"
      :description="
        t('PROJECTS.COLUMNS.DELETE_DIALOG.MESSAGE', {
          name: columnToDelete?.name,
        })
      "
      :confirm-button-label="t('PROJECTS.COLUMNS.DELETE_DIALOG.CONFIRM')"
      @confirm="deleteColumn"
    />
  </section>
</template>

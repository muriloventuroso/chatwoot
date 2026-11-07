<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStorage } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CompanySearchInput from 'dashboard/components-next/Companies/CompanySearchInput.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { SET_PROJECT_TASK } from 'dashboard/store/modules/projects/types';
import ColumnFormModal from './components/ColumnFormModal.vue';
import ProjectBoard from './components/ProjectBoard.vue';
import ProjectFormModal from './components/ProjectFormModal.vue';
import ProjectMembersPanel from './components/ProjectMembersPanel.vue';
import TaskDetailPanel from './components/TaskDetailPanel.vue';
import TaskFilters from './components/TaskFilters.vue';
import TaskListView from './components/TaskListView.vue';
import {
  DUE_TONE_CLASS,
  PROJECT_COLOR_CLASS,
  PROJECT_STATUS_CLASS,
  UNASSIGNED,
  dueTone,
  nextColumnPosition,
  progressWidthClass,
  taskSummary,
} from './constants';
import { useDueDate } from './useDueDate';
import { useProjectActions } from './useProjectActions';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { formatDate, relativeDue } = useDueDate();
const { menuItems, updateStatus, deleteProject } = useProjectActions();

const MAX_HEADER_AVATARS = 3;
// A project deadline gets the "soon" warning a week ahead.
const DEADLINE_WARNING_DAYS = 7;

// Remembered across visits, like the last tab of a table in Monday.
const view = useStorage('projects:task-view', 'board');
const searchQuery = ref('');
const assigneeFilter = ref('');
const priorityFilter = ref('');
const showProjectMenu = ref(false);
const formModalRef = ref(null);
const taskModalRef = ref(null);
const columnModalRef = ref(null);
const membersPanelRef = ref(null);
const deleteColumnDialogRef = ref(null);
const deleteProjectDialogRef = ref(null);
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

const viewTabs = computed(() => [
  {
    key: 'board',
    label: t('PROJECTS.DETAILS.BOARD'),
    icon: 'i-lucide-square-kanban',
  },
  { key: 'list', label: t('PROJECTS.DETAILS.LIST'), icon: 'i-lucide-list' },
]);

const activeFiltersCount = computed(
  () => Number(assigneeFilter.value !== '') + Number(!!priorityFilter.value)
);
const hasFilters = computed(
  () => activeFiltersCount.value > 0 || !!searchQuery.value.trim()
);

const clearFilters = () => {
  searchQuery.value = '';
  assigneeFilter.value = '';
  priorityFilter.value = '';
};

const matchesAssignee = task => {
  if (assigneeFilter.value === '') return true;
  if (assigneeFilter.value === UNASSIGNED) return !task.assignee_id;
  return task.assignee_id === assigneeFilter.value;
};

const filteredTasks = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return tasks.value.filter(
    task =>
      (!query || task.title?.toLowerCase().includes(query)) &&
      matchesAssignee(task) &&
      (!priorityFilter.value || task.priority === priorityFilter.value)
  );
});

const summary = computed(() => taskSummary(tasks.value));

const deadline = computed(() => {
  const date = project.value?.end_date;
  if (!date) return null;
  const isActive = project.value.status === 'active';
  return {
    date: formatDate(date),
    relative: isActive ? relativeDue(date) : '',
    class: DUE_TONE_CLASS[dueTone(date, !isActive, DEADLINE_WARNING_DAYS)],
  };
});

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

const saveProject = async payload => {
  try {
    await store.dispatch('projects/updateProject', payload);
    formModalRef.value?.close();
    useAlert(t('PROJECTS.MESSAGES.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.UPDATE_ERROR'));
  }
};

const onProjectAction = ({ action }) => {
  showProjectMenu.value = false;
  if (action === 'edit') formModalRef.value?.open(project.value);
  else if (action === 'delete') deleteProjectDialogRef.value?.open();
  else updateStatus(project.value, action);
};

const confirmDeleteProject = async () => {
  if (!(await deleteProject(project.value))) return;
  deleteProjectDialogRef.value?.close();
  router.push(accountScopedRoute('projects_list'));
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
      <header class="flex flex-col gap-4 px-4 pt-4 pb-3 sm:px-6 shrink-0">
        <div class="flex items-start gap-3">
          <div class="flex flex-col flex-1 min-w-0 gap-1">
            <router-link
              :to="accountScopedRoute('projects_list')"
              class="inline-flex items-center self-start gap-1 text-xs text-n-slate-11 hover:text-n-slate-12"
            >
              <Icon
                icon="i-lucide-chevron-left"
                class="size-3.5 rtl:rotate-180"
              />
              {{ t('PROJECTS.TITLE') }}
            </router-link>
            <div class="flex items-center min-w-0 gap-2">
              <span class="rounded-full size-3 shrink-0" :class="colorClass" />
              <h1
                class="mb-0 text-xl font-medium truncate text-n-slate-12"
                :title="project.name"
              >
                {{ project.name }}
              </h1>
              <span
                class="px-2 py-0.5 rounded-md text-label-small shrink-0 max-sm:hidden"
                :class="PROJECT_STATUS_CLASS[project.status]"
              >
                {{ t(`PROJECTS.STATUS.${project.status.toUpperCase()}`) }}
              </span>
            </div>
            <p
              v-if="project.description"
              class="mb-0 text-sm text-n-slate-11 line-clamp-1"
              :title="project.description"
            >
              {{ project.description }}
            </p>
          </div>
          <div class="flex items-center gap-1 pt-4 shrink-0 sm:gap-2">
            <button
              type="button"
              class="flex items-center gap-1.5 p-1 rounded-lg hover:bg-n-alpha-2"
              :aria-label="t('PROJECTS.MEMBERS.MANAGE')"
              :title="t('PROJECTS.MEMBERS.MANAGE')"
              @click="membersPanelRef?.open()"
            >
              <span
                v-if="memberUsers.length"
                class="flex -space-x-1.5 rtl:space-x-reverse max-sm:hidden"
              >
                <Avatar
                  v-for="user in memberUsers.slice(0, MAX_HEADER_AVATARS)"
                  :key="user.id"
                  :name="user.name"
                  :src="user.thumbnail"
                  :size="24"
                  rounded-full
                  class="rounded-full ring-2 ring-n-surface-1"
                />
              </span>
              <Icon
                icon="i-lucide-users"
                class="size-4 text-n-slate-11"
                :class="{ 'sm:hidden': memberUsers.length }"
              />
              <span class="text-xs font-medium text-n-slate-11 tabular-nums">
                {{ memberUsers.length }}
              </span>
            </button>
            <div
              v-on-clickaway="() => (showProjectMenu = false)"
              class="relative"
            >
              <Button
                variant="ghost"
                color="slate"
                size="sm"
                icon="i-lucide-ellipsis-vertical"
                :aria-label="t('PROJECTS.CARD.ACTIONS')"
                :aria-expanded="showProjectMenu"
                @click="showProjectMenu = !showProjectMenu"
              />
              <DropdownMenu
                v-if="showProjectMenu"
                :menu-items="menuItems(project)"
                class="mt-1 end-0 top-full w-52"
                @action="onProjectAction"
              />
            </div>
            <Button
              color="blue"
              size="sm"
              icon="i-lucide-plus"
              :aria-label="t('PROJECTS.DETAILS.NEW_TASK')"
              @click="openNewTask"
            >
              <span class="max-sm:hidden">
                {{ t('PROJECTS.DETAILS.NEW_TASK') }}
              </span>
            </Button>
          </div>
        </div>

        <dl
          class="flex gap-2 mb-0 -mx-4 overflow-x-auto reset-base px-4 sm:mx-0 sm:px-0 [scrollbar-width:none]"
        >
          <div
            class="flex flex-col justify-center gap-1 px-3 py-2 border rounded-lg shrink-0 border-n-weak bg-n-solid-1 min-w-36"
          >
            <dt class="text-xs text-n-slate-11">
              {{ t('PROJECTS.SUMMARY.PROGRESS') }}
            </dt>
            <dd class="flex items-center gap-2 mb-0">
              <span
                class="flex-1 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
              >
                <span
                  class="block h-full rounded-full bg-n-brand"
                  :class="progressWidthClass(project.progress)"
                />
              </span>
              <span class="text-sm font-medium tabular-nums text-n-slate-12">
                {{ `${project.progress}%` }}
              </span>
            </dd>
          </div>
          <div
            class="flex flex-col justify-center gap-0.5 px-3 py-2 border rounded-lg shrink-0 border-n-weak bg-n-solid-1"
          >
            <dt class="text-xs text-n-slate-11">
              {{ t('PROJECTS.SUMMARY.DONE') }}
            </dt>
            <dd class="mb-0 text-sm font-medium tabular-nums text-n-slate-12">
              {{ `${summary.done}/${summary.total}` }}
            </dd>
          </div>
          <div
            class="flex flex-col justify-center gap-0.5 px-3 py-2 border rounded-lg shrink-0"
            :class="
              summary.overdue
                ? 'border-n-ruby-6 bg-n-ruby-2'
                : 'border-n-weak bg-n-solid-1'
            "
          >
            <dt class="text-xs text-n-slate-11">
              {{ t('PROJECTS.SUMMARY.OVERDUE') }}
            </dt>
            <dd
              class="mb-0 text-sm font-medium tabular-nums"
              :class="summary.overdue ? 'text-n-ruby-11' : 'text-n-slate-12'"
            >
              {{ summary.overdue }}
            </dd>
          </div>
          <div
            class="flex flex-col justify-center gap-0.5 px-3 py-2 border rounded-lg shrink-0 border-n-weak bg-n-solid-1"
          >
            <dt class="text-xs text-n-slate-11">
              {{ t('PROJECTS.SUMMARY.DUE_SOON') }}
            </dt>
            <dd class="mb-0 text-sm font-medium tabular-nums text-n-slate-12">
              {{ summary.dueSoon }}
            </dd>
          </div>
          <div
            class="flex flex-col justify-center gap-0.5 px-3 py-2 border rounded-lg shrink-0 border-n-weak bg-n-solid-1"
          >
            <dt class="text-xs text-n-slate-11">
              {{ t('PROJECTS.SUMMARY.DEADLINE') }}
            </dt>
            <dd
              v-if="deadline"
              class="mb-0 text-sm font-medium whitespace-nowrap"
              :class="deadline.class"
            >
              {{ deadline.date }}
              <span v-if="deadline.relative" class="font-normal">
                {{ ` · ${deadline.relative}` }}
              </span>
            </dd>
            <dd v-else class="mb-0 text-sm text-n-slate-10">
              {{ t('PROJECTS.CARD.NO_DEADLINE') }}
            </dd>
          </div>
        </dl>

        <div class="flex flex-wrap items-center gap-2">
          <TabBar
            :tabs="viewTabs"
            :initial-active-tab="viewTabs.findIndex(tab => tab.key === view)"
            @tab-changed="tab => (view = tab.key)"
          />
          <div class="flex items-center gap-2 ms-auto">
            <Button
              v-if="hasFilters"
              variant="ghost"
              color="slate"
              size="sm"
              :label="t('PROJECTS.CLEAR_FILTERS')"
              class="max-sm:hidden"
              @click="clearFilters"
            />
            <Popover align="end">
              <Button
                :variant="activeFiltersCount ? 'faded' : 'ghost'"
                :color="activeFiltersCount ? 'blue' : 'slate'"
                size="sm"
                icon="i-lucide-list-filter"
                :aria-label="t('PROJECTS.DETAILS.FILTERS')"
              >
                <span class="max-sm:hidden">
                  {{ t('PROJECTS.DETAILS.FILTERS') }}
                </span>
                <span
                  v-if="activeFiltersCount"
                  class="px-1.5 text-xs rounded-full bg-n-brand text-white tabular-nums"
                >
                  {{ activeFiltersCount }}
                </span>
              </Button>
              <template #content>
                <TaskFilters
                  v-model:assignee="assigneeFilter"
                  v-model:priority="priorityFilter"
                  :people="memberUsers"
                  @clear="clearFilters"
                />
              </template>
            </Popover>
          </div>
          <CompanySearchInput
            v-model="searchQuery"
            :placeholder="t('PROJECTS.DETAILS.SEARCH_TASKS')"
            class="max-sm:order-last sm:!w-60"
          />
        </div>
      </header>

      <div
        class="flex-1 min-h-0"
        :class="{
          'px-4 pb-6 max-md:pb-24 overflow-y-auto sm:px-6': view === 'list',
        }"
      >
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
          @create-task="handleCreateTask"
        />
      </div>
    </template>

    <ProjectFormModal ref="formModalRef" @save="saveProject" />
    <ProjectMembersPanel
      ref="membersPanelRef"
      :members="members"
      :agents="agents"
      @add="addMember"
      @remove="removeMember"
    />
    <TaskDetailPanel
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
    <Dialog
      ref="deleteProjectDialogRef"
      type="alert"
      :title="t('PROJECTS.DELETE.TITLE')"
      :description="t('PROJECTS.DELETE.MESSAGE', { name: project?.name })"
      :confirm-button-label="t('PROJECTS.DELETE.CONFIRM')"
      @confirm="confirmDeleteProject"
    />
  </section>
</template>

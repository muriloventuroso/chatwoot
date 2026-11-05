<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { picoSearch } from '@chatwoot/pico-search';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CompanySearchInput from 'dashboard/components-next/Companies/CompanySearchInput.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ProjectFormModal from './components/ProjectFormModal.vue';
import {
  PROJECT_COLOR_CLASS,
  PROJECT_STATUSES,
  progressWidthClass,
} from './constants';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const searchQuery = ref('');
const statusFilter = ref('');
const onlyMine = ref(false);
const formModalRef = ref(null);
const deleteDialogRef = ref(null);
const projectToDelete = ref(null);
const showActionsMenu = ref(false);

const actionsMenuItems = computed(() => [
  {
    label: t('PROJECTS.NEW_PROJECT'),
    action: 'create',
    value: 'create',
    icon: 'i-lucide-plus',
  },
]);

const projects = useMapGetter('projects/getProjects');
const uiFlags = useMapGetter('projects/getUIFlags');

const fetchProjects = async () => {
  const params = {};
  if (statusFilter.value) params.status = statusFilter.value;
  if (onlyMine.value) params.mine = 'true';
  try {
    await store.dispatch('projects/fetchProjects', params);
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.LOAD_ERROR'));
  }
};

onMounted(fetchProjects);

const statusOptions = computed(() => [
  { value: '', label: t('PROJECTS.FILTERS.STATUS_ALL') },
  ...PROJECT_STATUSES.map(status => ({
    value: status,
    label: t(`PROJECTS.STATUS.${status.toUpperCase()}`),
  })),
]);

const filteredProjects = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return projects.value;
  return picoSearch(projects.value, query, ['name', 'description']);
});

const openCreate = () => {
  showActionsMenu.value = false;
  formModalRef.value?.open();
};

const toggleOnlyMine = () => {
  onlyMine.value = !onlyMine.value;
  fetchProjects();
};
const openEdit = project => formModalRef.value?.open(project);

const openProject = project => {
  router.push(accountScopedRoute('project_details', { projectId: project.id }));
};

const saveProject = async payload => {
  try {
    if (payload.id) {
      await store.dispatch('projects/updateProject', payload);
      useAlert(t('PROJECTS.MESSAGES.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('projects/createProject', payload);
      useAlert(t('PROJECTS.MESSAGES.CREATE_SUCCESS'));
    }
    formModalRef.value?.close();
    await fetchProjects();
  } catch (error) {
    useAlert(
      t(
        payload.id
          ? 'PROJECTS.MESSAGES.UPDATE_ERROR'
          : 'PROJECTS.MESSAGES.CREATE_ERROR'
      )
    );
  }
};

const updateProjectStatus = async (project, status) => {
  try {
    await store.dispatch('projects/updateProject', {
      id: project.id,
      status,
    });
    useAlert(t('PROJECTS.MESSAGES.UPDATE_SUCCESS'));
    await fetchProjects();
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.UPDATE_ERROR'));
  }
};

const tasksCountLabel = count =>
  t('PROJECTS.TASKS_COUNT', count || 0, { count: count || 0 });

const confirmDelete = project => {
  projectToDelete.value = project;
  deleteDialogRef.value?.open();
};

const deleteProject = async () => {
  if (!projectToDelete.value) return;
  try {
    await store.dispatch('projects/deleteProject', projectToDelete.value.id);
    useAlert(t('PROJECTS.MESSAGES.DELETE_SUCCESS'));
    deleteDialogRef.value?.close();
  } catch (error) {
    useAlert(t('PROJECTS.MESSAGES.DELETE_ERROR'));
  }
};

const colorClass = project =>
  PROJECT_COLOR_CLASS[project.color] || 'bg-n-brand';
</script>

<template>
  <section class="flex w-full h-full overflow-hidden bg-n-surface-1">
    <div class="flex flex-col w-full h-full">
      <header class="sticky top-0 z-10 px-6">
        <div
          class="flex flex-col justify-between w-full gap-4 py-6 mx-auto sm:flex-row sm:items-center max-w-5xl"
        >
          <h1 class="mb-0 text-xl font-medium shrink-0 text-n-slate-12">
            {{ t('PROJECTS.TITLE') }}
          </h1>
          <div class="flex flex-wrap items-center min-w-0 gap-2 sm:gap-4">
            <CompanySearchInput
              v-model="searchQuery"
              :placeholder="t('PROJECTS.SEARCH_PLACEHOLDER')"
              class="flex-1 min-w-0"
            />
            <div class="flex items-center flex-shrink-0 gap-2">
              <FilterSelect
                v-model="statusFilter"
                variant="ghost"
                :options="statusOptions"
                @update:model-value="fetchProjects"
              />
              <Button
                icon="i-lucide-user-round"
                size="sm"
                :variant="onlyMine ? 'faded' : 'ghost'"
                :color="onlyMine ? 'blue' : 'slate'"
                :label="t('PROJECTS.FILTERS.MINE')"
                :aria-pressed="onlyMine"
                @click="toggleOnlyMine"
              />
              <div
                v-on-clickaway="() => (showActionsMenu = false)"
                class="relative"
              >
                <Button
                  icon="i-lucide-ellipsis-vertical"
                  color="slate"
                  variant="ghost"
                  size="sm"
                  :class="showActionsMenu ? 'bg-n-alpha-2' : ''"
                  @click="showActionsMenu = !showActionsMenu"
                />
                <DropdownMenu
                  v-if="showActionsMenu"
                  :menu-items="actionsMenuItems"
                  class="end-0 mt-1 w-52 top-full"
                  @action="openCreate"
                />
              </div>
            </div>
          </div>
        </div>
      </header>

      <main class="flex-1 px-6 overflow-y-auto">
        <div class="w-full py-4 mx-auto max-w-5xl">
          <div v-if="uiFlags.isFetching" class="flex justify-center p-8">
            <Spinner />
          </div>
          <div
            v-else-if="!filteredProjects.length"
            class="flex items-center justify-center p-8 text-base text-n-slate-11"
          >
            {{ searchQuery ? t('PROJECTS.NO_RESULTS') : t('PROJECTS.EMPTY') }}
          </div>
          <div v-else class="divide-y divide-n-weak">
            <div
              v-for="project in filteredProjects"
              :key="project.id"
              class="flex items-start justify-between gap-4 py-4 cursor-pointer group max-sm:flex-col"
              @click="openProject(project)"
            >
              <div class="flex items-start flex-1 min-w-0 gap-3">
                <span
                  class="flex items-center justify-center text-white rounded-lg size-9 shrink-0"
                  :class="colorClass(project)"
                >
                  <Icon icon="i-lucide-folder-kanban" class="size-4" />
                </span>
                <div class="flex flex-col flex-1 min-w-0 gap-1">
                  <span
                    class="block truncate text-heading-3 text-n-slate-12 group-hover:text-n-blue-11"
                  >
                    {{ project.name }}
                  </span>
                  <p
                    v-if="project.description"
                    class="mb-0 text-n-slate-11 text-body-main line-clamp-2 sm:line-clamp-1"
                  >
                    {{ project.description }}
                  </p>
                  <div class="overflow-hidden">
                    <div
                      class="flex flex-wrap items-center gap-y-1 -ms-[calc(0.75rem+1px)] text-body-main text-n-slate-11 [&>span]:inline-flex [&>span]:items-center [&>span]:gap-1.5 [&>span]:me-3 [&>span]:before:content-[''] [&>span]:before:w-px [&>span]:before:h-3 [&>span]:before:shrink-0 [&>span]:before:bg-n-slate-6 [&>span]:before:me-1.5"
                    >
                      <span>
                        {{
                          t(`PROJECTS.STATUS.${project.status.toUpperCase()}`)
                        }}
                      </span>
                      <span>
                        <Icon
                          icon="i-lucide-list-checks"
                          class="size-3.5 shrink-0 text-n-slate-10"
                        />
                        {{ tasksCountLabel(project.tasks_count) }}
                      </span>
                      <span>
                        <span
                          class="w-16 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
                        >
                          <span
                            class="block h-full bg-n-brand"
                            :class="progressWidthClass(project.progress)"
                          />
                        </span>
                        {{ `${project.progress}%` }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
              <div
                class="flex items-center gap-3 shrink-0 max-sm:ps-12"
                @click.stop
              >
                <div v-if="project.members?.length" class="flex -space-x-2">
                  <Avatar
                    v-for="member in project.members.slice(0, 4)"
                    :key="member.id"
                    :name="member.name"
                    :src="member.thumbnail"
                    :size="24"
                  />
                </div>
                <div class="flex gap-1">
                  <Button
                    v-if="project.status === 'active'"
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-check"
                    :aria-label="t('PROJECTS.ACTIONS.COMPLETE')"
                    :title="t('PROJECTS.ACTIONS.COMPLETE')"
                    @click="updateProjectStatus(project, 'completed')"
                  />
                  <Button
                    v-if="project.status !== 'archived'"
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-archive"
                    :aria-label="t('PROJECTS.ACTIONS.ARCHIVE')"
                    :title="t('PROJECTS.ACTIONS.ARCHIVE')"
                    @click="updateProjectStatus(project, 'archived')"
                  />
                  <Button
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-pencil"
                    :aria-label="t('PROJECTS.ACTIONS.EDIT')"
                    :title="t('PROJECTS.ACTIONS.EDIT')"
                    @click="openEdit(project)"
                  />
                  <Button
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-trash"
                    :aria-label="t('PROJECTS.ACTIONS.DELETE')"
                    :title="t('PROJECTS.ACTIONS.DELETE')"
                    @click="confirmDelete(project)"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>

    <ProjectFormModal ref="formModalRef" @save="saveProject" />
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('PROJECTS.DELETE.TITLE')"
      :description="
        t('PROJECTS.DELETE.MESSAGE', { name: projectToDelete?.name })
      "
      :confirm-button-label="t('PROJECTS.DELETE.CONFIRM')"
      @confirm="deleteProject"
    />
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import CompanySearchInput from 'dashboard/components-next/Companies/CompanySearchInput.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import ProjectCard from './components/ProjectCard.vue';
import ProjectFormModal from './components/ProjectFormModal.vue';
import { PROJECT_STATUSES } from './constants';
import { useProjectActions } from './useProjectActions';

const { t } = useI18n();
const store = useStore();
const { updateStatus, deleteProject: removeProject } = useProjectActions();

const searchQuery = ref('');
// Archived and completed projects stay out of the way until asked for.
const statusFilter = ref('active');
const onlyMine = ref(false);
const formModalRef = ref(null);
const deleteDialogRef = ref(null);
const projectToDelete = ref(null);

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

const statusTabs = computed(() => [
  ...PROJECT_STATUSES.map(status => ({
    key: status,
    label: t(`PROJECTS.STATUS.${status.toUpperCase()}`),
  })),
  { key: '', label: t('PROJECTS.FILTERS.STATUS_ALL') },
]);
const activeTabIndex = computed(() =>
  statusTabs.value.findIndex(tab => tab.key === statusFilter.value)
);

const selectStatus = ({ key }) => {
  statusFilter.value = key;
  fetchProjects();
};

const toggleOnlyMine = () => {
  onlyMine.value = !onlyMine.value;
  fetchProjects();
};

const filteredProjects = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return projects.value;
  return picoSearch(projects.value, query, ['name', 'description']);
});

// The first visit with nothing at all shows the onboarding empty state; any filter gets a reset.
const isFiltered = computed(
  () =>
    Boolean(searchQuery.value.trim()) ||
    onlyMine.value ||
    statusFilter.value !== 'active'
);

const clearFilters = () => {
  searchQuery.value = '';
  if (onlyMine.value || statusFilter.value !== 'active') {
    onlyMine.value = false;
    statusFilter.value = 'active';
    fetchProjects();
  }
};

const openCreate = () => formModalRef.value?.open();

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

const confirmDelete = project => {
  projectToDelete.value = project;
  deleteDialogRef.value?.open();
};

const deleteProject = async () => {
  if (await removeProject(projectToDelete.value))
    deleteDialogRef.value?.close();
};

const onCardAction = ({ action, project }) => {
  if (action === 'edit') formModalRef.value?.open(project);
  else if (action === 'delete') confirmDelete(project);
  else updateStatus(project, action).then(saved => saved && fetchProjects());
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="px-4 shrink-0 sm:px-6">
      <div class="flex flex-col w-full max-w-5xl gap-4 pt-6 pb-4 mx-auto">
        <div class="flex flex-wrap items-center gap-3">
          <h1 class="flex-1 mb-0 text-xl font-medium text-n-slate-12">
            {{ t('PROJECTS.TITLE') }}
          </h1>
          <CompanySearchInput
            v-model="searchQuery"
            :placeholder="t('PROJECTS.SEARCH_PLACEHOLDER')"
            class="order-last sm:order-none"
          />
          <Button
            color="blue"
            size="sm"
            icon="i-lucide-plus"
            :label="t('PROJECTS.NEW_PROJECT')"
            @click="openCreate"
          />
        </div>
        <div class="flex items-center justify-between gap-3">
          <div class="min-w-0 -mx-1 overflow-x-auto">
            <TabBar
              class="mx-1"
              :tabs="statusTabs"
              :initial-active-tab="activeTabIndex"
              @tab-changed="selectStatus"
            />
          </div>
          <Button
            icon="i-lucide-user-round"
            size="sm"
            class="shrink-0"
            :variant="onlyMine ? 'faded' : 'ghost'"
            :color="onlyMine ? 'blue' : 'slate'"
            :aria-label="t('PROJECTS.FILTERS.MINE')"
            :aria-pressed="onlyMine"
            @click="toggleOnlyMine"
          >
            <span class="max-sm:hidden">{{ t('PROJECTS.FILTERS.MINE') }}</span>
          </Button>
        </div>
      </div>
    </header>

    <main class="flex-1 px-4 overflow-y-auto sm:px-6">
      <div class="w-full max-w-5xl pt-2 pb-8 mx-auto max-md:pb-24">
        <div v-if="uiFlags.isFetching" class="flex justify-center p-8">
          <Spinner />
        </div>
        <div
          v-else-if="!filteredProjects.length"
          class="flex flex-col items-center gap-3 px-6 py-16 text-center border border-dashed rounded-xl border-n-weak"
        >
          <span
            class="flex items-center justify-center rounded-full size-12 bg-n-alpha-2 text-n-slate-11"
          >
            <Icon icon="i-lucide-folder-kanban" class="size-6" />
          </span>
          <template v-if="isFiltered">
            <p class="mb-0 text-body-main text-n-slate-11">
              {{ t('PROJECTS.NO_RESULTS') }}
            </p>
            <Button
              variant="faded"
              color="slate"
              size="sm"
              :label="t('PROJECTS.CLEAR_FILTERS')"
              @click="clearFilters"
            />
          </template>
          <template v-else>
            <h2 class="mb-0 text-heading-2 text-n-slate-12">
              {{ t('PROJECTS.EMPTY_STATE.TITLE') }}
            </h2>
            <p class="max-w-md mb-0 text-body-main text-n-slate-11">
              {{ t('PROJECTS.EMPTY_STATE.DESCRIPTION') }}
            </p>
            <Button
              color="blue"
              size="sm"
              icon="i-lucide-plus"
              :label="t('PROJECTS.EMPTY_STATE.CREATE')"
              @click="openCreate"
            />
          </template>
        </div>
        <div
          v-else
          class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3"
        >
          <ProjectCard
            v-for="project in filteredProjects"
            :key="project.id"
            :project="project"
            :show-status="!statusFilter"
            @action="onCardAction"
          />
        </div>
      </div>
    </main>

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

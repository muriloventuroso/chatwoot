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
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
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

const filteredProjects = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return projects.value;
  return picoSearch(projects.value, query, ['name', 'description']);
});

const openCreate = () => formModalRef.value?.open();
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
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="flex flex-col gap-4 px-6 py-5 border-b border-n-weak shrink-0"
    >
      <div class="flex items-center justify-between gap-3">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('PROJECTS.TITLE') }}
        </h1>
        <Button
          color="blue"
          icon="i-lucide-plus"
          :label="t('PROJECTS.NEW_PROJECT')"
          @click="openCreate"
        />
      </div>
      <div class="flex flex-col gap-3 md:flex-row md:items-center">
        <Input
          v-model="searchQuery"
          class="md:max-w-sm"
          :placeholder="t('PROJECTS.SEARCH_PLACEHOLDER')"
        />
        <select
          v-model="statusFilter"
          class="h-10 px-3 text-sm border rounded-lg bg-n-solid-1 border-n-weak text-n-slate-12"
          @change="fetchProjects"
        >
          <option value="">
            {{ t('PROJECTS.FILTERS.STATUS_ALL') }}
          </option>
          <option
            v-for="status in PROJECT_STATUSES"
            :key="status"
            :value="status"
          >
            {{ t(`PROJECTS.STATUS.${status.toUpperCase()}`) }}
          </option>
        </select>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input v-model="onlyMine" type="checkbox" @change="fetchProjects" />
          {{ t('PROJECTS.FILTERS.MINE') }}
        </label>
      </div>
    </header>

    <div class="flex-1 p-6 overflow-y-auto">
      <div v-if="uiFlags.isFetching" class="flex justify-center py-16">
        <Spinner />
      </div>
      <div
        v-else-if="!filteredProjects.length"
        class="flex items-center justify-center py-16 text-sm text-n-slate-11"
      >
        {{ searchQuery ? t('PROJECTS.NO_RESULTS') : t('PROJECTS.EMPTY') }}
      </div>
      <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        <article
          v-for="project in filteredProjects"
          :key="project.id"
          class="flex flex-col overflow-hidden border cursor-pointer rounded-xl bg-n-solid-1 border-n-weak hover:border-n-strong"
          @click="openProject(project)"
        >
          <div class="h-1.5" :class="colorClass(project)" />
          <div class="flex flex-col gap-3 p-4">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <h2 class="text-base font-medium truncate text-n-slate-12">
                  {{ project.name }}
                </h2>
                <p
                  v-if="project.description"
                  class="mt-1 text-sm text-n-slate-11 line-clamp-2"
                >
                  {{ project.description }}
                </p>
              </div>
              <span
                class="px-2 py-0.5 text-xs rounded-md bg-n-slate-3 text-n-slate-11 shrink-0"
              >
                {{ t(`PROJECTS.STATUS.${project.status.toUpperCase()}`) }}
              </span>
            </div>
            <div class="flex flex-col gap-1">
              <div class="h-1.5 overflow-hidden rounded-full bg-n-slate-4">
                <div
                  class="h-full bg-n-brand"
                  :class="progressWidthClass(project.progress)"
                />
              </div>
              <span class="text-xs text-n-slate-10">
                {{ project.progress }}% ·
                {{ tasksCountLabel(project.tasks_count) }}
              </span>
            </div>
            <div class="flex items-center justify-between gap-2">
              <div class="flex -space-x-2">
                <Avatar
                  v-for="member in (project.members || []).slice(0, 4)"
                  :key="member.id"
                  :name="member.name"
                  :src="member.thumbnail"
                  :size="24"
                />
              </div>
              <div class="flex gap-1" @click.stop>
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
        </article>
      </div>
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

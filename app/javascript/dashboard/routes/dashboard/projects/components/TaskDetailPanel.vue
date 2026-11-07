<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import { formatBytes } from 'shared/helpers/FileHelper';
import ProjectSelect from './ProjectSelect.vue';
import TaskMarkdownEditor from './TaskMarkdownEditor.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import {
  DUE_TONE_CLASS,
  PRIORITY_CLASS,
  STATUS_PILL_CLASS,
  TASK_PRIORITIES,
  dueTone,
  nextColumnPosition,
  progressWidthClass,
} from '../constants';
import { useDueDate } from '../useDueDate';

const props = defineProps({
  projectId: { type: [Number, String], required: true },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'deleted', 'changed']);

// Selects open over the panel instead of growing its scroll area.
provideDropdownTeleport();
const { t } = useI18n();
const store = useStore();
const { isAdmin } = useAdmin();
const { relativeDue } = useDueDate();
const currentUserId = useMapGetter('getCurrentUserID');
const allAgents = useMapGetter('agents/getAgents');

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

const panelRef = ref(null);
const showTaskMenu = ref(false);
const deleteDialogRef = ref(null);
const fileInputRef = ref(null);
const taskId = ref(null);
const form = ref({
  title: '',
  description: '',
  project_column_id: null,
  priority: 'medium',
  assignee_id: '',
  due_date: '',
});
const subtaskTitle = ref('');
const commentContent = ref('');
const isSaving = ref(false);
const isEditingDescription = ref(false);
// The comment editor stays folded into one line until used, so it does not eat a phone screen.
const isComposing = ref(false);
const activeTab = ref('comments');
// Remounts the editors on each open so they load the task without stealing focus.
const editorKey = ref(0);

const task = computed(
  () => store.getters['projects/getTaskById'](taskId.value) || {}
);
const subtasks = computed(() =>
  taskId.value ? store.getters['projects/getSubtasksByTask'](taskId.value) : []
);
const comments = computed(() =>
  taskId.value ? store.getters['projects/getCommentsByTask'](taskId.value) : []
);
const completedSubtasks = computed(
  () => subtasks.value.filter(item => item.status === 'done').length
);
const subtaskProgressClass = computed(() =>
  progressWidthClass(
    subtasks.value.length
      ? (completedSubtasks.value / subtasks.value.length) * 100
      : 0
  )
);
const attachments = computed(() => task.value.attachments || []);
// The creator may no longer be a project member, so look them up among all agents.
const creatorName = computed(
  () =>
    allAgents.value.find(agent => agent.id === task.value.creator_id)?.name ||
    ''
);
const tabs = computed(() => [
  {
    key: 'comments',
    label: t('PROJECTS.TASK.COMMENTS.TITLE'),
    count: comments.value.length,
  },
  {
    key: 'subtasks',
    label: t('PROJECTS.TASK.SUBTASKS.TITLE'),
    count: subtasks.value.length,
  },
  {
    key: 'attachments',
    label: t('PROJECTS.TASK.ATTACHMENTS.TITLE'),
    count: attachments.value.length,
  },
]);
const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab => tab.key === activeTab.value)
);
const isEditing = computed(() => Boolean(taskId.value));

const statusPillClass = computed(
  () =>
    STATUS_PILL_CLASS[
      props.columns.find(column => column.id === form.value.project_column_id)
        ?.category
    ]
);
const assignee = computed(() =>
  props.agents.find(agent => agent.id === form.value.assignee_id)
);
const due = computed(() => {
  const date = form.value.due_date;
  if (!isEditing.value || !date || task.value.status === 'done') return null;
  return { text: relativeDue(date), class: DUE_TONE_CLASS[dueTone(date)] };
});
const taskMenuItems = computed(() => [
  {
    action: 'delete',
    value: 'delete',
    label: t('PROJECTS.TASK.FORM.DELETE'),
    icon: 'i-lucide-trash',
  },
]);
const isFormInvalid = computed(() => !form.value.title.trim());

const formFromTask = record => ({
  title: record?.title || '',
  description: record?.description || '',
  project_column_id: record?.project_column_id ?? null,
  priority: record?.priority || 'medium',
  assignee_id: record?.assignee_id || '',
  due_date: record?.due_date || '',
});

// Does not touch the form, so refreshing subtasks/comments keeps unsaved edits.
const loadTask = id =>
  Promise.all([
    store.dispatch('projects/fetchTask', id),
    store.dispatch('projects/fetchComments', id),
  ]);

const open = async ({ task: record, columnId } = {}) => {
  taskId.value = record?.id || null;
  form.value = formFromTask(record || { project_column_id: columnId });
  subtaskTitle.value = '';
  commentContent.value = '';
  isEditingDescription.value = false;
  isComposing.value = false;
  activeTab.value = 'comments';
  editorKey.value += 1;
  showTaskMenu.value = false;
  panelRef.value?.open();
  if (record?.id) await loadTask(record.id);
};

const close = () => panelRef.value?.close();

const createTask = async () => {
  if (isFormInvalid.value) return;
  isSaving.value = true;
  try {
    const created = await store.dispatch('projects/createTask', {
      projectId: props.projectId,
      title: form.value.title.trim(),
      description: form.value.description.trim() || null,
      project_column_id: form.value.project_column_id,
      priority: form.value.priority,
      assignee_id: form.value.assignee_id || null,
      due_date: form.value.due_date || null,
    });
    taskId.value = created.id;
    await loadTask(created.id);
    emit('changed');
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.CREATE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

// An existing task saves each field as soon as it changes; on failure the field falls back to the stored task.
const persist = async request => {
  try {
    await request();
    emit('changed');
    return true;
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.UPDATE_ERROR'));
    return false;
  }
};

const revertField = key => {
  form.value[key] = formFromTask(task.value)[key];
};

const saveField = async (key, value) => {
  if (!isEditing.value) return;
  const saved = await persist(() =>
    store.dispatch('projects/updateTask', { id: taskId.value, [key]: value })
  );
  if (!saved) revertField(key);
};

const saveColumn = async columnId => {
  if (!isEditing.value || columnId === task.value.project_column_id) return;
  const siblings = store.getters['projects/getTasksByProject'](props.projectId);
  const saved = await persist(() =>
    store.dispatch('projects/moveTask', {
      id: taskId.value,
      project_column_id: columnId,
      position: nextColumnPosition(siblings, columnId, taskId.value),
    })
  );
  if (!saved) revertField('project_column_id');
};

const saveTitle = () => {
  if (!isEditing.value) return;
  const title = form.value.title.trim();
  if (!title) {
    form.value.title = task.value.title;
    return;
  }
  if (title !== task.value.title) saveField('title', title);
};

// Saved on blur: typing a year fires an input per keystroke (0002, 0020, ...).
const saveDueDate = () => {
  if (form.value.due_date === formFromTask(task.value).due_date) return;
  saveField('due_date', form.value.due_date || null);
};

const cancelDescription = () => {
  form.value.description = task.value.description || '';
  isEditingDescription.value = false;
};

// Keeps the editor open on failure so the draft is not lost.
const saveDescription = async () => {
  const saved = await persist(() =>
    store.dispatch('projects/updateTask', {
      id: taskId.value,
      description: form.value.description.trim() || null,
    })
  );
  if (saved) isEditingDescription.value = false;
};

const confirmDelete = () => {
  showTaskMenu.value = false;
  deleteDialogRef.value?.open();
};

const deleteTask = async () => {
  try {
    await store.dispatch('projects/deleteTask', taskId.value);
    deleteDialogRef.value?.close();
    emit('deleted');
    close();
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.DELETE_ERROR'));
  }
};

const addSubtask = async () => {
  const title = subtaskTitle.value.trim();
  if (!title || !taskId.value) return;
  try {
    await store.dispatch('projects/createTask', {
      projectId: props.projectId,
      parent_task_id: taskId.value,
      title,
    });
    subtaskTitle.value = '';
    await loadTask(taskId.value);
    emit('changed');
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.CREATE_ERROR'));
  }
};

const toggleSubtask = async subtask => {
  try {
    await store.dispatch('projects/moveTask', {
      id: subtask.id,
      status: subtask.status === 'done' ? 'todo' : 'done',
      position: subtask.position,
    });
    await loadTask(taskId.value);
    emit('changed');
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.UPDATE_ERROR'));
  }
};

const removeSubtask = async subtask => {
  try {
    await store.dispatch('projects/deleteTask', subtask.id);
    await loadTask(taskId.value);
    emit('changed');
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.DELETE_ERROR'));
  }
};

const addComment = async () => {
  const content = commentContent.value.trim();
  if (!content || !taskId.value) return;
  try {
    await store.dispatch('projects/createComment', {
      taskId: taskId.value,
      content,
    });
    commentContent.value = '';
    isComposing.value = false;
    await loadTask(taskId.value);
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.COMMENT_ERROR'));
  }
};

const cancelComment = () => {
  commentContent.value = '';
  isComposing.value = false;
};

const canDeleteComment = comment =>
  comment.author_id === currentUserId.value || isAdmin.value;

const removeComment = async comment => {
  try {
    await store.dispatch('projects/deleteComment', {
      taskId: taskId.value,
      commentId: comment.id,
    });
    await loadTask(taskId.value);
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.COMMENT_ERROR'));
  }
};

const onSelectFiles = async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file || !taskId.value) return;
  try {
    await store.dispatch('projects/addAttachment', {
      taskId: taskId.value,
      file,
    });
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.ATTACHMENT_ERROR'));
  }
};

const removeAttachment = async attachment => {
  try {
    await store.dispatch('projects/deleteAttachment', {
      taskId: taskId.value,
      attachmentId: attachment.id,
    });
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.ATTACHMENT_ERROR'));
  }
};

const formatMarkdown = content =>
  new MessageFormatter(content).formattedMessage;

const formattedTime = timestamp => {
  if (!timestamp) return '';
  return new Date(timestamp * 1000).toLocaleString();
};

defineExpose({ open, close });
</script>

<template>
  <SidePanel
    ref="panelRef"
    width="2xl"
    :title="isEditing ? form.title : t('PROJECTS.DETAILS.NEW_TASK')"
    @close="emit('close')"
  >
    <template #header>
      <div class="flex flex-col min-w-0 gap-0.5">
        <h3
          v-if="!isEditing"
          class="mb-0 text-base font-medium text-n-slate-12"
        >
          {{ t('PROJECTS.DETAILS.NEW_TASK') }}
        </h3>
        <template v-else>
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.TASK.META.ID', { id: taskId }) }}
          </span>
          <span v-if="creatorName" class="text-xs text-n-slate-11">
            {{
              t('PROJECTS.TASK.META.CREATED_BY', {
                name: creatorName,
                time: formattedTime(task.created_at),
              })
            }}
          </span>
        </template>
      </div>
    </template>
    <template v-if="isEditing" #header-actions>
      <div v-on-clickaway="() => (showTaskMenu = false)" class="relative">
        <Button
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-ellipsis-vertical"
          :aria-label="t('PROJECTS.TASK.ACTIONS')"
          :aria-expanded="showTaskMenu"
          @click="showTaskMenu = !showTaskMenu"
        />
        <DropdownMenu
          v-if="showTaskMenu"
          :menu-items="taskMenuItems"
          class="mt-1 end-0 top-full w-44"
          @action="confirmDelete"
        />
      </div>
    </template>

    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-4">
        <input
          v-model="form.title"
          type="text"
          :autofocus="!isEditing"
          :aria-label="t('PROJECTS.TASK.FORM.TITLE')"
          :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
          class="w-full px-2 py-1 -mx-2 text-xl font-medium bg-transparent border border-transparent rounded-lg outline-none reset-base text-n-slate-12 hover:border-n-weak focus:border-n-brand placeholder:text-n-slate-10"
          @blur="saveTitle"
          @keydown.enter.prevent="saveTitle"
        />

        <dl
          class="grid items-center mb-0 reset-base grid-cols-[7.5rem_minmax(0,1fr)] sm:grid-cols-[9rem_minmax(0,1fr)] gap-x-2 gap-y-1"
        >
          <dt class="flex items-center gap-2 text-sm text-n-slate-11">
            <Icon icon="i-lucide-columns-3" class="size-4 shrink-0" />
            {{ t('PROJECTS.TASK.FORM.STATUS') }}
          </dt>
          <dd data-field="status" class="mb-0">
            <ProjectSelect
              v-model="form.project_column_id"
              :options="columnOptions"
              :trigger-class="[
                'h-9 font-medium !border-transparent hover:!border-n-weak',
                statusPillClass,
              ]"
              class="sm:max-w-60"
              @update:model-value="saveColumn"
            />
          </dd>

          <dt class="flex items-center gap-2 text-sm text-n-slate-11">
            <Icon icon="i-lucide-user-round" class="size-4 shrink-0" />
            {{ t('PROJECTS.TASK.FORM.ASSIGNEE') }}
          </dt>
          <dd data-field="assignee" class="flex items-center gap-1 mb-0">
            <Avatar
              v-if="assignee"
              :name="assignee.name"
              :src="assignee.thumbnail"
              :size="20"
              rounded-full
              class="ms-2"
            />
            <ProjectSelect
              v-model="form.assignee_id"
              :options="assigneeOptions"
              trigger-class="h-9 text-n-slate-12 bg-transparent !border-transparent hover:!border-n-weak"
              class="flex-1 min-w-0 sm:max-w-60"
              @update:model-value="
                value => saveField('assignee_id', value || null)
              "
            />
          </dd>

          <dt class="flex items-center gap-2 text-sm text-n-slate-11">
            <Icon icon="i-lucide-flag" class="size-4 shrink-0" />
            {{ t('PROJECTS.TASK.FORM.PRIORITY') }}
          </dt>
          <dd data-field="priority" class="mb-0">
            <ProjectSelect
              v-model="form.priority"
              :options="priorityOptions"
              :trigger-class="[
                'h-9 font-medium !border-transparent hover:!border-n-weak',
                PRIORITY_CLASS[form.priority],
              ]"
              class="sm:max-w-60"
              @update:model-value="value => saveField('priority', value)"
            />
          </dd>

          <dt class="flex items-center gap-2 text-sm text-n-slate-11">
            <Icon icon="i-lucide-calendar" class="size-4 shrink-0" />
            {{ t('PROJECTS.TASK.FORM.DUE_DATE') }}
          </dt>
          <dd
            data-field="due_date"
            class="flex flex-wrap items-center mb-0 gap-x-2"
          >
            <input
              v-model="form.due_date"
              type="date"
              :aria-label="t('PROJECTS.TASK.FORM.DUE_DATE')"
              class="h-9 px-3 text-sm bg-transparent border border-transparent rounded-lg reset-base text-n-slate-12 hover:border-n-weak focus:border-n-brand"
              @blur="saveDueDate"
            />
            <span v-if="due" class="text-xs" :class="due.class">
              {{ due.text }}
            </span>
          </dd>
        </dl>

        <TaskMarkdownEditor
          v-if="!isEditing"
          :key="`description-${editorKey}`"
          v-model="form.description"
          :placeholder="t('PROJECTS.TASK.FORM.DESCRIPTION_PLACEHOLDER')"
        />
      </div>

      <section v-if="isEditing" class="flex flex-col gap-2">
        <header class="flex items-center justify-between gap-2">
          <h4 class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.TASK.FORM.DESCRIPTION') }}
          </h4>
          <Button
            v-if="!isEditingDescription"
            type="button"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-pencil"
            :aria-label="t('PROJECTS.TASK.FORM.EDIT_DESCRIPTION')"
            @click="isEditingDescription = true"
          />
        </header>
        <template v-if="isEditingDescription">
          <TaskMarkdownEditor
            v-model="form.description"
            :placeholder="t('PROJECTS.TASK.FORM.DESCRIPTION_PLACEHOLDER')"
          />
          <div class="flex justify-end gap-2">
            <Button
              type="button"
              variant="faded"
              color="slate"
              size="sm"
              :label="t('PROJECTS.TASK.FORM.CANCEL')"
              @click="cancelDescription"
            />
            <Button
              type="button"
              color="blue"
              size="sm"
              :label="t('PROJECTS.TASK.FORM.SAVE_DESCRIPTION')"
              @click="saveDescription"
            />
          </div>
        </template>
        <div
          v-else-if="form.description"
          v-dompurify-html="formatMarkdown(form.description)"
          class="overflow-y-auto text-sm break-words max-h-96 prose-sm prose dark:prose-invert max-w-none text-n-slate-11 [&>:first-child]:mt-0 [&>:last-child]:mb-0"
        />
        <button
          v-else
          type="button"
          class="px-3 py-2 text-sm border border-dashed rounded-lg text-start border-n-weak text-n-slate-10 hover:text-n-slate-12 hover:border-n-strong"
          @click="isEditingDescription = true"
        >
          {{ t('PROJECTS.TASK.FORM.DESCRIPTION_EMPTY') }}
        </button>
      </section>

      <section v-if="isEditing" class="flex flex-col gap-4">
        <div class="-mx-1 overflow-x-auto">
          <TabBar
            :tabs="tabs"
            :initial-active-tab="activeTabIndex"
            class="mx-1 !w-max"
            @tab-changed="tab => (activeTab = tab.key)"
          />
        </div>

        <div v-if="activeTab === 'subtasks'" class="flex flex-col gap-3">
          <div v-if="subtasks.length" class="flex items-center gap-3">
            <span
              class="flex-1 h-1.5 overflow-hidden rounded-full bg-n-slate-4"
            >
              <span
                class="block h-full rounded-full bg-n-teal-9"
                :class="subtaskProgressClass"
              />
            </span>
            <span class="text-xs tabular-nums text-n-slate-11">
              {{
                t('PROJECTS.TASK.SUBTASKS.PROGRESS', {
                  done: completedSubtasks,
                  total: subtasks.length,
                })
              }}
            </span>
          </div>
          <ul class="flex flex-col mb-0 reset-base">
            <li
              v-for="subtask in subtasks"
              :key="subtask.id"
              class="flex items-center gap-3 px-2 py-1.5 -mx-2 rounded-lg group hover:bg-n-alpha-1"
            >
              <label
                class="flex items-center flex-1 min-w-0 gap-3 cursor-pointer"
              >
                <Checkbox
                  :model-value="subtask.status === 'done'"
                  @change="toggleSubtask(subtask)"
                />
                <span
                  class="flex-1 text-sm break-words"
                  :class="
                    subtask.status === 'done'
                      ? 'line-through text-n-slate-10'
                      : 'text-n-slate-12'
                  "
                >
                  {{ subtask.title }}
                </span>
              </label>
              <Button
                type="button"
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-x"
                class="md:opacity-0 md:group-hover:opacity-100 focus-visible:opacity-100"
                :aria-label="t('PROJECTS.TASK.SUBTASKS.DELETE')"
                @click="removeSubtask(subtask)"
              />
            </li>
          </ul>
          <p v-if="!subtasks.length" class="mb-0 text-sm text-n-slate-10">
            {{ t('PROJECTS.TASK.SUBTASKS.EMPTY') }}
          </p>
          <Input
            v-model="subtaskTitle"
            size="sm"
            :placeholder="t('PROJECTS.TASK.SUBTASKS.ADD_PLACEHOLDER')"
            @enter="addSubtask"
          />
        </div>

        <div
          v-else-if="activeTab === 'attachments'"
          class="flex flex-col gap-3"
        >
          <ul class="flex flex-col gap-2 mb-0 reset-base">
            <li
              v-for="attachment in attachments"
              :key="attachment.id"
              class="flex items-center gap-3 p-2 border rounded-lg border-n-weak"
            >
              <img
                v-if="attachment.file_type?.startsWith('image/')"
                :src="attachment.file_url"
                :alt="attachment.filename"
                class="object-cover rounded-md size-10 shrink-0"
              />
              <span
                v-else
                class="flex items-center justify-center rounded-md size-10 shrink-0 bg-n-alpha-2 text-n-slate-11"
              >
                <Icon icon="i-lucide-file" class="size-5" />
              </span>
              <a
                :href="attachment.file_url"
                target="_blank"
                rel="noopener noreferrer"
                class="flex flex-col flex-1 min-w-0"
              >
                <span class="text-sm truncate text-n-slate-12 hover:underline">
                  {{ attachment.filename }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ formatBytes(attachment.byte_size, 1) }}
                </span>
              </a>
              <Button
                type="button"
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-trash"
                :aria-label="t('PROJECTS.TASK.ATTACHMENTS.DELETE')"
                @click="removeAttachment(attachment)"
              />
            </li>
          </ul>
          <p v-if="!attachments.length" class="mb-0 text-sm text-n-slate-10">
            {{ t('PROJECTS.TASK.ATTACHMENTS.EMPTY') }}
          </p>
          <input
            ref="fileInputRef"
            type="file"
            class="hidden"
            @change="onSelectFiles"
          />
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            icon="i-lucide-paperclip"
            class="self-start"
            :label="t('PROJECTS.TASK.ATTACHMENTS.ADD')"
            @click="fileInputRef?.click()"
          />
        </div>

        <div v-else class="flex flex-col gap-3">
          <ul class="flex flex-col gap-4 mb-0 reset-base">
            <li
              v-for="comment in comments"
              :key="comment.id"
              class="flex gap-3 group"
            >
              <Avatar
                :name="comment.author?.name || ''"
                :src="comment.author?.thumbnail"
                :size="28"
                rounded-full
              />
              <div class="flex flex-col flex-1 min-w-0 gap-1">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ comment.author?.name }}
                  </span>
                  <span class="text-xs text-n-slate-10">
                    {{ formattedTime(comment.created_at) }}
                  </span>
                  <Button
                    v-if="canDeleteComment(comment)"
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="xs"
                    icon="i-lucide-trash"
                    class="ms-auto md:opacity-0 md:group-hover:opacity-100 focus-visible:opacity-100"
                    :aria-label="t('PROJECTS.TASK.COMMENTS.DELETE')"
                    @click="removeComment(comment)"
                  />
                </div>
                <div
                  v-dompurify-html="formatMarkdown(comment.content)"
                  class="text-sm break-words prose-sm prose dark:prose-invert max-w-none text-n-slate-11 [&>:first-child]:mt-0 [&>:last-child]:mb-0"
                />
              </div>
            </li>
          </ul>
          <p v-if="!comments.length" class="mb-0 text-sm text-n-slate-10">
            {{ t('PROJECTS.TASK.COMMENTS.EMPTY') }}
          </p>
        </div>
      </section>
    </div>

    <template v-if="!isEditing || activeTab === 'comments'" #footer>
      <div v-if="!isEditing" class="flex justify-end gap-2">
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="t('PROJECTS.TASK.FORM.CANCEL')"
          @click="close"
        />
        <Button
          type="button"
          color="blue"
          :label="t('PROJECTS.TASK.FORM.SAVE')"
          :disabled="isFormInvalid"
          :is-loading="isSaving"
          @click="createTask"
        />
      </div>
      <div v-else-if="isComposing" class="flex flex-col gap-2">
        <TaskMarkdownEditor
          :key="`comment-${editorKey}`"
          v-model="commentContent"
          autofocus
          :placeholder="t('PROJECTS.TASK.COMMENTS.ADD_PLACEHOLDER')"
          class="overflow-y-auto max-h-56"
        />
        <div class="flex justify-end gap-2">
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            :label="t('PROJECTS.TASK.FORM.CANCEL')"
            @click="cancelComment"
          />
          <Button
            type="button"
            color="blue"
            size="sm"
            :label="t('PROJECTS.TASK.COMMENTS.ADD')"
            :disabled="!commentContent.trim()"
            @click="addComment"
          />
        </div>
      </div>
      <button
        v-else
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2.5 text-sm border rounded-lg text-start border-n-weak text-n-slate-10 hover:border-n-strong hover:text-n-slate-11"
        @click="isComposing = true"
      >
        <Icon icon="i-lucide-message-square-plus" class="size-4" />
        {{ t('PROJECTS.TASK.COMMENTS.ADD_PLACEHOLDER') }}
      </button>
    </template>
  </SidePanel>

  <Dialog
    ref="deleteDialogRef"
    type="alert"
    :title="t('PROJECTS.TASK.DELETE.TITLE')"
    :description="t('PROJECTS.TASK.DELETE.MESSAGE', { name: form.title })"
    :confirm-button-label="t('PROJECTS.TASK.DELETE.CONFIRM')"
    @confirm="deleteTask"
  />
</template>

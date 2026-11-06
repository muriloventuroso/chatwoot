<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import ProjectSelect from './ProjectSelect.vue';
import TaskMarkdownEditor from './TaskMarkdownEditor.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import {
  nextColumnPosition,
  progressWidthClass,
  TASK_PRIORITIES,
} from '../constants';

const props = defineProps({
  projectId: { type: [Number, String], required: true },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'deleted', 'changed']);

// Selects open over the dialog instead of growing its scroll area.
provideDropdownTeleport();
const { t } = useI18n();
const store = useStore();
const { isAdmin } = useAdmin();
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

const dialogRef = ref(null);
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
  activeTab.value = 'comments';
  editorKey.value += 1;
  dialogRef.value?.open();
  if (record?.id) await loadTask(record.id);
};

const close = () => dialogRef.value?.close();

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

const confirmDelete = () => deleteDialogRef.value?.open();

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
    await loadTask(taskId.value);
  } catch (error) {
    useAlert(t('PROJECTS.TASK.MESSAGES.COMMENT_ERROR'));
  }
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
  <Dialog
    ref="dialogRef"
    width="3xl"
    overflow-y-auto
    :title="isEditing ? '' : t('PROJECTS.DETAILS.ADD_TASK')"
    :show-confirm-button="false"
    :show-cancel-button="false"
    @close="emit('close')"
  >
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-3">
        <div
          v-if="isEditing"
          class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-n-slate-10"
        >
          <span class="font-medium text-n-slate-11">{{
            t('PROJECTS.TASK.META.ID', { id: taskId })
          }}</span>
          <span v-if="creatorName">
            {{
              t('PROJECTS.TASK.META.CREATED_BY', {
                name: creatorName,
                time: formattedTime(task.created_at),
              })
            }}
          </span>
          <Button
            type="button"
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-trash-2"
            class="ms-auto"
            :label="t('PROJECTS.TASK.FORM.DELETE')"
            @click="confirmDelete"
          />
        </div>
        <Input
          v-model="form.title"
          :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
          :custom-input-class="isEditing ? '!text-base font-medium' : ''"
          @blur="saveTitle"
          @enter="saveTitle"
        />
        <TaskMarkdownEditor
          v-if="!isEditing"
          :key="`description-${editorKey}`"
          v-model="form.description"
          :placeholder="t('PROJECTS.TASK.FORM.DESCRIPTION_PLACEHOLDER')"
        />
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('PROJECTS.TASK.FORM.STATUS') }}
            </span>
            <ProjectSelect
              v-model="form.project_column_id"
              :options="columnOptions"
              @update:model-value="saveColumn"
            />
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('PROJECTS.TASK.FORM.PRIORITY') }}
            </span>
            <ProjectSelect
              v-model="form.priority"
              :options="priorityOptions"
              @update:model-value="value => saveField('priority', value)"
            />
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('PROJECTS.TASK.FORM.ASSIGNEE') }}
            </span>
            <ProjectSelect
              v-model="form.assignee_id"
              :options="assigneeOptions"
              @update:model-value="
                value => saveField('assignee_id', value || null)
              "
            />
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('PROJECTS.TASK.FORM.DUE_DATE') }}
            </span>
            <Input v-model="form.due_date" type="date" @blur="saveDueDate" />
          </div>
        </div>
        <div v-if="!isEditing" class="flex justify-end">
          <Button
            type="button"
            color="blue"
            :label="t('PROJECTS.TASK.FORM.SAVE')"
            :disabled="isFormInvalid"
            :is-loading="isSaving"
            @click="createTask"
          />
        </div>
      </div>

      <section v-if="isEditing" class="flex flex-col gap-2">
        <header class="flex items-center justify-between gap-2">
          <h4 class="text-sm font-medium text-n-slate-12">
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
          class="text-sm text-start text-n-slate-10 hover:text-n-slate-12"
          @click="isEditingDescription = true"
        >
          {{ t('PROJECTS.TASK.FORM.DESCRIPTION_EMPTY') }}
        </button>
      </section>

      <section v-if="isEditing" class="flex flex-col gap-4">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="tab => (activeTab = tab.key)"
        />
        <div v-if="activeTab === 'subtasks'" class="flex flex-col gap-3">
          <header class="flex items-center justify-end">
            <span class="text-xs text-n-slate-10">
              {{
                t('PROJECTS.TASK.SUBTASKS.PROGRESS', {
                  done: completedSubtasks,
                  total: subtasks.length,
                })
              }}
            </span>
          </header>
          <div
            v-if="subtasks.length"
            class="h-1 overflow-hidden rounded-full bg-n-slate-4"
          >
            <div class="h-full bg-n-brand" :class="subtaskProgressClass" />
          </div>
          <ul class="flex flex-col gap-2">
            <li
              v-for="subtask in subtasks"
              :key="subtask.id"
              class="flex items-center gap-2"
            >
              <button
                type="button"
                class="flex items-center justify-center size-5 rounded border border-n-weak"
                @click="toggleSubtask(subtask)"
              >
                <Icon
                  v-if="subtask.status === 'done'"
                  icon="i-lucide-check"
                  class="size-3.5 text-n-teal-11"
                />
              </button>
              <span
                class="flex-1 text-sm text-n-slate-12"
                :class="
                  subtask.status === 'done'
                    ? 'line-through text-n-slate-10'
                    : ''
                "
              >
                {{ subtask.title }}
              </span>
              <Button
                type="button"
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-x"
                @click="removeSubtask(subtask)"
              />
            </li>
          </ul>
          <p v-if="!subtasks.length" class="text-sm text-n-slate-10">
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
          <ul class="flex flex-col gap-2">
            <li
              v-for="attachment in attachments"
              :key="attachment.id"
              class="flex items-center justify-between gap-2 text-sm"
            >
              <a
                :href="attachment.file_url"
                target="_blank"
                rel="noopener noreferrer"
                class="truncate text-n-brand"
              >
                {{ attachment.filename }}
              </a>
              <Button
                type="button"
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-x"
                @click="removeAttachment(attachment)"
              />
            </li>
          </ul>
          <p v-if="!attachments.length" class="text-sm text-n-slate-10">
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
            icon="i-lucide-paperclip"
            :label="t('PROJECTS.TASK.ATTACHMENTS.ADD')"
            @click="fileInputRef?.click()"
          />
        </div>

        <div v-else class="flex flex-col gap-3">
          <ul class="flex flex-col gap-3">
            <li
              v-for="comment in comments"
              :key="comment.id"
              class="flex gap-2"
            >
              <Avatar
                :name="comment.author?.name || ''"
                :src="comment.author?.thumbnail"
                :size="24"
              />
              <div class="flex flex-col flex-1 gap-1">
                <div class="flex items-center justify-between gap-2">
                  <span class="text-xs font-medium text-n-slate-12">
                    {{ comment.author?.name }}
                  </span>
                  <span class="text-xs text-n-slate-10">
                    {{ formattedTime(comment.created_at) }}
                  </span>
                </div>
                <div
                  v-dompurify-html="formatMarkdown(comment.content)"
                  class="text-sm break-words prose-sm prose dark:prose-invert max-w-none text-n-slate-11 [&>:first-child]:mt-0 [&>:last-child]:mb-0"
                />
                <button
                  v-if="canDeleteComment(comment)"
                  type="button"
                  class="self-start text-xs text-n-ruby-11"
                  @click="removeComment(comment)"
                >
                  {{ t('PROJECTS.TASK.COMMENTS.DELETE') }}
                </button>
              </div>
            </li>
          </ul>
          <p v-if="!comments.length" class="text-sm text-n-slate-10">
            {{ t('PROJECTS.TASK.COMMENTS.EMPTY') }}
          </p>
          <TaskMarkdownEditor
            :key="`comment-${editorKey}`"
            v-model="commentContent"
            :placeholder="t('PROJECTS.TASK.COMMENTS.ADD_PLACEHOLDER')"
          />
          <Button
            type="button"
            color="blue"
            :label="t('PROJECTS.TASK.COMMENTS.ADD')"
            :disabled="!commentContent.trim()"
            @click="addComment"
          />
        </div>
      </section>
    </div>
  </Dialog>

  <Dialog
    ref="deleteDialogRef"
    type="alert"
    :title="t('PROJECTS.TASK.DELETE.TITLE')"
    :description="t('PROJECTS.TASK.DELETE.MESSAGE', { name: form.title })"
    :confirm-button-label="t('PROJECTS.TASK.DELETE.CONFIRM')"
    @confirm="deleteTask"
  />
</template>

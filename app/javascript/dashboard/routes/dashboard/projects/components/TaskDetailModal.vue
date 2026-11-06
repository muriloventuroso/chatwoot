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
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ProjectSelect from './ProjectSelect.vue';
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
const isEditing = computed(() => Boolean(taskId.value));
const isFormInvalid = computed(() => !form.value.title.trim());

const hydrateForm = record => {
  form.value = {
    title: record?.title || '',
    description: record?.description || '',
    project_column_id: record?.project_column_id ?? null,
    priority: record?.priority || 'medium',
    assignee_id: record?.assignee_id || '',
    due_date: record?.due_date || '',
  };
};

// Does not touch the form, so refreshing subtasks/comments keeps unsaved edits.
const loadTask = id =>
  Promise.all([
    store.dispatch('projects/fetchTask', id),
    store.dispatch('projects/fetchComments', id),
  ]);

const open = async ({ task: record, columnId } = {}) => {
  taskId.value = record?.id || null;
  hydrateForm(record || { project_column_id: columnId });
  subtaskTitle.value = '';
  commentContent.value = '';
  dialogRef.value?.open();
  if (record?.id) await loadTask(record.id);
};

const close = () => dialogRef.value?.close();

const saveTask = async () => {
  if (isFormInvalid.value) return;
  isSaving.value = true;
  const payload = {
    title: form.value.title.trim(),
    description: form.value.description.trim() || null,
    project_column_id: form.value.project_column_id,
    priority: form.value.priority,
    assignee_id: form.value.assignee_id || null,
    due_date: form.value.due_date || null,
  };
  try {
    if (taskId.value) {
      const { project_column_id: columnId, ...rest } = payload;
      if (columnId !== task.value.project_column_id) {
        const siblings = store.getters['projects/getTasksByProject'](
          props.projectId
        );
        await store.dispatch('projects/moveTask', {
          id: taskId.value,
          project_column_id: columnId,
          position: nextColumnPosition(siblings, columnId, taskId.value),
        });
      }
      await store.dispatch('projects/updateTask', {
        id: taskId.value,
        ...rest,
      });
      emit('changed');
    } else {
      const created = await store.dispatch('projects/createTask', {
        projectId: props.projectId,
        ...payload,
      });
      taskId.value = created.id;
      await loadTask(created.id);
      emit('changed');
    }
  } catch (error) {
    useAlert(
      t(
        taskId.value
          ? 'PROJECTS.TASK.MESSAGES.UPDATE_ERROR'
          : 'PROJECTS.TASK.MESSAGES.CREATE_ERROR'
      )
    );
  } finally {
    isSaving.value = false;
  }
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
    :title="form.title || t('PROJECTS.DETAILS.ADD_TASK')"
    :show-confirm-button="false"
    :show-cancel-button="false"
    @close="emit('close')"
  >
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-3">
        <Input
          v-model="form.title"
          :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
        />
        <TextArea
          v-model="form.description"
          :placeholder="t('PROJECTS.TASK.FORM.DESCRIPTION_PLACEHOLDER')"
          :max-length="5000"
          auto-height
        />
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <ProjectSelect
            v-model="form.project_column_id"
            :options="columnOptions"
          />
          <ProjectSelect v-model="form.priority" :options="priorityOptions" />
          <ProjectSelect
            v-model="form.assignee_id"
            :options="assigneeOptions"
          />
          <Input v-model="form.due_date" type="date" />
        </div>
        <div class="flex items-center justify-between gap-3">
          <Button
            v-if="isEditing"
            variant="ghost"
            color="ruby"
            :label="t('PROJECTS.TASK.FORM.DELETE')"
            @click="confirmDelete"
          />
          <span v-else />
          <Button
            color="blue"
            :label="t('PROJECTS.TASK.FORM.SAVE')"
            :disabled="isFormInvalid"
            :is-loading="isSaving"
            @click="saveTask"
          />
        </div>
      </div>

      <template v-if="isEditing">
        <section class="flex flex-col gap-3">
          <header class="flex items-center justify-between">
            <h4 class="text-sm font-medium text-n-slate-12">
              {{ t('PROJECTS.TASK.SUBTASKS.TITLE') }}
            </h4>
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
        </section>

        <section class="flex flex-col gap-3">
          <h4 class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.TASK.ATTACHMENTS.TITLE') }}
          </h4>
          <ul class="flex flex-col gap-2">
            <li
              v-for="attachment in task.attachments || []"
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
                variant="ghost"
                color="slate"
                size="xs"
                icon="i-lucide-x"
                @click="removeAttachment(attachment)"
              />
            </li>
          </ul>
          <p
            v-if="!(task.attachments || []).length"
            class="text-sm text-n-slate-10"
          >
            {{ t('PROJECTS.TASK.ATTACHMENTS.EMPTY') }}
          </p>
          <input
            ref="fileInputRef"
            type="file"
            class="hidden"
            @change="onSelectFiles"
          />
          <Button
            variant="faded"
            color="slate"
            icon="i-lucide-paperclip"
            :label="t('PROJECTS.TASK.ATTACHMENTS.ADD')"
            @click="fileInputRef?.click()"
          />
        </section>

        <section class="flex flex-col gap-3">
          <h4 class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.TASK.COMMENTS.TITLE') }}
          </h4>
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
                <p class="text-sm text-n-slate-11">{{ comment.content }}</p>
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
          <TextArea
            v-model="commentContent"
            :placeholder="t('PROJECTS.TASK.COMMENTS.ADD_PLACEHOLDER')"
            :max-length="5000"
            auto-height
          />
          <Button
            color="blue"
            :label="t('PROJECTS.TASK.COMMENTS.ADD')"
            :disabled="!commentContent.trim()"
            @click="addComment"
          />
        </section>
      </template>
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

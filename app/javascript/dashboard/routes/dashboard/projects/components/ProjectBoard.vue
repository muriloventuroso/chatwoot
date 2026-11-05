<script setup>
import { reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ProjectTaskCard from './ProjectTaskCard.vue';
import { STATUS_DOT_CLASS } from '../constants';

const props = defineProps({
  columns: { type: Array, default: () => [] },
  tasks: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'move',
  'openTask',
  'createTask',
  'addColumn',
  'editColumn',
  'moveColumn',
  'deleteColumn',
]);
const { t } = useI18n();

// Keyed by column id.
const columnTasks = reactive({});
const drafting = reactive({});
const draftTitles = reactive({});
const openMenuId = ref(null);

const syncColumns = () => {
  props.columns.forEach(column => {
    columnTasks[column.id] = props.tasks
      .filter(task => task.project_column_id === column.id)
      .sort((a, b) => a.position - b.position);
  });
};

watch(() => [props.columns, props.tasks], syncColumns, {
  immediate: true,
  deep: true,
});

const startCreate = columnId => {
  drafting[columnId] = true;
};

const submitDraft = columnId => {
  const title = (draftTitles[columnId] || '').trim();
  drafting[columnId] = false;
  draftTitles[columnId] = '';
  if (!title) return;
  emit('createTask', { columnId, title });
};

const menuItems = index => [
  {
    label: t('PROJECTS.COLUMNS.EDIT'),
    action: 'edit',
    value: 'edit',
    icon: 'i-lucide-pencil',
  },
  {
    label: t('PROJECTS.COLUMNS.MOVE_LEFT'),
    action: 'moveLeft',
    value: 'moveLeft',
    icon: 'i-lucide-arrow-left',
    disabled: index === 0,
  },
  {
    label: t('PROJECTS.COLUMNS.MOVE_RIGHT'),
    action: 'moveRight',
    value: 'moveRight',
    icon: 'i-lucide-arrow-right',
    disabled: index === props.columns.length - 1,
  },
  {
    label: t('PROJECTS.COLUMNS.DELETE'),
    action: 'delete',
    value: 'delete',
    icon: 'i-lucide-trash',
  },
];

const toggleMenu = columnId => {
  openMenuId.value = openMenuId.value === columnId ? null : columnId;
};

const closeMenu = columnId => {
  if (openMenuId.value === columnId) openMenuId.value = null;
};

const handleMenuAction = (column, { action }) => {
  openMenuId.value = null;
  if (action === 'edit') emit('editColumn', column);
  if (action === 'moveLeft') emit('moveColumn', { column, direction: -1 });
  if (action === 'moveRight') emit('moveColumn', { column, direction: 1 });
  if (action === 'delete') emit('deleteColumn', column);
};

const onChange = (columnId, event) => {
  if (!event.added && !event.moved) return;
  const element = event.added?.element || event.moved?.element;
  const newIndex = event.added?.newIndex ?? event.moved?.newIndex;
  if (!element) return;
  const siblings = columnTasks[columnId];
  const previous = siblings[newIndex - 1];
  const nextSibling = siblings[newIndex + 1];
  let position;
  if (previous && nextSibling)
    position = (previous.position + nextSibling.position) / 2;
  else if (previous) position = previous.position + 1;
  else if (nextSibling) position = nextSibling.position / 2;
  else position = 1;
  if (element.project_column_id === columnId && element.position === position)
    return;
  emit('move', { task: element, columnId, position });
};
</script>

<template>
  <div class="flex flex-col flex-1 gap-4 md:flex-row md:overflow-x-auto">
    <section
      v-for="(column, index) in columns"
      :key="column.id"
      class="flex flex-col gap-3 p-3 rounded-xl bg-n-surface-2 md:w-72 md:shrink-0"
    >
      <header class="flex items-center justify-between gap-2">
        <span
          class="flex items-center min-w-0 gap-2 text-sm font-medium text-n-slate-12"
        >
          <span
            class="w-2 h-2 rounded-full shrink-0"
            :class="STATUS_DOT_CLASS[column.category]"
          />
          <span class="truncate">{{ column.name }}</span>
          <span class="text-xs text-n-slate-10">
            {{ columnTasks[column.id]?.length || 0 }}
          </span>
        </span>
        <div class="flex items-center shrink-0">
          <Button
            variant="ghost"
            color="slate"
            icon="i-lucide-plus"
            size="xs"
            :aria-label="t('PROJECTS.DETAILS.ADD_TASK')"
            @click="startCreate(column.id)"
          />
          <div v-on-clickaway="() => closeMenu(column.id)" class="relative">
            <Button
              variant="ghost"
              color="slate"
              icon="i-lucide-ellipsis-vertical"
              size="xs"
              :aria-label="t('PROJECTS.COLUMNS.MENU')"
              :class="openMenuId === column.id ? 'bg-n-alpha-2' : ''"
              @click="toggleMenu(column.id)"
            />
            <DropdownMenu
              v-if="openMenuId === column.id"
              :menu-items="menuItems(index)"
              class="end-0 mt-1 w-52 top-full"
              @action="handleMenuAction(column, $event)"
            />
          </div>
        </div>
      </header>
      <Input
        v-if="drafting[column.id]"
        :key="`draft-${column.id}`"
        v-model="draftTitles[column.id]"
        size="sm"
        autofocus
        :placeholder="t('PROJECTS.TASK.FORM.TITLE_PLACEHOLDER')"
        @enter="submitDraft(column.id)"
        @blur="submitDraft(column.id)"
      />
      <Draggable
        v-model="columnTasks[column.id]"
        group="project-tasks"
        item-key="id"
        class="flex flex-col flex-1 gap-2 min-h-16"
        @change="onChange(column.id, $event)"
      >
        <template #item="{ element }">
          <ProjectTaskCard :task="element" @open="emit('openTask', $event)" />
        </template>
      </Draggable>
      <button
        type="button"
        class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12"
        @click="startCreate(column.id)"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('PROJECTS.DETAILS.ADD_TASK') }}
      </button>
    </section>
    <button
      type="button"
      class="flex items-center justify-center gap-2 p-3 text-sm border border-dashed rounded-xl border-n-weak text-n-slate-11 hover:text-n-slate-12 hover:border-n-strong md:self-start md:w-72 md:shrink-0"
      @click="emit('addColumn')"
    >
      <Icon icon="i-lucide-plus" class="size-4" />
      {{ t('PROJECTS.COLUMNS.ADD') }}
    </button>
  </div>
</template>

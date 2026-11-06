<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ProjectSelect from './ProjectSelect.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import { TASK_STATUSES } from '../constants';

defineProps({
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

// Selects open over the dialog instead of growing its scroll area.
provideDropdownTeleport();
const { t } = useI18n();

const dialogRef = ref(null);
const editingId = ref(null);
const form = reactive({ name: '', category: 'in_progress' });

const isEditing = computed(() => editingId.value !== null);
const isFormInvalid = computed(() => !form.name.trim());

// A column's type is the task status it stands for.
const categoryOptions = computed(() =>
  TASK_STATUSES.map(status => ({
    value: status,
    label: t(`PROJECTS.TASK.STATUS.${status.toUpperCase()}`),
  }))
);

const open = (column = null) => {
  editingId.value = column?.id ?? null;
  form.name = column?.name || '';
  form.category = column?.category || 'in_progress';
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (isFormInvalid.value) return;
  emit('save', {
    id: editingId.value,
    name: form.name.trim(),
    category: form.category,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      isEditing
        ? t('PROJECTS.COLUMNS.FORM.EDIT_TITLE')
        : t('PROJECTS.COLUMNS.FORM.CREATE_TITLE')
    "
    :confirm-button-label="t('PROJECTS.COLUMNS.FORM.SAVE')"
    :disable-confirm-button="isFormInvalid"
    :is-loading="isSaving"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('PROJECTS.COLUMNS.FORM.NAME') }}
        </label>
        <Input
          v-model="form.name"
          :placeholder="t('PROJECTS.COLUMNS.FORM.NAME_PLACEHOLDER')"
          autofocus
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('PROJECTS.COLUMNS.FORM.CATEGORY') }}
        </label>
        <ProjectSelect v-model="form.category" :options="categoryOptions" />
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('PROJECTS.COLUMNS.FORM.CATEGORY_HELP') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>

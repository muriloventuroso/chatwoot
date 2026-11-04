<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import {
  PROJECT_COLOR_CLASS,
  PROJECT_COLORS,
  PROJECT_STATUSES,
} from '../constants';

const emit = defineEmits(['save']);
const { t } = useI18n();

const dialogRef = ref(null);
const editingId = ref(null);
const form = reactive({
  name: '',
  description: '',
  status: 'active',
  color: PROJECT_COLORS[0],
  start_date: '',
  end_date: '',
});

const isEditing = computed(() => editingId.value !== null);
const isFormInvalid = computed(() => !form.name.trim());

const open = (project = null) => {
  editingId.value = project?.id ?? null;
  form.name = project?.name || '';
  form.description = project?.description || '';
  form.status = project?.status || 'active';
  form.color = project?.color || PROJECT_COLORS[0];
  form.start_date = project?.start_date || '';
  form.end_date = project?.end_date || '';
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (isFormInvalid.value) return;
  emit('save', {
    id: editingId.value,
    name: form.name.trim(),
    description: form.description.trim() || null,
    status: form.status,
    color: form.color,
    start_date: form.start_date || null,
    end_date: form.end_date || null,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    overflow-y-auto
    :title="
      isEditing
        ? t('PROJECTS.FORM.EDIT_TITLE')
        : t('PROJECTS.FORM.CREATE_TITLE')
    "
    :show-confirm-button="false"
    :show-cancel-button="false"
    @close="() => {}"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('PROJECTS.FORM.NAME') }}
        </label>
        <Input
          v-model="form.name"
          :placeholder="t('PROJECTS.FORM.NAME_PLACEHOLDER')"
          autofocus
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('PROJECTS.FORM.DESCRIPTION') }}
        </label>
        <TextArea
          v-model="form.description"
          :placeholder="t('PROJECTS.FORM.DESCRIPTION_PLACEHOLDER')"
          :max-length="5000"
          auto-height
        />
      </div>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.FORM.STATUS') }}
          </label>
          <select
            v-model="form.status"
            class="w-full h-10 px-3 text-sm border rounded-lg bg-n-solid-1 border-n-weak text-n-slate-12"
          >
            <option
              v-for="status in PROJECT_STATUSES"
              :key="status"
              :value="status"
            >
              {{ t(`PROJECTS.STATUS.${status.toUpperCase()}`) }}
            </option>
          </select>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.FORM.COLOR') }}
          </label>
          <div class="flex items-center gap-2 h-10">
            <button
              v-for="color in PROJECT_COLORS"
              :key="color"
              type="button"
              class="w-6 h-6 rounded-full"
              :class="[
                PROJECT_COLOR_CLASS[color],
                form.color === color ? 'ring-2 ring-offset-2 ring-n-brand' : '',
              ]"
              @click="form.color = color"
            />
          </div>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.FORM.START_DATE') }}
          </label>
          <Input v-model="form.start_date" type="date" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('PROJECTS.FORM.END_DATE') }}
          </label>
          <Input v-model="form.end_date" type="date" />
        </div>
      </div>
      <div class="flex items-center justify-between gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="faded"
          color="slate"
          @click="close"
        />
        <Button
          :label="t('PROJECTS.FORM.SAVE')"
          color="blue"
          :disabled="isFormInvalid"
          @click="handleConfirm"
        />
      </div>
    </div>
  </Dialog>
</template>

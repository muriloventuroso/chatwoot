<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import ProjectSelect from './ProjectSelect.vue';

const props = defineProps({
  members: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['add', 'remove']);

// The panel body scrolls, so the picker opens on top of it instead of inside it.
provideDropdownTeleport();
const { t } = useI18n();

const panelRef = ref(null);
const removeDialogRef = ref(null);
const memberToRemove = ref(null);

const addOptions = computed(() => {
  const memberIds = new Set(props.members.map(member => member.user_id));
  return props.agents
    .filter(agent => !memberIds.has(agent.id))
    .map(agent => ({ value: agent.id, label: agent.name }));
});

const confirmRemove = member => {
  memberToRemove.value = member;
  removeDialogRef.value?.open();
};

const remove = () => {
  emit('remove', memberToRemove.value);
  removeDialogRef.value?.close();
};

defineExpose({
  open: () => panelRef.value?.open(),
  close: () => panelRef.value?.close(),
});
</script>

<template>
  <SidePanel
    ref="panelRef"
    width="md"
    :title="t('PROJECTS.MEMBERS.TITLE')"
    :description="t('PROJECTS.MEMBERS.DESCRIPTION')"
  >
    <div class="flex flex-col gap-4">
      <ProjectSelect
        model-value=""
        :options="addOptions"
        :placeholder="t('PROJECTS.MEMBERS.ADD')"
        trigger-class="h-10 bg-n-alpha-1 text-n-slate-11 !border-transparent"
        @update:model-value="emit('add', $event)"
      />
      <ul class="flex flex-col mb-0 divide-y divide-n-weak">
        <li
          v-for="member in members"
          :key="member.id"
          class="flex items-center gap-3 py-2.5"
        >
          <Avatar
            :name="member.user?.name || ''"
            :src="member.user?.thumbnail"
            :size="32"
            rounded-full
          />
          <div class="flex flex-col flex-1 min-w-0">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ member.user?.name }}
            </span>
            <span class="text-xs truncate text-n-slate-11">
              {{ member.user?.email }}
            </span>
          </div>
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-user-minus"
            :aria-label="
              t('PROJECTS.MEMBERS.REMOVE_NAMED', { name: member.user?.name })
            "
            :title="t('PROJECTS.MEMBERS.REMOVE')"
            @click="confirmRemove(member)"
          />
        </li>
      </ul>
      <p v-if="!members.length" class="mb-0 text-sm text-n-slate-11">
        {{ t('PROJECTS.MEMBERS.EMPTY') }}
      </p>
    </div>
  </SidePanel>
  <Dialog
    ref="removeDialogRef"
    type="alert"
    :title="t('PROJECTS.MEMBERS.REMOVE_DIALOG.TITLE')"
    :description="
      t('PROJECTS.MEMBERS.REMOVE_DIALOG.MESSAGE', {
        name: memberToRemove?.user?.name,
      })
    "
    :confirm-button-label="t('PROJECTS.MEMBERS.REMOVE_DIALOG.CONFIRM')"
    @confirm="remove"
  />
</template>

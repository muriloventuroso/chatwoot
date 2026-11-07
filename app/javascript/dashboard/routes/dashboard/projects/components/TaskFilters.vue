<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { PRIORITY_ICON_CLASS, TASK_PRIORITIES, UNASSIGNED } from '../constants';

const props = defineProps({
  // Project members: [{ id, name, thumbnail }]
  people: { type: Array, default: () => [] },
});

const emit = defineEmits(['clear']);

// '' matches everyone; UNASSIGNED matches tasks with nobody on them.
const assignee = defineModel('assignee', { type: [String, Number] });
const priority = defineModel('priority', { type: String });

const { t } = useI18n();
const currentUserId = useMapGetter('getCurrentUserID');

// The current user goes first: filtering by "me" is the most common case.
const assigneeOptions = computed(() => {
  const people = [...props.people].sort(
    (a, b) => (b.id === currentUserId.value) - (a.id === currentUserId.value)
  );
  return [
    { value: '', label: t('PROJECTS.FILTERS.EVERYONE') },
    ...people.map(person => ({
      value: person.id,
      label:
        person.id === currentUserId.value
          ? t('PROJECTS.FILTERS.ME', { name: person.name })
          : person.name,
      person,
    })),
    { value: UNASSIGNED, label: t('PROJECTS.TASK.FORM.UNASSIGNED') },
  ];
});

const priorityOptions = computed(() => [
  { value: '', label: t('PROJECTS.FILTERS.ANY_PRIORITY') },
  ...TASK_PRIORITIES.map(value => ({
    value,
    label: t(`PROJECTS.TASK.PRIORITY.${value.toUpperCase()}`),
  })),
]);

const isFiltered = computed(() => assignee.value !== '' || !!priority.value);
</script>

<template>
  <div class="flex flex-col gap-4 p-4 sm:w-80">
    <section class="flex flex-col gap-1.5">
      <h4 class="mb-0 text-label-small text-n-slate-11">
        {{ t('PROJECTS.TASK.FORM.ASSIGNEE') }}
      </h4>
      <div class="flex flex-col overflow-y-auto max-h-56 -mx-1">
        <button
          v-for="option in assigneeOptions"
          :key="option.value"
          type="button"
          class="flex items-center gap-2 px-2 py-1.5 mx-1 text-sm rounded-lg text-start text-n-slate-12 hover:bg-n-alpha-2"
          :class="{ 'bg-n-alpha-1': assignee === option.value }"
          :aria-pressed="assignee === option.value"
          @click="assignee = option.value"
        >
          <Avatar
            v-if="option.person"
            :name="option.person.name"
            :src="option.person.thumbnail"
            :size="20"
            rounded-full
          />
          <Icon
            v-else
            :icon="option.value ? 'i-lucide-user-x' : 'i-lucide-users'"
            class="size-5 p-0.5 text-n-slate-11"
          />
          <span class="flex-1 truncate">{{ option.label }}</span>
          <Icon
            v-if="assignee === option.value"
            icon="i-lucide-check"
            class="size-4 text-n-brand"
          />
        </button>
      </div>
    </section>
    <section class="flex flex-col gap-1.5">
      <h4 class="mb-0 text-label-small text-n-slate-11">
        {{ t('PROJECTS.TASK.FORM.PRIORITY') }}
      </h4>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="option in priorityOptions"
          :key="option.value"
          type="button"
          class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            priority === option.value
              ? 'border-n-brand text-n-blue-11 bg-n-blue-2'
              : 'border-n-weak text-n-slate-11 hover:border-n-strong'
          "
          :aria-pressed="priority === option.value"
          @click="priority = option.value"
        >
          <Icon
            v-if="option.value"
            icon="i-lucide-flag"
            class="size-3"
            :class="PRIORITY_ICON_CLASS[option.value]"
          />
          {{ option.label }}
        </button>
      </div>
    </section>
    <Button
      v-if="isFiltered"
      variant="ghost"
      color="slate"
      size="sm"
      icon="i-lucide-x"
      class="self-start"
      :label="t('PROJECTS.CLEAR_FILTERS')"
      @click="emit('clear')"
    />
  </div>
</template>

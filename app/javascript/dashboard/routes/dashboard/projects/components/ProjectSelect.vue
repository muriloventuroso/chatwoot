<script setup>
import { computed } from 'vue';

import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// A native <select> opens on macOS centered on the selected item, not below the field.
const props = defineProps({
  // [{ value, label }]
  options: { type: Array, required: true },
  // Shown when the value matches no option.
  placeholder: { type: String, default: '' },
  triggerClass: {
    type: [String, Array, Object],
    default: 'h-10 bg-n-solid-1 text-n-slate-12',
  },
});

const modelValue = defineModel({ type: [String, Number], required: true });

const selectedLabel = computed(
  () =>
    props.options.find(option => option.value === modelValue.value)?.label ||
    props.placeholder
);
</script>

<template>
  <FilterSelect v-model="modelValue" :options="options">
    <template #trigger="{ toggle }">
      <button
        type="button"
        class="flex items-center justify-between w-full gap-2 px-3 text-sm border rounded-lg text-start border-n-weak"
        :class="triggerClass"
        @click="toggle"
      >
        <span class="truncate">{{ selectedLabel }}</span>
        <Icon icon="i-lucide-chevron-down" class="size-4 shrink-0 opacity-70" />
      </button>
    </template>
  </FilterSelect>
</template>

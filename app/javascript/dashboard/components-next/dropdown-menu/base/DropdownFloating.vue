<script setup>
import { ref } from 'vue';
import { useDropdownPosition } from 'dashboard/composables/useDropdownPosition';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const { trigger } = defineProps({
  trigger: {
    type: Function,
    required: true,
  },
});

const menuRef = ref(null);

// A modal <dialog> sits in the browser's top layer, above anything on <body>, so a menu opened
// inside one must render in it to be seen.
const teleportTarget = trigger()?.closest('dialog') ?? 'body';

const { fixedPosition } = useDropdownPosition(trigger, menuRef, true, {
  align: 'start',
});
</script>

<template>
  <TeleportWithDirection :to="teleportTarget">
    <div
      data-dropdown-menu
      class="overflow-y-auto"
      :class="fixedPosition.class"
      :style="fixedPosition.style"
    >
      <div ref="menuRef" class="[&>*]:!static">
        <slot />
      </div>
    </div>
  </TeleportWithDirection>
</template>

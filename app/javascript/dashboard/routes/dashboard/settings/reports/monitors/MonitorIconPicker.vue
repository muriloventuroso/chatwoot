<script setup>
import { defineAsyncComponent, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import EmojiIcon from 'dashboard/components-next/emoji-icon-picker/EmojiIcon.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownFloating from 'dashboard/components-next/dropdown-menu/base/DropdownFloating.vue';

const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const icon = defineModel('icon', { type: String, required: true });
const color = defineModel('color', { type: String, required: true });

const { t } = useI18n();
const isOpen = ref(false);
const triggerRef = ref(null);

const select = selected => {
  icon.value = selected.value;
  color.value = selected.type === 'icon' ? selected.color : '';
  isOpen.value = false;
};
</script>

<template>
  <div class="absolute bottom-0 start-0">
    <OnClickOutside
      :options="{ ignore: ['[data-dropdown-menu]'] }"
      @trigger="isOpen = false"
    >
      <Button
        ref="triggerRef"
        v-tooltip.top="t('MONITORS.CHOOSE_ICON')"
        type="button"
        variant="ghost"
        color="slate"
        :aria-label="t('MONITORS.CHOOSE_ICON')"
        :aria-expanded="isOpen"
        class="!size-10 !p-0 ltr:!rounded-r-none rtl:!rounded-l-none"
        @click="isOpen = !isOpen"
      >
        <EmojiIcon
          v-if="icon"
          :value="icon"
          :color="color"
          class="size-5 text-xl !leading-5"
        />
        <Icon v-else icon="i-lucide-monitor" class="size-4" />
      </Button>
      <DropdownFloating v-if="isOpen" :trigger="() => triggerRef?.$el">
        <EmojiIconPicker
          :value="icon"
          :color="color"
          @select="select"
          @color-change="value => (color = value)"
        />
      </DropdownFloating>
    </OnClickOutside>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { isSafeUrl } from '@chatwoot/prosemirror-schema/src/rules/links';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  href: { type: String, required: true },
  position: { type: Object, default: null },
});

const emit = defineEmits(['save', 'remove', 'cancel']);

const { t } = useI18n();

const url = ref(props.href);

const isValid = computed(() => isSafeUrl(url.value));
const canOpen = computed(() => isSafeUrl(props.href));

const menuStyle = computed(() => {
  if (!props.position) return {};
  const style = { top: `${props.position.top}px` };
  if (props.position.right != null) {
    style.right = `${props.position.right}px`;
  } else {
    style.left = `${props.position.left}px`;
  }
  return style;
});

const onSave = () => {
  if (isValid.value) emit('save', url.value.trim());
};

const openLink = () =>
  window.open(props.href.trim(), '_blank', 'noopener,noreferrer');
</script>

<template>
  <div
    class="absolute z-50 flex flex-col p-3 shadow-lg gap-2.5 w-[22rem] bg-n-solid-2 outline outline-1 outline-n-weak rounded-xl"
    :style="menuStyle"
    @keydown.esc.prevent="emit('cancel')"
  >
    <Input
      v-model="url"
      type="url"
      custom-input-class="!ps-9"
      :placeholder="t('HELP_CENTER.ARTICLE_EDITOR.LINK_EDIT.PLACEHOLDER')"
      :message-type="isValid ? 'info' : 'error'"
      @enter="onSave"
    >
      <template #prefix>
        <Icon
          icon="i-lucide-link"
          class="absolute z-10 -translate-y-1/2 pointer-events-none start-3 top-5 size-4"
          :class="isValid ? 'text-n-slate-11' : 'text-n-ruby-9'"
        />
      </template>
    </Input>
    <div class="flex items-center justify-between gap-2">
      <Button
        ghost
        slate
        sm
        type="button"
        icon="i-lucide-external-link"
        :label="t('HELP_CENTER.ARTICLE_EDITOR.LINK_EDIT.OPEN')"
        :disabled="!canOpen"
        @click="openLink"
      />
      <div class="flex items-center gap-2">
        <Button
          ghost
          ruby
          sm
          type="button"
          :label="t('HELP_CENTER.ARTICLE_EDITOR.LINK_EDIT.REMOVE')"
          @click="emit('remove')"
        />
        <Button
          solid
          sm
          type="button"
          :label="t('HELP_CENTER.ARTICLE_EDITOR.LINK_EDIT.SAVE')"
          :disabled="!isValid || url.trim() === href"
          @click="onSave"
        />
      </div>
    </div>
  </div>
</template>

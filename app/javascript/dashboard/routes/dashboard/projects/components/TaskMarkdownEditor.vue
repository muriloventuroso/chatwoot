<script setup>
import FullEditor from 'dashboard/components/widgets/WootWriter/FullEditor.vue';
import { ARTICLE_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';

defineProps({
  placeholder: { type: String, default: '' },
  autofocus: { type: Boolean, default: false },
});

const content = defineModel({ type: String, default: '' });
</script>

<!-- Same editor and toolbar as help center articles, sized for the task panel. -->
<template>
  <FullEditor
    v-model="content"
    :placeholder="placeholder"
    :enabled-menu-options="ARTICLE_EDITOR_MENU_OPTIONS"
    :autofocus="autofocus"
    class="px-3 pb-3 border rounded-lg border-n-weak [&_.ProseMirror-woot-style]:min-h-24 [&_.ProseMirror-menubar]:sticky [&_.ProseMirror-menubar]:top-0 [&_.ProseMirror-menubar]:z-10 [&_.ProseMirror-menubar]:flex [&_.ProseMirror-menubar]:flex-wrap [&_.ProseMirror-menubar]:items-center [&_.ProseMirror-menubar]:gap-4 [&_.ProseMirror-menubar]:!w-full [&_.ProseMirror-menubar]:py-2 [&_.ProseMirror-menubar]:mb-2 [&_.ProseMirror-menubar]:border-b [&_.ProseMirror-menubar]:border-n-weak [&_.ProseMirror-menubar]:bg-n-solid-2 [&_.ProseMirror-menuitem]:flex [&_.ProseMirror-menuitem]:items-center [&_.ProseMirror-menuitem]:size-4 [&_.ProseMirror-menuitem]:!me-0 [&_.ProseMirror-icon]:p-0.5 [&_.ProseMirror-icon]:shrink-0 [&_.ProseMirror-menu-active]:bg-n-slate-3"
  />
</template>

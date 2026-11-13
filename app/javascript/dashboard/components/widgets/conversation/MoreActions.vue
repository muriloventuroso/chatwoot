<script setup>
import { computed, onUnmounted, useTemplateRef } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConversationRoutePath } from 'dashboard/composables/useConversationRoutePath';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import wootConstants from 'dashboard/constants/globals';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { isSessionLayerProvider } from 'dashboard/helper/whatsappSession';

import {
  CMD_MUTE_CONVERSATION,
  CMD_PIN_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
  CMD_UNPIN_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

// No props needed as we're getting currentChat from the store directly
const store = useStore();
const router = useRouter();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const { updateUISettings } = useUISettings();
const { buildConversationListPath } = useConversationRoutePath();
const deleteDialogRef = useTemplateRef('deleteDialogRef');

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);

const currentChat = computed(() => store.getters.getSelectedChat);
const isPinnedGetter = useMapGetter('conversationPins/isPinned');
const isPinned = computed(() => isPinnedGetter.value(currentChat.value.id));
// Resolving drops the pins, so pinning a resolved conversation would only burn one of the five slots.
const canTogglePin = computed(
  () =>
    isPinned.value ||
    currentChat.value.status !== wootConstants.STATUS_TYPE.RESOLVED
);

const pin = async () => {
  try {
    await store.dispatch('conversationPins/pin', currentChat.value.id);
  } catch (error) {
    useAlert(error?.message ?? t('CONVERSATION.PIN.ERROR'));
  }
};

const unpin = async () => {
  try {
    await store.dispatch('conversationPins/unpin', currentChat.value.id);
  } catch (error) {
    useAlert(error?.message ?? t('CONVERSATION.PIN.ERROR'));
  }
};

const togglePin = () => {
  if (!canTogglePin.value) return undefined;

  return isPinned.value ? unpin() : pin();
};

useKeyboardEvents({
  'Alt+KeyI': { action: togglePin },
});

// The files of an imported history that the inbox's automatic fetch left behind, for one
// conversation: somebody reading an old group is who needs them.
const canFetchHistoryMedia = computed(() => {
  const inbox = store.getters['inboxes/getInbox'](currentChat.value.inbox_id);
  return isSessionLayerProvider(inbox?.provider);
});

const fetchHistoryMedia = async () => {
  try {
    await ConversationApi.fetchHistoryMedia(currentChat.value.id);
    useAlert(t('CONVERSATION.HISTORY_MEDIA.DOWNLOAD_ALL_REQUESTED'));
  } catch (error) {
    useAlert(t('CONVERSATION.HISTORY_MEDIA.DOWNLOAD_ALL_ERROR'));
  }
};

const actionMenuItems = computed(() => {
  const items = [];

  if (!currentChat.value.muted) {
    items.push({
      icon: 'i-lucide-volume-off',
      label: t('CONTACT_PANEL.MUTE_CONTACT'),
      action: 'mute',
      value: 'mute',
    });
  } else {
    items.push({
      icon: 'i-lucide-volume-1',
      label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
      action: 'unmute',
      value: 'unmute',
    });
  }

  if (canTogglePin.value) {
    items.push({
      icon: isPinned.value ? 'i-lucide-pin-off' : 'i-lucide-pin',
      label: isPinned.value
        ? t('CONVERSATION.PIN.UNPIN')
        : t('CONVERSATION.PIN.PIN'),
      action: 'toggle_pin',
      value: 'toggle_pin',
    });
  }

  items.push(
    {
      icon: 'i-lucide-mail',
      label: t('CONVERSATION.CARD_CONTEXT_MENU.MARK_AS_UNREAD'),
      action: 'mark_unread',
      value: 'mark_unread',
    },
    // Assignee, team, priority and labels live in the side panel, which is the only place a phone
    // or the single-column layout can reach them: the list's right-click menu needs a mouse.
    {
      icon: 'i-lucide-sliders-horizontal',
      label: t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS'),
      action: 'conversation_actions',
      value: 'conversation_actions',
    },
    {
      icon: 'i-lucide-share',
      label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
      action: 'send_transcript',
      value: 'send_transcript',
    }
  );

  if (isAdmin.value) {
    items.push({
      icon: 'i-lucide-trash-2',
      label: t('CONVERSATION.CARD_CONTEXT_MENU.DELETE'),
      action: 'delete',
      value: 'delete',
    });
  }

  if (canFetchHistoryMedia.value) {
    items.push({
      icon: 'i-lucide-download',
      label: t('CONVERSATION.HISTORY_MEDIA.DOWNLOAD_ALL'),
      action: 'fetch_history_media',
      value: 'fetch_history_media',
    });
  }

  return items;
});

const markAsUnread = async () => {
  try {
    await store.dispatch('markMessagesUnread', { id: currentChat.value.id });
    router.push(buildConversationListPath());
  } catch {
    // Same as the list's context menu: a failed mark leaves the conversation as it was.
  }
};

const openConversationActions = () =>
  updateUISettings({
    is_contact_sidebar_open: true,
    is_copilot_panel_open: false,
    is_conv_actions_open: true,
  });

const deleteConversation = async () => {
  try {
    await store.dispatch('deleteConversation', currentChat.value.id);
    deleteDialogRef.value.close();
    router.push(buildConversationListPath());
    useAlert(t('CONVERSATION.SUCCESS_DELETE_CONVERSATION'));
  } catch {
    useAlert(t('CONVERSATION.FAIL_DELETE_CONVERSATION'));
  }
};

const handleActionClick = ({ action }) => {
  toggleDropdown(false);

  if (action === 'mute') {
    store.dispatch('muteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
  } else if (action === 'unmute') {
    store.dispatch('unmuteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
  } else if (action === 'toggle_pin') {
    togglePin();
  } else if (action === 'send_transcript') {
    toggleEmailModal();
  } else if (action === 'mark_unread') {
    markAsUnread();
  } else if (action === 'conversation_actions') {
    openConversationActions();
  } else if (action === 'delete') {
    deleteDialogRef.value.open();
  } else if (action === 'fetch_history_media') {
    fetchHistoryMedia();
  }
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_PIN_CONVERSATION, pin);
emitter.on(CMD_UNPIN_CONVERSATION, unpin);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_PIN_CONVERSATION, pin);
  emitter.off(CMD_UNPIN_CONVERSATION, unpin);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <div
      v-on-clickaway="() => toggleDropdown(false)"
      class="relative flex items-center group"
    >
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleDropdown()"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :menu-items="actionMenuItems"
        class="mt-1 ltr:right-0 rtl:left-0 top-full"
        @action="handleActionClick"
      />
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="
        $t('CONVERSATION.DELETE_CONVERSATION.TITLE', {
          conversationId: currentChat.id,
        })
      "
      :description="$t('CONVERSATION.DELETE_CONVERSATION.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
      @confirm="deleteConversation"
    />
  </div>
</template>

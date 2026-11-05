import { ref } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { useMapGetter } from 'dashboard/composables/store';
import Message from '../Message.vue';
import ContextMenu from 'dashboard/modules/conversations/components/MessageContextMenu.vue';

vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables', () => ({ useTrack: vi.fn() }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(1), currentAccount: ref({}) }),
}));
vi.mock('dashboard/composables/useTranslations', () => ({
  useTranslations: () => ({ translationContent: ref('') }),
}));
vi.mock('shared/composables/useBranding', () => ({
  useBranding: () => ({ replaceInstallationName: text => text }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 }, query: {} }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const GETTERS = {
  'inboxes/getInbox': () => ({}),
  'globalConfig/isOnChatwootCloud': false,
  getCurrentUser: { id: 1, accounts: [{ id: 1, role: 'agent' }] },
  'integrations/getIntegration': () => ({ hooks: [] }),
  getAutoTranslate: {},
  getMessageTranslationState: () => ({}),
};

const mountMessage = (props = {}) =>
  shallowMount(Message, {
    props: {
      id: 10,
      messageType: 0,
      status: 'sent',
      content: 'Olá',
      conversationId: 1,
      createdAt: 100,
      currentUserId: 1,
      ...props,
    },
  });

const actionsButton = wrapper =>
  wrapper.find('button[aria-label="CONVERSATION.MESSAGE_ACTIONS"]');

describe('message actions button', () => {
  beforeEach(() => {
    useMapGetter.mockImplementation(name => ref(GETTERS[name]));
  });

  it('opens the context menu on a message whose inbox has no reactions', async () => {
    const wrapper = mountMessage({ inboxSupportsReactions: false });
    const menu = wrapper.findComponent(ContextMenu);

    expect(menu.props('isOpen')).toBe(false);
    await actionsButton(wrapper).trigger('click', { clientX: 5, clientY: 8 });

    expect(menu.props('isOpen')).toBe(true);
    expect(menu.props('enabledOptions').translate).toBe(true);
  });

  it('is not rendered for an unsupported message, which has no context menu', () => {
    const wrapper = mountMessage({
      contentAttributes: { isUnsupported: true },
    });

    expect(actionsButton(wrapper).exists()).toBe(false);
  });
});

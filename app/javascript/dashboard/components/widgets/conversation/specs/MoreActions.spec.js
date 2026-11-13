import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref, nextTick } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import MoreActions from '../MoreActions.vue';

const dispatch = vi.fn();
const push = vi.fn();
const updateUISettings = vi.fn();
const isAdmin = ref(false);
const openDialog = vi.fn();

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch,
    getters: {
      getSelectedChat: { id: 42, status: 'open', muted: false },
      'inboxes/getInbox': () => ({}),
    },
  }),
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(() => false),
}));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ updateUISettings }),
}));
vi.mock('dashboard/composables/useConversationRoutePath', () => ({
  useConversationRoutePath: () => ({
    buildConversationListPath: () => '/conversations',
  }),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
// @vueuse/core resolves its own copy of vue under vitest, so its useToggle ref never re-renders the component.
vi.mock('@vueuse/core', async () => {
  const actual = await vi.importActual('@vueuse/core');
  const { ref: vueRef } = await vi.importActual('vue');
  return {
    ...actual,
    useToggle: initial => {
      const state = vueRef(initial);
      const toggle = value => {
        state.value = value ?? !state.value;
      };
      return [state, toggle];
    },
  };
});
vi.mock('vue-i18n', async () => {
  const actual = await vi.importActual('vue-i18n');
  return { ...actual, useI18n: () => ({ t: key => key }) };
});

const mountActions = () =>
  mount(MoreActions, {
    global: {
      mocks: { $t: key => key },
      directives: { onClickaway: {} },
      stubs: {
        ResolveAction: true,
        EmailTranscriptModal: true,
        DropdownMenu: {
          props: ['menuItems'],
          emits: ['action'],
          template: '<div class="menu" />',
        },
        Dialog: {
          emits: ['confirm'],
          methods: { open: openDialog, close: vi.fn() },
          template: '<div class="dialog" />',
        },
      },
    },
  });

const openMenu = async wrapper => {
  await wrapper.find('button').trigger('click');
  return wrapper.findComponent('.menu');
};

const actionsOf = menu => menu.props('menuItems').map(item => item.action);

describe('MoreActions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    isAdmin.value = false;
  });

  it('offers delete only to administrators, like the API', async () => {
    const wrapper = mountActions();
    expect(actionsOf(await openMenu(wrapper))).not.toContain('delete');

    isAdmin.value = true;
    await nextTick();
    expect(actionsOf(wrapper.findComponent('.menu'))).toContain('delete');
  });

  it('deletes the open conversation only after confirming, then leaves it', async () => {
    isAdmin.value = true;
    const wrapper = mountActions();
    const menu = await openMenu(wrapper);

    menu.vm.$emit('action', { action: 'delete' });
    expect(openDialog).toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();

    wrapper.findComponent('.dialog').vm.$emit('confirm');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('deleteConversation', 42);
    expect(push).toHaveBeenCalledWith('/conversations');
  });

  it('opens the side panel on the conversation actions', async () => {
    const menu = await openMenu(mountActions());

    menu.vm.$emit('action', { action: 'conversation_actions' });

    expect(updateUISettings).toHaveBeenCalledWith({
      is_contact_sidebar_open: true,
      is_copilot_panel_open: false,
      is_conv_actions_open: true,
    });
  });
});

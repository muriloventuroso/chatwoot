import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import SearchAPI from 'dashboard/api/search';
import ConversationMessageSearch from '../ConversationMessageSearch.vue';

const push = vi.fn();

vi.mock('dashboard/api/search', () => ({ default: { messages: vi.fn() } }));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ query: { tab: 'all' } }),
}));
// @vueuse/core resolves its own copy of vue under vitest, so its refs never re-render the component.
vi.mock('@vueuse/core', async () => {
  const actual = await vi.importActual('@vueuse/core');
  const { ref: vueRef } = await vi.importActual('vue');
  return {
    ...actual,
    useDebounceFn: fn => fn,
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

const buildMessages = (count, startId = 1) =>
  Array.from({ length: count }, (_, index) => ({
    id: startId + index,
    content: 'hello there',
    created_at: 1700000000,
    sender: { name: 'Ana' },
  }));

const respond = messages =>
  Promise.resolve({ data: { payload: { messages } } });

const mountSearch = () =>
  mount(ConversationMessageSearch, {
    // display_id; the API resolves it, so the component must send it untouched
    props: { conversationId: 7 },
    global: {
      directives: { onClickaway: {}, focus: {} },
      stubs: { MessageContent: true, Spinner: true },
    },
  });

const search = async (wrapper, q) => {
  await wrapper.find('button').trigger('click');
  await wrapper.find('input').setValue(q);
  await flushPromises();
};

describe('ConversationMessageSearch', () => {
  beforeEach(() => {
    push.mockClear();
    SearchAPI.messages.mockReset();
  });

  it('searches only the current conversation and lists the matches', async () => {
    SearchAPI.messages.mockReturnValue(respond(buildMessages(2)));
    const wrapper = mountSearch();

    await search(wrapper, ' hello ');

    expect(SearchAPI.messages).toHaveBeenCalledWith(
      expect.objectContaining({ q: 'hello', page: 1, conversationId: 7 })
    );
    expect(wrapper.findAll('li')).toHaveLength(2);
  });

  it('shows the empty state once a search returns nothing', async () => {
    SearchAPI.messages.mockReturnValue(respond([]));
    const wrapper = mountSearch();

    await search(wrapper, 'nothing');

    expect(wrapper.text()).toContain(
      'CONVERSATION.HEADER.MESSAGE_SEARCH.EMPTY'
    );
  });

  it('appends the next page when loading more', async () => {
    SearchAPI.messages
      .mockReturnValueOnce(respond(buildMessages(15)))
      .mockReturnValueOnce(respond(buildMessages(3, 16)));
    const wrapper = mountSearch();
    await search(wrapper, 'hello');

    const loadMore = wrapper
      .findAll('button')
      .find(button =>
        button.text().includes('CONVERSATION.HEADER.MESSAGE_SEARCH.LOAD_MORE')
      );
    await loadMore.trigger('click');
    await flushPromises();

    expect(SearchAPI.messages).toHaveBeenLastCalledWith(
      expect.objectContaining({ page: 2 })
    );
    expect(wrapper.findAll('li')).toHaveLength(18);
  });

  it('jumps to the clicked message keeping the current route query', async () => {
    SearchAPI.messages.mockReturnValue(respond(buildMessages(1, 99)));
    const wrapper = mountSearch();
    await search(wrapper, 'hello');

    await wrapper.find('li button').trigger('click');

    expect(push).toHaveBeenCalledWith({
      query: { tab: 'all', messageId: 99 },
    });
    expect(wrapper.find('input').exists()).toBe(false);
  });
});

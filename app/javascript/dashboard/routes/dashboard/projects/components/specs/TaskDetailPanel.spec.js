import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { withFullI18n } from 'test-i18n';
import TaskDetailPanel from '../TaskDetailPanel.vue';

withFullI18n();

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const task = {
  id: 7,
  title: 'Store artwork',
  description: '',
  project_column_id: 1,
  priority: 'medium',
  assignee_id: null,
  due_date: '2026-11-10',
  creator_id: 3,
  created_at: 1789000000,
  attachments: [],
};

const stubs = {
  SidePanel: {
    name: 'SidePanel',
    template: '<div><slot name="header" /><slot /><slot name="footer" /></div>',
    methods: { open() {}, close() {} },
  },
  Dialog: true,
  TaskMarkdownEditor: true,
  ProjectSelect: {
    name: 'ProjectSelect',
    props: ['modelValue', 'options'],
    emits: ['update:modelValue'],
    template: '<div />',
  },
};

const mountPanel = async ({ updateTask = vi.fn() } = {}) => {
  const store = createStore({
    getters: {
      getCurrentUserID: () => 3,
      getCurrentRole: () => 'agent',
      'agents/getAgents': () => [{ id: 3, name: 'Kamila' }],
    },
    modules: {
      projects: {
        namespaced: true,
        state: { task: { ...task } },
        getters: {
          getTaskById: state => () => state.task,
          getSubtasksByTask: () => () => [],
          getCommentsByTask: () => () => [],
          getTasksByProject: () => () => [],
        },
        actions: { fetchTask: vi.fn(), fetchComments: vi.fn(), updateTask },
      },
    },
  });
  const wrapper = mount(TaskDetailPanel, {
    props: { projectId: 1 },
    global: {
      plugins: [store],
      stubs,
      directives: { dompurifyHtml: {}, onClickaway: {} },
    },
  });
  await wrapper.vm.open({ task });
  await flushPromises();
  return wrapper;
};

describe('TaskDetailPanel', () => {
  it('puts a field back to the stored value when saving it fails', async () => {
    const updateTask = vi.fn().mockRejectedValue(new Error('422'));
    const wrapper = await mountPanel({ updateTask });
    const prioritySelect = wrapper
      .find('[data-field="priority"]')
      .findComponent({ name: 'ProjectSelect' });

    prioritySelect.vm.$emit('update:modelValue', 'high');
    await flushPromises();

    expect(updateTask).toHaveBeenCalledWith(expect.anything(), {
      id: 7,
      priority: 'high',
    });
    expect(prioritySelect.props('modelValue')).toBe('medium');
  });

  it('saves the due date once, on blur, with the final value', async () => {
    const updateTask = vi.fn();
    const wrapper = await mountPanel({ updateTask });
    const dateInput = wrapper.find('input[type="date"]');

    await dateInput.setValue('0002-11-20');
    await dateInput.setValue('2026-11-20');
    expect(updateTask).not.toHaveBeenCalled();

    await dateInput.trigger('blur');
    await flushPromises();

    expect(updateTask).toHaveBeenCalledTimes(1);
    expect(updateTask).toHaveBeenCalledWith(expect.anything(), {
      id: 7,
      due_date: '2026-11-20',
    });
  });
});

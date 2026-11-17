import { mount } from '@vue/test-utils';
import ArticleEditor from '../ArticleEditor.vue';

vi.mock('vue-router', () => ({ onBeforeRouteLeave: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

let uploading = false;

const article = {
  id: 1,
  locale: 'en',
  title: 'Hello',
  content: '',
  associatedArticles: [{ id: 2, locale: 'pt_BR' }],
};

const mountEditor = props =>
  mount(ArticleEditor, {
    props: { article, ...props },
    global: {
      stubs: {
        HelpCenterLayout: {
          template:
            '<div><slot name="header-actions" /><slot name="content" /></div>',
        },
        ArticleEditorHeader: true,
        ArticleEditorControls: true,
        ArticleDiffPanel: true,
        FullEditor: {
          template: '<div />',
          methods: { hasPendingUploads: () => uploading },
        },
        TextArea: true,
        Button: {
          props: ['label'],
          emits: ['click'],
          template: '<button @click="$emit(\'click\')">{{ label }}</button>',
        },
        DropdownMenu: {
          props: ['menuItems'],
          emits: ['action'],
          template:
            '<ul><li v-for="item in menuItems" :key="item.value" @click="$emit(\'action\', item)">{{ item.label }}</li></ul>',
        },
      },
    },
  });

describe('ArticleEditor language switch', () => {
  beforeEach(() => {
    uploading = false;
  });

  it('lists the article and its translations and emits the chosen one', async () => {
    const wrapper = mountEditor();
    await wrapper.find('button').trigger('click');

    const items = wrapper.findAll('li');
    expect(items.map(item => item.text())).toEqual([
      'English (en)',
      'Portuguese (Brazil) (pt_BR)',
    ]);

    await items[1].trigger('click');
    expect(wrapper.emitted('switchTranslation')).toEqual([
      [{ id: 2, locale: 'pt_BR' }],
    ]);
  });

  it('does not emit when picking the current language', async () => {
    const wrapper = mountEditor();
    await wrapper.find('button').trigger('click');
    await wrapper.findAll('li')[0].trigger('click');
    expect(wrapper.emitted('switchTranslation')).toBeUndefined();
  });

  it('does not switch while a file is uploading', async () => {
    uploading = true;
    const wrapper = mountEditor();
    await wrapper.find('button').trigger('click');
    await wrapper.findAll('li')[1].trigger('click');
    expect(wrapper.emitted('switchTranslation')).toBeUndefined();
  });

  it('hides the switch when there are no translations', () => {
    const wrapper = mountEditor({
      article: { ...article, associatedArticles: [] },
    });
    expect(wrapper.text()).not.toContain('English (en)');
  });
});

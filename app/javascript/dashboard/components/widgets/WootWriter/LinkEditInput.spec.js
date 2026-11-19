import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import LinkEditInput from './LinkEditInput.vue';

const mountInput = href =>
  mount(LinkEditInput, {
    props: { href, position: { top: 0, left: 0 } },
  });

const buttonByLabel = (wrapper, key) =>
  wrapper.findAll('button').find(button => button.text().includes(key));

describe('LinkEditInput', () => {
  it('saves the edited destination trimmed', async () => {
    const wrapper = mountInput('https://a.test');
    await wrapper.find('input').setValue('  https://b.test  ');
    await buttonByLabel(wrapper, 'SAVE').trigger('click');

    expect(wrapper.emitted('save').at(-1)).toEqual(['https://b.test']);
  });

  it('refuses unsafe destinations', async () => {
    const wrapper = mountInput('https://a.test');
    // eslint-disable-next-line no-script-url
    await wrapper.find('input').setValue('javascript:alert(1)');
    await buttonByLabel(wrapper, 'SAVE').trigger('click');

    expect(wrapper.emitted('save')).toBeUndefined();
  });

  it('opens the current destination in a new tab', async () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    const wrapper = mountInput('https://a.test');
    await buttonByLabel(wrapper, 'OPEN').trigger('click');

    expect(open).toHaveBeenCalledWith(
      'https://a.test',
      '_blank',
      'noopener,noreferrer'
    );
  });
});

import { imageResizeView } from '@chatwoot/prosemirror-schema';

// Markdown has no image alignment, so it rides on the URL as cw_image_align, like
// cw_image_width does for size; CustomMarkdownRenderer#image_style reads it back.
// Left is the default and is stored as the absence of the param.
const ALIGN_PARAM = /([?&])cw_image_align=[^&#]*&?/;

const ALIGNMENTS = {
  left: { icon: 'i-lucide-align-left', wrapper: [] },
  center: { icon: 'i-lucide-align-center', wrapper: ['!table', 'mx-auto'] },
  right: { icon: 'i-lucide-align-right', wrapper: ['!table', 'ml-auto'] },
};

export const getImageAlign = src => {
  const align = (src || '').match(/[?&]cw_image_align=([^&#]*)/)?.[1];
  return align in ALIGNMENTS ? align : 'left';
};

export const setImageAlign = (src, align) => {
  const base = src.replace(ALIGN_PARAM, '$1').replace(/[?&]$/, '');
  if (align === 'left') return base;
  return `${base}${base.includes('?') ? '&' : '?'}cw_image_align=${align}`;
};

const BUTTON_CLASSES =
  'flex items-center justify-center size-6 border-0 rounded-md text-n-slate-12 hover:bg-n-alpha-2';

// The library's resizable image view plus an alignment bar shown while the image is selected.
// `labels` maps each alignment to its translated button label.
export const articleImageView = labels => (node, view, getPos) => {
  const inner = imageResizeView(node, view, getPos);
  const bar = document.createElement('span');
  bar.contentEditable = 'false';
  bar.className =
    'absolute top-2 start-2 z-10 hidden gap-0.5 p-0.5 rounded-lg bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-container shadow-lg group-[.ProseMirror-selectednode]:flex group-[.pm-image-uploading]:!hidden';

  const buttons = Object.entries(ALIGNMENTS).map(([align, { icon }]) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = BUTTON_CLASSES;
    button.title = labels[align];
    button.setAttribute('aria-label', labels[align]);
    button.innerHTML = `<span class="size-3.5 ${icon}"></span>`;
    // mousedown, so the image keeps its node selection
    button.addEventListener('mousedown', event => {
      event.preventDefault();
      const pos = getPos();
      if (pos == null) return;
      const { attrs } = inner.node;
      view.dispatch(
        view.state.tr.setNodeMarkup(pos, null, {
          ...attrs,
          src: setImageAlign(attrs.src, align),
        })
      );
    });
    return [align, button];
  });

  const sync = () => {
    const current = getImageAlign(inner.node.attrs.src);
    inner.dom.classList.remove('!table', 'mx-auto', 'ml-auto');
    inner.dom.classList.add(...ALIGNMENTS[current].wrapper);
    buttons.forEach(([align, button]) => {
      button.classList.toggle('bg-n-alpha-2', align === current);
      button.setAttribute('aria-pressed', String(align === current));
    });
  };

  bar.append(...buttons.map(([, button]) => button));
  inner.dom.classList.add('group');
  inner.dom.append(bar);
  sync();

  return {
    dom: inner.dom,
    update(newNode) {
      if (!inner.update(newNode)) return false;
      sync();
      return true;
    },
    selectNode: () => inner.selectNode(),
    deselectNode: () => inner.deselectNode(),
    ignoreMutation: () => true,
    stopEvent: event => bar.contains(event.target) || inner.stopEvent(event),
    destroy: () => inner.destroy(),
  };
};

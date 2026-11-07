import messages from 'widget/i18n';
import { forkMessages } from 'widget/i18n/fazer-ai';
import upstreamPtBr from 'widget/i18n/locale/pt_BR.json';

describe('fazer.ai widget translation overlay', () => {
  it('exposes a fork tree for every language we translate', () => {
    expect(Object.keys(forkMessages).sort()).toEqual(['en', 'es', 'pt_BR']);
  });

  it('adds the fork keys while keeping the upstream ones in the namespace', () => {
    expect(messages.pt_BR.REPLY_TIME.BACK_ON.MONDAY).toBe(
      'Estaremos de volta na segunda-feira'
    );
    expect(messages.pt_BR.REPLY_TIME.BACK_TOMORROW).toBe(
      upstreamPtBr.REPLY_TIME.BACK_TOMORROW
    );
  });

  it('leaves a language without a fork file untouched', () => {
    expect(messages.fr.REPLY_TIME.BACK_ON).toBeUndefined();
    expect(messages.fr.REPLY_TIME.BACK_TOMORROW).toBeDefined();
  });
});

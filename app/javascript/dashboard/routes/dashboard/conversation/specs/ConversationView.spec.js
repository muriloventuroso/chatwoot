import ConversationView from '../ConversationView.vue';

const { closeContactPanelOnSmallScreen } = ConversationView.methods;

describe('ConversationView', () => {
  describe('#closeContactPanelOnSmallScreen', () => {
    const desktopWidth = window.innerWidth;
    let view;

    beforeEach(() => {
      view = {
        conversationId: '12',
        uiSettings: { is_contact_sidebar_open: true },
        updateUISettings: vi.fn(),
      };
    });

    afterEach(() => {
      window.innerWidth = desktopWidth;
    });

    // The flag is shared with the desktop, where the panel was left open.
    it('closes the panel when a conversation opens on a phone', () => {
      window.innerWidth = 375;

      closeContactPanelOnSmallScreen.call(view);

      expect(view.updateUISettings).toHaveBeenCalledWith({
        is_contact_sidebar_open: false,
      });
    });

    it('keeps the panel open on a wide screen', () => {
      window.innerWidth = 1280;

      closeContactPanelOnSmallScreen.call(view);

      expect(view.updateUISettings).not.toHaveBeenCalled();
    });

    it('saves nothing when the panel is already closed', () => {
      window.innerWidth = 375;
      view.uiSettings.is_contact_sidebar_open = false;

      closeContactPanelOnSmallScreen.call(view);

      expect(view.updateUISettings).not.toHaveBeenCalled();
    });
  });
});

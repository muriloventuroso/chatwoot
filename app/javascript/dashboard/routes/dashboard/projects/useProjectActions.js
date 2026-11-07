import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';

// The project menu shared by the cards and the project page.
export function useProjectActions() {
  const { t } = useI18n();
  const store = useStore();

  const item = (action, label, icon) => ({
    action,
    value: action,
    label,
    icon,
  });

  const menuItems = ({ status }) =>
    [
      item('edit', t('PROJECTS.ACTIONS.EDIT'), 'i-lucide-pencil'),
      status === 'active' &&
        item(
          'completed',
          t('PROJECTS.ACTIONS.COMPLETE'),
          'i-lucide-circle-check'
        ),
      status !== 'active' &&
        item('active', t('PROJECTS.ACTIONS.REACTIVATE'), 'i-lucide-rotate-ccw'),
      status !== 'archived' &&
        item('archived', t('PROJECTS.ACTIONS.ARCHIVE'), 'i-lucide-archive'),
      item('delete', t('PROJECTS.ACTIONS.DELETE'), 'i-lucide-trash'),
    ].filter(Boolean);

  const updateStatus = async (project, status) => {
    try {
      await store.dispatch('projects/updateProject', {
        id: project.id,
        status,
      });
      useAlert(t('PROJECTS.MESSAGES.UPDATE_SUCCESS'));
      return true;
    } catch (error) {
      useAlert(t('PROJECTS.MESSAGES.UPDATE_ERROR'));
      return false;
    }
  };

  const deleteProject = async project => {
    try {
      await store.dispatch('projects/deleteProject', project.id);
      useAlert(t('PROJECTS.MESSAGES.DELETE_SUCCESS'));
      return true;
    } catch (error) {
      useAlert(t('PROJECTS.MESSAGES.DELETE_ERROR'));
      return false;
    }
  };

  return { menuItems, updateStatus, deleteProject };
}

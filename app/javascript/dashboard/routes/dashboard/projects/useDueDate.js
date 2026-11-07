import { useI18n } from 'vue-i18n';
import { daysUntilDue } from './constants';

// Dates are bare `YYYY-MM-DD`, read as local midnight (see daysUntilDue).
export function useDueDate() {
  const { t } = useI18n();

  const formatDate = date =>
    date
      ? new Date(`${date}T00:00:00`).toLocaleDateString(undefined, {
          day: 'numeric',
          month: 'short',
        })
      : '';

  const relativeDue = date => {
    const days = daysUntilDue(date);
    if (days < 0) return t('PROJECTS.DUE.LATE', -days, { count: -days });
    if (days === 0) return t('PROJECTS.DUE.TODAY');
    if (days === 1) return t('PROJECTS.DUE.TOMORROW');
    return t('PROJECTS.DUE.IN_DAYS', days, { count: days });
  };

  return { formatDate, relativeDue };
}

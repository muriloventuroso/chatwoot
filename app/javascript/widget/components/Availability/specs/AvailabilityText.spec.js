import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'widget/i18n';
import AvailabilityText from '../AvailabilityText.vue';

const workingHours = [0, 1, 2, 3, 4, 5, 6].map(dayOfWeek => ({
  dayOfWeek,
  openHour: 14,
  openMinutes: 0,
  closeHour: 18,
  closeMinutes: 0,
  // Open only on Mondays, so a Friday evening is several days away from it.
  closedAllDay: dayOfWeek !== 1,
}));

// Friday, July 19, 2024, 20:00 UTC
const FRIDAY_EVENING = new Date('2024-07-19T20:00:00.000Z');
// Monday, July 15, 2024, 08:00 UTC: six hours before opening
const MONDAY_MORNING = new Date('2024-07-15T08:00:00.000Z');

const render = (locale, time = FRIDAY_EVENING) =>
  mount(AvailabilityText, {
    props: {
      time,
      utcOffset: '+00:00',
      workingHours,
      workingHoursEnabled: true,
      isOnline: false,
      isInWorkingHours: false,
    },
    global: {
      plugins: [
        createI18n({ legacy: false, locale, fallbackLocale: 'en', messages }),
      ],
    },
  }).text();

describe('AvailabilityText', () => {
  it('names the reopening weekday with its own preposition in pt-BR', () => {
    expect(render('pt_BR')).toBe('Estaremos de volta na segunda-feira');
  });

  it('gives the same-day opening time on each language clock', () => {
    expect(render('pt_BR', MONDAY_MORNING)).toBe('Estaremos de volta às 14:00');
    expect(render('en', MONDAY_MORNING)).toBe(
      'We will be back online at 02:00 PM'
    );
  });

  it('falls back to English in a language the fork does not translate', () => {
    expect(render('fr')).toBe('We will be back online on Monday');
  });
});

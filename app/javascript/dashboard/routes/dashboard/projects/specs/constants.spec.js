import { daysUntilDue, dueTone, taskProgress, taskSummary } from '../constants';

describe('daysUntilDue', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 10, 5, 23, 30));
  });

  afterEach(() => vi.useRealTimers());

  it('counts whole days from today, negative once the date has passed', () => {
    expect(daysUntilDue('2026-11-05')).toBe(0);
    expect(daysUntilDue('2026-11-08')).toBe(3);
    expect(daysUntilDue('2026-10-28')).toBe(-8);
  });
});

describe('taskProgress', () => {
  it('is 100 for done tasks, the subtask ratio otherwise', () => {
    expect(taskProgress({ status: 'done', subtasks_count: 0 })).toBe(100);
    expect(
      taskProgress({
        status: 'todo',
        subtasks_count: 3,
        completed_subtasks_count: 1,
      })
    ).toBe(33);
    expect(taskProgress({ status: 'in_progress', subtasks_count: 0 })).toBe(0);
  });
});

describe('with today fixed', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 10, 5, 9, 0));
  });

  afterEach(() => vi.useRealTimers());

  it('dueTone flags late and imminent dates, never a finished one', () => {
    expect(dueTone('2026-11-04')).toBe('late');
    expect(dueTone('2026-11-06')).toBe('soon');
    expect(dueTone('2026-11-07')).toBe('normal');
    expect(dueTone('2026-11-10', false, 7)).toBe('soon');
    expect(dueTone('2026-11-04', true)).toBe('muted');
  });

  it('taskSummary counts done, overdue and due-this-week pending tasks', () => {
    expect(
      taskSummary([
        { status: 'done', due_date: '2026-11-01' },
        { status: 'todo', due_date: '2026-11-01' },
        { status: 'in_progress', due_date: '2026-11-05' },
        { status: 'todo', due_date: '2026-11-12' },
        { status: 'todo', due_date: '2026-11-13' },
        { status: 'todo', due_date: null },
      ])
    ).toEqual({ total: 6, done: 1, overdue: 1, dueSoon: 2 });
  });
});

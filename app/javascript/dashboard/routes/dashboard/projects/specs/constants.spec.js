import { daysUntilDue, taskProgress } from '../constants';

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

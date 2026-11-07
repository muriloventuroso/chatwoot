export const PROJECT_STATUSES = ['active', 'completed', 'archived'];
export const TASK_STATUSES = ['todo', 'in_progress', 'done'];
export const TASK_PRIORITIES = ['low', 'medium', 'high'];
// Assignee filter value for tasks with nobody on them.
export const UNASSIGNED = 'none';

export const PROJECT_COLORS = [
  '#3A5BC7',
  '#008573',
  '#C2298A',
  '#99543A',
  '#4747C2',
  '#60646C',
];

export const PROJECT_COLOR_CLASS = {
  '#3A5BC7': 'bg-[#3A5BC7]',
  '#008573': 'bg-[#008573]',
  '#C2298A': 'bg-[#C2298A]',
  '#99543A': 'bg-[#99543A]',
  '#4747C2': 'bg-[#4747C2]',
  '#60646C': 'bg-[#60646C]',
};

const PROGRESS_WIDTH_CLASS = {
  0: 'w-0',
  10: 'w-[10%]',
  20: 'w-[20%]',
  30: 'w-[30%]',
  40: 'w-[40%]',
  50: 'w-[50%]',
  60: 'w-[60%]',
  70: 'w-[70%]',
  80: 'w-[80%]',
  90: 'w-[90%]',
  100: 'w-full',
};

export const progressWidthClass = progress => {
  const value = Number(progress) || 0;
  const bucket = Math.min(100, Math.max(0, Math.round(value / 10) * 10));
  return PROGRESS_WIDTH_CLASS[bucket];
};

export const nextColumnPosition = (tasks, columnId, excludeId) => {
  const positions = tasks
    .filter(
      task => task.project_column_id === columnId && task.id !== excludeId
    )
    .map(task => Number(task.position) || 0);
  return Math.max(0, ...positions) + 1;
};

export const STATUS_DOT_CLASS = {
  todo: 'bg-n-slate-9',
  in_progress: 'bg-n-amber-10',
  done: 'bg-n-teal-10',
};

export const PRIORITY_CLASS = {
  low: 'bg-n-slate-3 text-n-slate-11',
  medium: 'bg-n-amber-3 text-n-amber-11',
  high: 'bg-n-ruby-3 text-n-ruby-11',
};

export const PRIORITY_ICON_CLASS = {
  low: 'text-n-slate-10',
  medium: 'text-n-amber-10',
  high: 'text-n-ruby-10',
};

export const STATUS_ACCENT_CLASS = {
  todo: 'border-t-n-slate-8',
  in_progress: 'border-t-n-amber-9',
  done: 'border-t-n-teal-9',
};

// Column categories, shown as Monday-style status pills.
export const STATUS_PILL_CLASS = {
  todo: 'bg-n-slate-3 text-n-slate-12',
  in_progress: 'bg-n-amber-3 text-n-amber-11',
  done: 'bg-n-teal-3 text-n-teal-11',
};

export const PROJECT_STATUS_CLASS = {
  active: 'bg-n-blue-3 text-n-blue-11',
  completed: 'bg-n-teal-3 text-n-teal-11',
  archived: 'bg-n-slate-3 text-n-slate-11',
};

export const DUE_TONE_CLASS = {
  late: 'text-n-ruby-11',
  soon: 'text-n-amber-11',
  normal: 'text-n-slate-11',
  muted: 'text-n-slate-10',
};

// Whole days from today to the due date; negative when it has passed.
// Parsed as local midnight: a bare `YYYY-MM-DD` is read as UTC and would be a
// day off in timezones west of UTC.
export const daysUntilDue = dueDate =>
  Math.round(
    (new Date(`${dueDate}T00:00:00`) - new Date(new Date().toDateString())) /
      86400000
  );

// How urgent a due date looks: nothing pending is ever late.
export const dueTone = (dueDate, isDone = false, soonDays = 1) => {
  if (isDone) return 'muted';
  const days = daysUntilDue(dueDate);
  if (days < 0) return 'late';
  return days <= soonDays ? 'soon' : 'normal';
};

export const taskProgress = task => {
  if (task.status === 'done') return 100;
  if (!task.subtasks_count) return 0;
  return Math.round(
    (task.completed_subtasks_count / task.subtasks_count) * 100
  );
};

// Root-task counts for the project summary; "due soon" means within the next week.
export const taskSummary = tasks =>
  tasks.reduce(
    (summary, task) => {
      summary.total += 1;
      if (task.status === 'done') {
        summary.done += 1;
        return summary;
      }
      if (!task.due_date) return summary;
      const days = daysUntilDue(task.due_date);
      if (days < 0) summary.overdue += 1;
      else if (days <= 7) summary.dueSoon += 1;
      return summary;
    },
    { total: 0, done: 0, overdue: 0, dueSoon: 0 }
  );

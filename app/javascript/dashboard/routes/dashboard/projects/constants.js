export const PROJECT_STATUSES = ['active', 'completed', 'archived'];
export const TASK_STATUSES = ['todo', 'in_progress', 'done'];
export const TASK_PRIORITIES = ['low', 'medium', 'high'];

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

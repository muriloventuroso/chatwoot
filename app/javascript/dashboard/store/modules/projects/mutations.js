import {
  SET_PROJECT_UI_FLAG,
  SET_PROJECTS,
  SET_PROJECT,
  DELETE_PROJECT,
  SET_PROJECT_TASKS,
  SET_PROJECT_TASK,
  DELETE_PROJECT_TASK,
  SET_TASK_COMMENTS,
  ADD_TASK_COMMENT,
  DELETE_TASK_COMMENT,
  SET_PROJECT_MEMBERS,
} from './types';

const upsertMany = (records, items) => {
  const next = { ...records };
  items.forEach(item => {
    next[item.id] = { ...(next[item.id] || {}), ...item };
  });
  return next;
};

export const mutations = {
  [SET_PROJECT_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [SET_PROJECTS]($state, data) {
    $state.projects = upsertMany({}, data);
  },
  [SET_PROJECT]($state, data) {
    $state.projects = upsertMany($state.projects, [data]);
  },
  [DELETE_PROJECT]($state, projectId) {
    const { [projectId]: _deleted, ...projects } = $state.projects;
    $state.projects = projects;
  },
  [SET_PROJECT_TASKS]($state, { projectId, tasks }) {
    const others = Object.fromEntries(
      Object.entries($state.tasks).filter(
        ([, task]) => task.project_id !== Number(projectId)
      )
    );
    $state.tasks = upsertMany(others, tasks);
  },
  [SET_PROJECT_TASK]($state, task) {
    const items = task.subtasks ? [task, ...task.subtasks] : [task];
    $state.tasks = upsertMany($state.tasks, items);
  },
  [DELETE_PROJECT_TASK]($state, taskId) {
    $state.tasks = Object.fromEntries(
      Object.entries($state.tasks).filter(
        ([, task]) => task.id !== taskId && task.parent_task_id !== taskId
      )
    );
  },
  [SET_TASK_COMMENTS]($state, { taskId, comments }) {
    const others = Object.fromEntries(
      Object.entries($state.comments).filter(
        ([, comment]) => comment.project_task_id !== Number(taskId)
      )
    );
    $state.comments = upsertMany(others, comments);
  },
  [ADD_TASK_COMMENT]($state, comment) {
    $state.comments = upsertMany($state.comments, [comment]);
  },
  [DELETE_TASK_COMMENT]($state, commentId) {
    const { [commentId]: _deleted, ...comments } = $state.comments;
    $state.comments = comments;
  },
  [SET_PROJECT_MEMBERS]($state, { projectId, members }) {
    const others = Object.fromEntries(
      Object.entries($state.members).filter(
        ([, member]) => member.project_id !== Number(projectId)
      )
    );
    $state.members = upsertMany(others, members);
  },
};

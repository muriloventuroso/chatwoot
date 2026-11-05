export const getters = {
  getProjects($state) {
    return Object.values($state.projects).sort((a, b) => b.id - a.id);
  },
  getProjectById: $state => id => $state.projects[Number(id)] || null,
  getTasksByProject: $state => projectId =>
    Object.values($state.tasks)
      .filter(
        task => task.project_id === Number(projectId) && !task.parent_task_id
      )
      .sort((a, b) => a.position - b.position),
  getTaskById: $state => id => $state.tasks[Number(id)] || null,
  getSubtasksByTask: $state => taskId =>
    Object.values($state.tasks)
      .filter(task => task.parent_task_id === Number(taskId))
      .sort((a, b) => a.position - b.position),
  getCommentsByTask: $state => taskId =>
    Object.values($state.comments)
      .filter(comment => comment.project_task_id === Number(taskId))
      .sort((a, b) => a.created_at - b.created_at),
  getMembersByProject: $state => projectId =>
    Object.values($state.members).filter(
      member => member.project_id === Number(projectId)
    ),
  getColumnsByProject: $state => projectId =>
    Object.values($state.columns)
      .filter(column => column.project_id === Number(projectId))
      .sort((a, b) => a.position - b.position || a.id - b.id),
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

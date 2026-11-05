import { getters } from '../../projects/getters';

describe('#projects getters', () => {
  const state = {
    projects: {
      2: { id: 2, name: 'Beta' },
      1: { id: 1, name: 'Alpha' },
    },
    tasks: {
      1: { id: 1, project_id: 1, parent_task_id: null, position: 2 },
      2: { id: 2, project_id: 1, parent_task_id: 1, position: 1 },
      3: { id: 3, project_id: 1, parent_task_id: null, position: 1 },
    },
    comments: {
      1: { id: 1, project_task_id: 1, created_at: 20 },
      2: { id: 2, project_task_id: 1, created_at: 10 },
    },
    members: {
      1: { id: 1, project_id: 1 },
      2: { id: 2, project_id: 2 },
    },
    uiFlags: { isFetching: true },
  };

  it('getProjects sorts by id descending', () => {
    expect(getters.getProjects(state).map(project => project.id)).toEqual([
      2, 1,
    ]);
  });

  it('getProjectById returns a project', () => {
    expect(getters.getProjectById(state)(1).name).toEqual('Alpha');
  });

  it('getTasksByProject returns root tasks ordered by position', () => {
    expect(
      getters
        .getTasksByProject(state)(1)
        .map(task => task.id)
    ).toEqual([3, 1]);
  });

  it('getSubtasksByTask returns child tasks', () => {
    expect(
      getters
        .getSubtasksByTask(state)(1)
        .map(task => task.id)
    ).toEqual([2]);
  });

  it('getCommentsByTask sorts by created_at', () => {
    expect(
      getters
        .getCommentsByTask(state)(1)
        .map(comment => comment.id)
    ).toEqual([2, 1]);
  });

  it('getMembersByProject filters by project', () => {
    expect(
      getters
        .getMembersByProject(state)(1)
        .map(member => member.id)
    ).toEqual([1]);
  });

  it('getColumnsByProject filters by project and orders by position', () => {
    const columnsState = {
      columns: {
        1: { id: 1, project_id: 1, position: 2 },
        2: { id: 2, project_id: 1, position: 0.5 },
        3: { id: 3, project_id: 2, position: 1 },
      },
    };
    expect(
      getters
        .getColumnsByProject(columnsState)(1)
        .map(column => column.id)
    ).toEqual([2, 1]);
  });

  it('getUIFlags returns ui flags', () => {
    expect(getters.getUIFlags(state)).toEqual({ isFetching: true });
  });
});

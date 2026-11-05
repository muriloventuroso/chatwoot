import { actions } from '../../projects/actions';
import {
  SET_PROJECT_UI_FLAG,
  SET_PROJECTS,
  SET_PROJECT,
  DELETE_PROJECT,
  SET_PROJECT_TASKS,
  SET_PROJECT_TASK,
  DELETE_PROJECT_TASK,
  SET_TASK_COMMENTS,
  SET_PROJECT_COLUMNS,
  SET_PROJECT_COLUMN,
  DELETE_PROJECT_COLUMN,
} from '../../projects/types';
import { projectsAPI, projectTasksAPI } from '../../../../api/projects';

vi.mock('../../../../api/projects', () => ({
  projectsAPI: {
    get: vi.fn(),
    show: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    getTasks: vi.fn(),
    createTask: vi.fn(),
    getColumns: vi.fn(),
    createColumn: vi.fn(),
    updateColumn: vi.fn(),
    deleteColumn: vi.fn(),
  },
  projectTasksAPI: {
    show: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    move: vi.fn(),
    getComments: vi.fn(),
  },
}));

const commit = vi.fn();

describe('#projects actions', () => {
  beforeEach(() => {
    commit.mockClear();
  });

  describe('#fetchProjects', () => {
    it('commits projects on success', async () => {
      const data = [{ id: 1, name: 'Alpha' }];
      projectsAPI.get.mockResolvedValue({ data });

      await actions.fetchProjects({ commit });

      expect(commit.mock.calls).toEqual([
        [SET_PROJECT_UI_FLAG, { isFetching: true }],
        [SET_PROJECTS, data],
        [SET_PROJECT_UI_FLAG, { isFetching: false }],
      ]);
    });

    it('clears fetching flag on error', async () => {
      projectsAPI.get.mockRejectedValue(new Error('failed'));
      await expect(actions.fetchProjects({ commit })).rejects.toThrow('failed');
      expect(commit.mock.calls).toEqual([
        [SET_PROJECT_UI_FLAG, { isFetching: true }],
        [SET_PROJECT_UI_FLAG, { isFetching: false }],
      ]);
    });
  });

  describe('#createProject', () => {
    it('commits the created project', async () => {
      const data = { id: 2, name: 'Beta' };
      projectsAPI.create.mockResolvedValue({ data });

      const result = await actions.createProject({ commit }, { name: 'Beta' });

      expect(result).toEqual(data);
      expect(commit.mock.calls).toEqual([
        [SET_PROJECT_UI_FLAG, { isCreating: true }],
        [SET_PROJECT, data],
        [SET_PROJECT_UI_FLAG, { isCreating: false }],
      ]);
    });
  });

  describe('#updateProject', () => {
    it('flags the update while the request runs', async () => {
      const data = { id: 2, name: 'Gamma' };
      projectsAPI.update.mockResolvedValue({ data });

      await actions.updateProject({ commit }, { id: 2, name: 'Gamma' });

      expect(projectsAPI.update).toHaveBeenCalledWith(2, {
        project: { name: 'Gamma' },
      });
      expect(commit.mock.calls).toEqual([
        [SET_PROJECT_UI_FLAG, { isUpdating: true }],
        [SET_PROJECT, data],
        [SET_PROJECT_UI_FLAG, { isUpdating: false }],
      ]);
    });

    it('clears the updating flag on error', async () => {
      projectsAPI.update.mockRejectedValue(new Error('failed'));
      await expect(
        actions.updateProject({ commit }, { id: 2 })
      ).rejects.toThrow('failed');
      expect(commit).toHaveBeenLastCalledWith(SET_PROJECT_UI_FLAG, {
        isUpdating: false,
      });
    });
  });

  describe('#deleteProject', () => {
    it('removes the project from the store', async () => {
      projectsAPI.delete.mockResolvedValue({});
      await actions.deleteProject({ commit }, 2);
      expect(commit).toHaveBeenCalledWith(DELETE_PROJECT, 2);
    });
  });

  describe('#fetchTasks', () => {
    it('commits tasks for the project', async () => {
      const data = [{ id: 9, project_id: 1 }];
      projectsAPI.getTasks.mockResolvedValue({ data });

      await actions.fetchTasks({ commit }, { projectId: 1 });

      expect(commit).toHaveBeenCalledWith(SET_PROJECT_TASKS, {
        projectId: 1,
        tasks: data,
      });
    });
  });

  describe('#moveTask', () => {
    it('sends the column and position and commits the moved task', async () => {
      const data = { id: 9, project_column_id: 4, position: 1 };
      projectTasksAPI.move.mockResolvedValue({ data });

      const result = await actions.moveTask(
        { commit },
        { id: 9, project_column_id: 4, position: 1 }
      );

      expect(projectTasksAPI.move).toHaveBeenCalledWith(9, {
        project_task: { project_column_id: 4, position: 1 },
      });
      expect(result).toEqual(data);
      expect(commit).toHaveBeenCalledWith(SET_PROJECT_TASK, data);
    });
  });

  describe('columns', () => {
    it('fetches the columns of a project', async () => {
      const data = [{ id: 4, project_id: 1, name: 'To do' }];
      projectsAPI.getColumns.mockResolvedValue({ data });

      await actions.fetchColumns({ commit }, 1);

      expect(commit).toHaveBeenCalledWith(SET_PROJECT_COLUMNS, {
        projectId: 1,
        columns: data,
      });
    });

    it('creates a column', async () => {
      const data = { id: 5, project_id: 1, name: 'Review' };
      projectsAPI.createColumn.mockResolvedValue({ data });

      await actions.createColumn(
        { commit },
        { projectId: 1, name: 'Review', category: 'in_progress' }
      );

      expect(projectsAPI.createColumn).toHaveBeenCalledWith(1, {
        name: 'Review',
        category: 'in_progress',
      });
      expect(commit).toHaveBeenCalledWith(SET_PROJECT_COLUMN, data);
    });

    it('updates a column', async () => {
      const data = { id: 5, project_id: 1, position: 0.5 };
      projectsAPI.updateColumn.mockResolvedValue({ data });

      await actions.updateColumn(
        { commit },
        { projectId: 1, id: 5, position: 0.5 }
      );

      expect(projectsAPI.updateColumn).toHaveBeenCalledWith(1, 5, {
        position: 0.5,
      });
      expect(commit).toHaveBeenCalledWith(SET_PROJECT_COLUMN, data);
    });

    it('deletes a column', async () => {
      projectsAPI.deleteColumn.mockResolvedValue({});

      await actions.deleteColumn({ commit }, { projectId: 1, id: 5 });

      expect(projectsAPI.deleteColumn).toHaveBeenCalledWith(1, 5);
      expect(commit).toHaveBeenCalledWith(DELETE_PROJECT_COLUMN, 5);
    });
  });

  describe('#deleteTask', () => {
    it('removes the task from the store', async () => {
      projectTasksAPI.delete.mockResolvedValue({});
      await actions.deleteTask({ commit }, 9);
      expect(commit).toHaveBeenCalledWith(DELETE_PROJECT_TASK, 9);
    });
  });

  describe('#fetchComments', () => {
    it('replaces comments for the task', async () => {
      const data = [{ id: 1, project_task_id: 9, content: 'Hi' }];
      projectTasksAPI.getComments.mockResolvedValue({ data });

      await actions.fetchComments({ commit }, 9);

      expect(commit).toHaveBeenCalledWith(SET_TASK_COMMENTS, {
        taskId: 9,
        comments: data,
      });
    });
  });
});

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
    it('commits the moved task', async () => {
      const data = { id: 9, status: 'done', position: 1 };
      projectTasksAPI.move.mockResolvedValue({ data });

      const result = await actions.moveTask(
        { commit },
        { id: 9, status: 'done', position: 1 }
      );

      expect(result).toEqual(data);
      expect(commit).toHaveBeenCalledWith(SET_PROJECT_TASK, data);
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

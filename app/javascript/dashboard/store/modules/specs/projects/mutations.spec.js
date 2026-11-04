import { mutations } from '../../projects/mutations';
import {
  SET_PROJECTS,
  SET_PROJECT,
  DELETE_PROJECT,
  SET_PROJECT_TASKS,
  SET_PROJECT_TASK,
  DELETE_PROJECT_TASK,
  SET_TASK_COMMENTS,
  ADD_TASK_COMMENT,
  DELETE_TASK_COMMENT,
} from '../../projects/types';

describe('#projects mutations', () => {
  describe('#SET_PROJECTS', () => {
    it('replaces the project records', () => {
      const state = { projects: { 1: { id: 1, name: 'Old' } } };
      mutations[SET_PROJECTS](state, [{ id: 2, name: 'New' }]);
      expect(state.projects).toEqual({ 2: { id: 2, name: 'New' } });
    });
  });

  describe('#SET_PROJECT', () => {
    it('upserts a project', () => {
      const state = { projects: { 1: { id: 1, name: 'Alpha' } } };
      mutations[SET_PROJECT](state, { id: 1, name: 'Renamed' });
      expect(state.projects[1].name).toEqual('Renamed');
    });
  });

  describe('#DELETE_PROJECT', () => {
    it('removes a project', () => {
      const state = { projects: { 1: { id: 1 } } };
      mutations[DELETE_PROJECT](state, 1);
      expect(state.projects).toEqual({});
    });
  });

  describe('#SET_PROJECT_TASKS', () => {
    it('replaces tasks for the given project', () => {
      const state = {
        tasks: {
          1: { id: 1, project_id: 10 },
          2: { id: 2, project_id: 20 },
        },
      };
      mutations[SET_PROJECT_TASKS](state, {
        projectId: 10,
        tasks: [{ id: 3, project_id: 10 }],
      });
      expect(state.tasks).toEqual({
        2: { id: 2, project_id: 20 },
        3: { id: 3, project_id: 10 },
      });
    });
  });

  describe('#SET_PROJECT_TASK', () => {
    it('upserts a task and its subtasks', () => {
      const state = { tasks: {} };
      mutations[SET_PROJECT_TASK](state, {
        id: 1,
        title: 'Parent',
        subtasks: [{ id: 2, title: 'Child', parent_task_id: 1 }],
      });
      expect(state.tasks[1].title).toEqual('Parent');
      expect(state.tasks[2].title).toEqual('Child');
    });
  });

  describe('#DELETE_PROJECT_TASK', () => {
    it('removes a task and its subtasks', () => {
      const state = {
        tasks: {
          1: { id: 1 },
          2: { id: 2, parent_task_id: 1 },
          3: { id: 3 },
        },
      };
      mutations[DELETE_PROJECT_TASK](state, 1);
      expect(state.tasks).toEqual({ 3: { id: 3 } });
    });
  });

  describe('#comments', () => {
    it('replaces comments for the given task', () => {
      const state = {
        comments: {
          1: { id: 1, content: 'Stale', project_task_id: 9 },
          2: { id: 2, content: 'Other', project_task_id: 8 },
        },
      };
      mutations[SET_TASK_COMMENTS](state, {
        taskId: 9,
        comments: [{ id: 3, content: 'Fresh', project_task_id: 9 }],
      });
      expect(state.comments).toEqual({
        2: { id: 2, content: 'Other', project_task_id: 8 },
        3: { id: 3, content: 'Fresh', project_task_id: 9 },
      });
    });

    it('adds and deletes comments', () => {
      const state = { comments: {} };
      mutations[ADD_TASK_COMMENT](state, {
        id: 2,
        content: 'There',
        project_task_id: 9,
      });
      mutations[DELETE_TASK_COMMENT](state, 2);
      expect(state.comments).toEqual({});
    });
  });
});

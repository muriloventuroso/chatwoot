import { projectsAPI, projectTasksAPI } from '../../../api/projects';
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

export const actions = {
  fetchProjects: async ({ commit }, params = {}) => {
    commit(SET_PROJECT_UI_FLAG, { isFetching: true });
    try {
      const response = await projectsAPI.get(params);
      commit(SET_PROJECTS, response.data);
      return response.data;
    } finally {
      commit(SET_PROJECT_UI_FLAG, { isFetching: false });
    }
  },

  fetchProject: async ({ commit }, id) => {
    const response = await projectsAPI.show(id);
    commit(SET_PROJECT, response.data);
    return response.data;
  },

  createProject: async ({ commit }, data) => {
    commit(SET_PROJECT_UI_FLAG, { isCreating: true });
    try {
      const response = await projectsAPI.create({ project: data });
      commit(SET_PROJECT, response.data);
      return response.data;
    } finally {
      commit(SET_PROJECT_UI_FLAG, { isCreating: false });
    }
  },

  updateProject: async ({ commit }, { id, ...data }) => {
    const response = await projectsAPI.update(id, { project: data });
    commit(SET_PROJECT, response.data);
    return response.data;
  },

  deleteProject: async ({ commit }, id) => {
    await projectsAPI.delete(id);
    commit(DELETE_PROJECT, id);
  },

  fetchTasks: async ({ commit }, { projectId, params = {} }) => {
    commit(SET_PROJECT_UI_FLAG, { isFetchingTasks: true });
    try {
      const response = await projectsAPI.getTasks(projectId, params);
      commit(SET_PROJECT_TASKS, { projectId, tasks: response.data });
      return response.data;
    } finally {
      commit(SET_PROJECT_UI_FLAG, { isFetchingTasks: false });
    }
  },

  fetchTask: async ({ commit }, id) => {
    const response = await projectTasksAPI.show(id);
    commit(SET_PROJECT_TASK, response.data);
    return response.data;
  },

  createTask: async ({ commit }, { projectId, ...data }) => {
    const response = await projectsAPI.createTask(projectId, {
      project_task: data,
    });
    commit(SET_PROJECT_TASK, response.data);
    return response.data;
  },

  updateTask: async ({ commit }, { id, ...data }) => {
    const response = await projectTasksAPI.update(id, { project_task: data });
    commit(SET_PROJECT_TASK, response.data);
    return response.data;
  },

  deleteTask: async ({ commit }, id) => {
    await projectTasksAPI.delete(id);
    commit(DELETE_PROJECT_TASK, id);
  },

  moveTask: async ({ commit }, { id, status, position }) => {
    const response = await projectTasksAPI.move(id, {
      project_task: { status, position },
    });
    commit(SET_PROJECT_TASK, response.data);
    return response.data;
  },

  fetchComments: async ({ commit }, taskId) => {
    const response = await projectTasksAPI.getComments(taskId);
    commit(SET_TASK_COMMENTS, { taskId, comments: response.data });
    return response.data;
  },

  createComment: async ({ commit }, { taskId, content }) => {
    const response = await projectTasksAPI.createComment(taskId, content);
    commit(ADD_TASK_COMMENT, response.data);
    return response.data;
  },

  deleteComment: async ({ commit }, { taskId, commentId }) => {
    await projectTasksAPI.deleteComment(taskId, commentId);
    commit(DELETE_TASK_COMMENT, commentId);
  },

  addAttachment: async ({ commit }, { taskId, file }) => {
    const response = await projectTasksAPI.addAttachment(taskId, file);
    commit(SET_PROJECT_TASK, response.data);
    return response.data;
  },

  deleteAttachment: async ({ commit }, { taskId, attachmentId }) => {
    await projectTasksAPI.deleteAttachment(taskId, attachmentId);
    const response = await projectTasksAPI.show(taskId);
    commit(SET_PROJECT_TASK, response.data);
    return response.data;
  },

  fetchMembers: async ({ commit }, projectId) => {
    const response = await projectsAPI.getMembers(projectId);
    commit(SET_PROJECT_MEMBERS, { projectId, members: response.data });
    return response.data;
  },

  addMembers: async ({ commit }, { projectId, userIds }) => {
    const response = await projectsAPI.addMembers(projectId, userIds);
    commit(SET_PROJECT_MEMBERS, { projectId, members: response.data });
    return response.data;
  },

  removeMember: async ({ dispatch }, { projectId, memberId }) => {
    await projectsAPI.removeMember(projectId, memberId);
    await dispatch('fetchMembers', projectId);
  },
};

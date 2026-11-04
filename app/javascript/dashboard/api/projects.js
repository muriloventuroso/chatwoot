/* global axios */
/* eslint-disable max-classes-per-file */
import ApiClient from './ApiClient';

class ProjectsAPI extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  getTasks(projectId, params = {}) {
    return axios.get(`${this.url}/${projectId}/tasks`, { params });
  }

  createTask(projectId, data) {
    return axios.post(`${this.url}/${projectId}/tasks`, data);
  }

  getMembers(projectId) {
    return axios.get(`${this.url}/${projectId}/members`);
  }

  addMembers(projectId, userIds) {
    return axios.post(`${this.url}/${projectId}/members`, {
      user_ids: userIds,
    });
  }

  removeMember(projectId, memberId) {
    return axios.delete(`${this.url}/${projectId}/members/${memberId}`);
  }
}

class ProjectTasksAPI extends ApiClient {
  constructor() {
    super('project_tasks', { accountScoped: true });
  }

  move(id, data) {
    return axios.post(`${this.url}/${id}/move`, data);
  }

  getComments(taskId) {
    return axios.get(`${this.url}/${taskId}/comments`);
  }

  createComment(taskId, content) {
    return axios.post(`${this.url}/${taskId}/comments`, {
      comment: { content },
    });
  }

  deleteComment(taskId, commentId) {
    return axios.delete(`${this.url}/${taskId}/comments/${commentId}`);
  }

  addAttachment(taskId, file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/${taskId}/attachments`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  deleteAttachment(taskId, attachmentId) {
    return axios.delete(`${this.url}/${taskId}/attachments/${attachmentId}`);
  }
}

export const projectsAPI = new ProjectsAPI();
export const projectTasksAPI = new ProjectTasksAPI();
export default projectsAPI;

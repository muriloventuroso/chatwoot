import { getters } from './getters';
import { actions } from './actions';
import { mutations } from './mutations';

const state = {
  projects: {},
  tasks: {},
  comments: {},
  members: {},
  columns: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isFetchingTasks: false,
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

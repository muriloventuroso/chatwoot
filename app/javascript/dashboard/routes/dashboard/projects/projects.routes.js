import { frontendURL } from '../../../helper/URLHelper';
import ProjectsList from './ProjectsList.vue';
import ProjectDetails from './ProjectDetails.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/projects'),
    component: ProjectsList,
    name: 'projects_list',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/projects/:projectId'),
    component: ProjectDetails,
    name: 'project_details',
    meta,
  },
];

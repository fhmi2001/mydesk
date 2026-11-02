// Custom (MyDesk): the Sales CRM store modules, registered as crm/status, crm/pipelines, crm/deals, crm/tasks
import status from './status';
import pipelines from './pipelines';
import deals from './deals';
import tasks from './tasks';

export default {
  namespaced: true,
  modules: { status, pipelines, deals, tasks },
};

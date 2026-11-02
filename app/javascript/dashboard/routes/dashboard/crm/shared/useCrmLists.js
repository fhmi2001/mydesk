// Custom (MyDesk): the Sales CRM managed lists (lead source, product, competitor, region, industry), loaded once per
// page load and shared by the deal form, the deal page and Sales settings. An archived item is gone from the
// pickers; a deal that already has it still shows its id, named "—" here, until reports name it from the server.
import { reactive } from 'vue';
import { crmListItemsAPI } from 'dashboard/api/crm';
import { DEAL_LISTS } from './dealHelpers';

const items = reactive(Object.fromEntries(DEAL_LISTS.map(list => [list, []])));
let loading = null;

const loadAll = () => {
  loading ||= Promise.all(
    DEAL_LISTS.map(async list => {
      const { data } = await crmListItemsAPI.get(list);
      items[list] = data;
    })
  ).catch(error => {
    loading = null;
    throw error;
  });
  return loading;
};

export const useCrmLists = () => ({
  items,
  load: () => loadAll().catch(() => {}),
  // After Sales settings change a list
  replace: (list, data) => {
    items[list] = data;
  },
  options: (list, noneLabel) => [
    { value: '', label: noneLabel },
    ...items[list].map(item => ({ value: item.id, label: item.name })),
  ],
  nameOf: (list, id) => items[list].find(item => item.id === id)?.name || '',
});

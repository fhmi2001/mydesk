import { defineComponent, h, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { useSuggestionArrivals } from '../useSuggestionArrivals';

const mountWith = (conversationId, onArrive) =>
  mount(
    defineComponent({
      setup() {
        useSuggestionArrivals(() => conversationId.value, onArrive);
        return () => h('div');
      },
    })
  );

describe('useSuggestionArrivals', () => {
  it('calls back when a suggestion for this conversation arrives', () => {
    const onArrive = vi.fn();
    mountWith(ref(14), onArrive);
    emitter.emit(BUS_EVENTS.CRM_SUGGESTION_CREATED, { conversation_id: 14 });
    expect(onArrive).toHaveBeenCalledTimes(1);
  });

  it("ignores another conversation's suggestion", () => {
    const onArrive = vi.fn();
    mountWith(ref('14'), onArrive);
    emitter.emit(BUS_EVENTS.CRM_SUGGESTION_CREATED, { conversation_id: 9 });
    expect(onArrive).not.toHaveBeenCalled();
  });

  it('stops listening once the panel is gone', () => {
    const onArrive = vi.fn();
    mountWith(ref(14), onArrive).unmount();
    emitter.emit(BUS_EVENTS.CRM_SUGGESTION_CREATED, { conversation_id: 14 });
    expect(onArrive).not.toHaveBeenCalled();
  });
});

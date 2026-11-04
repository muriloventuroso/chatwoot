<script setup>
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  holidays: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const updateHoliday = (index, patch) => {
  emit(
    'update',
    props.holidays.map((holiday, i) =>
      i === index ? { ...holiday, ...patch } : holiday
    )
  );
};

const addHoliday = () => {
  emit('update', [
    ...props.holidays,
    { id: null, name: '', message: '', date: '', recurring: false },
  ]);
};

const removeHoliday = index => {
  emit(
    'update',
    props.holidays.filter((_, i) => i !== index)
  );
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-body-main text-n-slate-11">
      {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.HELP') }}
    </p>
    <div
      v-for="(holiday, index) in holidays"
      :key="holiday.id || `new-${index}`"
      class="flex flex-col gap-3 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak p-4"
    >
      <div class="flex flex-wrap items-end gap-3">
        <NextInput
          :model-value="holiday.name"
          :label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.NAME_LABEL')"
          :placeholder="
            t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.NAME_PLACEHOLDER')
          "
          class="flex-1 min-w-40"
          @update:model-value="value => updateHoliday(index, { name: value })"
        />
        <NextInput
          :model-value="holiday.date"
          type="date"
          :label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.DATE_LABEL')"
          @update:model-value="value => updateHoliday(index, { date: value })"
        />
        <div class="flex items-center gap-2 pb-2">
          <input
            type="checkbox"
            class="m-0"
            :checked="holiday.recurring"
            @change="
              event => updateHoliday(index, { recurring: event.target.checked })
            "
          />
          <span class="text-body-main text-n-slate-12">
            {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.RECURRING_LABEL') }}
          </span>
        </div>
        <NextButton
          ghost
          color="ruby"
          icon="i-lucide-trash-2"
          :aria-label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.REMOVE')"
          @click="removeHoliday(index)"
        />
      </div>
      <NextInput
        :model-value="holiday.message"
        :label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.MESSAGE_LABEL')"
        :placeholder="
          t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.MESSAGE_PLACEHOLDER')
        "
        @update:model-value="value => updateHoliday(index, { message: value })"
      />
      <span v-if="!holiday.date" class="text-label-small text-n-ruby-9">
        {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.DATE_REQUIRED') }}
      </span>
    </div>
    <p v-if="!holidays.length" class="text-body-main text-n-slate-11">
      {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.EMPTY') }}
    </p>
    <div>
      <NextButton
        faded
        icon="i-lucide-plus"
        :label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.ADD')"
        @click="addHoliday"
      />
    </div>
  </div>
</template>

<script setup>
import router from '../../routes/index';
const props = defineProps({
  backUrl: {
    type: [String, Object],
    default: '',
  },
  buttonLabel: {
    type: String,
    default: '',
  },
  compact: {
    type: Boolean,
    default: false,
  },
  // Custom (MyDesk): below sm only the arrow shows (the label stays for screen readers)
  hideLabelOnMobile: {
    type: Boolean,
    default: false,
  },
});

const goBack = () => {
  if (props.backUrl !== '') {
    router.push(props.backUrl);
  } else {
    router.go(-1);
  }
};

const buttonStyleClass = props.compact ? 'text-sm' : 'text-base';
</script>

<template>
  <!-- Custom (MyDesk): the arrow points back in the reading direction (mirrored in RTL) -->
  <button
    class="flex items-center p-0 font-normal cursor-pointer text-n-slate-11"
    :class="[
      buttonStyleClass,
      { 'touch:min-h-11 touch:min-w-11': hideLabelOnMobile },
    ]"
    @click.capture="goBack"
  >
    <i class="i-lucide-chevron-left -ms-1 text-lg rtl:rotate-180" />
    <span :class="{ 'max-sm:sr-only': hideLabelOnMobile }">
      {{ buttonLabel || $t('GENERAL_SETTINGS.BACK') }}
    </span>
  </button>
</template>

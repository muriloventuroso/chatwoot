<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  DUE_TONE_CLASS,
  PROJECT_COLOR_CLASS,
  PROJECT_STATUS_CLASS,
  dueTone,
  progressWidthClass,
} from '../constants';
import { useDueDate } from '../useDueDate';
import { useProjectActions } from '../useProjectActions';

const props = defineProps({
  project: { type: Object, required: true },
  // Redundant when the list is already filtered by status.
  showStatus: { type: Boolean, default: false },
});

const emit = defineEmits(['action']);

const MAX_AVATARS = 4;
// A project deadline gets the "soon" warning a week ahead.
const DEADLINE_WARNING_DAYS = 7;

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { formatDate, relativeDue } = useDueDate();
const { menuItems: projectMenuItems } = useProjectActions();
const showMenu = ref(false);

const projectRoute = computed(() =>
  accountScopedRoute('project_details', { projectId: props.project.id })
);

const members = computed(() => props.project.members || []);
const hiddenMembersCount = computed(() =>
  Math.max(0, members.value.length - MAX_AVATARS)
);
const isActive = computed(() => props.project.status === 'active');

const deadline = computed(() => {
  const date = props.project.end_date;
  if (!date) return null;
  const tone = dueTone(date, !isActive.value, DEADLINE_WARNING_DAYS);
  return {
    date: formatDate(date),
    relative: isActive.value ? relativeDue(date) : '',
    class: DUE_TONE_CLASS[tone],
  };
});

const menuItems = computed(() => projectMenuItems(props.project));

const onMenuAction = ({ action }) => {
  showMenu.value = false;
  emit('action', { action, project: props.project });
};
</script>

<template>
  <article
    class="relative flex flex-col overflow-hidden transition-shadow border cursor-pointer rounded-xl bg-n-solid-1 border-n-weak hover:shadow-md focus-within:shadow-md"
    @click="router.push(projectRoute)"
  >
    <span
      class="h-1 shrink-0"
      :class="PROJECT_COLOR_CLASS[project.color] || 'bg-n-brand'"
    />
    <div class="flex flex-col flex-1 gap-3 p-4">
      <header class="flex items-start gap-2">
        <div class="flex flex-col flex-1 min-w-0 gap-1">
          <h3 class="mb-0 text-heading-3 text-n-slate-12 line-clamp-2">
            <!-- The link makes the card reachable by keyboard; the card handles the mouse. -->
            <router-link
              :to="projectRoute"
              class="rounded-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
              @click.stop
            >
              {{ project.name }}
            </router-link>
          </h3>
          <p
            v-if="project.description"
            class="mb-0 text-body-main text-n-slate-11 line-clamp-1"
          >
            {{ project.description }}
          </p>
        </div>
        <span
          v-if="showStatus"
          class="px-2 py-0.5 rounded-md text-label-small shrink-0"
          :class="PROJECT_STATUS_CLASS[project.status]"
        >
          {{ t(`PROJECTS.STATUS.${project.status.toUpperCase()}`) }}
        </span>
        <div
          v-on-clickaway="() => (showMenu = false)"
          class="relative -my-1 -me-2 shrink-0"
          @click.stop
        >
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-ellipsis-vertical"
            :aria-label="t('PROJECTS.CARD.ACTIONS')"
            :aria-expanded="showMenu"
            @click="showMenu = !showMenu"
          />
          <DropdownMenu
            v-if="showMenu"
            :menu-items="menuItems"
            class="mt-1 end-0 top-full w-52"
            @action="onMenuAction"
          />
        </div>
      </header>

      <div class="flex flex-col gap-1.5 mt-auto">
        <div class="flex items-center gap-2">
          <span class="flex-1 h-1.5 overflow-hidden rounded-full bg-n-slate-4">
            <span
              class="block h-full rounded-full bg-n-brand"
              :class="progressWidthClass(project.progress)"
            />
          </span>
          <span class="text-xs font-medium tabular-nums text-n-slate-12">
            {{ `${project.progress}%` }}
          </span>
        </div>
        <div
          class="flex flex-wrap items-center text-xs gap-x-3 gap-y-1 text-n-slate-11"
        >
          <span class="inline-flex items-center gap-1">
            <Icon icon="i-lucide-list-checks" class="size-3.5 shrink-0" />
            {{
              project.tasks_count
                ? t('PROJECTS.CARD.TASKS_DONE', {
                    done: project.completed_tasks_count,
                    total: project.tasks_count,
                  })
                : t('PROJECTS.CARD.NO_TASKS')
            }}
          </span>
          <span
            v-if="project.overdue_tasks_count"
            class="inline-flex items-center gap-1 font-medium text-n-ruby-11"
          >
            <Icon icon="i-lucide-circle-alert" class="size-3.5 shrink-0" />
            {{
              t('PROJECTS.CARD.OVERDUE', project.overdue_tasks_count, {
                count: project.overdue_tasks_count,
              })
            }}
          </span>
        </div>
      </div>

      <footer
        class="flex items-center justify-between gap-2 pt-3 border-t border-n-weak min-h-11"
      >
        <span
          v-if="deadline"
          class="inline-flex items-center min-w-0 gap-1 text-xs"
          :class="deadline.class"
        >
          <Icon icon="i-lucide-calendar" class="size-3.5 shrink-0" />
          <span class="truncate">
            {{ deadline.date }}
            <template v-if="deadline.relative">
              {{ ` · ${deadline.relative}` }}
            </template>
          </span>
        </span>
        <span v-else class="text-xs text-n-slate-10">
          {{ t('PROJECTS.CARD.NO_DEADLINE') }}
        </span>
        <div
          v-if="members.length"
          class="flex items-center -space-x-1.5 shrink-0 rtl:space-x-reverse"
        >
          <Avatar
            v-for="member in members.slice(0, MAX_AVATARS)"
            :key="member.id"
            :name="member.name"
            :src="member.thumbnail"
            :size="24"
            class="rounded-full ring-2 ring-n-solid-1"
            rounded-full
          />
          <span
            v-if="hiddenMembersCount"
            class="z-10 flex items-center justify-center text-xs font-medium rounded-full size-6 ring-2 ring-n-solid-1 bg-n-slate-4 text-n-slate-12"
          >
            {{ `+${hiddenMembersCount}` }}
          </span>
        </div>
      </footer>
    </div>
  </article>
</template>

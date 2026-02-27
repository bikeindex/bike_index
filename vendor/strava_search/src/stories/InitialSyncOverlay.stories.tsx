import type { Meta, StoryObj } from '@storybook/react';
import { InitialSyncOverlay } from '../components/InitialSyncPrompt';

const meta = {
  title: 'Components/InitialSyncOverlay',
  component: InitialSyncOverlay,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
} satisfies Meta<typeof InitialSyncOverlay>;

export default meta;
type Story = StoryObj<typeof meta>;

export const StartingSyncNoTotal: Story = {
  args: {
    loaded: 0,
    total: null,
    status: 'Checking sync status...',
  },
};

export const SyncingWithProgress: Story = {
  args: {
    loaded: 50,
    total: 150,
    status: '50 of ~150 activities synced',
  },
};

export const SyncingWithoutTotal: Story = {
  args: {
    loaded: 23,
    total: null,
    status: '23 activities synced',
  },
};

export const NearlyComplete: Story = {
  args: {
    loaded: 142,
    total: 150,
    status: '142 of ~150 activities synced',
  },
};

export const LoadingActivities: Story = {
  args: {
    loaded: 0,
    total: null,
    status: 'Loading activities...',
  },
};

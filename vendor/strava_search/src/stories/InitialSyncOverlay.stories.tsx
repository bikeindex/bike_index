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

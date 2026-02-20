import type { Meta, StoryObj } from '@storybook/react';
import { ErrorBanner } from '../components/ErrorBanner';

const meta = {
  title: 'Components/ErrorBanner',
  component: ErrorBanner,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
  argTypes: {
    onDismiss: { action: 'dismiss' },
  },
} satisfies Meta<typeof ErrorBanner>;

export default meta;
type Story = StoryObj<typeof meta>;

export const RateLimitError: Story = {
  args: {
    message: 'Rate limit exceeded. Please wait a few minutes and try again.',
    onDismiss: () => {},
  },
};

export const SyncFailedError: Story = {
  args: {
    message: 'Sync failed. Please check your internet connection and try again.',
    onDismiss: () => {},
  },
};

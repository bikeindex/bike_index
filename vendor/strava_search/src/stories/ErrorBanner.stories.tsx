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
  decorators: [
    (Story) => (
      <div className="relative min-h-[400px] bg-gray-50 dark:bg-gray-900">
        <div className="fixed bottom-8 right-8 z-50 flex flex-col gap-2">
          <Story />
        </div>
      </div>
    ),
  ],
} satisfies Meta<typeof ErrorBanner>;

export default meta;
type Story = StoryObj<typeof meta>;

export const RateLimitError: Story = {
  args: {
    message: 'Rate limit exceeded. Please wait a few minutes and try again.',
    onDismiss: () => {},
  },
};

export const SessionExpired: Story = {
  args: {
    message: 'Updated 0/1 activities.\nActivity 17419209324: Session expired. Please log in again.',
    onDismiss: () => {},
  },
};

export const MultipleErrors: Story = {
  args: {
    message: 'Sync failed.',
    onDismiss: () => {},
  },
  decorators: [
    () => (
      <div className="relative min-h-[400px] bg-gray-50 dark:bg-gray-900">
        <div className="fixed bottom-8 right-8 z-50 flex flex-col gap-2">
          <ErrorBanner message="Sync failed. Please check your internet connection and try again." onDismiss={() => {}} />
          <ErrorBanner message="Updated 0/2 activities.\nActivity 17419209324: Session expired. Please log in again.\nActivity 13329733465: Rate limit exceeded." onDismiss={() => {}} />
        </div>
      </div>
    ),
  ],
};

import type { Meta, StoryObj } from '@storybook/react';
import { InitialSyncOverlay } from '../components/InitialSyncPrompt';
import { ErrorBanner } from '../components/ErrorBanner';

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

export const WithErrorBanner: Story = {
  args: {
    loaded: 12,
    total: 150,
    status: '12 of ~150 activities synced',
  },
  decorators: [
    (Story) => (
      <>
        <Story />
        <div className="fixed bottom-8 right-8 z-[1050] flex flex-col gap-2">
          <ErrorBanner
            message="Session expired. Please log in again."
            onDismiss={() => {}}
            loginUrl="/strava_authentication"
          />
        </div>
      </>
    ),
  ],
};

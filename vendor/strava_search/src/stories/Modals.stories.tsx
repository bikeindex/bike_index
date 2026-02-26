import type { Meta, StoryObj } from '@storybook/react';
import { BulkActions } from '../components/BulkActions';
import { mockGear } from './mocks';

const defaultArgs = {
  selectedCount: 12,
  pageCount: 50,
  totalPages: 3,
  currentPage: 1,
  onPageChange: () => {},
  onSelectAll: () => {},
  onDeselectAll: () => {},
  onUpdateSelected: async () => {
    await new Promise((resolve) => setTimeout(resolve, 1000));
  },
  isUpdating: false,
  gear: mockGear,
  hasActivityWrite: true,
  authUrl: '/strava_integration/new?scope=strava_search',
};

const meta = {
  title: 'Modals/BulkActions',
  component: BulkActions,
  parameters: {
    layout: 'padded',
  },
  tags: ['autodocs'],
} satisfies Meta<typeof BulkActions>;

export default meta;
type Story = StoryObj<typeof meta>;

export const ChangeTypeModal: Story = {
  args: defaultArgs,
  play: async ({ canvasElement }) => {
    const button = [...canvasElement.querySelectorAll('button')].find(
      (b) => b.textContent?.includes('Change Type')
    );
    button?.click();
  },
};

export const ChangeGearModal: Story = {
  args: defaultArgs,
  play: async ({ canvasElement }) => {
    const button = [...canvasElement.querySelectorAll('button')].find(
      (b) => b.textContent?.includes('Change Gear')
    );
    button?.click();
  },
};

export const CommuteModal: Story = {
  args: defaultArgs,
  play: async ({ canvasElement }) => {
    const button = [...canvasElement.querySelectorAll('button')].find(
      (b) => b.textContent?.trim() === 'Commute'
    );
    button?.click();
  },
};

export const TrainerIndoorModal: Story = {
  args: defaultArgs,
  play: async ({ canvasElement }) => {
    const button = [...canvasElement.querySelectorAll('button')].find(
      (b) => b.textContent?.includes('Trainer/Indoor')
    );
    button?.click();
  },
};

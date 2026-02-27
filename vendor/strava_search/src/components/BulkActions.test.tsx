import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BulkActions } from './BulkActions';

describe('BulkActions', () => {
  const defaultProps = {
    selectedCount: 0,
    pageCount: 10,
    totalPages: 3,
    currentPage: 1,
    onPageChange: vi.fn(),
    onSelectAll: vi.fn(),
    onDeselectAll: vi.fn(),
    onUpdateSelected: vi.fn().mockResolvedValue(undefined),
    isUpdating: false,
    gear: [
      { id: 'b123', name: 'Road Bike', distance: 1000, primary: true, resource_state: 2 },
      { id: 's456', name: 'Running Shoes', distance: 500, primary: false, resource_state: 2 },
    ],
    hasActivityWrite: true,
    authUrl: '/strava_integration/new?scope=strava_search',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders select all on page button when multiple pages', () => {
    render(<BulkActions {...defaultProps} />);
    expect(screen.getByText('Select all on page (10)')).toBeInTheDocument();
  });

  it('renders select all button when single page', () => {
    render(<BulkActions {...defaultProps} totalPages={1} />);
    expect(screen.getByText('Select all (10)')).toBeInTheDocument();
  });

  it('shows selected count when items are selected', () => {
    render(<BulkActions {...defaultProps} selectedCount={3} />);
    expect(screen.getByText('3 selected · Clear')).toBeInTheDocument();
  });

  it('shows labeled update fields when items are selected', () => {
    render(<BulkActions {...defaultProps} selectedCount={2} />);
    expect(screen.getByText('Activity Type')).toBeInTheDocument();
    expect(screen.getByText('Equipment')).toBeInTheDocument();
    expect(screen.getByText('Commute')).toBeInTheDocument();
    expect(screen.getByText('Trainer')).toBeInTheDocument();
  });

  it('all fields default to "No change"', () => {
    render(<BulkActions {...defaultProps} selectedCount={2} />);
    expect(screen.getByLabelText('Activity Type')).toHaveValue('');
    expect(screen.getByLabelText('Equipment')).toHaveValue('');
    expect(screen.getByLabelText('Commute')).toHaveValue('');
    expect(screen.getByLabelText('Trainer')).toHaveValue('');
    // Verify the placeholder text
    expect(screen.getAllByText('No change')).toHaveLength(4);
  });

  it('collapses update fields when nothing selected', () => {
    render(<BulkActions {...defaultProps} />);
    const animatedContainer = screen.getByLabelText('Activity Type').closest('[class*="transition"]')!;
    expect(animatedContainer).toHaveStyle({ gridTemplateRows: '0fr' });
  });

  it('calls onSelectAll when select all on page is clicked', () => {
    render(<BulkActions {...defaultProps} />);
    fireEvent.click(screen.getByText('Select all on page (10)'));
    expect(defaultProps.onSelectAll).toHaveBeenCalled();
  });

  it('calls onDeselectAll when selected count is clicked', () => {
    render(<BulkActions {...defaultProps} selectedCount={10} />);
    fireEvent.click(screen.getByText('10 selected · Clear'));
    expect(defaultProps.onDeselectAll).toHaveBeenCalled();
  });

  describe('Update form', () => {
    it('has a single Update button showing the selected count', () => {
      render(<BulkActions {...defaultProps} selectedCount={5} />);
      expect(screen.getByText('Update 5 activities')).toBeInTheDocument();
    });

    it('disables Update button when all fields are "No change"', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      expect(screen.getByText('Update 2 activities')).toBeDisabled();
    });

    it('does not call onUpdateSelected when no fields are changed', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      // Button is disabled, but verify the guard in handleSubmit too
      expect(screen.getByText('Update 2 activities')).toBeDisabled();
      expect(defaultProps.onUpdateSelected).not.toHaveBeenCalled();
    });

    it('enables Update button when a field is changed', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Activity Type'), { target: { value: 'Run' } });
      expect(screen.getByText('Update 2 activities')).not.toBeDisabled();
    });

    it('submits type change', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Activity Type'), { target: { value: 'Run' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ type: 'Run' });
      });
    });

    it('submits gear change', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Equipment'), { target: { value: 'b123' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ gear_id: 'b123' });
      });
    });

    it('removes gear when "None (remove)" is selected', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Equipment'), { target: { value: '_none' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ gear_id: '' });
      });
    });

    it('submits commute change', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Commute'), { target: { value: 'true' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ commute: true });
      });
    });

    it('submits trainer change', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Trainer'), { target: { value: 'false' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ trainer: false });
      });
    });

    it('submits multiple changes at once', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Activity Type'), { target: { value: 'Ride' } });
      fireEvent.change(screen.getByLabelText('Equipment'), { target: { value: 'b123' } });
      fireEvent.change(screen.getByLabelText('Commute'), { target: { value: 'true' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({
          type: 'Ride',
          gear_id: 'b123',
          commute: true,
        });
      });
    });

    it('only includes changed fields in update', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      // Only change commute, leave everything else as "No change"
      fireEvent.change(screen.getByLabelText('Commute'), { target: { value: 'false' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ commute: false });
      });
      // Should NOT include type, gear_id, or trainer
      const call = defaultProps.onUpdateSelected.mock.calls[0][0];
      expect(call).not.toHaveProperty('type');
      expect(call).not.toHaveProperty('gear_id');
      expect(call).not.toHaveProperty('trainer');
    });

    it('resets fields after update', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.change(screen.getByLabelText('Activity Type'), { target: { value: 'Run' } });
      fireEvent.click(screen.getByText('Update 2 activities'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalled();
      });

      expect(screen.getByLabelText('Activity Type')).toHaveValue('');
    });

    it('disables all fields when isUpdating is true', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} isUpdating={true} />);
      expect(screen.getByLabelText('Activity Type')).toBeDisabled();
      expect(screen.getByLabelText('Equipment')).toBeDisabled();
      expect(screen.getByLabelText('Commute')).toBeDisabled();
      expect(screen.getByLabelText('Trainer')).toBeDisabled();
    });
  });

  describe('Authorization modal', () => {
    const noWriteProps = { ...defaultProps, selectedCount: 2, hasActivityWrite: false };

    it('shows auth modal immediately when activities are selected without write permission', () => {
      render(<BulkActions {...noWriteProps} />);
      expect(screen.getByText('Authorization Required')).toBeInTheDocument();
      expect(screen.getByText('You need to authorize updating Strava Activities')).toBeInTheDocument();
    });

    it('does not show auth modal when nothing is selected', () => {
      render(<BulkActions {...defaultProps} selectedCount={0} hasActivityWrite={false} />);
      expect(screen.queryByText('Authorization Required')).not.toBeInTheDocument();
    });

    it('has an Authorize link in the modal', () => {
      render(<BulkActions {...noWriteProps} />);
      const authorizeLink = screen.getByText('Authorize').closest('a');
      expect(authorizeLink).toHaveAttribute('href', expect.stringContaining('/strava_integration/new?scope=strava_search'));
    });

    it('calls onDeselectAll when X is clicked', () => {
      render(<BulkActions {...noWriteProps} />);
      const closeButton = screen.getByText('Authorization Required').closest('div')!.querySelector('button')!;
      fireEvent.click(closeButton);
      expect(defaultProps.onDeselectAll).toHaveBeenCalled();
    });

    it('calls onDeselectAll when Escape is pressed', () => {
      render(<BulkActions {...noWriteProps} />);
      fireEvent.keyDown(document, { key: 'Escape' });
      expect(defaultProps.onDeselectAll).toHaveBeenCalled();
    });
  });

  describe('Top Pagination', () => {
    it('shows pagination when there are multiple pages', () => {
      render(<BulkActions {...defaultProps} totalPages={3} currentPage={2} />);
      expect(screen.getByText('2 / 3')).toBeInTheDocument();
    });

    it('does not show pagination when there is only one page', () => {
      render(<BulkActions {...defaultProps} totalPages={1} currentPage={1} />);
      expect(screen.queryByText('1 / 1')).not.toBeInTheDocument();
    });

    it('calls onPageChange when clicking next', () => {
      render(<BulkActions {...defaultProps} totalPages={3} currentPage={1} />);
      const buttons = screen.getAllByRole('button');
      const nextButton = buttons.find(btn => btn.querySelector('svg.lucide-chevron-right'));
      fireEvent.click(nextButton!);
      expect(defaultProps.onPageChange).toHaveBeenCalledWith(2);
    });

    it('calls onPageChange when clicking previous', () => {
      render(<BulkActions {...defaultProps} totalPages={3} currentPage={2} />);
      const buttons = screen.getAllByRole('button');
      const prevButton = buttons.find(btn => btn.querySelector('svg.lucide-chevron-left'));
      fireEvent.click(prevButton!);
      expect(defaultProps.onPageChange).toHaveBeenCalledWith(1);
    });

    it('disables previous button on first page', () => {
      render(<BulkActions {...defaultProps} totalPages={3} currentPage={1} />);
      const buttons = screen.getAllByRole('button');
      const prevButton = buttons.find(btn => btn.querySelector('svg.lucide-chevron-left'));
      expect(prevButton).toBeDisabled();
    });

    it('disables next button on last page', () => {
      render(<BulkActions {...defaultProps} totalPages={3} currentPage={3} />);
      const buttons = screen.getAllByRole('button');
      const nextButton = buttons.find(btn => btn.querySelector('svg.lucide-chevron-right'));
      expect(nextButton).toBeDisabled();
    });
  });
});

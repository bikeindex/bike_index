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
    expect(screen.getByText('3 selected')).toBeInTheDocument();
  });

  it('shows action buttons when items are selected', () => {
    render(<BulkActions {...defaultProps} selectedCount={2} />);
    expect(screen.getByText('Change Type')).toBeInTheDocument();
    expect(screen.getByText('Change Gear')).toBeInTheDocument();
    expect(screen.getByText('Change Tags')).toBeInTheDocument();
  });

  it('does not show action buttons when nothing selected', () => {
    render(<BulkActions {...defaultProps} />);
    expect(screen.queryByText('Change Type')).not.toBeInTheDocument();
    expect(screen.queryByText('Change Gear')).not.toBeInTheDocument();
    expect(screen.queryByText('Change Tags')).not.toBeInTheDocument();
  });

  it('calls onSelectAll when select all on page is clicked', () => {
    render(<BulkActions {...defaultProps} />);
    fireEvent.click(screen.getByText('Select all on page (10)'));
    expect(defaultProps.onSelectAll).toHaveBeenCalled();
  });

  it('calls onDeselectAll when all are selected and toggle is clicked', () => {
    render(<BulkActions {...defaultProps} selectedCount={10} />);
    fireEvent.click(screen.getByText('10 selected'));
    expect(defaultProps.onDeselectAll).toHaveBeenCalled();
  });

  describe('Change Type Modal', () => {
    it('opens type modal when Change Type is clicked', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Type'));
      expect(screen.getByText('Change Activity Type')).toBeInTheDocument();
    });

    it('updates activities with selected type', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Type'));

      const select = screen.getByRole('combobox');
      fireEvent.change(select, { target: { value: 'Run' } });
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ type: 'Run' });
      });
    });
  });

  describe('Change Gear Modal', () => {
    it('opens gear modal when Change Gear is clicked', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Gear'));
      expect(screen.getByText('Change Equipment')).toBeInTheDocument();
    });

    it('updates activities with selected gear', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Gear'));

      const select = screen.getByRole('combobox');
      fireEvent.change(select, { target: { value: 'b123' } });
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ gear_id: 'b123' });
      });
    });

    it('removes gear when None is selected', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Gear'));

      // The default value is already empty (None)
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ gear_id: '' });
      });
    });
  });

  describe('Change Tags Modal', () => {
    it('opens tags modal when Change Tags is clicked', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));
      // Modal title and button both say "Change Tags", so check for modal content instead
      expect(screen.getByText('Commute')).toBeInTheDocument();
      expect(screen.getByText('Trainer / Indoor')).toBeInTheDocument();
    });

    it('updates activities with commute tag', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));

      const selects = screen.getAllByRole('combobox');
      const commuteSelect = selects[0];
      fireEvent.change(commuteSelect, { target: { value: 'true' } });
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ commute: true });
      });
    });

    it('updates activities with trainer tag', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));

      const selects = screen.getAllByRole('combobox');
      const trainerSelect = selects[1];
      fireEvent.change(trainerSelect, { target: { value: 'true' } });
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ trainer: true });
      });
    });

    it('updates activities with both tags', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));

      const selects = screen.getAllByRole('combobox');
      fireEvent.change(selects[0], { target: { value: 'true' } });
      fireEvent.change(selects[1], { target: { value: 'false' } });
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({
          commute: true,
          trainer: false
        });
      });
    });

    it('removes commute tag when false is selected', async () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));

      const selects = screen.getAllByRole('combobox');
      fireEvent.change(selects[0], { target: { value: 'false' } });
      fireEvent.click(screen.getByText('Update'));

      await waitFor(() => {
        expect(defaultProps.onUpdateSelected).toHaveBeenCalledWith({ commute: false });
      });
    });

    it('disables update button when no tags are selected', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));

      const updateButton = screen.getByText('Update');
      expect(updateButton).toBeDisabled();
    });

    it('enables update button when a tag is selected', () => {
      render(<BulkActions {...defaultProps} selectedCount={2} />);
      fireEvent.click(screen.getByText('Change Tags'));

      const selects = screen.getAllByRole('combobox');
      fireEvent.change(selects[0], { target: { value: 'true' } });

      const updateButton = screen.getByText('Update');
      expect(updateButton).not.toBeDisabled();
    });
  });

  it('closes modal when Cancel is clicked', () => {
    render(<BulkActions {...defaultProps} selectedCount={2} />);
    fireEvent.click(screen.getByText('Change Type'));
    expect(screen.getByText('Change Activity Type')).toBeInTheDocument();

    fireEvent.click(screen.getByText('Cancel'));
    expect(screen.queryByText('Change Activity Type')).not.toBeInTheDocument();
  });

  it('closes modal immediately when Update is clicked', async () => {
    render(<BulkActions {...defaultProps} selectedCount={2} />);
    fireEvent.click(screen.getByText('Change Gear'));
    expect(screen.getByText('Change Equipment')).toBeInTheDocument();

    fireEvent.click(screen.getByText('Update'));

    // Modal should close immediately, before the update completes
    await waitFor(() => {
      expect(screen.queryByText('Change Equipment')).not.toBeInTheDocument();
    });
  });

  it('disables buttons when isUpdating is true', () => {
    render(<BulkActions {...defaultProps} selectedCount={2} isUpdating={true} />);
    expect(screen.getByText('Change Type').closest('button')).toBeDisabled();
    expect(screen.getByText('Change Gear').closest('button')).toBeDisabled();
    expect(screen.getByText('Change Tags').closest('button')).toBeDisabled();
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
      // Find the next button (has ChevronRight)
      const nextButton = buttons.find(btn => btn.querySelector('svg.lucide-chevron-right'));
      fireEvent.click(nextButton!);
      expect(defaultProps.onPageChange).toHaveBeenCalledWith(2);
    });

    it('calls onPageChange when clicking previous', () => {
      render(<BulkActions {...defaultProps} totalPages={3} currentPage={2} />);
      const buttons = screen.getAllByRole('button');
      // Find the previous button (has ChevronLeft)
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

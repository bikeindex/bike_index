import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { InitialSyncOverlay } from './InitialSyncPrompt';

describe('InitialSyncOverlay', () => {
  it('displays the status message', () => {
    render(<InitialSyncOverlay loaded={0} total={null} status="Checking sync status..." />);

    expect(screen.getByText('Syncing Your Activities')).toBeInTheDocument();
    expect(screen.getByText('Checking sync status...')).toBeInTheDocument();
  });

  it('hides progress bar when loaded is 0 and total is null', () => {
    render(<InitialSyncOverlay loaded={0} total={null} status="Checking sync status..." />);

    const bars = document.querySelectorAll('.bg-\\[\\#fc4c02\\]');
    expect(bars).toHaveLength(0);
  });

  it('shows spinner icon', () => {
    render(<InitialSyncOverlay loaded={0} total={null} status="Loading..." />);

    const spinner = document.querySelector('.animate-spin');
    expect(spinner).toBeInTheDocument();
  });
});

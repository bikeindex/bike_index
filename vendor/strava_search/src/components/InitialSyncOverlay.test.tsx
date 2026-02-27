import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { InitialSyncOverlay } from './InitialSyncPrompt';

describe('InitialSyncOverlay', () => {
  it('displays the status message', () => {
    render(<InitialSyncOverlay loaded={0} total={null} status="Checking sync status..." />);

    expect(screen.getByText('Syncing Your Activities')).toBeInTheDocument();
    expect(screen.getByText('Checking sync status...')).toBeInTheDocument();
  });

  it('shows progress bar when total is known', () => {
    render(<InitialSyncOverlay loaded={50} total={150} status="50 of ~150 activities synced" />);

    const bar = document.querySelector('.bg-\\[\\#fc4c02\\]') as HTMLElement;
    expect(bar).toBeInTheDocument();
    expect(bar.style.width).toBe('33.33333333333333%');
  });

  it('shows progress bar at 50% when total is unknown but loaded > 0', () => {
    render(<InitialSyncOverlay loaded={23} total={null} status="23 activities synced" />);

    const bars = document.querySelectorAll('.bg-\\[\\#fc4c02\\]');
    expect(bars.length).toBeGreaterThan(0);

    const bar = bars[0] as HTMLElement;
    expect(bar.style.width).toBe('50%');
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

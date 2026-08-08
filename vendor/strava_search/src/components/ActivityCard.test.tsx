import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ActivityCard } from './ActivityCard';
import { mockActivities, mockGear } from '../stories/mocks';
import type { StoredActivity } from '../services/database';

vi.mock('../contexts/PreferencesContext', () => ({
  usePreferences: () => ({ units: 'imperial' }),
}));

function renderCard(overrides: Partial<StoredActivity>) {
  return render(
    <ActivityCard
      activity={{ ...mockActivities[0], ...overrides }}
      gear={mockGear}
      isSelected={false}
      onToggleSelect={() => {}}
      showCheckbox={false}
    />,
  );
}

describe('ActivityCard top 10 badge', () => {
  it('lists each rank', () => {
    renderCard({ top_10_ranks: [1, 2, 10] });
    expect(screen.getByText(/top 10: #1, #2, #10/)).toBeInTheDocument();
  });

  it('caps the list at five ranks and counts the rest', () => {
    renderCard({ top_10_ranks: [1, 1, 2, 3, 4, 6, 8] });
    expect(screen.getByText(/top 10: #1, #1, #2, #3, #4/)).toBeInTheDocument();
    expect(screen.getByText(/\+2 more/)).toBeInTheDocument();
  });

  it('is absent without ranks', () => {
    renderCard({ top_10_ranks: [] });
    expect(screen.queryByText(/top 10/)).not.toBeInTheDocument();
  });

  it('is absent when the activity has not been enriched', () => {
    renderCard({ top_10_ranks: null });
    expect(screen.queryByText(/top 10/)).not.toBeInTheDocument();
  });
});

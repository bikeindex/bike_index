import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ErrorBanner } from './ErrorBanner';

describe('ErrorBanner', () => {
  it('displays the error message', () => {
    render(<ErrorBanner message="Something went wrong" />);

    expect(screen.getByText('Something went wrong')).toBeInTheDocument();
  });

  it('calls onDismiss when dismiss button is clicked', async () => {
    const user = userEvent.setup();
    const onDismiss = vi.fn();

    render(<ErrorBanner message="Error message" onDismiss={onDismiss} />);

    const dismissButton = screen.getByRole('button', { name: /dismiss/i });
    await user.click(dismissButton);

    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it('does not show dismiss button when onDismiss is not provided', () => {
    render(<ErrorBanner message="Error message" />);

    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('does not dismiss on Escape key', () => {
    const onDismiss = vi.fn();

    render(<ErrorBanner message="Error message" onDismiss={onDismiss} />);

    fireEvent.keyDown(document, { key: 'Escape' });

    expect(onDismiss).not.toHaveBeenCalled();
    expect(screen.getByText('Error message')).toBeInTheDocument();
  });

  describe('login link', () => {
    it('shows login link when message contains "log in" and loginUrl is provided', () => {
      render(
        <ErrorBanner
          message="Session expired. Please log in again."
          loginUrl="/strava_authentication"
        />
      );

      const link = screen.getByRole('link', { name: /log in/i });
      expect(link).toBeInTheDocument();
      expect(link).toHaveAttribute('href', '/strava_authentication');
    });

    it('does not show login link when message does not mention logging in', () => {
      render(
        <ErrorBanner
          message="Network error"
          loginUrl="/strava_authentication"
        />
      );

      expect(screen.queryByRole('link')).not.toBeInTheDocument();
    });

    it('does not show login link when loginUrl is not provided', () => {
      render(<ErrorBanner message="Session expired. Please log in again." />);

      expect(screen.queryByRole('link')).not.toBeInTheDocument();
    });

    it('shows login link when message contains "not authenticated"', () => {
      render(
        <ErrorBanner
          message="Not authenticated"
          loginUrl="/strava_authentication"
        />
      );

      const link = screen.getByRole('link', { name: /log in/i });
      expect(link).toHaveAttribute('href', '/strava_authentication');
    });

    it('shows login link for multiline messages that mention log in', () => {
      render(
        <ErrorBanner
          message="Updated 0/1 activities.\nActivity 123: Session expired. Please log in again."
          loginUrl="/strava_authentication"
        />
      );

      const link = screen.getByRole('link', { name: /log in/i });
      expect(link).toHaveAttribute('href', '/strava_authentication');
    });
  });
});

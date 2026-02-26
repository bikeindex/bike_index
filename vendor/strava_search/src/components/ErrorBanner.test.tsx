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
});

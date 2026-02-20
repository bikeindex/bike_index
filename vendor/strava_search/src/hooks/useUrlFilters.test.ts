import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useUrlFilters } from './useUrlFilters';

describe('useUrlFilters', () => {
  beforeEach(() => {
    // Reset URL to clean state
    window.history.replaceState({}, '', '/');
  });

  afterEach(() => {
    window.history.replaceState({}, '', '/');
    vi.restoreAllMocks();
  });

  describe('initialization', () => {
    it('returns default filters when URL has no params', () => {
      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0]).toEqual({
        query: '',
        activityTypes: [],
        gearIds: [],
        noEquipment: false,
        dateFrom: null,
        dateTo: null,
        distanceFrom: null,
        distanceTo: null,
        elevationFrom: null,
        elevationTo: null,
        activityTypesExpanded: true,
        equipmentExpanded: true,
        mutedFilter: 'all',
        photoFilter: 'all',
        privateFilter: 'all',
        commuteFilter: 'all',
        sufferScoreFrom: null,
        sufferScoreTo: null,
        kudosFrom: null,
        kudosTo: null,
        page: 1,
        view: 'activities',
      });
    });

    it('parses query param from URL', () => {
      window.history.replaceState({}, '', '/?q=morning%20run');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].query).toBe('morning run');
    });

    it('parses activity types from URL', () => {
      window.history.replaceState({}, '', '/?types=Run,Hike,Swim');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].activityTypes).toEqual(['Run', 'Hike', 'Swim']);
      // Default is expanded (true) unless typesClosed=1 is present
      expect(result.current[0].activityTypesExpanded).toBe(true);
    });

    it('parses gear IDs from URL', () => {
      window.history.replaceState({}, '', '/?gear=b12345,g67890');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].gearIds).toEqual(['b12345', 'g67890']);
      // Default is expanded (true) unless gearClosed=1 is present
      expect(result.current[0].equipmentExpanded).toBe(true);
    });

    it('parses noEquipment flag from URL', () => {
      window.history.replaceState({}, '', '/?noGear=1');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].noEquipment).toBe(true);
      // Default is expanded (true) unless gearClosed=1 is present
      expect(result.current[0].equipmentExpanded).toBe(true);
    });

    it('parses date range from URL', () => {
      window.history.replaceState({}, '', '/?from=2024-01-01&to=2024-12-31');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].dateFrom).toBe('2024-01-01');
      expect(result.current[0].dateTo).toBe('2024-12-31');
    });

    it('parses multiple params from URL', () => {
      window.history.replaceState({}, '', '/?q=park&types=Run&gear=g12345&from=2024-01-01');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0]).toEqual({
        query: 'park',
        activityTypes: ['Run'],
        gearIds: ['g12345'],
        noEquipment: false,
        dateFrom: '2024-01-01',
        dateTo: null,
        distanceFrom: null,
        distanceTo: null,
        elevationFrom: null,
        elevationTo: null,
        activityTypesExpanded: true,
        equipmentExpanded: true,
        mutedFilter: 'all',
        photoFilter: 'all',
        privateFilter: 'all',
        commuteFilter: 'all',
        sufferScoreFrom: null,
        sufferScoreTo: null,
        kudosFrom: null,
        kudosTo: null,
        page: 1,
        view: 'activities',
      });
    });

    it('parses page from URL', () => {
      window.history.replaceState({}, '', '/?page=3');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].page).toBe(3);
    });

    it('parses closed state from URL', () => {
      window.history.replaceState({}, '', '/?typesClosed=1&gearClosed=1');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].activityTypesExpanded).toBe(false);
      expect(result.current[0].equipmentExpanded).toBe(false);
    });

    it('parses commute filter from URL', () => {
      window.history.replaceState({}, '', '/?commute=commute');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].commuteFilter).toBe('commute');
    });

    it('parses suffer score range from URL', () => {
      window.history.replaceState({}, '', '/?sufferFrom=20&sufferTo=100');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].sufferScoreFrom).toBe(20);
      expect(result.current[0].sufferScoreTo).toBe(100);
    });

    it('parses kudos range from URL', () => {
      window.history.replaceState({}, '', '/?kudosFrom=5&kudosTo=50');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].kudosFrom).toBe(5);
      expect(result.current[0].kudosTo).toBe(50);
    });
  });

  describe('setFilters', () => {
    it('updates filters state', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: 'test',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(result.current[0].query).toBe('test');
    });

    it('updates URL with query param', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: 'morning run',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toBe('?q=morning+run');
    });

    it('updates URL with activity types', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: ['Run', 'Hike'],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toContain('types=Run');
      expect(window.location.search).toContain('Hike');
    });

    it('updates URL with gear IDs', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: ['b12345'],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toBe('?gear=b12345');
    });

    it('updates URL with noEquipment flag', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: true,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toBe('?noGear=1');
    });

    it('updates URL with date range', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: '2024-01-01',
          dateTo: '2024-12-31',
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toContain('from=2024-01-01');
      expect(window.location.search).toContain('to=2024-12-31');
    });

    it('updates URL with closed state', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: false,
            equipmentExpanded: false,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toContain('typesClosed=1');
      expect(window.location.search).toContain('gearClosed=1');
    });

    it('updates URL with commute filter', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'commute',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toBe('?commute=commute');
    });

    it('updates URL with suffer score range', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: 20,
          sufferScoreTo: 100,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toContain('sufferFrom=20');
      expect(window.location.search).toContain('sufferTo=100');
    });

    it('updates URL with kudos range', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: 5,
          kudosTo: 50,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toContain('kudosFrom=5');
      expect(window.location.search).toContain('kudosTo=50');
    });

    it('clears URL when filters are reset to defaults', () => {
      window.history.replaceState({}, '', '/?q=test');
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(window.location.search).toBe('');
    });

    it('supports functional updates', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: 'initial',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      act(() => {
        result.current[1]((prev) => ({
          ...prev,
          query: prev.query + ' updated',
        }));
      });

      expect(result.current[0].query).toBe('initial updated');
    });
  });

  describe('browser navigation', () => {
    it('updates filters on popstate event', () => {
      const { result } = renderHook(() => useUrlFilters());

      // Simulate navigating to a URL with filters
      act(() => {
        result.current[1]({
          query: 'first',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      act(() => {
        result.current[1]({
          query: 'second',
          activityTypes: [],
            gearIds: [],
          noEquipment: false,
          dateFrom: null,
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          page: 1,
          view: 'activities',
        });
      });

      expect(result.current[0].query).toBe('second');

      // Simulate back button
      act(() => {
        window.history.back();
        window.dispatchEvent(new PopStateEvent('popstate', {
          state: {
            filters: {
              query: 'first',
              activityTypes: [],
              gearIds: [],
              noEquipment: false,
              dateFrom: null,
              dateTo: null,
              distanceFrom: null,
              distanceTo: null,
              elevationFrom: null,
              elevationTo: null,
              activityTypesExpanded: true,
              equipmentExpanded: true,
              mutedFilter: 'all',
              photoFilter: 'all',
              privateFilter: 'all',
              commuteFilter: 'all',
              sufferScoreFrom: null,
              sufferScoreTo: null,
              kudosFrom: null,
              kudosTo: null,
              view: 'activities',
            },
          },
        }));
      });

      expect(result.current[0].query).toBe('first');
    });

    it('parses URL when popstate has no state', () => {
      const { result } = renderHook(() => useUrlFilters());

      // Simulate popstate without state (e.g., manual URL entry)
      act(() => {
        window.history.replaceState(null, '', '/?q=manual');
        window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
      });

      expect(result.current[0].query).toBe('manual');
    });
  });
});

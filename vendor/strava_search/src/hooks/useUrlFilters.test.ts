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
        filtersExpanded: false,
        activityTypesExpanded: false,
        equipmentExpanded: false,
        mutedFilter: 'all',
        photoFilter: 'all',
        privateFilter: 'all',
        commuteFilter: 'all',
        trainerFilter: 'all',
        sufferScoreFrom: null,
        sufferScoreTo: null,
        kudosFrom: null,
        kudosTo: null,
        country: null,
        region: null,
        city: null,
        page: 1,
      });
    });

    it('parses query param from URL', () => {
      window.history.replaceState({}, '', '/?q=morning%20run');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].query).toBe('morning run');
    });

    it('parses activity types from URL and auto-expands panel', () => {
      window.history.replaceState({}, '', '/?types=Run,Hike,Swim');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].activityTypes).toEqual(['Run', 'Hike', 'Swim']);
      expect(result.current[0].activityTypesExpanded).toBe(true);
    });

    it('parses gear IDs from URL and auto-expands panel', () => {
      window.history.replaceState({}, '', '/?gear=b12345,g67890');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].gearIds).toEqual(['b12345', 'g67890']);
      expect(result.current[0].equipmentExpanded).toBe(true);
    });

    it('parses noEquipment flag from URL and auto-expands panel', () => {
      window.history.replaceState({}, '', '/?noGear=1');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].noEquipment).toBe(true);
      expect(result.current[0].equipmentExpanded).toBe(true);
    });

    it('parses date range from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?from=2024-01-01&to=2024-12-31');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].dateFrom).toBe('2024-01-01');
      expect(result.current[0].dateTo).toBe('2024-12-31');
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses multiple params from URL and auto-expands all panels', () => {
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
        filtersExpanded: true,
        activityTypesExpanded: true,
        equipmentExpanded: true,
        mutedFilter: 'all',
        photoFilter: 'all',
        privateFilter: 'all',
        commuteFilter: 'all',
        trainerFilter: 'all',
        sufferScoreFrom: null,
        sufferScoreTo: null,
        kudosFrom: null,
        kudosTo: null,
        country: null,
        region: null,
        city: null,
        page: 1,
      });
    });

    it('parses page from URL', () => {
      window.history.replaceState({}, '', '/?page=3');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].page).toBe(3);
    });

    it('keeps panels collapsed when panel=closed overrides auto-open', () => {
      window.history.replaceState({}, '', '/?types=Run&typesPanel=closed&gear=b123&gearPanel=closed&from=2024-01-01&propertiesPanel=closed');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].activityTypes).toEqual(['Run']);
      expect(result.current[0].activityTypesExpanded).toBe(false);
      expect(result.current[0].gearIds).toEqual(['b123']);
      expect(result.current[0].equipmentExpanded).toBe(false);
      expect(result.current[0].dateFrom).toBe('2024-01-01');
      expect(result.current[0].filtersExpanded).toBe(false);
    });

    it('expands panels when panel=open without active filters', () => {
      window.history.replaceState({}, '', '/?propertiesPanel=open&typesPanel=open&gearPanel=open');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].filtersExpanded).toBe(true);
      expect(result.current[0].activityTypesExpanded).toBe(true);
      expect(result.current[0].equipmentExpanded).toBe(true);
    });

    it('parses commute filter from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?commute=commute');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].commuteFilter).toBe('commute');
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses suffer score range from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?sufferFrom=20&sufferTo=100');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].sufferScoreFrom).toBe(20);
      expect(result.current[0].sufferScoreTo).toBe(100);
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses trainer filter from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?trainer=trainer');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].trainerFilter).toBe('trainer');
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses muted filter from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?muted=muted');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].mutedFilter).toBe('muted');
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses photo filter from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?photo=has_photo');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].photoFilter).toBe('has_photo');
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses private filter from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?private=private');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].privateFilter).toBe('private');
      expect(result.current[0].filtersExpanded).toBe(true);
    });

    it('parses kudos range from URL and auto-expands properties panel', () => {
      window.history.replaceState({}, '', '/?kudosFrom=5&kudosTo=50');

      const { result } = renderHook(() => useUrlFilters());

      expect(result.current[0].kudosFrom).toBe(5);
      expect(result.current[0].kudosTo).toBe(50);
      expect(result.current[0].filtersExpanded).toBe(true);
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: false,
          activityTypesExpanded: false,
            equipmentExpanded: false,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: false,
          activityTypesExpanded: false,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: false,
          activityTypesExpanded: false,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
        });
      });

      expect(window.location.search).toContain('from=2024-01-01');
      expect(window.location.search).toContain('to=2024-12-31');
    });

    it('does not write *Closed params when panels have no active filters', () => {
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
          filtersExpanded: false,
          activityTypesExpanded: false,
          equipmentExpanded: false,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
        });
      });

      expect(window.location.search).toBe('');
    });

    it('writes panel=closed when panels are closed with active filters', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: ['Run'],
          gearIds: ['b123'],
          noEquipment: false,
          dateFrom: '2024-01-01',
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          filtersExpanded: false,
          activityTypesExpanded: false,
          equipmentExpanded: false,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
        });
      });

      expect(window.location.search).toContain('typesPanel=closed');
      expect(window.location.search).toContain('gearPanel=closed');
      expect(window.location.search).toContain('propertiesPanel=closed');
    });

    it('writes panel=open when panels are expanded without active filters', () => {
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
          filtersExpanded: true,
          activityTypesExpanded: true,
          equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
        });
      });

      expect(window.location.search).toContain('propertiesPanel=open');
      expect(window.location.search).toContain('typesPanel=open');
      expect(window.location.search).toContain('gearPanel=open');
    });

    it('uses replaceState for panel-only changes', () => {
      const { result } = renderHook(() => useUrlFilters());
      const pushSpy = vi.spyOn(window.history, 'pushState');
      const replaceSpy = vi.spyOn(window.history, 'replaceState');

      // Set some filters first (pushState)
      act(() => {
        result.current[1]({
          ...result.current[0],
          query: 'test',
        });
      });
      expect(pushSpy).toHaveBeenCalledTimes(1);
      pushSpy.mockClear();
      replaceSpy.mockClear();

      // Toggle panel only (replaceState)
      act(() => {
        result.current[1]({
          ...result.current[0],
          filtersExpanded: !result.current[0].filtersExpanded,
        });
      });
      expect(replaceSpy).toHaveBeenCalledTimes(1);
      expect(pushSpy).not.toHaveBeenCalled();
    });

    it('uses pushState for filter changes', () => {
      const { result } = renderHook(() => useUrlFilters());
      const pushSpy = vi.spyOn(window.history, 'pushState');
      const replaceSpy = vi.spyOn(window.history, 'replaceState');

      act(() => {
        result.current[1]({
          ...result.current[0],
          query: 'morning run',
        });
      });
      expect(pushSpy).toHaveBeenCalledTimes(1);
      expect(replaceSpy).not.toHaveBeenCalled();
    });

    it('omits panel params when expanded panels have active filters', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          query: '',
          activityTypes: ['Run'],
          gearIds: ['b123'],
          noEquipment: false,
          dateFrom: '2024-01-01',
          dateTo: null,
          distanceFrom: null,
          distanceTo: null,
          elevationFrom: null,
          elevationTo: null,
          filtersExpanded: true,
          activityTypesExpanded: true,
          equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
        });
      });

      expect(window.location.search).not.toContain('propertiesPanel');
      expect(window.location.search).not.toContain('typesPanel');
      expect(window.location.search).not.toContain('gearPanel');
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
          filtersExpanded: true,
          activityTypesExpanded: false,
            equipmentExpanded: false,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'commute',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
        });
      });

      expect(window.location.search).toBe('?commute=commute');
    });

    it('updates URL with trainer filter', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          ...result.current[0],
          trainerFilter: 'trainer',
          filtersExpanded: true,
        });
      });

      expect(window.location.search).toContain('trainer=trainer');
    });

    it('updates URL with muted filter', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          ...result.current[0],
          mutedFilter: 'muted',
          filtersExpanded: true,
        });
      });

      expect(window.location.search).toContain('muted=muted');
    });

    it('updates URL with photo filter', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          ...result.current[0],
          photoFilter: 'has_photo',
          filtersExpanded: true,
        });
      });

      expect(window.location.search).toContain('photo=has_photo');
    });

    it('updates URL with private filter', () => {
      const { result } = renderHook(() => useUrlFilters());

      act(() => {
        result.current[1]({
          ...result.current[0],
          privateFilter: 'private',
          filtersExpanded: true,
        });
      });

      expect(window.location.search).toContain('private=private');
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: 20,
          sufferScoreTo: 100,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: 5,
          kudosTo: 50,
          page: 1,
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
          filtersExpanded: false,
          activityTypesExpanded: false,
            equipmentExpanded: false,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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
          filtersExpanded: true,
          activityTypesExpanded: true,
            equipmentExpanded: true,
          mutedFilter: 'all',
          photoFilter: 'all',
          privateFilter: 'all',
          commuteFilter: 'all',
          trainerFilter: 'all',
          sufferScoreFrom: null,
          sufferScoreTo: null,
          kudosFrom: null,
          kudosTo: null,
          country: null,
          region: null,
          city: null,
          page: 1,
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

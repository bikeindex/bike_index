import React, { useState, useEffect, useCallback } from 'react';
import type { SearchFilters, MutedFilter, PhotoFilter, PrivateFilter, CommuteFilter } from '../types/strava';

function filtersToParams(filters: SearchFilters): URLSearchParams {
  const params = new URLSearchParams();

  if (filters.query) {
    params.set('q', filters.query);
  }
  if (filters.activityTypes.length > 0) {
    params.set('types', filters.activityTypes.join(','));
  }
  if (filters.gearIds.length > 0) {
    params.set('gear', filters.gearIds.join(','));
  }
  if (filters.noEquipment) {
    params.set('noGear', '1');
  }
  if (filters.dateFrom) {
    params.set('from', filters.dateFrom);
  }
  if (filters.dateTo) {
    params.set('to', filters.dateTo);
  }
  if (filters.distanceFrom !== null && filters.distanceFrom !== undefined) {
    params.set('distFrom', filters.distanceFrom.toString());
  }
  if (filters.distanceTo !== null && filters.distanceTo !== undefined) {
    params.set('distTo', filters.distanceTo.toString());
  }
  if (filters.elevationFrom !== null && filters.elevationFrom !== undefined) {
    params.set('elevFrom', filters.elevationFrom.toString());
  }
  if (filters.elevationTo !== null && filters.elevationTo !== undefined) {
    params.set('elevTo', filters.elevationTo.toString());
  }
  if (!filters.activityTypesExpanded) {
    params.set('typesClosed', '1');
  }
  if (!filters.equipmentExpanded) {
    params.set('gearClosed', '1');
  }
  if (filters.mutedFilter && filters.mutedFilter !== 'all') {
    params.set('muted', filters.mutedFilter);
  }
  if (filters.photoFilter && filters.photoFilter !== 'all') {
    params.set('photo', filters.photoFilter);
  }
  if (filters.privateFilter && filters.privateFilter !== 'all') {
    params.set('private', filters.privateFilter);
  }
  if (filters.commuteFilter && filters.commuteFilter !== 'all') {
    params.set('commute', filters.commuteFilter);
  }
  if (filters.sufferScoreFrom !== null && filters.sufferScoreFrom !== undefined) {
    params.set('sufferFrom', filters.sufferScoreFrom.toString());
  }
  if (filters.sufferScoreTo !== null && filters.sufferScoreTo !== undefined) {
    params.set('sufferTo', filters.sufferScoreTo.toString());
  }
  if (filters.kudosFrom !== null && filters.kudosFrom !== undefined) {
    params.set('kudosFrom', filters.kudosFrom.toString());
  }
  if (filters.kudosTo !== null && filters.kudosTo !== undefined) {
    params.set('kudosTo', filters.kudosTo.toString());
  }
  if (filters.page > 1) {
    params.set('page', filters.page.toString());
  }
  if (filters.filtersCollapsed) {
    params.set('collapsed', '1');
  }

  return params;
}

function paramsToFilters(params: URLSearchParams): SearchFilters {
  const distFromStr = params.get('distFrom');
  const distToStr = params.get('distTo');
  const elevFromStr = params.get('elevFrom');
  const elevToStr = params.get('elevTo');
  const sufferFromStr = params.get('sufferFrom');
  const sufferToStr = params.get('sufferTo');
  const kudosFromStr = params.get('kudosFrom');
  const kudosToStr = params.get('kudosTo');
  return {
    query: params.get('q') || '',
    activityTypes: params.get('types')?.split(',').filter(Boolean) || [],
    gearIds: params.get('gear')?.split(',').filter(Boolean) || [],
    noEquipment: params.get('noGear') === '1',
    dateFrom: params.get('from') || null,
    dateTo: params.get('to') || null,
    distanceFrom: distFromStr ? parseFloat(distFromStr) : null,
    distanceTo: distToStr ? parseFloat(distToStr) : null,
    elevationFrom: elevFromStr ? parseFloat(elevFromStr) : null,
    elevationTo: elevToStr ? parseFloat(elevToStr) : null,
    activityTypesExpanded: params.get('typesClosed') !== '1',
    equipmentExpanded: params.get('gearClosed') !== '1',
    mutedFilter: (params.get('muted') as MutedFilter) || 'all',
    photoFilter: (params.get('photo') as PhotoFilter) || 'all',
    privateFilter: (params.get('private') as PrivateFilter) || 'all',
    commuteFilter: (params.get('commute') as CommuteFilter) || 'all',
    sufferScoreFrom: sufferFromStr ? parseFloat(sufferFromStr) : null,
    sufferScoreTo: sufferToStr ? parseFloat(sufferToStr) : null,
    kudosFrom: kudosFromStr ? parseFloat(kudosFromStr) : null,
    kudosTo: kudosToStr ? parseFloat(kudosToStr) : null,
    page: parseInt(params.get('page') || '1', 10),
    filtersCollapsed: params.get('collapsed') === '1',
  };
}

export function useUrlFilters(): [SearchFilters, React.Dispatch<React.SetStateAction<SearchFilters>>] {
  // Initialize from URL
  const [filters, setFiltersState] = useState<SearchFilters>(() => {
    const params = new URLSearchParams(window.location.search);
    return paramsToFilters(params);
  });

  // Update URL when filters change
  const setFilters = useCallback((newFilters: SearchFilters | ((prev: SearchFilters) => SearchFilters)) => {
    setFiltersState((prev) => {
      const resolved = typeof newFilters === 'function' ? newFilters(prev) : newFilters;

      // Update URL
      const params = filtersToParams(resolved);
      const newUrl = params.toString()
        ? `${window.location.pathname}?${params.toString()}`
        : window.location.pathname;

      window.history.pushState({ filters: resolved }, '', newUrl);

      return resolved;
    });
  }, []);

  // Handle browser back/forward
  useEffect(() => {
    const handlePopState = (event: PopStateEvent) => {
      if (event.state?.filters) {
        setFiltersState(event.state.filters);
      } else {
        // Parse from URL if no state
        const params = new URLSearchParams(window.location.search);
        setFiltersState(paramsToFilters(params));
      }
    };

    window.addEventListener('popstate', handlePopState);

    // Store initial state
    const params = new URLSearchParams(window.location.search);
    const initialFilters = paramsToFilters(params);
    window.history.replaceState({ filters: initialFilters }, '', window.location.href);

    return () => {
      window.removeEventListener('popstate', handlePopState);
    };
  }, []);

  return [filters, setFilters];
}

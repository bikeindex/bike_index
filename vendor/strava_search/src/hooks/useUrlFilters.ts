import React, { useState, useEffect, useCallback } from 'react';
import type { SearchFilters, MutedFilter, PhotoFilter, PrivateFilter, CommuteFilter, TrainerFilter } from '../types/strava';

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
  // Only write panel state when it differs from default (auto-open with filters, closed without)
  if (filters.filtersExpanded && !hasPropertyFilters(filters)) {
    params.set('propertiesPanel', 'open');
  } else if (!filters.filtersExpanded && hasPropertyFilters(filters)) {
    params.set('propertiesPanel', 'closed');
  }
  if (filters.activityTypesExpanded && filters.activityTypes.length === 0) {
    params.set('typesPanel', 'open');
  } else if (!filters.activityTypesExpanded && filters.activityTypes.length > 0) {
    params.set('typesPanel', 'closed');
  }
  if (filters.equipmentExpanded && !filters.gearIds.length && !filters.noEquipment) {
    params.set('gearPanel', 'open');
  } else if (!filters.equipmentExpanded && (filters.gearIds.length > 0 || filters.noEquipment)) {
    params.set('gearPanel', 'closed');
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
  if (filters.trainerFilter && filters.trainerFilter !== 'all') {
    params.set('trainer', filters.trainerFilter);
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
  if (filters.country) {
    params.set('country', filters.country);
  }
  if (filters.region) {
    params.set('region', filters.region);
  }
  if (filters.city) {
    params.set('city', filters.city);
  }
  if (filters.page > 1) {
    params.set('page', filters.page.toString());
  }

  return params;
}

function hasPropertyFilters(filters: SearchFilters): boolean {
  return !!(
    filters.dateFrom || filters.dateTo ||
    filters.distanceFrom !== null || filters.distanceTo !== null ||
    filters.elevationFrom !== null || filters.elevationTo !== null ||
    (filters.mutedFilter !== 'all') || (filters.photoFilter !== 'all') ||
    (filters.privateFilter !== 'all') || (filters.commuteFilter !== 'all') ||
    (filters.trainerFilter !== 'all') ||
    filters.sufferScoreFrom !== null || filters.sufferScoreTo !== null ||
    filters.kudosFrom !== null || filters.kudosTo !== null ||
    filters.country || filters.region || filters.city
  );
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

  // Auto-expand panels when they have active filters, unless explicitly closed
  const hasTypes = !!params.get('types');
  const hasGear = !!(params.get('gear') || params.get('noGear'));
  const hasProps = !!(
    params.get('from') || params.get('to') ||
    distFromStr || distToStr || elevFromStr || elevToStr ||
    params.get('muted') || params.get('photo') || params.get('private') ||
    params.get('commute') || params.get('trainer') ||
    sufferFromStr || sufferToStr || kudosFromStr || kudosToStr ||
    params.get('country') || params.get('region') || params.get('city')
  );

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
    filtersExpanded: params.get('propertiesPanel') !== 'closed' && (hasProps || params.get('propertiesPanel') === 'open'),
    activityTypesExpanded: params.get('typesPanel') !== 'closed' && (hasTypes || params.get('typesPanel') === 'open'),
    equipmentExpanded: params.get('gearPanel') !== 'closed' && (hasGear || params.get('gearPanel') === 'open'),
    mutedFilter: (params.get('muted') as MutedFilter) || 'all',
    photoFilter: (params.get('photo') as PhotoFilter) || 'all',
    privateFilter: (params.get('private') as PrivateFilter) || 'all',
    commuteFilter: (params.get('commute') as CommuteFilter) || 'all',
    trainerFilter: (params.get('trainer') as TrainerFilter) || 'all',
    sufferScoreFrom: sufferFromStr ? parseFloat(sufferFromStr) : null,
    sufferScoreTo: sufferToStr ? parseFloat(sufferToStr) : null,
    kudosFrom: kudosFromStr ? parseFloat(kudosFromStr) : null,
    kudosTo: kudosToStr ? parseFloat(kudosToStr) : null,
    country: params.get('country') || null,
    region: params.get('region') || null,
    city: params.get('city') || null,
    page: parseInt(params.get('page') || '1', 10),
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

      // Use replaceState for panel-only changes to avoid polluting history
      const panelOnly = prev.query === resolved.query &&
        prev.activityTypes.join(',') === resolved.activityTypes.join(',') &&
        prev.gearIds.join(',') === resolved.gearIds.join(',') &&
        prev.noEquipment === resolved.noEquipment &&
        prev.dateFrom === resolved.dateFrom && prev.dateTo === resolved.dateTo &&
        prev.distanceFrom === resolved.distanceFrom && prev.distanceTo === resolved.distanceTo &&
        prev.elevationFrom === resolved.elevationFrom && prev.elevationTo === resolved.elevationTo &&
        prev.mutedFilter === resolved.mutedFilter && prev.photoFilter === resolved.photoFilter &&
        prev.privateFilter === resolved.privateFilter && prev.commuteFilter === resolved.commuteFilter &&
        prev.trainerFilter === resolved.trainerFilter &&
        prev.sufferScoreFrom === resolved.sufferScoreFrom && prev.sufferScoreTo === resolved.sufferScoreTo &&
        prev.kudosFrom === resolved.kudosFrom && prev.kudosTo === resolved.kudosTo &&
        prev.country === resolved.country && prev.region === resolved.region && prev.city === resolved.city &&
        prev.page === resolved.page;

      if (panelOnly) {
        window.history.replaceState({ filters: resolved }, '', newUrl);
      } else {
        window.history.pushState({ filters: resolved }, '', newUrl);
      }

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

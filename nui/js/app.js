/* ari_garage — NUI app.js  v1.16.1-ari */

(function () {
  'use strict';

  const DEFAULT_ACCENT = '#A855F7';

  let state = {
    tab: 'garage',
    garageVehicles: [],
    impoundedVehicles: [],
    renderedVehicles: [],
    spawnPoint: null,
    poundName: null,
    poundSpawnPoint: null,
    locales: {},
    animateCards: true,
    showFuel: false,
    menuType: 'garage',
    defaultPoundCost: 0,
    freeRelease: false,
  };

  const overlay = document.getElementById('overlay');
  const garageLabel = document.getElementById('garage-label');
  const contentTitle = document.getElementById('content-title');
  const topbarSubtitle = document.getElementById('topbar-subtitle');
  const tabImpounded = document.getElementById('tab-impounded');
  const badgeGarage = document.getElementById('badge-garage');
  const badgeImpounded = document.getElementById('badge-impounded');
  const vehicleGrid = document.getElementById('vehicle-grid');
  const emptyState = document.getElementById('empty-state');
  const emptyMsg = document.getElementById('empty-msg');
  const searchInput = document.getElementById('search-input');
  const btnClose = document.getElementById('btn-close');
  const scrollHint = document.getElementById('scroll-hint');

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function escapeHtml(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function formatCurrency(value) {
    return `$${Number(value || 0).toLocaleString('en-US')}`;
  }

  function conditionClass(percent) {
    if (percent >= 70) return 'good';
    if (percent >= 35) return 'ok';
    return 'bad';
  }

  function calcCondition(props) {
    const data = props || {};
    const body = typeof data.bodyHealth === 'number' ? data.bodyHealth : 1000;
    const engine = typeof data.engineHealth === 'number' ? data.engineHealth : 1000;
    const tank = typeof data.tankHealth === 'number' ? data.tankHealth : 1000;
    const bodyPct = clamp((body / 1000) * 100, 0, 100);
    const enginePct = clamp((engine / 1000) * 100, 0, 100);
    const tankPct = clamp((tank / 1000) * 100, 0, 100);

    return clamp(Math.round((bodyPct + enginePct + tankPct) / 3), 0, 100);
  }

  function post(endpoint, payload) {
    const resource = typeof GetParentResourceName !== 'undefined' ? GetParentResourceName() : 'ari_garage';
    return fetch(`https://${resource}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    });
  }

  function refreshIcons() {
    if (typeof lucide !== 'undefined' && lucide.createIcons) {
      lucide.createIcons();
    }
  }

  function getStateLabel(vehicle) {
    const loc = state.locales;
    if (vehicle.state === 'impounded') return loc.state_impound || 'Impounded';
    if (vehicle.state === 'out') return loc.state_out || 'Out';
    return loc.state_garage || 'Stored';
  }

  function getTabTitle(tab) {
    return tab === 'impounded' ? 'Impounded' : 'Garage';
  }

  function getActionLabel(type, vehicle) {
    const loc = state.locales;
    if (type === 'impounded') {
      if (vehicle.state === 'out') {
        if (state.menuType === 'garage') {
          return loc.action || loc.veh_exit || 'Retrieve';
        }
        return loc.out_action || 'Outside';
      }

      if (state.menuType === 'garage') {
        return loc.pay_impound || 'Pay & Release';
      }

      return state.menuType === 'impound'
        ? (loc.pay_impound || 'Pay & Release')
        : (loc.locate_impound || 'Mark impound');
    }

    return loc.action || loc.veh_exit || 'Retrieve';
  }

  function buildStatCells(vehicle, condition) {
    const loc = state.locales;
    const cells = [
      `<div class="stat-cell"><span>${escapeHtml(loc.state_label || 'State')}</span><strong>${escapeHtml(getStateLabel(vehicle))}</strong></div>`,
      `<div class="stat-cell"><span>${escapeHtml(loc.veh_condition || 'Condition')}</span><strong>${condition}%</strong></div>`,
    ];

    if (vehicle.state === 'impounded') {
      const costLabel = vehicle.releaseFree
        ? (loc.free_release || 'Free release')
        : formatCurrency(vehicle.releaseCost);
      cells.push(`<div class="stat-cell accent"><span>${escapeHtml(loc.release_cost || 'Release')}</span><strong>${escapeHtml(costLabel)}</strong></div>`);
    }

    const colsClass = cells.length === 2 ? ' cols-2' : '';
    return `<div class="vcard-stats${colsClass}">${cells.join('')}</div>`;
  }

  function buildMetrics(vehicle, condition, conditionState) {
    const loc = state.locales;
    const blocks = [
      `<div class="metric-block">
        <div class="metric-row">
          <span>${escapeHtml(loc.veh_condition || 'Condition')}</span>
          <strong>${condition}%</strong>
        </div>
        <div class="progress-track">
          <div class="progress-fill ${conditionState}" style="width:${condition}%"></div>
        </div>
      </div>`,
    ];

    if (state.showFuel && vehicle.props && typeof vehicle.props.fuelLevel === 'number') {
      const fuelPct = clamp(Math.round(vehicle.props.fuelLevel), 0, 100);
      blocks.push(`<div class="metric-block">
        <div class="metric-row">
          <span>${escapeHtml(loc.fuel || 'Fuel')}</span>
          <strong>${fuelPct}%</strong>
        </div>
        <div class="progress-track">
          <div class="progress-fill fuel" style="width:${fuelPct}%"></div>
        </div>
      </div>`);
    }

    return `<div class="vcard-metrics">${blocks.join('')}</div>`;
  }

  function buildActionButton(type, vehicle, index) {
    const label = escapeHtml(getActionLabel(type, vehicle));
    const idx = Number(index);

    if (type === 'impounded') {
      if (vehicle.state === 'out') {
        if (state.menuType === 'garage') {
          return `<button type="button" class="btn-action btn-primary vcard-spawn-btn" data-index="${idx}">
            <i data-lucide="arrow-right" aria-hidden="true"></i>${label}
          </button>`;
        }
        return `<button type="button" class="btn-action btn-disabled" disabled>
            <i data-lucide="ban" aria-hidden="true"></i>${label}
          </button>`;
      }

      if (vehicle.state === 'impounded' && state.menuType === 'garage') {
        return `<button type="button" class="btn-action btn-primary vcard-spawn-btn" data-index="${idx}">
          <i data-lucide="arrow-right" aria-hidden="true"></i>${label}
        </button>`;
      }

      return `<button type="button" class="btn-action btn-secondary vcard-impound-btn"
          data-index="${idx}"
          data-mode="${state.menuType === 'impound' ? 'release' : 'track'}">
          <i data-lucide="map-pin" aria-hidden="true"></i>${label}
        </button>`;
    }

    return `<button type="button" class="btn-action btn-primary vcard-spawn-btn" data-index="${idx}">
      <i data-lucide="arrow-right" aria-hidden="true"></i>${label}
    </button>`;
  }

  function buildCard(vehicle, type, index, listMode) {
    const condition = calcCondition(vehicle.props);
    const conditionState = conditionClass(condition);
    const delay = state.animateCards ? `animation-delay:${Math.min(index, 12) * 35}ms` : '';
    const listClass = listMode ? ' vcard-list' : '';
    const hasFuel = state.showFuel && vehicle.props && typeof vehicle.props.fuelLevel === 'number';
    const fuelClass = hasFuel ? ' has-fuel' : '';

    return `
      <article class="vcard${state.animateCards ? ' animate-in' : ''}${listClass}${fuelClass}" style="${delay}"
        data-model="${escapeHtml((vehicle.model || '').toLowerCase())}"
        data-plate="${escapeHtml((vehicle.plate || '').toLowerCase())}">
        <div class="vcard-orb"></div>
        <header class="vcard-header">
          <div>
            <span class="vcard-kicker">vehicle</span>
            <h3 class="vcard-model">${escapeHtml(vehicle.model || 'Unknown')}</h3>
          </div>
          <span class="vcard-plate">${escapeHtml(vehicle.plate || '—')}</span>
        </header>
        <div class="vcard-content">
          ${buildStatCells(vehicle, condition)}
          ${buildMetrics(vehicle, condition, conditionState)}
        </div>
        <footer class="vcard-footer">${buildActionButton(type, vehicle, index)}</footer>
      </article>`;
  }

  function updateScrollHint(count, listMode) {
    if (!scrollHint) return;
    const show = count > 4;
    scrollHint.classList.toggle('hidden', !show);
    if (show) {
      const hint = state.locales.scroll_hint || `${count} vehicles — scroll to see all`;
      scrollHint.textContent = listMode ? `↑ ${hint} (compact view) ↑` : `↑ ${hint} ↑`;
    }
  }

  function renderGrid() {
    const query = searchInput.value.trim().toLowerCase();
    const list = state.tab === 'impounded' ? state.impoundedVehicles : state.garageVehicles;
    const type = state.tab === 'impounded' ? 'impounded' : 'garage';
    const loc = state.locales;

    const filtered = list.filter((vehicle) => {
      if (!query) return true;
      return (vehicle.model || '').toLowerCase().includes(query)
        || (vehicle.plate || '').toLowerCase().includes(query);
    });

    state.renderedVehicles = filtered.map((vehicle) => ({
      ...vehicle,
      props: vehicle.props ? { ...vehicle.props } : {},
    }));

    const listMode = filtered.length > 5;
    vehicleGrid.innerHTML = filtered.map((vehicle, index) => buildCard(vehicle, type, index, listMode)).join('');

    const isEmpty = filtered.length === 0;
    emptyState.classList.toggle('hidden', !isEmpty);
    vehicleGrid.classList.toggle('list-mode', listMode);
    updateScrollHint(filtered.length, listMode);
    refreshIcons();

    if (!isEmpty) {
      return;
    }

    if (list.length === 0) {
      emptyMsg.textContent = state.tab === 'impounded'
        ? (loc.no_veh_impounded || 'No impounded vehicles.')
        : (loc.no_veh_parking || 'No vehicles stored here.');
      return;
    }

    emptyMsg.textContent = query
      ? `${loc.no_results || 'No results.'} "${query}"`
      : (loc.no_results || 'No results.');
  }

  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.nav-btn').forEach((button) => {
      button.classList.toggle('active', button.dataset.tab === tab);
    });
    contentTitle.textContent = getTabTitle(tab);
    if (topbarSubtitle) {
      topbarSubtitle.textContent = tab === 'impounded'
        ? (state.locales.impound_subtitle || 'Pay fees or track impounded vehicles')
        : (state.locales.garage_subtitle || 'Select a vehicle to retrieve');
    }
    searchInput.value = '';
    renderGrid();
  }

  function applyAccentColor(color) {
    const hex = (color || DEFAULT_ACCENT).replace('#', '');
    if (hex.length !== 6) {
      return;
    }

    const red = parseInt(hex.slice(0, 2), 16);
    const green = parseInt(hex.slice(2, 4), 16);
    const blue = parseInt(hex.slice(4, 6), 16);

    document.documentElement.style.setProperty('--accent', `#${hex}`);
    document.documentElement.style.setProperty('--accent-dim', `rgba(${red},${green},${blue},0.18)`);
    document.documentElement.style.setProperty('--accent-soft', `rgba(${red},${green},${blue},0.10)`);
    document.documentElement.style.setProperty('--accent-glow', `rgba(${red},${green},${blue},0.42)`);
  }

  function getSpawnPayload(vehicle) {
    const needPay = vehicle.state === 'impounded' && !vehicle.releaseFree && state.menuType === 'garage';
    const fee = needPay ? Number(vehicle.releaseCost || state.defaultPoundCost || 0) : 0;

    return {
      vehicleProps: vehicle.props,
      plate: vehicle.plate || vehicle.props?.plate || '',
      spawnPoint: state.spawnPoint,
      exitVehicleCost: fee,
      poundName: state.poundName,
      requireImpoundPay: needPay,
      impoundPound: vehicle.pound || '',
    };
  }

  function showMenu(data) {
    state.locales = data.locales || {};
    state.spawnPoint = data.spawnPoint || null;
    state.poundName = data.poundName || null;
    state.poundSpawnPoint = data.poundSpawnPoint || null;
    state.menuType = data.menuType || 'garage';
    state.animateCards = data.animateCards !== false;
    state.showFuel = data.showFuel === true;
    state.defaultPoundCost = data.poundCost || 0;
    state.freeRelease = data.freeRelease === true;

    applyAccentColor(data.accentColor);
    garageLabel.textContent = data.garageLabel || '';

    state.garageVehicles = data.vehiclesList ? JSON.parse(data.vehiclesList) : [];
    state.impoundedVehicles = data.vehiclesImpoundedList ? JSON.parse(data.vehiclesImpoundedList) : [];

    badgeGarage.textContent = state.garageVehicles.length;
    badgeImpounded.textContent = state.impoundedVehicles.length;
    tabImpounded.style.display = state.menuType === 'impound' ? 'none' : '';

    switchTab('garage');
    overlay.classList.remove('hidden');
    refreshIcons();
    searchInput.focus();
  }

  function bootPreviewMode() {
    const isPreview = window.location.protocol === 'file:' && window.location.search.includes('preview=1');
    if (!isPreview) {
      return;
    }

    const many = [];
    for (let i = 1; i <= 8; i += 1) {
      many.push({
        model: `Preview Car ${i}`,
        plate: `ARI ${String(i).padStart(3, '0')}`,
        state: 'stored',
        props: { bodyHealth: 900, engineHealth: 820, tankHealth: 1000, fuelLevel: 76, plate: `ARI${i}` },
      });
    }

    showMenu({
      action: 'show',
      menuType: 'garage',
      garageLabel: 'Preview Garage',
      accentColor: DEFAULT_ACCENT,
      animateCards: true,
      showFuel: true,
      poundName: 'LosSantos',
      poundSpawnPoint: { x: 400.7, y: -1630.5 },
      spawnPoint: { x: 0, y: 0, z: 0, heading: 0 },
      locales: {
        action: 'Retrieve Vehicle',
        scroll_hint: 'Scroll to see all vehicles',
        veh_condition: 'Condition',
        no_veh_parking: 'No vehicles stored here.',
        fuel: 'Fuel',
        state_label: 'State',
        state_garage: 'Stored',
        garage_subtitle: 'Select a vehicle to retrieve',
      },
      vehiclesList: JSON.stringify(many),
      vehiclesImpoundedList: JSON.stringify([]),
    });
  }

  function hideVisual() {
    overlay.classList.add('hidden');
  }

  function hideMenu() {
    overlay.classList.add('hidden');
    post('escape', {});
  }

  btnClose.addEventListener('click', hideMenu);

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      hideMenu();
    }
  });

  searchInput.addEventListener('input', renderGrid);

  document.querySelectorAll('.nav-btn').forEach((button) => {
    button.addEventListener('click', () => switchTab(button.dataset.tab));
  });

  vehicleGrid.addEventListener('click', (event) => {
    const spawnButton = event.target.closest('.vcard-spawn-btn');
    if (spawnButton) {
      const index = Number(spawnButton.dataset.index);
      const vehicle = state.renderedVehicles[index];
      if (!vehicle) return;

      post('spawnVehicle', getSpawnPayload(vehicle));
      hideVisual();
      return;
    }

    const impoundButton = event.target.closest('.vcard-impound-btn');
    if (impoundButton) {
      const index = Number(impoundButton.dataset.index);
      const vehicle = state.renderedVehicles[index];
      if (!vehicle) return;

      post('impound', {
        mode: impoundButton.dataset.mode,
        vehicleProps: vehicle.props,
        poundName: state.poundName,
        poundSpawnPoint: state.poundSpawnPoint,
      });
      hideVisual();
    }
  });

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) {
      return;
    }

    if (data.action === 'show') {
      showMenu(data);
    } else if (data.action === 'hide') {
      overlay.classList.add('hidden');
    }
  });

  refreshIcons();
  bootPreviewMode();
})();
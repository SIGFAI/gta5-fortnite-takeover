// Fortnite guest HUD (lib/nui/guest.js) for cl_fn.lua (Fn.Hud(true)): health/shield, hotbar, materials, counters, kill feed, Victory Royale.
(() => {
  const root = document.getElementById('guest');
  root.innerHTML = `
    <div class="counters"><span class="alive">👤 0</span><span class="elims">☠ 0</span><span class="storm hidden">⛈ 0:00</span></div>
    <div class="feed"></div>
    <div class="bars"><div class="bar shield"><i></i><b>0</b></div><div class="bar hp"><i></i><b>100</b></div></div>
    <div class="hotbar"></div>
    <div class="mats"><div class="mat wood"><span class="n">0</span><i></i></div><div class="mat brick"><span class="n">0</span><i></i></div><div class="mat metal"><span class="n">0</span><i></i></div></div>`;
  const $ = (s) => root.querySelector(s);
  const slots = [1, 2, 3, 4, 5].map(() => $('.hotbar').appendChild(Object.assign(document.createElement('div'), { className: 'slot' })));
  const H = window.sigfHandlers;
  const fmt = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  // Slots arrive as a list of { i, name, hex } (cl_fn.lua push).
  const slotOf = (slots, i) => (Array.isArray(slots) ? slots : []).find((s) => s.i === i);

  H.fnshow = (m) => root.classList.toggle('hidden', !m.on);
  H.fn = (m) => {
    $('.bar.shield i').style.width = `${m.shield}%`;
    $('.bar.shield b').textContent = m.shield;
    $('.bar.hp i').style.width = `${m.hp}%`;
    $('.bar.hp b').textContent = m.hp;
    $('.alive').textContent = `👤 ${m.alive}`;
    $('.elims').textContent = `☠ ${m.elims}`;
    for (const k of ['wood', 'brick', 'metal']) {
      const el = root.querySelector(`.mat.${k}`);
      el.querySelector('.n').textContent = (m.mats || {})[k] ?? 0;
      el.classList.toggle('sel', m.mat === k);
    }
    if (m.matPop) {
      const el = root.querySelector(`.mat.${m.matPop}`);
      const p = document.createElement('span');
      p.className = 'pop';
      p.textContent = (m.matDelta > 0 ? '+' : '') + m.matDelta;
      el.prepend(p);
      setTimeout(() => p.remove(), 800);
    }
    slots.forEach((d, k) => {
      const i = k + 1, s = slotOf(m.slots, i);
      d.classList.toggle('on', m.slot === i);
      const bg = s ? `linear-gradient(160deg, ${s.hex}, rgba(0,0,0,.55))` : '';
      if (d.style.background !== bg) d.style.background = bg;
      if (d.textContent !== (s ? s.name : '')) d.textContent = s ? s.name : '';
    });
  };
  H.fnstorm = (m) => {
    const el = $('.storm');
    el.classList.toggle('hidden', m.left < 0);
    if (m.left >= 0) { el.textContent = `⛈ ${fmt(m.left)}`; el.classList.toggle('warn', m.left <= 10); }
  };
  H.fnfeed = (m) => {
    const d = document.createElement('div');
    if (m.killer === 'You') d.className = 'you';
    d.textContent = `${m.killer} eliminated ${m.victim}${m.weapon ? ' with ' + m.weapon : ''}`;
    $('.feed').prepend(d);
    setTimeout(() => d.remove(), 6000);
  };
  H.fnelim = (m) => {
    const d = document.createElement('div');
    d.className = 'elim';
    d.innerHTML = '<b>ELIMINATED</b>';
    d.append(m.name);
    root.appendChild(d);
    setTimeout(() => d.remove(), 2500);
  };
  H.fnpickup = (m) => {
    const d = document.createElement('div');
    d.className = 'pickup';
    d.style.background = `linear-gradient(90deg, ${m.hex}, rgba(0,0,0,.5))`;
    d.textContent = m.name;
    root.appendChild(d);
    setTimeout(() => d.remove(), 2200);
  };
  H.fnvictory = (m) => {
    root.classList.remove('hidden');
    const d = document.createElement('div');
    d.className = 'victory';
    d.innerHTML = '<div class="one">#1</div><div class="title"></div><div class="sub"></div>';
    d.querySelector('.title').textContent = m.title;
    d.querySelector('.sub').textContent = m.sub || '';
    root.appendChild(d);
    setTimeout(() => d.remove(), 9000);
  };
})();

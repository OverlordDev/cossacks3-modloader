(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var store = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };

  // ---- тема: по умолчанию тёмная «Amber Docs», светлая — «бумага»
  var root = document.documentElement;
  var saved = store.get('cs3-theme');
  if (saved === 'light') root.setAttribute('data-theme', 'light');
  var themeBtn = $('#theme');
  function paintTheme() { if (themeBtn) themeBtn.textContent = root.getAttribute('data-theme') === 'light' ? '☾' : '☀'; }
  if (themeBtn) themeBtn.addEventListener('click', function () {
    var next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
    if (next === 'light') root.setAttribute('data-theme', 'light'); else root.removeAttribute('data-theme');
    store.set('cs3-theme', next); paintTheme();
  });
  paintTheme();

  // ---- мобильное меню
  var menuBtn = $('#menu'), side = $('.side');
  if (menuBtn && side) menuBtn.addEventListener('click', function () { side.classList.toggle('open'); });

  // ---- подсветка кода (Lua / JS / Pascal / patch — грубо, но достаточно)
  var KW = /^(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while|var|begin|const|const|await|async|let|new|null|undefined|typeof|class|switch|case|default|try|catch|finally|throw|import|export|from|of|this|procedure|shl|shr|xor|div|mod|Result|downto)$/;
  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function highlight(src, lang) {
    if (lang === 'html' || lang === 'text' || lang === 'json') return esc(src);
    var out = '', i = 0, n = src.length, lua = lang !== 'js' && lang !== 'javascript' && lang !== 'pascal' && lang !== 'patch';
    while (i < n) {
      var c = src[i], rest = src.slice(i, i + 2);
      if ((lua && rest === '--') || (!lua && rest === '//')) {
        var e = src.indexOf('\n', i); if (e < 0) e = n;
        out += '<span class="tk-c">' + esc(src.slice(i, e)) + '</span>'; i = e;
      } else if (c === '"' || c === "'" || (!lua && c === '`')) {
        var j = i + 1;
        while (j < n && src[j] !== c && src[j] !== '\n') j += src[j] === '\\' ? 2 : 1;
        out += '<span class="tk-s">' + esc(src.slice(i, j + 1)) + '</span>'; i = j + 1;
      } else if (/[0-9]/.test(c) && !/[\w]/.test(src[i - 1] || ' ')) {
        var m = /^(0x[0-9a-fA-F]+|\d+\.?\d*)/.exec(src.slice(i));
        out += '<span class="tk-n">' + m[0] + '</span>'; i += m[0].length;
      } else if (/[A-Za-z_]/.test(c)) {
        var w = /^[A-Za-z_]\w*/.exec(src.slice(i))[0];
        out += KW.test(w) ? '<span class="tk-k">' + w + '</span>' : esc(w); i += w.length;
      } else { out += esc(c); i++; }
    }
    return out;
  }
  $$('pre code').forEach(function (code) {
    var lang = code.getAttribute('data-lang') || 'lua';
    code.innerHTML = highlight(code.textContent, lang);
    var pre = code.parentNode, b = document.createElement('button');
    b.className = 'copy'; b.type = 'button'; b.textContent = 'COPY';
    b.addEventListener('click', function () {
      var text = code.textContent;
      var done = function () { b.textContent = 'OK ✓'; setTimeout(function () { b.textContent = 'COPY'; }, 1400); };
      if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, done); else done();
    });
    pre.appendChild(b);
  });

  // ---- аккордеоны и табы
  $$('.acc-head').forEach(function (h) {
    h.addEventListener('click', function () { h.parentNode.classList.toggle('open'); });
  });
  $$('.tabs').forEach(function (tabs) {
    var panes = $$('.tabpane', tabs.parentNode);
    $$('button', tabs).forEach(function (btn, i) {
      btn.addEventListener('click', function () {
        $$('button', tabs).forEach(function (b) { b.classList.remove('active'); });
        panes.forEach(function (p) { p.classList.remove('active'); });
        btn.classList.add('active'); if (panes[i]) panes[i].classList.add('active');
      });
    });
  });

  // ---- ссылка на якорь раскрывает аккордеон, в котором лежит цель
  function openTarget() {
    if (!location.hash) return;
    var el = document.getElementById(decodeURIComponent(location.hash.slice(1)));
    for (var p = el; p; p = p.parentNode) if (p.classList && p.classList.contains('acc')) p.classList.add('open');
  }
  window.addEventListener('hashchange', openTarget); openTarget();

  // ---- ripple на кнопках, стрелки
  $$('.btn').forEach(function (b) { b.innerHTML = b.innerHTML.replace(/→/g, '<span class="arr">→</span>'); });
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('.btn'); if (!b) return;
    var r = document.createElement('span'); r.className = 'ripple';
    var rc = b.getBoundingClientRect(), s = Math.max(rc.width, rc.height);
    r.style.width = r.style.height = s + 'px';
    r.style.left = (e.clientX - rc.left - s / 2) + 'px'; r.style.top = (e.clientY - rc.top - s / 2) + 'px';
    b.appendChild(r); setTimeout(function () { r.remove(); }, 600);
  });

  // ---- reveal и счётчики
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (x) { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } });
    }, { threshold: .08 });
    $$('.rv').forEach(function (el) { io.observe(el); });
    var cio = new IntersectionObserver(function (es) {
      es.forEach(function (x) {
        if (!x.isIntersecting) return; cio.unobserve(x.target);
        var el = x.target, end = +el.getAttribute('data-count'), t0 = performance.now();
        (function f(t) {
          var p = Math.min((t - t0) / 1100, 1);
          el.textContent = Math.round(end * (1 - Math.pow(1 - p, 3)));
          if (p < 1) requestAnimationFrame(f);
        })(t0);
      });
    }, { threshold: .4 });
    $$('.cnt').forEach(function (el) { cio.observe(el); });
  } else {
    $$('.rv').forEach(function (el) { el.classList.add('in'); });
    $$('.cnt').forEach(function (el) { el.textContent = el.getAttribute('data-count'); });
  }

  // ---- оглавление страницы + scrollspy
  var toc = $('#toc');
  if (toc) {
    var heads = $$('main h2[id], main h3[id]');
    if (heads.length < 2) toc.style.display = 'none';
    else {
      var links = heads.map(function (h) {
        var a = document.createElement('a');
        a.href = '#' + h.id; a.textContent = h.getAttribute('data-t') || h.textContent.replace(/#$/, '').trim();
        if (h.tagName === 'H3') a.className = 'l3';
        toc.appendChild(a); return a;
      });
      if ('IntersectionObserver' in window) {
        var spy = new IntersectionObserver(function (es) {
          es.forEach(function (x) {
            if (!x.isIntersecting) return;
            var i = heads.indexOf(x.target);
            links.forEach(function (l) { l.classList.remove('on'); }); links[i].classList.add('on');
          });
        }, { rootMargin: '0px 0px -75% 0px' });
        heads.forEach(function (h) { spy.observe(h); });
      }
    }
  }

  // ---- поиск
  var input = $('#q'), box = $('#results');
  var index = window.CS3_SEARCH || [];
  var current = -1, shown = [];
  function score(item, words) {
    var t = item.t.toLowerCase(), x = item.x, s = 0;
    for (var i = 0; i < words.length; i++) {
      var w = words[i], hit = false;
      if (t === w) { s += 100; hit = true; }
      else if (t.indexOf(w) === 0) { s += 60; hit = true; }
      else if (t.indexOf(w) >= 0) { s += 40; hit = true; }
      if (x.indexOf(w) >= 0) { s += 8; hit = true; }
      if (!hit) return 0;
    }
    return s + (item.k === 'fn' ? 5 : 0);
  }
  function render(list) {
    shown = list; current = -1;
    if (!list.length) { box.innerHTML = '<div class="none">' + esc((window.CS3_I18N && window.CS3_I18N.none) || 'Nothing found') + '</div>'; box.classList.add('show'); return; }
    box.innerHTML = list.map(function (r) {
      return '<a href="' + r.u + '"><b>' + esc(r.t) + '</b><small>' + esc(r.s) + (r.d ? ' — ' + esc(r.d) : '') + '</small></a>';
    }).join('');
    box.classList.add('show');
  }
  function run() {
    var q = input.value.trim().toLowerCase();
    if (!q) { box.classList.remove('show'); return; }
    var words = q.split(/\s+/);
    var res = index.map(function (it) { return { it: it, s: score(it, words) }; })
      .filter(function (r) { return r.s > 0; })
      .sort(function (a, b) { return b.s - a.s; }).slice(0, 12)
      .map(function (r) { return { t: r.it.t, s: r.it.s, d: r.it.d, u: r.it.u }; });
    render(res);
  }
  function move(d) {
    var items = $$('a', box); if (!items.length) return;
    if (current >= 0) items[current].classList.remove('sel');
    current = (current + d + items.length) % items.length;
    items[current].classList.add('sel'); items[current].scrollIntoView({ block: 'nearest' });
  }
  if (input && box) {
    input.addEventListener('input', run);
    input.addEventListener('focus', run);
    input.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
      else if (e.key === 'Enter') {
        var target = current >= 0 ? $$('a', box)[current] : $('a', box);
        if (target) location.href = target.getAttribute('href');
      } else if (e.key === 'Escape') { box.classList.remove('show'); input.blur(); }
    });
    document.addEventListener('click', function (e) {
      if (!e.target.closest('.search-wrap')) box.classList.remove('show');
    });
    document.addEventListener('keydown', function (e) {
      var typing = /^(INPUT|TEXTAREA)$/.test((document.activeElement || {}).tagName || '');
      if ((e.key === '/' && !typing) || ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k')) {
        e.preventDefault(); input.focus(); input.select();
      }
    });
  }
})();

// смена языка сохраняет якорь (#f-balance-set и т.п.)
(function () {
  var link = document.querySelector('a[hreflang]');
  if (link) link.addEventListener('click', function () { link.href = link.getAttribute('href').split('#')[0] + location.hash; });
})();

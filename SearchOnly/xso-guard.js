// 防滑门卫。
// 规则只有一条：内容页（一条笔记）只能是你自己点进去的。
// 网页自己换到另一条内容（往下滑到下一条、自动连播下一个），就退回刚才那一条，并告诉 app 拦下了一次。
// 只看网址、手指和点击，不读页面内容，不发任何请求。
// app 注入时在前面拼一行：`const XSO_GUARD_CONTENT = '<内容页网址路径的正则>';`
// （见 Config.contentPattern，括号里抓内容 id；拼法见 WKUserScript.guardScript）。改了门卫先跑 node tools/guard-test.mjs
(() => {
  if (window.__xsoGuardInstalled) return;
  window.__xsoGuardInstalled = true;

  const content = new RegExp(XSO_GUARD_CONTENT);
  // 点下去以后多久之内换页，都算是这一下点出来的（有的网站点完要先等接口回来才换网址）
  const TAP_WINDOW = 2500;
  // 页面刚打开的这几秒里网站自己改网址（换成标准写法、短链落地、av 号换 BV 号），算打开的一部分。
  // 整页打开本身已经过了关：是你点的、app 打开的，或者 app 那边的原生检查放行的
  const ARRIVAL_WINDOW = 3000;
  const loadedAt = Date.now();
  const post = (name, body) => { try { window.webkit?.messageHandlers?.[name]?.postMessage(body); } catch (e) {} };

  // ── 认出「点」：手指按下、没怎么移动就抬起，或者一次真实的点击、回车 ──
  // 手指一拖动（滑屏）就把「刚点过」作废：滑一下换到下一条，不能因为几秒前点过别的东西就放行
  let lastTap = 0, startX = 0, startY = 0, moved = false;
  const tapped = () => { lastTap = Date.now(); post('xsoTap', 1); };
  addEventListener('touchstart', (e) => {
    const t = e.touches[0];
    if (t) { startX = t.clientX; startY = t.clientY; }
    moved = false;
  }, { capture: true, passive: true });
  addEventListener('touchmove', (e) => {
    const t = e.touches[0];
    if (t && Math.hypot(t.clientX - startX, t.clientY - startY) > 12) { moved = true; lastTap = 0; }
  }, { capture: true, passive: true });
  addEventListener('touchend', (e) => { if (e.isTrusted && !moved) tapped(); }, { capture: true, passive: true });
  addEventListener('click', (e) => { if (e.isTrusted) tapped(); }, true);
  addEventListener('keydown', (e) => { if (e.isTrusted && e.key === 'Enter') tapped(); }, true);

  // app 自己发起的跳转（搜索、点底栏、打开链接）先把 window.__xsoNavOK 设成当前时间，也算「你选的」
  const chosen = (replaced) => {
    const now = Date.now();
    if (now - lastTap < TAP_WINDOW || now - (window.__xsoNavOK || 0) < TAP_WINDOW) return true;
    // 只有「替换网址」才看刚打开的那几秒：往历史里新加一条（换到下一条）不算改写
    return replaced && now - loadedAt < ARRIVAL_WINDOW;
  };

  /// 一个网址是哪一条内容：内容页返回它的 id（同一条内容不管网址怎么写、带什么参数都一样），别的页面返回 null。
  const contentKey = (href) => {
    try {
      const path = new URL(href, location.href).pathname.replace(/\/+$/, '');
      const match = path.match(content);
      if (!match) return null;
      const ids = match.slice(1).filter((id) => id !== undefined);
      return ids.length ? ids[ids.length - 1] : path;
    } catch (e) {
      return null;
    }
  };
  // 给 tools/guard-test.mjs 用：测试时把 contentKey 交出去。网页里没有这个函数，什么也不做
  if (typeof window.__xsoGuardExpose === 'function') window.__xsoGuardExpose({ contentKey });

  // 整页退回去以后，同一个地方 10 秒内不再整页退第二次：万一哪个网站打开以后还会自己改网址，最多刷一次，不会死循环
  const BOUNCE_KEY = 'xsoGuardBounce';
  const recentlyBounced = (href) => {
    try {
      const last = JSON.parse(sessionStorage.getItem(BOUNCE_KEY) || 'null');
      return last && last.href === href && Date.now() - last.at < 10000;
    } catch (e) {
      return false;
    }
  };
  const rememberBounce = (href) => {
    try { sessionStorage.setItem(BOUNCE_KEY, JSON.stringify({ href, at: Date.now() })); } catch (e) {}
  };

  // ── 单页网站换网址（不整页刷新）：在 pushState / replaceState 之后检查 ──
  let here = location.href;
  const check = (pushed) => {
    const before = here;
    here = location.href;
    const to = contentKey(here);
    if (!to || to === contentKey(before) || chosen(!pushed)) return;
    if (!pushed && recentlyBounced(before)) {
      // 刚为它整页退过一次，网站又改回来了：多半是网站自己的网址改写，不是换了一条。放行，免得一直刷新
      post('xsoGuardLoop', to);
      return;
    }
    post('xsoGuard', to);
    here = before;
    if (pushed) {
      // 新加了一条历史：退一步就回到刚才那条，页面不用重新加载
      history.back();
    } else {
      // 是替换掉的（没有历史可退）：整页回到刚才那条
      rememberBounce(before);
      location.replace(before);
    }
  };
  for (const name of ['pushState', 'replaceState']) {
    const original = history[name];
    history[name] = function (...args) {
      const result = original.apply(this, args);
      check(name === 'pushState');
      return result;
    };
  }
  // 返回、前进是你自己按的，照常
  addEventListener('popstate', () => { here = location.href; });
})();

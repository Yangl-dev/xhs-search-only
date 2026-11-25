// app 注入到小红书网页里的小帮手，页面解析完（documentEnd）才开始。前面会拼上 xhs-rules.js，
// 页面结构一律从 XSO_RULES 取。整个文件只挂一个页面变化监听，0.1 秒内的多次变化只检查一次，没有常驻的定时器。
// 开关存在小红书网页的 localStorage 里（app 里的开关会同步过来），每个页面都能读到
const log = (m) => window.webkit?.messageHandlers?.log?.postMessage(m);
// 页面解析完了：app 收起网页顶上的进度条。侧滑返回时页面可能从返回缓存里整个恢复，脚本不会重跑，靠 pageshow 再说一次
window.webkit?.messageHandlers?.xsoReady?.postMessage(true);
addEventListener('pageshow', (e) => e.persisted && window.webkit?.messageHandlers?.xsoReady?.postMessage(true));
const find = (xpath) =>
  document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;

// 搜索页的「筛选」（第四版，2026-11-16）：小红书的筛选是照电脑写的，鼠标移入就开、移出就关、点一下再切换。
// 真手指一点会先后发出「移入、按下、抬起、点击」，几套开关各自响应。前三版都是在中间拦事件，总有漏的，收起要点好几下。
// 这一版让手指根本碰不到它：小红书的按钮和弹窗整个藏起来（样式见 XSO_RULES.css），
// 原位放一个 app 自己的「筛选」按钮。点一下开 app 自己的面板，再点一下（或点面板外任何地方、点「完成」）就关。
// 面板上的选项是从小红书藏起来的弹窗里读的。用户选了哪个，就替他去藏起来的弹窗里点同一个选项（小红书点了就重新搜），
// 再把最新的选中状态读回来。小红书那边只收到程序发的一下「点击」，没有移入移出，不会再打架
const realOnes = (els) => [...els].filter((el) => !el.closest('[aria-hidden]'));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const xhsFilter = () => document.querySelector(XSO_RULES.filterButton);
const xhsPanel = () => document.querySelector(XSO_RULES.filterPanel);
const openXhsPanel = async () => {
  if (!xhsPanel()) xhsFilter()?.click();
  for (let i = 0; i < 40 && !xhsPanel(); i++) await sleep(25); // 弹窗是下一帧才做出来的
  return xhsPanel();
};
const xhsAction = (text) => xhsPanel() && realOnes(xhsPanel().querySelectorAll(XSO_RULES.filterAction)).find((b) => b.textContent.trim() === text);
const closeXhsPanel = () => { if (xhsPanel()) (xhsAction(XSO_RULES.collapseText) || xhsFilter())?.click(); };
const groupTitle = (group) => group.querySelector(XSO_RULES.filterGroupTitle)?.textContent.trim() ?? '';
const readFilters = (panel) => realOnes(panel.querySelectorAll(XSO_RULES.filterGroup)).map((group) => ({
  title: groupTitle(group),
  options: realOnes(group.querySelectorAll(XSO_RULES.filterOption))
    .map((o) => ({ text: o.textContent.trim(), on: o.classList.contains(XSO_RULES.activeClass) })),
}));
let filters = []; // 最近一次从小红书弹窗里读到的选项
let filterJobs = Promise.resolve(); // 一次只做一件事：手快连点几个选项时按顺序来
const queueFilter = (job) => { filterJobs = filterJobs.then(job).catch((e) => log('filter error ' + e)); };
const filterSheet = () => document.getElementById('xso-filter-sheet');
const filterShade = () => document.getElementById('xso-filter-shade');
const myFilterButton = () => document.querySelector('.xso-filter-btn');
const make = (tag, className, text) => {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (text != null) el.textContent = text;
  return el;
};
// 按钮：选了不是第一项（默认）的，按钮变成强调色，收起来也看得出筛过了
const renderFilters = () => {
  myFilterButton()?.classList.toggle('xso-on', filters.some((g) => g.options.findIndex((o) => o.on) > 0));
  const sheet = filterSheet();
  if (!sheet) return;
  const groups = filters.map((g, gi) => {
    const box = make('div', 'xso-g');
    const row = make('div', 'xso-opts');
    g.options.forEach((o, oi) => {
      const b = make('button', 'xso-o' + (o.on ? ' xso-on' : ''), o.text);
      b.dataset.pick = `${gi}/${oi}`;
      row.append(b);
    });
    box.append(make('div', 'xso-t', g.title), row);
    return box;
  });
  if (!filters.length) groups.push(make('div', 'xso-t', '正在读取筛选项…'));
  const ops = make('div', 'xso-ops');
  ops.append(make('button', 'xso-reset', XSO_RULES.resetText), make('button', 'xso-done', '完成'));
  sheet.replaceChildren(...groups, ops);
};
// 去小红书藏起来的弹窗里点一下（选项或「重置」），再把选中状态读回来
const clickInXhsPanel = (describe, find) => queueFilter(async () => {
  const panel = await openXhsPanel();
  const target = panel && find(panel);
  if (!target) { log(`filter: ${describe} not found`); return; }
  target.click();
  await sleep(80);
  if (xhsPanel()) filters = readFilters(xhsPanel());
  renderFilters();
  log(`filter: ${describe}`);
});
const pickFilter = (gi, oi) => {
  const group = filters[gi];
  const option = group?.options[oi];
  if (!option || option.on) return;
  group.options.forEach((o, i) => { o.on = i === oi; }); // 先在面板上显示选中，不等小红书
  renderFilters();
  clickInXhsPanel(`picked ${group.title}/${option.text}`, (panel) => {
    const g = realOnes(panel.querySelectorAll(XSO_RULES.filterGroup)).find((x) => groupTitle(x) === group.title);
    return g && realOnes(g.querySelectorAll(XSO_RULES.filterOption)).find((x) => x.textContent.trim() === option.text);
  });
};
const closeFilterSheet = () => {
  if (!filterSheet()) return;
  filterSheet().remove();
  filterShade()?.remove();
  queueFilter(async () => closeXhsPanel());
  log('filter sheet closed');
};
const openFilterSheet = () => {
  if (filterSheet()) return;
  // 面板挂在按钮下面；半透明的遮罩盖住整页，点遮罩（包括盖在下面的「筛选」按钮）就是关，不会点进下面的笔记
  const top = Math.max(8, (myFilterButton()?.getBoundingClientRect().bottom ?? 48) + 6);
  const shade = make('div');
  shade.id = 'xso-filter-shade';
  const sheet = make('div');
  sheet.id = 'xso-filter-sheet';
  sheet.style.top = `${top}px`;
  sheet.style.maxHeight = `${Math.max(160, innerHeight - top - 12)}px`;
  shade.addEventListener('click', (e) => { e.stopPropagation(); closeFilterSheet(); });
  sheet.addEventListener('click', (e) => {
    e.stopPropagation();
    const b = e.target instanceof Element && e.target.closest('button');
    if (!b) return;
    if (b.dataset.pick) { const [gi, oi] = b.dataset.pick.split('/').map(Number); pickFilter(gi, oi); }
    else if (b.classList.contains('xso-reset')) clickInXhsPanel('reset', () => xhsAction(XSO_RULES.resetText));
    else if (b.classList.contains('xso-done')) closeFilterSheet();
  });
  document.body.append(shade, sheet);
  renderFilters();
  queueFilter(async () => {
    const panel = await openXhsPanel();
    if (panel) filters = readFilters(panel);
    renderFilters();
    log(`filter sheet opened: ${filters.length} groups`);
  });
};
// 页面变化时检查：搜索页上有小红书的「筛选」，就在它旁边放 app 的按钮（小红书重画那一排时会被拿掉，再放一次）；
// 离开搜索页时面板跟着关
const placeFilterButton = () => {
  const theirs = xhsFilter();
  if (!theirs) { if (filterSheet()) { filterSheet().remove(); filterShade()?.remove(); } return; }
  if (!document.documentElement.hasAttribute('data-xso-blank')) return; // 不藏小红书的按钮时就不放第二个
  if (theirs.nextElementSibling?.classList.contains('xso-filter-btn')) return;
  myFilterButton()?.remove();
  const mine = theirs.cloneNode(true); // 照搬它的文字和图标，看上去和原来一样；复制出来的元素不带小红书的事件
  mine.querySelector(XSO_RULES.filterPanel)?.remove();
  mine.className = 'xso-filter-btn';
  mine.setAttribute('role', 'button');
  mine.addEventListener('click', (e) => {
    e.stopPropagation();
    if (filterSheet()) closeFilterSheet(); else openFilterSheet();
  });
  theirs.after(mine);
  renderFilters();
};

// 笔记里的 Live 图：其实是叠在图片上的一小段视频，打开笔记小红书会自己播一遍。它没有标「在画面里播放」（playsinline），
// iPhone 上没这个标记的视频一播就全屏，于是一打开笔记就跳到全屏。在它开始播之前补上这个标记（并静音），
// 就跟小红书 app 一样只在图片框里动一下。视频笔记的播放器不动，照旧点开全屏看
const inlineLivePhoto = (video) => {
  if (!(video instanceof HTMLVideoElement) || !video.matches(XSO_RULES.livePhotoVideo) || video.playsInline) return;
  video.playsInline = true;
  video.setAttribute('webkit-playsinline', '');
  video.muted = true;
};
const nativePlay = HTMLMediaElement.prototype.play;
HTMLMediaElement.prototype.play = function (...args) {
  inlineLivePhoto(this);
  return nativePlay.apply(this, args);
};
const fixLivePhotos = () => document.querySelectorAll(XSO_RULES.livePhotoVideo).forEach(inlineLivePhoto);

// Live 图「翻到就动」（2026-11-16）：小红书一篇笔记里同时只有一段 Live 视频，翻到哪张才现做那张的视频，再现下载
// （真机上一段要 0.7 秒左右），翻得快、下载慢的那几张会停在第一帧，要按 LIVE 才动。
// （另一个原因在 WebView.swift：原来所有视频都要「用户点过」才准播，左右滑不算点，翻过去的 Live 一律不动，已改成只拦有声的。）所以：
// ① 提前下载：翻到第 N 张时，把后面两张和前一张的 Live 视频先下载好放在内存里，小红书来下载时直接把这份给它；
// ② 兜底：翻得太快、还没下载好的那张，等它能播了还停在开头，就替它播一遍（静音、在图片框里）。
// 不去点图上的「LIVE」：那是开关，小红书正要自己播的时候点一下反而把它关了（真机上试过）。
// 每段视频只替它播一次，用户再按 LIVE 停下就停下。只下载这篇笔记本来就要放的视频，不请求别的
const liveCache = new Map(); // 视频文件路径 → 下载好的内容（Promise<Blob>），最多留 6 段
let liveKey = null; // 小红书用的是哪一路编码（EF4、H264……），从它第一次下载的地址认出来
let liveSlide = '';
const kickedLive = new WeakSet();
const videoPath = (url) => { try { return new URL(url, location.href).pathname; } catch { return ''; } };
const currentNote = () => XSO_RULES.noteDetail(location.pathname.split('/').pop());
const nativeFetch = window.fetch;
window.fetch = function (input, init) {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input?.url;
  const path = url?.includes(XSO_RULES.videoHost) ? videoPath(url) : '';
  if (path) {
    if (!liveKey) {
      liveKey = (currentNote()?.imageList ?? []).flatMap((im) => XSO_RULES.liveStreams(im)).find((s) => videoPath(s.url) === path)?.key ?? null;
    }
    const cached = liveCache.get(path);
    const ranged = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined)).has('range');
    if (cached && !ranged) {
      log('live video served from preload');
      return cached.then(
        (blob) => new Response(blob, { status: 200, headers: { 'Content-Type': blob.type || 'video/mp4' } }),
        () => nativeFetch.call(this, input, init));
    }
  }
  return nativeFetch.call(this, input, init);
};
const preloadLive = (image) => {
  const streams = XSO_RULES.liveStreams(image);
  const url = (streams.find((s) => s.key === liveKey) ?? streams[0])?.url;
  const path = url && videoPath(url);
  if (!path || liveCache.has(path)) return;
  const job = nativeFetch(url.replace(/^http:/, 'https:'), { credentials: 'omit' })
    .then((r) => { if (!r.ok) throw new Error(r.status); return r.blob(); });
  job.catch(() => liveCache.delete(path));
  liveCache.set(path, job);
  while (liveCache.size > 6) liveCache.delete(liveCache.keys().next().value);
};
const followLivePhotos = () => {
  const active = document.querySelector(XSO_RULES.activeSlide);
  if (!active) return;
  const index = Number(active.getAttribute(XSO_RULES.slideIndexAttr));
  const slide = `${location.pathname}#${index}`;
  const images = currentNote()?.imageList ?? [];
  if (slide !== liveSlide && Number.isInteger(index) && images.length) {
    liveSlide = slide;
    for (const step of [1, 2, -1]) preloadLive(images[(index + step + images.length) % images.length]);
  }
  const video = active.querySelector(XSO_RULES.livePhotoVideo);
  if (!video || kickedLive.has(video)) return;
  kickedLive.add(video);
  const kick = () => {
    // 已经播过（currentTime 不是 0）或者已经翻走了，就不管
    if (!video.isConnected || !video.paused || video.currentTime > 0 || !video.closest(XSO_RULES.activeSlide)) return;
    video.play().then(() => log(`live: started slide ${index}`), (e) => log(`live: could not start slide ${index}: ${e.name}`));
  };
  setTimeout(kick, 600); // 先给小红书自己播的机会
  video.addEventListener('canplay', () => setTimeout(kick, 300), { once: true });
};

// 「我的收藏」：网址带了 ?tab=fav 一般就直接是收藏页；保险起见，app 打开主页前在 localStorage 里留个记号，
// 主页出现「笔记 / 收藏」标签时，如果「收藏」还没选中就替用户点一下，只点一次
const pickFavTab = () => {
  if (!location.pathname.startsWith('/user/profile') || localStorage.getItem('xsoOpenFav') !== '1') return;
  const tab = find(XSO_RULES.favTab);
  if (!tab) return;
  localStorage.removeItem('xsoOpenFav');
  if (tab.closest('.' + XSO_RULES.activeClass)) return;
  tab.click();
  log('picked 收藏 tab');
};

// 登录要扫码时帮忙（见 LoginHelp.swift）：登录框里出现「扫码」或者消失时告诉 app
let scanPrompt;
const reportScan = () => {
  const now = !!document.querySelector(XSO_RULES.loginBox)?.textContent.includes(XSO_RULES.scanText);
  if (now === scanPrompt) return;
  scanPrompt = now;
  window.webkit?.messageHandlers?.xsoScan?.postMessage(now);
};

// 预先下载站内要去的几个页面的代码：小红书按页面分包，第一次去某页时要先下载那页的代码，路由才会切过去。
// 首页加载完、空下来以后先拿好，第一次搜索、第一次点底栏就不用等。只下载小红书自己的页面代码，不请求任何数据
const PRELOAD_PAGES = ['/search_result', '/explore/0', '/chat', '/notification', '/ai_chat', '/user/profile/0'];
const preload = () => {
  const router = XSO_RULES.vue()?.$router;
  if (!router) return;
  let started = 0;
  for (const path of PRELOAD_PAGES) {
    for (const record of router.resolve(path).matched) {
      for (const component of Object.values(record.components ?? {})) {
        // 和 Vue Router 自己的判断一样：没带这些标记的函数就是「用到时再下载」的页面
        const lazy = typeof component === 'function' &&
          !('displayName' in component) && !('props' in component) && !('__vccOpts' in component);
        if (!lazy) continue;
        started++;
        Promise.resolve().then(component).catch(() => {});
      }
    }
  }
  log(`preloading code for ${started} pages`);
};
// 站内的页面白名单（第二道）：小红书自己的链接（点左上角 logo、笔记里链到「发现」……）要去不放行的页面时，
// 在跳转发生前就拦下，换成 app 的原生搜索首页，推荐流根本不加载。第一道是「只留搜索」脚本的搜索框遮挡。
// 放不放行问「只留搜索」脚本（xso-allowed 事件），名单只在那边维护；没人回答（脚本没装上）就放行
const guardRoutes = (router) => router.beforeEach((to) => {
  const ask = new CustomEvent('xso-allowed', { detail: { path: to.path, allowed: true } });
  dispatchEvent(ask);
  if (ask.detail.allowed) return true;
  log(`blocked in-page jump to ${to.path}`);
  window.webkit?.messageHandlers?.xsoGoHome?.postMessage(to.path);
  return false;
});

// 视频点了才播：WebKit 只拦有声的自动播放，静音视频照样自己播，网页里点过一下以后也不再拦。
// 所以视频一开始播就看看：最近 1 秒里用户有没有点在这个视频上（含它上下的控制条），没有就暂停。
// 不按页面结构，只看点的位置，小红书换播放器也不用改
let lastTap = { at: 0, x: 0, y: 0 };
addEventListener('pointerdown', (e) => { lastTap = { at: Date.now(), x: e.clientX, y: e.clientY }; }, true);
const tappedOn = (video) => {
  if (Date.now() - lastTap.at > 1000) return false;
  const r = video.getBoundingClientRect();
  return lastTap.x >= r.left && lastTap.x <= r.right && lastTap.y >= r.top - 60 && lastTap.y <= r.bottom + 60;
};
addEventListener('play', (e) => {
  const video = e.target;
  if (!(video instanceof HTMLVideoElement) || localStorage.getItem('xsoTapToPlay') === '0' || tappedOn(video)) return;
  if (video.matches(XSO_RULES.livePhotoVideo)) return; // Live 图只是图片框里动一下，照小红书 app 那样让它播
  // 笔记里的视频没标 playsinline，一播就进 iOS 自己的全屏播放器。那里的播放键网页收不到点按，
  // 以前每按一次播放都被当成「自己播的」又按停，视频根本放不了。
  // 所以只按停第一次自己开播；之后它在全屏播放器里再播，只能是你按的播放键，放行
  if (video.webkitDisplayingFullscreen && video.dataset.xsoHeld) return;
  video.dataset.xsoHeld = '1';
  video.addEventListener('webkitendfullscreen', () => delete video.dataset.xsoHeld, { once: true }); // 小红书换笔记可能复用同一个 <video>
  video.pause();
  log('paused a video that started by itself');
}, true);

// 不等整页 load：首页底下的推荐流图片可能要几十秒才加载完。页面解析完 1.5 秒后试，网页还没启动好就再等等
if (location.hostname === 'www.xiaohongshu.com') {
  let tries = 0;
  const setUp = () => {
    const router = XSO_RULES.vue()?.$router;
    if (!router) return ++tries < 5 && setTimeout(setUp, 1500);
    guardRoutes(router);
    preload();
  };
  setTimeout(setUp, 1500);
}

// 图片没加载出来就再试（T03a，2026-11-22）：小红书的图片服务器偶尔慢或者断一下，网页自己不会重试，那张图就一直空着。
// 只针对小红书自己图片服务器上的图，同一张最多再试 2 次（隔 1 秒、3 秒），请求和网页本来要发的一模一样。
// 首页（被原生首页盖着）的图是 app 故意挡的，不试
const isHomePath = () => location.pathname === '/' || location.pathname === '/explore';
const imageTries = new WeakMap();
addEventListener('error', (e) => {
  const img = e.target;
  if (!(img instanceof HTMLImageElement) || isHomePath()) return;
  const src = img.currentSrc || img.src;
  if (!/^https:\/\/[^/]*xhscdn\.com\//.test(src)) return;
  const tries = imageTries.get(img) ?? 0;
  if (tries >= 2) {
    log(`image failed for good: ${new URL(src).host}`);
    return;
  }
  imageTries.set(img, tries + 1);
  setTimeout(() => {
    // 等的时候小红书可能已经把这个 <img> 换成别的图、或者拿走了
    if (!img.isConnected || (img.currentSrc || img.src) !== src) return;
    log(`image retry ${tries + 1}: ${new URL(src).host}`);
    img.removeAttribute('src'); // 先拿掉再放回，WebKit 才会真的重新下载同一个地址
    img.src = src;
  }, tries === 0 ? 1000 : 3000);
}, true);

// 首页上先和图片服务器连上（只建连接，不下载任何东西）：首页的图被挡着，不连的话第一次搜索的封面要先花时间握手。
// 网页自己既用 <img> 也用 fetch 下载图，两种连接分开算，所以各连一条
if (isHomePath()) {
  for (const host of XSO_RULES.imageHosts) {
    for (const cors of [false, true]) {
      const link = document.createElement('link');
      link.rel = 'preconnect';
      link.href = host;
      if (cors) link.crossOrigin = 'anonymous';
      document.head.append(link);
    }
  }
}

// 从链接整页打开的笔记：图片区的高度小红书写的是 auto（见 xhs-rules.js 里 noteMedia 那条样式），样式先按 3:4 撑开，
// 这里换成第一张图的真实比例（和小红书自己算的一样，最高到 3:4 竖图）。只读页面里已有的笔记数据
const sizeNoteMedia = () => {
  const box = document.querySelector(XSO_RULES.noteMedia);
  if (!box || box.style.height !== 'auto') return;
  const first = currentNote()?.imageList?.[0];
  if (!(first?.width > 0 && first?.height > 0)) return;
  const ratio = String(Math.round(Math.max(first.width / first.height, 3 / 4) * 1000) / 1000);
  if (box.dataset.xsoRatio === ratio && box.style.aspectRatio) return;
  box.dataset.xsoRatio = ratio;
  box.style.aspectRatio = ratio;
  log(`note media sized by ratio ${ratio}`);
};

const checks = [pickFavTab, reportScan, fixLivePhotos, followLivePhotos, placeFilterButton, sizeNoteMedia];
let queued = false;
const runChecks = () => {
  queued = false;
  for (const check of checks) check();
};
runChecks();
// 不用 requestAnimationFrame：页面上字少的时候 WebKit 会一直不画，下一帧可能要几十秒才来
new MutationObserver(() => {
  if (queued) return;
  queued = true;
  setTimeout(runChecks, 100);
}).observe(document, { childList: true, subtree: true });

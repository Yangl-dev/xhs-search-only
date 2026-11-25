// 防滑门卫的自动测试。用法：node tools/guard-test.mjs
// 不开浏览器、不联网：在 node 里造一个假的 window / history / location，把 SearchOnly/xso-guard.js 原样跑起来，
// 时间也是假的（想跳几秒就跳几秒），所以几毫秒就跑完。
// 测两样东西：
//   1. 网址认成哪一条内容（SearchOnlyApp.swift 里的 Config.contentPattern），用 xso-guard.js 自己的 contentKey 算
//   2. 门卫在各种情况下该放行还是该拦：同一条换写法、刚打开时网站自己改写、没点就换到下一条、滑一下换到下一条、
//      整页退回以后网站又改回来（最多刷新一次）……
// 以后改 xso-guard.js 或 contentPattern，先跑一遍这个
import vm from 'node:vm';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const tools = path.dirname(fileURLToPath(import.meta.url));
const app = path.join(tools, '..', 'SearchOnly');
const appSwift = fs.readFileSync(path.join(app, 'SearchOnlyApp.swift'), 'utf8');
const guardSource = fs.readFileSync(path.join(app, 'xso-guard.js'), 'utf8');

// 从 SearchOnlyApp.swift 里读出 contentPattern，测的就是 app 里真在用的那份
const patterns = { xhs: (appSwift.match(/static let contentPattern = #"(.*?)"#/) || [])[1] };

const clock = { t: 1_000_000 }; // 假时间，门卫里的 Date.now() 读它
const ORIGIN = 'https://www.example.com';
let failures = 0;
const check = (ok, label, detail = '') => {
  if (!ok) failures++;
  console.log(`${ok ? '  ok  ' : '  FAIL'} ${label}${!ok && detail ? `  （${detail}）` : ''}`);
};

// ── 1. 网址 → 内容 id ──
const N1 = '0000000000000000000000a1', N2 = '0000000000000000000000a2'; // 假的笔记 id，格式和真的一样（24 位十六进制）
const ids = {
  xhs: [
    [`/explore/${N1}`, N1], [`/discovery/item/${N1}`, N1], [`/search_result/${N1}`, N1], [`/explore/${N1}/`, N1],
    ['/explore', null], ['/search_result', null], [`/user/profile/${N1}`, null],
  ],
};

console.log('1. 网址认成哪一条内容');
Object.entries(ids).forEach(([platform, rows]) => {
  if (!patterns[platform]) return check(false, `${platform}: SearchOnlyApp.swift 里找不到 contentPattern`);
  // 用 xso-guard.js 自己的 contentKey（门卫装好时通过 __xsoGuardExpose 交出来）
  const { contentKey } = openPage(platform, '/').exposed;
  rows.forEach(([p, want]) => {
    const got = contentKey(ORIGIN + p);
    check(got === want, `${platform} ${p} → ${want ?? '不是内容页'}`, `JS 得到 ${got}`);
  });
});

// ── 2. 门卫行为 ──
// 一个假的网页：sessionStorage 跨「整页刷新」保留（和真浏览器一样），时间用 clock.t
// （function 声明会提前，第 1 部分也用它来拿 contentKey）
function openPage(platform, href, storage = new Map()) {
  const page = { href: ORIGIN + href, posts: [], reloadTo: null, backs: 0, storage, listeners: {} };
  const stack = [page.href];
  let index = 0;
  const go = (url) => new URL(url, page.href).href;
  const history = {
    pushState(state, title, url) { stack.splice(index + 1, Infinity, go(url)); index++; page.href = stack[index]; },
    replaceState(state, title, url) { stack[index] = go(url); page.href = stack[index]; },
    back() { page.backs++; if (index > 0) { index--; page.href = stack[index]; fire('popstate', {}); } },
  };
  const fire = (type, event) => (page.listeners[type] || []).forEach((f) => f(event));
  const context = {
    history,
    location: { get href() { return page.href; }, replace(url) { page.reloadTo = go(url); } },
    sessionStorage: { getItem: (k) => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, String(v)) },
    addEventListener: (type, f) => (page.listeners[type] ||= []).push(f),
    webkit: { messageHandlers: new Proxy({}, { get: (_, name) => ({ postMessage: (body) => page.posts.push(name) }) }) },
    Date: { now: () => clock.t },
    URL, JSON, Math, BigInt, console,
    __xsoGuardExpose: (inside) => { page.exposed = inside; },
  };
  context.window = context;
  vm.createContext(context);
  // 和 WKUserScript.guardScript() 拼法一样
  vm.runInContext(`{\nconst XSO_GUARD_CONTENT = ${JSON.stringify(patterns[platform])};\n${guardSource}\n}`, context);
  page.history = history;
  page.window = context;
  page.path = () => new URL(page.href).pathname + new URL(page.href).search;
  page.blocked = () => page.posts.filter((n) => n === 'xsoGuard').length;
  page.tap = () => {
    fire('touchstart', { touches: [{ clientX: 100, clientY: 100 }] });
    fire('touchend', { isTrusted: true });
  };
  page.swipe = () => {
    fire('touchstart', { touches: [{ clientX: 100, clientY: 400 }] });
    fire('touchmove', { touches: [{ clientX: 100, clientY: 100 }] });
    fire('touchend', { isTrusted: true });
  };
  return page;
}
const later = (ms) => { clock.t += ms; };

console.log('2. 门卫该放行还是该拦');
{
  const page = openPage('xhs', `/discovery/item/${N1}?xsec_token=x`);
  later(500);
  page.history.replaceState(null, '', `/explore/${N1}?xsec_token=x`);
  check(page.blocked() === 0 && page.reloadTo === null, '小红书刚打开就把 /discovery/item 改成 /explore（同一条）：放行');
  later(5000);
  page.history.replaceState(null, '', `/explore/${N1}?xsec_token=y&from=z`);
  check(page.blocked() === 0, '过了几秒同一条换参数：放行');
  later(5000);
  page.history.pushState(null, '', `/explore/${N2}`);
  check(page.blocked() === 1 && page.backs === 1 && page.path().startsWith(`/explore/${N1}`), '没点，网页自己往历史里加了下一条：拦下，退一步回到原来那条');
}
{
  const page = openPage('xhs', `/explore/${N1}`);
  later(200);
  page.history.pushState(null, '', `/explore/${N2}`);
  check(page.blocked() === 1, '刚打开就 push 到另一条（不是改写，是换了一条）：拦下');
}
{
  const page = openPage('xhs', `/explore/${N1}`);
  later(500);
  page.history.replaceState(null, '', `/explore/${N2}`);
  check(page.blocked() === 0, '刚打开 3 秒内 replace 成另一条（算打开的一部分，比如短链落地）：放行');
}
{
  const storage = new Map();
  const page = openPage('xhs', `/explore/${N1}`, storage);
  later(5000);
  page.history.replaceState(null, '', `/explore/${N2}`);
  check(page.blocked() === 1 && page.reloadTo === `${ORIGIN}/explore/${N1}`, '打开 5 秒后偷偷 replace 成另一条：拦下，整页回到原来那条');
  // 整页回去以后，网站又改了一次：这次放行，不再刷新（防死循环）
  const again = openPage('xhs', `/explore/${N1}`, storage);
  later(4000);
  again.history.replaceState(null, '', `/explore/${N2}`);
  check(again.blocked() === 0 && again.reloadTo === null && again.posts.includes('xsoGuardLoop'), '整页退回后网站又改回去：放行，最多刷新一次');
}
{
  const page = openPage('xhs', '/search_result?keyword=a');
  later(5000);
  page.tap();
  later(800);
  page.history.pushState(null, '', `/explore/${N1}`);
  check(page.blocked() === 0, '在搜索结果里点了一下，0.8 秒后打开笔记：放行');
}
{
  const page = openPage('xhs', `/explore/${N1}`);
  later(5000);
  page.tap();
  later(3000);
  page.history.pushState(null, '', `/explore/${N2}`);
  check(page.blocked() === 1, '点完过了 3 秒才换到另一条（超出 2.5 秒）：拦下');
}
{
  const page = openPage('xhs', `/explore/${N1}`);
  later(5000);
  page.tap();
  later(300);
  page.swipe();
  later(200);
  page.history.pushState(null, '', `/explore/${N2}`);
  check(page.blocked() === 1, '点过以后又滑了一下，换到下一条：拦下（滑动让「刚点过」作废）');
}
{
  const page = openPage('xhs', `/explore/${N1}`);
  later(5000);
  page.window.__xsoNavOK = clock.t;
  later(100);
  page.history.replaceState(null, '', `/explore/${N2}`);
  check(page.blocked() === 0, 'app 自己发起的跳转（__xsoNavOK）：放行');
}
{
  const page = openPage('xhs', '/explore');
  later(5000);
  page.history.pushState(null, '', '/search_result?keyword=b');
  check(page.blocked() === 0, '换到不是内容页的页面（搜索结果）：不管');
}

console.log(failures ? `\n${failures} 项没过` : '\n全部通过');
process.exit(failures ? 1 : 0);

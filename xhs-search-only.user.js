// ==UserScript==
// @name         小红书：只留搜索
// @namespace    xhs-search-only
// @version      1.7.1
// @description  首页、视频、直播等推荐页一律换成一个搜索框；搜索结果、笔记详情、通知和 AI 问答不动。
// @license      MIT
// @match        https://www.xiaohongshu.com/*
// @match        https://xiaohongshu.com/*
// @run-at       document-start
// @noframes
// @grant        none
// ==/UserScript==

(() => {
  'use strict';

  // 只管 www 主站（和上面的 @match 一样）。套壳 app 会把脚本注入到所有小红书域名的页面，别的子域名不归这里拦
  if (location.hostname !== 'www.xiaohongshu.com' && location.hostname !== 'xiaohongshu.com') return;

  // 作者主页默认放行：用来看发帖的人是不是营销号，以及「我」里的收藏。想一起拦掉就改成 false。
  const ALLOW_PROFILE = true;

  // 只按网址判断，不碰小红书的页面结构，改版也基本不会坏。
  // 下面这些页面放行，其余（首页、发现、视频、直播、通知……）都换成搜索框。
  const ALLOWED = [
    /^\/search_result\/?$/,               // 搜索结果
    /^\/search_result\/[0-9a-f]{24}\/?$/i, // 从搜索结果点开的笔记（app 整页打开时会换成 /explore/<id>，站内跳过来时是这个样子）
    /^\/explore\/[0-9a-z]+\/?$/i,         // 笔记详情：/explore/<笔记 ID>
    /^\/discovery\/item\/[0-9a-z]+\/?$/i, // 老格式的笔记分享链接
    /^\/website-login\//,                 // 登录、风控安全验证
    /^\/login\/?$/,
    /^\/ai_chat\/?$/,                     // 小红书的 AI 问答（点点）：也是带着问题来搜，放行
    /^\/notification\/?$/,                // 通知（评论、点赞、关注）：别人找你的消息，不是推荐
    /^\/chat(\/[0-9a-z_-]+)?\/?$/i,        // 私信：会话列表和某个会话，也是别人找你，不是推荐
  ];
  if (ALLOW_PROFILE) ALLOWED.push(/^\/user\/profile\/[0-9a-z]+\/?$/i);

  // 套壳 app 里可以关掉「首页空白模式」（会在 localStorage 里记成 '0'），关掉时什么都不拦。Safari 里没人设它，不受影响
  const blankHomeOff = () => { try { return localStorage.getItem('xsoBlankHome') === '0'; } catch { return false; } };
  const isAllowedPath = (path) => blankHomeOff() || ALLOWED.some((re) => re.test(path));
  const isAllowed = () => isAllowedPath(location.pathname);
  // 套壳 app 在站内跳转之前会来问某个页面放不放行（见 app 的 xso-page.js），放行名单只在这里维护一份
  addEventListener('xso-allowed', (e) => { e.detail.allowed = isAllowedPath(e.detail.path); });

  // 只在拦截时挂到页面上，所以这些规则不会影响放行的页面
  const style = document.createElement('style');
  style.textContent = `
    html { overflow: hidden !important; background: #fff !important; }
    body { display: none !important; }
    #xso-gate {
      position: fixed; inset: 0; z-index: 2147483647;
      display: flex; align-items: center; justify-content: center;
      background: #fff; color: #333;
      font: 16px/1.5 -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
    }
    #xso-gate * { box-sizing: border-box; margin: 0; }
    #xso-gate form { width: min(560px, calc(100vw - 32px)); margin-top: -12vh; }
    #xso-gate h1 { font-size: 28px; font-weight: 600; text-align: center; margin-bottom: 20px; }
    #xso-gate input {
      display: block; width: 100%; height: 48px; padding: 0 20px;
      border: 1px solid #e5e5e5; border-radius: 24px; outline: none;
      background: #f5f5f5; color: inherit; font: inherit; font-size: 17px;
      -webkit-appearance: none; appearance: none;
    }
    #xso-gate input:focus { border-color: #ff2442; background: #fff; }
    #xso-gate p { margin-top: 14px; text-align: center; font-size: 13px; color: #999; }
    @media (prefers-color-scheme: dark) {
      html { background: #111 !important; }
      #xso-gate { background: #111; color: #eee; }
      #xso-gate input { background: #1e1e1e; border-color: #333; }
      #xso-gate input:focus { background: #181818; }
      #xso-gate p { color: #777; }
    }
  `;

  const gate = document.createElement('div');
  gate.id = 'xso-gate';
  gate.innerHTML = `
    <form role="search">
      <h1>搜小红书</h1>
      <input type="search" placeholder="想查什么？" autocomplete="off" enterkeyhint="search">
      <p>推荐流已关，想好要搜什么再来</p>
    </form>
  `;
  const input = gate.querySelector('input');

  gate.querySelector('form').addEventListener('submit', (e) => {
    e.preventDefault();
    const q = input.value.trim();
    // 带斜杠的网址：不带的话小红书会先重定向到 http，套壳 app 里会被 iOS 拦下
    if (q) location.assign(`/search_result/?keyword=${encodeURIComponent(q)}&source=web_explore_feed`);
  });
  // 别让小红书自己的快捷键吃掉输入
  for (const type of ['keydown', 'keypress', 'keyup']) {
    gate.addEventListener(type, (e) => e.stopPropagation());
  }

  // 告诉套壳 app 搜索框现在盖没盖着，app 可以换成自己的原生搜索页。Safari 里没有这个通道，什么也不做
  let shown;
  const report = (now) => {
    if (now === shown) return;
    shown = now;
    window.webkit?.messageHandlers?.xsoGate?.postMessage(now);
  };

  let checkedPath = null;
  const update = () => {
    checkedPath = location.pathname;
    if (isAllowed()) {
      style.remove();
      gate.remove();
      report(false);
      return;
    }
    report(true);
    // 挂在 <html> 下而不是 <body> 里，小红书重渲染页面时不会把它冲掉
    const root = document.documentElement;
    if (!style.isConnected) root.append(style);
    if (!gate.isConnected) {
      root.append(gate);
      input.focus();
    }
  };

  update();
  // 站内跳转（比如点侧栏「发现」）不刷新页面：页面一变就当场重新检查，赶在画出来之前把推荐流盖住。
  // 页面一直在变，所以先看一眼：网址没变、搜索框该在的时候在（不该在的时候不在），就什么都不做。
  // 不能等下一帧再查：页面上字少的时候 WebKit 会一直不画，等到整页加载完，下一帧可能要几十秒才来
  new MutationObserver(() => {
    if (location.pathname === checkedPath && gate.isConnected === shown && style.isConnected === shown) return;
    update();
  }).observe(document, { childList: true, subtree: true });
  addEventListener('popstate', update);
  // 返回时页面可能从浏览器的返回缓存里整个恢复（脚本不重跑）：重新检查一遍，并再告诉 app 一次搜索框在不在
  addEventListener('pageshow', (e) => {
    if (!e.persisted) return;
    shown = undefined;
    update();
  });
  // 套壳 app 切换「首页空白模式」时页面不一定有变化，app 发这个事件让脚本马上重新检查
  addEventListener('xso-recheck', update);
  document.addEventListener('DOMContentLoaded', () => {
    if (gate.isConnected) input.focus();
  });
})();

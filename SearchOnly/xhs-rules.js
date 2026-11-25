// 小红书网页的页面结构，全在这一个文件里：小红书改版后 app 里哪里失灵了，就来这里改。
// 别处的代码只认这里的名字，不直接写选择器。app 把这个文件拼在每段用到它的网页脚本前面（见 WebView.swift）。
// 「只留搜索」脚本本身只按网址判断，不用这里的任何东西
const XSO_RULES = Object.freeze({
  // Vue 挂载的根节点：站内跳转、取自己的用户 ID、预加载页面代码都要经过它
  appRoot: '#app',
  vue() { return document.querySelector(this.appRoot)?.__vue_app__?.config.globalProperties; },
  // 小红书网页自己记的登录状态（pinia 里的 user）：loggedIn、userInfo.userId
  user() { return this.vue()?.$pinia?.state.value.user; },

  // 登录框：登录页和弹出来的登录框都是它。里面出现「扫码」就是要扫二维码
  loginBox: '.login-container',
  scanText: '扫码',

  // 个人主页的「收藏」标签：附近有「笔记」的那个
  favTab: "//*[normalize-space(text())='收藏'][ancestor::*[position()<=3]//*[normalize-space(text())='笔记']]",
  // 选中的标签带这个 class
  activeClass: 'active',

  // 笔记卡片：搜索结果、个人主页里的一格一格（调试日志用；下面「图片先模糊」的样式也是按它写的）
  noteCard: 'section.note-item',

  // 搜索结果顶上的「筛选」按钮和点开后的弹窗（弹窗是按钮里面的一个子元素，关上时整个拿掉）。
  // 弹窗里一组一组的选项：.filters（第一个 span 是标题「排序依据」「笔记类型」……，.tags 是选项，选中的带 active），
  // 底部 .operation 是「重置」「收起」。小红书在每个按钮旁边还放了一个看不见的同名副本（aria-hidden），要认真的那个
  filterButton: '.search-layout .filter',
  filterPanel: '.search-layout .filter-panel',
  filterGroup: '.filters',
  filterGroupTitle: ':scope > span',
  filterOption: '.tags',
  filterAction: '.operation',
  resetText: '重置',
  collapseText: '收起',

  // 笔记里的 Live 图：图片上叠着一段很短的视频（不是视频笔记的播放器）。一篇笔记里同时只有一段：
  // 翻到哪张（轮播里带 swiper-slide-active 的那张，data-swiper-slide-index 是第几张）才现做那张的视频。
  livePhotoVideo: '.live-photo-contain video, video.live-video',
  activeSlide: '#noteContainer .swiper-slide-active',
  // 笔记的图片区（轮播外面那一块）
  noteMedia: '#noteContainer .media-container',
  slideIndexAttr: 'data-swiper-slide-index',
  // 视频文件都在这个域名下
  videoHost: 'xhscdn.com',
  // 搜索结果封面、笔记图片、头像所在的图片服务器（真机日志里看到的），首页先连上，第一次搜索时省掉建连接的时间
  imageHosts: ['https://sns-webpic-qc.xhscdn.com', 'https://sns-avatar-qc.xhscdn.com'],
  // 网页自己存着的笔记内容（pinia 里的 note.noteDetailMap），按笔记 ID 取
  noteDetail(id) { return this.vue()?.$pinia?.state.value.note?.noteDetailMap?.[id]?.note; },
  // 一张图的 Live 视频地址：imageList 里 livePhoto 为真的图，stream 下按编码分几路（EF4、H264……），每路有 masterUrl
  liveStreams(image) {
    if (!image?.livePhoto) return [];
    return Object.entries(image.stream ?? {})
      .flatMap(([key, list]) => (list ?? []).map((s) => ({ key, url: s?.masterUrl })))
      .filter((s) => s.url);
  },

  // 页面一开始就插进去的样式。<html> 上的属性对应 app 里的开关：
  // data-xso-blank 空白首页（一直开着），data-xso-gray「灰度模式」，data-xso-blur「搜索图片先模糊」，
  // data-xso-style 当前的界面风格。
  // 用到的小红书页面结构：.header-container 顶栏；.feeds-page / .notification-page / .user-page .user 给顶栏留的空位；
  // .reds-sticky 吸顶的那一条；#channel-container「全部 / 图文 / 视频 / 用户」；.feeds-container 结果列表；
  // section.note-item 笔记卡片（.cover 封面、.title 标题）；以及它自己的一组颜色变量（--bg、--title、--primary ……）
  css: `
    /* 这条不按页面结构：去掉点按时的灰色高亮；不用双击放大，点一下就不用等 0.3 秒判断是不是双击（双指缩放照样能用） */
    html { touch-action: manipulation; -webkit-tap-highlight-color: transparent; }
    /* 这条也不按页面结构：电脑版网页在手机窄屏上偶尔有东西比屏幕宽，整页就能往右拖出一截。超出的部分裁掉，只能上下滑
       （app 那边 UIScrollView.lockSideways 再保一道） */
    html { overflow-x: hidden; }
    /* 窄屏时底部那排导航（首页、视频、发布、通知……）是回推荐流的入口：app 有自己的底栏，藏掉 */
    html[data-xso-blank] [class^="bottom-menu"] { display: none !important; }
    /* 灰度：整个网页变黑白（加在根元素上不影响固定定位的东西） */
    html[data-xso-gray] { filter: grayscale(1); }
    /* 笔记卡片的封面图先模糊；点进笔记看的是大图，不在卡片里，是清楚的 */
    html[data-xso-blur] section.note-item img { filter: blur(14px); }
    /* 去掉小红书自己的顶栏（logo、搜索、菜单）：app 有自己的顶栏和底栏。顶栏高度这个变量也清零，页面内容就顶上来了 */
    html[data-xso-blank] .header-container { display: none !important; }
    html[data-xso-blank], html[data-xso-blank] body { --header-height: 0px !important; }
    html[data-xso-blank] .feeds-page, html[data-xso-blank] .notification-page { padding-top: 0 !important; }
    /* 吸顶的那一条（搜索页的话题标签、通知页和个人主页的分类）不再吸顶：它是按「顶栏有 72pt 高」来判断该不该吸的，
       顶栏没了以后一进页面就吸上去，盖住上面的「筛选」，原来的位置还空着一块 */
    html[data-xso-blank] .reds-sticky { position: static !important; width: auto !important; }
    html[data-xso-blank] .user-page .user { padding-top: 16px !important; }
    html[data-xso-blank] .search-layout__top { padding-top: 8px; }
    /* 网页配色跟着界面风格走：小红书的颜色都来自它自己的一组变量，这里换成当前风格的数值（--xso-*，见 WebSkin） */
    html[data-xso-blank][data-xso-style], html[data-xso-blank][data-xso-style] body {
      --bg: var(--xso-bg) !important; --bg0: var(--xso-bg) !important; --bg0-lighter: var(--xso-bg) !important;
      --color-background: var(--xso-bg) !important; --mask-paper: var(--xso-bg) !important;
      --bg2: var(--xso-surface) !important; --elevation-low-background: var(--xso-surface) !important;
      --elevation-high-background: var(--xso-surface) !important; --elevation-note-background: var(--xso-bg) !important;
      --bg1: var(--xso-fill) !important; --fill1: var(--xso-fill) !important; --color-active-background: var(--xso-fill) !important;
      --title: var(--xso-text) !important; --color-title: var(--xso-text) !important; --color-primary-label: var(--xso-text) !important;
      --paragraph: color-mix(in srgb, var(--xso-text) 78%, var(--xso-bg)) !important;
      --color-secondary-label: color-mix(in srgb, var(--xso-text) 78%, var(--xso-bg)) !important;
      --description: var(--xso-text-2) !important; --color-tertiary-label: var(--xso-text-2) !important;
      --placeholder: color-mix(in srgb, var(--xso-text-2) 62%, var(--xso-bg)) !important;
      --color-quaternary-label: color-mix(in srgb, var(--xso-text-2) 62%, var(--xso-bg)) !important;
      --separator: var(--xso-line) !important; --color-border: var(--xso-line) !important; --opaque-separator: var(--xso-line) !important;
      --primary: var(--xso-accent) !important; --color-primary: var(--xso-accent) !important;
      --primary2: color-mix(in srgb, var(--xso-accent) 9%, var(--xso-bg)) !important;
      --color-tinted-red: color-mix(in srgb, var(--xso-accent) 9%, var(--xso-bg)) !important;
      --note-card-corner-radius: var(--xso-radius-media) !important;
    }
    /* 笔记卡片：底色、圆角、描边、阴影；卡片有了底色以后上下要留一点缝（小红书是按卡片实际高度排的，留的缝它会算进去） */
    html[data-xso-blank][data-xso-style] section.note-item { padding-bottom: var(--xso-card-gap, 0px); box-sizing: content-box; }
    html[data-xso-blank][data-xso-style] section.note-item > div {
      background: var(--xso-surface); border-radius: var(--xso-radius-card); border: var(--xso-card-border);
      box-shadow: var(--xso-card-shadow); overflow: hidden; box-sizing: border-box;
    }
    html[data-xso-blank][data-xso-style] section.note-item .cover { border-radius: var(--xso-radius-media) !important; }

    /* 「筛选」：小红书自己的按钮和弹窗整个藏起来，手指碰不到它，它的「移入就开、移出就关」也就不会再和点击打架。
       原位换成 app 自己的按钮 .xso-filter-btn 和面板 #xso-filter-sheet（见 xso-page.js），配色全用当前风格的变量 */
    html[data-xso-blank] .search-layout .filter { display: none !important; }
    .xso-filter-btn {
      display: flex; align-items: center; gap: 2px; flex: 0 0 auto; height: 40px; padding: 0 16px;
      font-size: 16px; color: var(--paragraph, #505050); cursor: pointer; user-select: none; -webkit-user-select: none;
    }
    .xso-filter-btn.xso-on { color: var(--xso-accent, #ff2442); font-weight: 600; }
    #xso-filter-shade { position: fixed; inset: 0; z-index: 9998; background: rgba(0, 0, 0, .14); touch-action: none; }
    #xso-filter-sheet {
      position: fixed; left: 12px; right: 12px; z-index: 9999; box-sizing: border-box; padding: 16px 16px 14px;
      background: var(--xso-surface, #fff); color: var(--xso-text, #222);
      border-radius: var(--xso-radius-card, 16px); border: var(--xso-card-border, none);
      box-shadow: 0 10px 30px rgba(0, 0, 0, .18); overflow-y: auto; overscroll-behavior: contain; font-size: 14px;
    }
    #xso-filter-sheet .xso-g + .xso-g { margin-top: 14px; }
    #xso-filter-sheet .xso-t { font-size: 13px; color: var(--xso-text-2, #888); margin-bottom: 8px; }
    #xso-filter-sheet .xso-opts { display: flex; flex-wrap: wrap; gap: 8px; }
    #xso-filter-sheet button {
      -webkit-appearance: none; appearance: none; margin: 0; font: inherit; cursor: pointer;
      border-radius: var(--xso-radius-control, 10px);
    }
    #xso-filter-sheet .xso-o {
      padding: 6px 13px; font-size: 14px; line-height: 20px; color: var(--xso-text, #222);
      background: var(--xso-fill, #f5f5f5); border: 1px solid transparent;
    }
    #xso-filter-sheet .xso-o.xso-on {
      color: var(--xso-accent, #ff2442); font-weight: 600; border-color: var(--xso-accent, #ff2442);
      background: color-mix(in srgb, var(--xso-accent, #ff2442) 9%, var(--xso-surface, #fff));
    }
    #xso-filter-sheet .xso-ops { display: flex; gap: 10px; margin-top: 18px; }
    #xso-filter-sheet .xso-ops button { flex: 1; height: 40px; font-size: 15px; border: 0; }
    #xso-filter-sheet .xso-reset { background: var(--xso-fill, #f5f5f5); color: var(--xso-text, #222); }
    #xso-filter-sheet .xso-done { background: var(--xso-accent, #ff2442); color: var(--xso-on-accent, #fff); font-weight: 600; }

    /* 笔记详情（#noteContainer，整页就是它，自己滚动）：作者一行 .author（停在顶上）、图 .media-container
       （下面一排小点 .pagination-list .dot、右上角页码 .fraction）、正文 .note-content（话题标签 a.tag）、分隔线 .interaction-divider、
       评论 .comments-el（「展开 N 条回复」.show-more）、底部操作条 .engage-bar（评论框 .content-input、发送 .btn.submit）。
       小红书在这页写死了几处红色、蓝色，不走它的颜色变量，所以逐个换成当前风格的；--xso-panel-* 让「圆润」把各块放进卡片 */
    html[data-xso-blank][data-xso-style] #noteContainer { background: var(--xso-bg) !important; }
    html[data-xso-blank][data-xso-style] #noteContainer > .author {
      background: var(--xso-bg) !important; border-bottom: var(--xso-header-rule) !important;
    }
    html[data-xso-blank][data-xso-style] #noteContainer .follow-button {
      background: var(--xso-follow-bg) !important; color: var(--xso-follow-fg) !important;
      border: 1px solid var(--xso-accent) !important; border-radius: var(--xso-radius-control) !important;
    }
    html[data-xso-blank][data-xso-style] #noteContainer .follow-button * { color: inherit !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .media-container {
      background: var(--xso-fill) !important; margin: var(--xso-panel-inset) var(--xso-panel-inset) 0;
      border-radius: var(--xso-panel-radius); box-shadow: var(--xso-panel-shadow); overflow: hidden;
      /* 它和里面的轮播原本都写死了整屏宽，四周留缝时一起变窄。页面一开始就有这条样式，轮播第一次量宽度时就是窄的，每张图跟着排 */
      width: calc(100% - 2 * var(--xso-panel-inset)) !important; min-width: 0 !important;
    }
    /* 图的高度：小红书已经按第一张图的比例算好写在元素上（最高到 3:4 竖图），但网页版又把它压在 50%–60% 屏宽之间，
       竖图就成了窄窄一条。去掉这个限制，跟小红书 app 一样整屏宽、按比例显示 */
    html[data-xso-blank] #noteContainer .media-container { max-height: none !important; min-height: 0 !important; }
    /* 从链接整页打开的笔记页不一样（2026-11-23）：小红书没把高度算好写上去，写的是 height: auto，全靠上面去掉的那个最小高度撑着，
       里面的图又都是绝对定位，于是整块塌成 0 高，只剩文字和评论。这时按比例给高度：先按 3:4，xso-page.js 再换成第一张图的真实比例 */
    html[data-xso-blank] #noteContainer .media-container[style*="height: auto"] { aspect-ratio: 3 / 4; }
    html[data-xso-blank][data-xso-style] #noteContainer .media-container .xhs-slider-container,
    html[data-xso-blank][data-xso-style] #noteContainer .media-container .note-slider { width: 100% !important; min-width: 0 !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .pagination-list .dot.active { background: var(--xso-accent) !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .fraction { border-radius: var(--xso-radius-control) !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .note-text a.tag,
    html[data-xso-blank][data-xso-style] #noteContainer .show-more { color: var(--xso-link) !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .interaction-container { background: transparent !important; border-radius: 0 !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .note-scroller > .note-content,
    html[data-xso-blank][data-xso-style] #noteContainer .note-scroller > .comments-el {
      background: var(--xso-panel-bg); margin: var(--xso-panel-inset) var(--xso-panel-inset) 0;
      border-radius: var(--xso-panel-radius); box-shadow: var(--xso-panel-shadow);
    }
    html[data-xso-blank][data-xso-style] #noteContainer .note-scroller > .comments-el { margin-bottom: var(--xso-panel-inset); }
    html[data-xso-blank][data-xso-style] #noteContainer .interaction-divider { display: var(--xso-panel-divider) !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .engage-bar.interactions {
      background: var(--xso-bg) !important; border-top: var(--xso-panel-rule) !important;
    }
    html[data-xso-blank][data-xso-style] #noteContainer .engage-bar-container {
      background: var(--xso-panel-bg); border-radius: var(--xso-panel-radius); box-shadow: var(--xso-panel-shadow);
    }
    html[data-xso-blank][data-xso-style] #noteContainer .content-input { border-radius: var(--xso-radius-control) !important; }
    html[data-xso-blank][data-xso-style] #noteContainer .btn.submit {
      background: var(--xso-accent) !important; color: var(--xso-on-accent) !important; border-radius: var(--xso-radius-control) !important;
    }
    html[data-xso-blank][data-xso-style] #noteContainer .btn.cancel { border-radius: var(--xso-radius-control) !important; }
  `,
});

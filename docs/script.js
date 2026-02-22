// =============================================================
//  Sabique — script.js
//  Features: i18n (JP/EN), scroll fade-in, FAQ accordion,
//            smooth scroll, news.json loader
// =============================================================

/* ── i18n Strings ─────────────────────────────────────────── */
const i18n = {
    ja: {
        nav_features: '機能',
        nav_howitworks: '使い方',
        nav_widget: 'ウィジェット',
        nav_community: 'コミュニティ',
        nav_premium: 'Premium',
        nav_news: 'お知らせ',

        hero_eyebrow: 'Apple Music × ハイライト再生',
        hero_title1: '好きな曲の、',
        hero_title2: 'いちばん好きな',
        hero_title3: 'ところだけをつなぐ。',
        hero_sub: 'Sabiqueは、Apple Musicの楽曲からサビ・イントロ・ギターソロなど「推しパート」だけを秒単位で指定し、途切れなく連続再生できる音楽アプリです。',
        hero_req_note: '利用にはApple Musicサブスクリプションが必要です',
        appstore_alt: 'App Storeからダウンロード',

        feat_label: '主な機能',
        feat_title: 'あなただけの最強メドレーを。',
        feat_desc: '聴きたい部分だけを集めた、世界にひとつのプレイリスト。',

        feat1_title: 'サビだけ連続再生',
        feat1_desc: '設定したハイライト区間だけを途切れなく再生。好きな部分の美味しいとこ取りが実現します。',
        feat2_title: '直感的なハイライト指定',
        feat2_desc: '開始・終了位置を秒単位で設定。シークバーを操作するだけで誰でも簡単に設定できます。',
        feat3_title: 'Apple Music完全連携',
        feat3_desc: '1億曲以上のカタログから自由に選んでプレイリストに追加。トップチャートや検索から即追加。',

        hiw_label: '使い方',
        hiw_title: '3ステップではじめよう',
        hiw_desc: '難しい操作は不要。あっという間にあなただけのメドレーが完成します。',
        step1_title: 'プレイリストを作る',
        step1_desc: 'Apple Musicから好きな曲を検索して追加。何曲でもOK。',
        step2_title: 'サビ位置を設定する',
        step2_desc: '各曲の「ここからここまで」を秒単位で指定するだけ。',
        step3_title: '再生して楽しむ',
        step3_desc: '再生ボタンを押せばハイライトだけを次々と再生。気分が上がる！',

        widget_label: 'ウィジェット',
        widget_title: 'ホーム画面から即再生。',
        widget_desc: 'iOSウィジェットに対応。ホーム画面から今聴いている曲を確認したり、ワンタップで再生をコントロール。Small・Medium・Largeの3サイズから選べます。',
        widget_small: 'Small',
        widget_medium: 'Medium',
        widget_large: 'Large',

        com_label: 'コミュニティ',
        com_title: '世界中の音楽センスと出会う。',
        com_desc: 'こだわりのメドレーをコミュニティに公開。人気順・新着順で他のユーザーの作品を発見できます。',
        com1_title: '人気・新着ランキング',
        com1_desc: 'いいね数・ダウンロード数でランキング。話題のメドレーをすぐ発見。',
        com2_title: 'いいね & インポート',
        com2_desc: '気に入ったプレイリストはワンタップでインポート。すぐ再生できます。',
        com3_title: 'プロフィールをカスタマイズ',
        com3_desc: 'ニックネームや国旗を設定して、あなたらしさをアピール。',

        prem_label: 'Sabique Premium',
        prem_title: '無制限で、もっと自由に。',
        prem_desc: '買い切り型のプレミアムプラン。一度購入すれば月額なしで全機能をお楽しみいただけます。',
        prem_free: '無料版',
        prem_premium: 'Sabique Premium',
        prem_row1: 'メドレー再生',
        prem_row2: 'ハイライト指定',
        prem_row3: 'コミュニティ閲覧',
        prem_row4: 'プレイリスト共有',
        prem_row5: 'プレイリスト作成数',
        prem_row5f: '最大2個',
        prem_row5p: '無制限',
        prem_row6: '1プレイリストの曲数',
        prem_row6f: '最大3曲',
        prem_row6p: '無制限',
        prem_row7: 'コミュニティ投稿',
        prem_row7f: '月3回',
        prem_row7p: '月10回',
        prem_row8: 'コミュニティからのインポート',
        prem_row8f: '最大3曲',
        prem_row8p: '全曲',
        prem_row9: '料金',
        prem_row9f: '無料',
        prem_row9p: '買い切り',

        faq_label: 'よくある質問',
        faq_title: 'Q&A',
        faq_desc: 'その他のご不明点は X からお気軽にどうぞ。',
        faqs: [
            { q: '音楽ファイルの用意は必要ですか？', a: 'いいえ、音楽ファイルを用意する必要はありません。Apple Musicのサブスクリプション会員であれば、Apple Music上の楽曲を検索してそのまま利用できます。' },
            { q: '再生範囲は自動で決まりますか？', a: 'ご自身で「開始位置」と「終了位置」を設定していただきます。これにより、あなた好みの完璧なハイライトを作成できます。' },
            { q: 'プレイリストの上限はありますか？', a: '無料版では作成できるプレイリスト数が最大2つ、1つのプレイリストに入れられる曲数が最大3曲に制限されています。Sabique Premium（買い切り）にアップグレードすることで、無制限になります。' },
            { q: 'コミュニティに投稿したプレイリストは削除できますか？', a: 'はい、自分が投稿したプレイリストはいつでも削除できます。プロフィール画面から自分の投稿一覧を確認し、削除が可能です。' },
            { q: 'Sabique Premiumの料金体系はどうなっていますか？', a: '買い切り型（1回購入）の課金プランです。月額料金はかかりません。' },
        ],

        news_label: '最新情報',
        news_title: 'お知らせ',
        news_desc: 'アップデート情報やニュースをお届けします。',
        news_nolink: '',

        req_label: '動作環境',
        req_title: '動作要件',
        req_desc: '快適にご利用いただくために、以下の環境が必要です。',
        req1_label: 'プラットフォーム',
        req1_val: 'iPhone（iPad非対応）',
        req2_label: 'OSバージョン',
        req2_val: 'iOS 18.6 以上',
        req3_label: '必要なサービス',
        req3_val: 'Apple Musicサブスクリプション',

        footer_privacy: 'プライバシーポリシー',
        footer_terms: '利用規約',
        footer_x: 'X でフォロー',
        footer_copy: '© 2025 Sabique. All rights reserved.',
    },

    en: {
        nav_features: 'Features',
        nav_howitworks: 'How It Works',
        nav_widget: 'Widget',
        nav_community: 'Community',
        nav_premium: 'Premium',
        nav_news: 'News',

        hero_eyebrow: 'Apple Music × Highlight Playback',
        hero_title1: 'Play only what',
        hero_title2: 'you love,',
        hero_title3: 'back to back.',
        hero_sub: 'Sabique lets you pick the exact part of each song you love — chorus, intro, guitar solo — and play them all in a seamless medley using Apple Music.',
        hero_req_note: 'Requires an Apple Music subscription',
        appstore_alt: 'Download on the App Store',

        feat_label: 'Features',
        feat_title: 'Your ultimate medley, your way.',
        feat_desc: 'Create a playlist of only the parts you love from any song.',

        feat1_title: 'Seamless Highlight Playback',
        feat1_desc: 'Play only the highlighted sections of each track, one after another — no skipping required.',
        feat2_title: 'Intuitive Highlight Setting',
        feat2_desc: 'Set start and end times to the second. Just scrub the timeline and you\'re done.',
        feat3_title: 'Full Apple Music Integration',
        feat3_desc: 'Choose from 100M+ songs. Search any track or browse Top Charts and add it instantly.',

        hiw_label: 'How It Works',
        hiw_title: 'Get started in 3 steps.',
        hiw_desc: 'No complicated setup — your highlight medley is ready in minutes.',
        step1_title: 'Create a Playlist',
        step1_desc: 'Search Apple Music and add your favorite songs.',
        step2_title: 'Set Your Highlights',
        step2_desc: 'Pick the start and end time for each song — to the second.',
        step3_title: 'Play & Enjoy',
        step3_desc: 'Hit play and enjoy your custom medley in order.',

        widget_label: 'Widget',
        widget_title: 'Control from your Home Screen.',
        widget_desc: 'Sabique supports iOS widgets in Small, Medium, and Large sizes. See what\'s playing and jump right back into your medley without opening the app.',
        widget_small: 'Small',
        widget_medium: 'Medium',
        widget_large: 'Large',

        com_label: 'Community',
        com_title: 'Discover amazing taste worldwide.',
        com_desc: 'Share your highlight playlists with the world. Browse popular or new playlists and find your next obsession.',
        com1_title: 'Popular & New Rankings',
        com1_desc: 'Sorted by likes and downloads — great taste rises to the top.',
        com2_title: 'Like & Import',
        com2_desc: 'Found something great? Import it in one tap and start playing.',
        com3_title: 'Customize Your Profile',
        com3_desc: 'Set a nickname and country flag to show off your personality.',

        prem_label: 'Sabique Premium',
        prem_title: 'Go unlimited.',
        prem_desc: 'A one-time purchase — no subscription. Unlock full access forever.',
        prem_free: 'Free',
        prem_premium: 'Sabique Premium',
        prem_row1: 'Medley Playback',
        prem_row2: 'Highlight Setting',
        prem_row3: 'Browse Community',
        prem_row4: 'Share Playlists',
        prem_row5: 'Playlists',
        prem_row5f: 'Up to 2',
        prem_row5p: 'Unlimited',
        prem_row6: 'Songs per Playlist',
        prem_row6f: 'Up to 3',
        prem_row6p: 'Unlimited',
        prem_row7: 'Community Posts',
        prem_row7f: '3 / month',
        prem_row7p: '10 / month',
        prem_row8: 'Import from Community',
        prem_row8f: 'Up to 3 songs',
        prem_row8p: 'All songs',
        prem_row9: 'Price',
        prem_row9f: 'Free',
        prem_row9p: 'One-time purchase',

        faq_label: 'FAQ',
        faq_title: 'Frequently Asked Questions',
        faq_desc: 'Have more questions? Feel free to reach out on X.',
        faqs: [
            { q: 'Do I need to prepare music files?', a: 'No. As long as you have an Apple Music subscription, you can search and use any song in the Apple Music catalog directly.' },
            { q: 'Are highlights set automatically?', a: 'You set the start and end time yourself. This lets you create the perfect highlight exactly the way you like it.' },
            { q: 'Are there limits on playlists?', a: 'The free tier allows up to 2 playlists with up to 3 songs each. Upgrade to Sabique Premium (one-time purchase) to unlock unlimited playlists and songs.' },
            { q: 'Can I delete a playlist I published to the community?', a: 'Yes, you can delete your own published playlists anytime from your profile page.' },
            { q: 'How is Sabique Premium priced?', a: 'It\'s a one-time purchase — no monthly subscription. Pay once and enjoy full access forever.' },
        ],

        news_label: 'Latest',
        news_title: 'News',
        news_desc: 'Updates and announcements from the Sabique team.',
        news_nolink: '',

        req_label: 'Requirements',
        req_title: 'System Requirements',
        req_desc: 'Make sure your device meets these requirements.',
        req1_label: 'Platform',
        req1_val: 'iPhone (iPad not supported)',
        req2_label: 'OS Version',
        req2_val: 'iOS 18.6 or later',
        req3_label: 'Required Service',
        req3_val: 'Apple Music subscription',

        footer_privacy: 'Privacy Policy',
        footer_terms: 'Terms of Use',
        footer_x: 'Follow on X',
        footer_copy: '© 2025 Sabique. All rights reserved.',
    }
};

/* ── Language ─────────────────────────────────────────────── */
let currentLang = localStorage.getItem('sabique_lang') || 'ja';

function setLang(lang) {
    currentLang = lang;
    localStorage.setItem('sabique_lang', lang);
    render();
    updateLangButtons();
    updateAppStoreBadge();
}

function updateLangButtons() {
    document.querySelectorAll('.lang-btn button').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.lang === currentLang);
    });
}

function updateAppStoreBadge() {
    const src = currentLang === 'ja'
        ? 'https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/ja-jp'
        : 'https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us';
    document.querySelectorAll('.appstore-badge-img').forEach(img => img.src = src);
}

function t(key) { return (i18n[currentLang] || i18n.ja)[key] || key; }

/* ── Render ───────────────────────────────────────────────── */
function render() {
    const s = i18n[currentLang];

    // Nav
    setText('nav-features', s.nav_features);
    setText('nav-howitworks', s.nav_howitworks);
    setText('nav-widget', s.nav_widget);
    setText('nav-community', s.nav_community);
    setText('nav-premium', s.nav_premium);
    setText('nav-news', s.nav_news);

    // Hero
    setText('hero-eyebrow', s.hero_eyebrow);
    setText('hero-title1', s.hero_title1);
    setText('hero-title2', s.hero_title2);
    setText('hero-title3', s.hero_title3);
    setText('hero-sub', s.hero_sub);
    setText('hero-req-note', s.hero_req_note);
    setAttr('appstore-badge-img-hero', 'alt', s.appstore_alt);

    // Features
    setText('feat-label', s.feat_label);
    setText('feat-title', s.feat_title);
    setText('feat-desc', s.feat_desc);
    setText('feat1-title', s.feat1_title); setText('feat1-desc', s.feat1_desc);
    setText('feat2-title', s.feat2_title); setText('feat2-desc', s.feat2_desc);
    setText('feat3-title', s.feat3_title); setText('feat3-desc', s.feat3_desc);

    // How It Works
    setText('hiw-label', s.hiw_label);
    setText('hiw-title', s.hiw_title);
    setText('hiw-desc', s.hiw_desc);
    setText('step1-title', s.step1_title); setText('step1-desc', s.step1_desc);
    setText('step2-title', s.step2_title); setText('step2-desc', s.step2_desc);
    setText('step3-title', s.step3_title); setText('step3-desc', s.step3_desc);

    // Widget
    setText('widget-label', s.widget_label);
    setText('widget-title', s.widget_title);
    setText('widget-desc', s.widget_desc);
    setText('widget-small', s.widget_small);
    setText('widget-medium', s.widget_medium);
    setText('widget-large', s.widget_large);

    // Community
    setText('com-label', s.com_label);
    setText('com-title', s.com_title);
    setText('com-desc', s.com_desc);
    setText('com1-title', s.com1_title); setText('com1-desc', s.com1_desc);
    setText('com2-title', s.com2_title); setText('com2-desc', s.com2_desc);
    setText('com3-title', s.com3_title); setText('com3-desc', s.com3_desc);

    // Premium
    setText('prem-label', s.prem_label);
    setText('prem-title', s.prem_title);
    setText('prem-desc', s.prem_desc);
    setText('prem-free', s.prem_free);
    setText('prem-premium', s.prem_premium);
    setText('prem-row1', s.prem_row1);
    setText('prem-row2', s.prem_row2);
    setText('prem-row3', s.prem_row3);
    setText('prem-row4', s.prem_row4);
    setText('prem-row5', s.prem_row5); setText('prem-row5f', s.prem_row5f); setText('prem-row5p', s.prem_row5p);
    setText('prem-row6', s.prem_row6); setText('prem-row6f', s.prem_row6f); setText('prem-row6p', s.prem_row6p);
    setText('prem-row7', s.prem_row7); setText('prem-row7f', s.prem_row7f); setText('prem-row7p', s.prem_row7p);
    setText('prem-row8', s.prem_row8); setText('prem-row8f', s.prem_row8f); setText('prem-row8p', s.prem_row8p);
    setText('prem-row9', s.prem_row9); setText('prem-row9f', s.prem_row9f); setText('prem-row9p', s.prem_row9p);

    // FAQ
    setText('faq-label', s.faq_label);
    setText('faq-title', s.faq_title);
    setText('faq-desc', s.faq_desc);
    renderFAQ(s.faqs);

    // Requirements
    setText('req-label', s.req_label);
    setText('req-title', s.req_title);
    setText('req-desc', s.req_desc);
    setText('req1-label', s.req1_label); setText('req1-val', s.req1_val);
    setText('req2-label', s.req2_label); setText('req2-val', s.req2_val);
    setText('req3-label', s.req3_label); setText('req3-val', s.req3_val);

    // News
    setText('news-label', s.news_label);
    setText('news-title', s.news_title);
    setText('news-desc', s.news_desc);

    // Footer
    setText('footer-privacy', s.footer_privacy);
    setText('footer-terms', s.footer_terms);
    setText('footer-x', s.footer_x);
    setText('footer-copy', s.footer_copy);

    // Re-render news cards with new lang
    renderNewsCards();
}

function setText(id, text) {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
}

function setAttr(id, attr, val) {
    const el = document.getElementById(id);
    if (el) el.setAttribute(attr, val);
}

/* ── FAQ ──────────────────────────────────────────────────── */
function renderFAQ(faqs) {
    const list = document.getElementById('faq-list');
    if (!list) return;
    list.innerHTML = faqs.map((f, i) => `
    <div class="faq-item fade-in" id="faq-item-${i}">
      <button class="faq-q" onclick="toggleFAQ(${i})">
        <span>${f.q}</span>
        <span class="faq-icon">+</span>
      </button>
      <div class="faq-a">${f.a}</div>
    </div>
  `).join('');
    // Re-observe newly added elements
    observeFadeIns();
}

function toggleFAQ(i) {
    const item = document.getElementById(`faq-item-${i}`);
    if (!item) return;
    const isOpen = item.classList.contains('open');
    document.querySelectorAll('.faq-item.open').forEach(el => el.classList.remove('open'));
    if (!isOpen) item.classList.add('open');
}

/* ── News Loader ──────────────────────────────────────────── */
let newsData = [];

async function loadNews() {
    try {
        const res = await fetch('news.json');
        newsData = await res.json();
    } catch {
        newsData = [];
    }
    renderNewsCards();
}

function renderNewsCards() {
    const container = document.getElementById('news-grid');
    if (!container) return;

    if (newsData.length === 0) {
        container.innerHTML = `<p style="color:var(--text-muted);font-size:0.9rem;">Coming soon...</p>`;
        return;
    }

    container.innerHTML = newsData.map(item => {
        const title = typeof item.title === 'object'
            ? (item.title[currentLang] || item.title['ja'] || '')
            : item.title;
        const dateStr = item.date || '';
        const linkIcon = item.url ? ' <span class="news-link-icon">→</span>' : '';
        const tag = item.url ? 'a' : 'div';
        const href = item.url ? `href="${item.url}" target="_blank" rel="noopener"` : '';
        return `
      <${tag} class="news-card fade-in" ${href}>
        <span class="news-date">${dateStr}</span>
        <span class="news-title">${title}</span>
        ${item.url ? '<span class="news-link-icon">→</span>' : ''}
      </${tag}>
    `;
    }).join('');
    observeFadeIns();
}

/* ── Scroll Fade-in ───────────────────────────────────────── */
function observeFadeIns() {
    const observer = new IntersectionObserver(entries => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
                observer.unobserve(entry.target);
            }
        });
    }, { threshold: 0.12 });

    document.querySelectorAll('.fade-in:not(.is-visible)').forEach(el => observer.observe(el));
}

/* ── Init ─────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
    render();
    updateLangButtons();
    updateAppStoreBadge();
    observeFadeIns();
    loadNews();
});

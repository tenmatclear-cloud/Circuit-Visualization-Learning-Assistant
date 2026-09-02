const APP_LANGUAGE_KEY = "cvla-language";
const CATALOG_URL = "/assets/examples/library/catalog.json";

const translations = {
  "zh-Hant": {
    documentTitle: "範例電路",
    heroEyebrow: "Ready-made classroom examples",
    heroTitle: "範例電路",
    heroCopy: "課堂上即時示範，或自己對比串聯、並聯與綜合。每條都有圖和 Falstad 代碼，不用等待生成。",
    homeLink: "返回主頁",
    introCopy: "投影圖卡即可講。要看電流，按「在主頁模擬」。開關先打開，載入後點一下合上。",
    filterAll: "全部",
    filterSeries: "串聯",
    filterParallel: "並聯",
    filterCombine: "綜合",
    sectionSeries: "串聯",
    sectionParallel: "並聯",
    sectionCombine: "綜合",
    viewCode: "查看 Falstad 代碼",
    copyCode: "複製代碼",
    openSimulator: "在主頁模擬",
    loadFailed: "未能載入範例。請確認已用本地伺服器打開本頁。",
    copiedCode: "已複製電路代碼",
    copyFailed: "複製失敗，請打開代碼後手動選取。",
    noCopy: "這條範例還沒有電路代碼。",
  },
  en: {
    documentTitle: "Example Circuits",
    heroEyebrow: "Ready-made classroom examples",
    heroTitle: "Example Circuits",
    heroCopy:
      "Use these in class right away, or compare series, parallel, and combination circuits. Each card has a diagram and Falstad code. No generation wait.",
    homeLink: "Back to home",
    introCopy: "Project a card to teach. Click Open in simulator to watch the current. The switch starts open; click it after loading.",
    filterAll: "All",
    filterSeries: "Series",
    filterParallel: "Parallel",
    filterCombine: "Combination",
    sectionSeries: "Series",
    sectionParallel: "Parallel",
    sectionCombine: "Combination",
    viewCode: "View Falstad code",
    copyCode: "Copy code",
    openSimulator: "Open in simulator",
    loadFailed: "The examples could not be loaded. Open this page through the local server.",
    copiedCode: "Circuit code copied",
    copyFailed: "Copy failed. Open the code and select it manually.",
    noCopy: "This example has no circuit code yet.",
  },
};

const CATEGORIES = [
  { id: "series", sectionKey: "sectionSeries", filterKey: "filterSeries" },
  { id: "parallel", sectionKey: "sectionParallel", filterKey: "filterParallel" },
  { id: "combine", sectionKey: "sectionCombine", filterKey: "filterCombine" },
];

const els = {
  heroEyebrow: document.getElementById("heroEyebrow"),
  heroTitle: document.getElementById("heroTitle"),
  heroCopy: document.getElementById("heroCopy"),
  introCopy: document.getElementById("introCopy"),
  exampleFilters: document.getElementById("exampleFilters"),
  feedbackText: document.getElementById("feedbackText"),
  exampleLibrary: document.getElementById("exampleLibrary"),
  langZhButton: document.getElementById("langZhButton"),
  langEnButton: document.getElementById("langEnButton"),
};

function normalizeAppLanguage(value) {
  return String(value || "").trim() === "en" ? "en" : "zh-Hant";
}

function readStoredLanguage() {
  return normalizeAppLanguage(localStorage.getItem(APP_LANGUAGE_KEY) || localStorage.getItem("language"));
}

let currentLanguage = readStoredLanguage();
let currentFilter = "all";
let catalog = [];

function t(key) {
  return translations[currentLanguage]?.[key] || translations["zh-Hant"][key] || key;
}

function localized(value) {
  if (!value || typeof value !== "object") {
    return "";
  }

  return value[currentLanguage] || value["zh-Hant"] || value.en || "";
}

function setLanguage(language) {
  currentLanguage = normalizeAppLanguage(language);
  localStorage.setItem(APP_LANGUAGE_KEY, currentLanguage);
  renderLanguage();
}

function setFeedback(message, isError = false) {
  els.feedbackText.textContent = message || "";
  els.feedbackText.classList.toggle("is-error", Boolean(isError && message));
}

function renderLanguage() {
  document.documentElement.lang = currentLanguage === "en" ? "en" : "zh-Hant";
  document.title = t("documentTitle");
  els.heroEyebrow.textContent = t("heroEyebrow");
  els.heroTitle.textContent = t("heroTitle");
  els.heroCopy.textContent = t("heroCopy");
  els.introCopy.textContent = t("introCopy");
  els.langZhButton.classList.toggle("is-active", currentLanguage === "zh-Hant");
  els.langEnButton.classList.toggle("is-active", currentLanguage === "en");
  renderFilters();
  renderLibrary();
}

function renderFilters() {
  const filters = [
    { id: "all", label: t("filterAll") },
    ...CATEGORIES.map((category) => ({ id: category.id, label: t(category.filterKey) })),
  ];

  els.exampleFilters.replaceChildren();
  filters.forEach((filter) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "example-filter";
    button.dataset.filter = filter.id;
    button.textContent = filter.label;
    button.setAttribute("aria-pressed", String(currentFilter === filter.id));
    button.classList.toggle("is-active", currentFilter === filter.id);
    els.exampleFilters.append(button);
  });
}

function examplesForCategory(categoryId) {
  return catalog.filter((example) => example.category === categoryId);
}

function renderLibrary() {
  els.exampleLibrary.replaceChildren();

  CATEGORIES.forEach((category) => {
    if (currentFilter !== "all" && currentFilter !== category.id) {
      return;
    }

    const examples = examplesForCategory(category.id);
    if (!examples.length) {
      return;
    }

    const section = document.createElement("section");
    section.className = "example-section panel";
    section.dataset.category = category.id;

    const header = document.createElement("div");
    header.className = "example-section-header";

    const heading = document.createElement("h2");
    heading.textContent = t(category.sectionKey);

    const homeLink = document.createElement("a");
    homeLink.className = "ghost-button small example-section-home";
    homeLink.href = "./index.html";
    homeLink.textContent = t("homeLink");

    header.append(heading, homeLink);
    section.append(header);

    const grid = document.createElement("div");
    grid.className = "example-grid";
    examples.forEach((example) => {
      grid.append(renderCard(example, category));
    });
    section.append(grid);
    els.exampleLibrary.append(section);
  });
}

function renderCard(example, category) {
  const card = document.createElement("article");
  card.className = "example-card";
  card.dataset.exampleId = example.id;

  const badge = document.createElement("p");
  badge.className = "example-badge";
  badge.textContent = t(category.filterKey);

  const title = document.createElement("h3");
  title.textContent = localized(example.title);

  const figure = document.createElement("figure");
  figure.className = "example-figure";
  const image = document.createElement("img");
  image.src = example.image;
  image.alt = localized(example.title);
  figure.append(image);

  const copy = document.createElement("p");
  copy.className = "example-copy";
  copy.textContent = localized(example.description);

  const details = document.createElement("details");
  details.className = "example-code";
  const summary = document.createElement("summary");
  summary.textContent = t("viewCode");
  const pre = document.createElement("pre");
  const code = document.createElement("code");
  code.textContent = example.falstadCode || "";
  pre.append(code);
  details.append(summary, pre);

  const actions = document.createElement("div");
  actions.className = "example-actions";

  const copyButton = document.createElement("button");
  copyButton.type = "button";
  copyButton.className = "ghost-button small";
  copyButton.dataset.copyId = example.id;
  copyButton.textContent = t("copyCode");

  const openLink = document.createElement("a");
  openLink.className = "primary-button small";
  openLink.href = `./index.html?example=${encodeURIComponent(example.id)}`;
  openLink.textContent = t("openSimulator");

  actions.append(copyButton, openLink);
  card.append(badge, title, figure, copy, details, actions);
  return card;
}

function copyWithFallback(text) {
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.left = "-9999px";
  document.body.append(textarea);
  textarea.select();
  const ok = document.execCommand("copy");
  textarea.remove();
  if (!ok) {
    throw new Error("execCommand copy failed");
  }
}

async function copyExampleCode(exampleId) {
  const example = catalog.find((item) => item.id === exampleId);
  const code = example?.falstadCode?.trim();
  if (!code) {
    setFeedback(t("noCopy"), true);
    return;
  }

  const payload = code.endsWith("\n") ? code : `${code}\n`;

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(payload);
    } else {
      copyWithFallback(payload);
    }
    setFeedback(t("copiedCode"));
  } catch (error) {
    try {
      copyWithFallback(payload);
      setFeedback(t("copiedCode"));
    } catch (fallbackError) {
      console.error(error, fallbackError);
      setFeedback(t("copyFailed"), true);
    }
  }
}

async function loadCatalog() {
  const response = await fetch(CATALOG_URL, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Catalog HTTP ${response.status}`);
  }

  const data = await response.json();
  const examples = Array.isArray(data.examples) ? data.examples : [];

  catalog = await Promise.all(
    examples.map(async (example) => {
      if (!example.circuit) {
        return { ...example, falstadCode: "" };
      }

      const circuitResponse = await fetch(example.circuit, { cache: "no-store" });
      if (!circuitResponse.ok) {
        throw new Error(`Circuit HTTP ${circuitResponse.status} for ${example.id}`);
      }

      const falstadCode = (await circuitResponse.text()).replace(/\r\n/g, "\n").trim();
      return { ...example, falstadCode };
    })
  );
}

els.langZhButton.addEventListener("click", () => setLanguage("zh-Hant"));
els.langEnButton.addEventListener("click", () => setLanguage("en"));
els.exampleFilters.addEventListener("click", (event) => {
  const button = event.target.closest("[data-filter]");
  if (!button) {
    return;
  }

  currentFilter = button.dataset.filter;
  renderFilters();
  renderLibrary();
});
els.exampleLibrary.addEventListener("click", (event) => {
  const button = event.target.closest("[data-copy-id]");
  if (button) {
    copyExampleCode(button.dataset.copyId);
  }
});

renderLanguage();

loadCatalog()
  .then(() => {
    setFeedback("");
    renderLibrary();
  })
  .catch((error) => {
    console.error(error);
    setFeedback(t("loadFailed"), true);
  });

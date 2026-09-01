const APP_CONFIG = {
  generateEndpoint: "/api/generate",
  healthEndpoint: "/api/health",
  defaultLanguage: "zh-Hant",
  uploadImageMaxDimension: 1280,
  maxUploadBytes: 8 * 1024 * 1024,
  allowedImageTypes: ["image/png", "image/jpeg", "image/webp"],
  simulatorSources: {
    "zh-Hant": "/circuit/circuitjs-zh-tw.html?lang=zh-tw&startCircuit=blank.txt&whiteBackground=false",
    en: "/circuit/circuitjs.html?lang=en&startCircuit=blank.txt&whiteBackground=false",
  },
  teachingCurrentSpeed: 40,
  teachingFalstadHeader: "$ 1 0.000005 10.20027730826997 40 5 43",
};

const translations = {
  "zh-Hant": {
    heroEyebrow: "Series / Parallel Learning Studio",
    heroTitle: "電路視覺化教學助手",
    heroCopy: "用文字或電路圖片生成電路，再觀察電流、電壓與串聯／並聯的分別。",
    step1Label: "開始",
    inputSectionTitle: "輸入需求",
    promptLabel: "文字需求",
    promptPlaceholder: "例如：請設計一個由兩個電阻組成的串聯電路，並加入一個短路變形圖供比較。",
    promptModePill: "使用文字",
    clearPromptButton: "清除文字",
    imageLabel: "電路圖圖片（可選）",
    imageModePill: "使用圖片",
    removeImageButton: "移除圖片",
    generateCircuitButton: "生成電路",
    generateGuideButton: "生成教學指引",
    generateTutorButton: "生成解題教學",
    stopGenerationButton: "停止生成",
    exampleButton: "載入示例",
    helperText: "輸入需求或上載題目圖片，按「生成電路」。電路會自動出現在右側，可直接觀察電流與電壓。",
    step2Label: "進階",
    codeSectionTitle: "電路代碼",
    copyCodeButton: "複製",
    loadToFalstadButton: "載入右側模擬器",
    falstadCodePlaceholder: "生成後的電路代碼會顯示在這裡，一般不必打開。",
    step3Label: "觀察",
    guideSectionTitle: "教學指引",
    copyGuideButton: "複製",
    teachingGuidePlaceholder: "觀察重點與操作建議會顯示在這裡。",
    step4Label: "進階",
    tutorSectionTitle: "解題教學草稿",
    copyTutorButton: "複製",
    tutorPlaceholder: "引導式提問與教學流程會顯示在這裡。",
    stepRawLabel: "進階",
    rawSectionTitle: "除錯輸出",
    copyRawButton: "複製",
    rawOutputPlaceholder: "生成失敗時才需要打開這裡。",
    step5Label: "模擬器",
    simulatorTitle: "電路模擬",
    presentButton: "課堂展示",
    exitPresentButton: "離開展示",
    simulatorToolsSummary: "進階：模擬器工具",
    overlayTitle: "本地 Falstad 尚未成功載入",
    overlayBody:
      "此專案已內建本地 CircuitJS1 runtime。若右側仍未顯示模擬器，通常是因為你直接雙擊 index.html 開啟，或本地伺服器尚未啟動。",
    overlayItem1: "請先用 serve.command 或 ruby server.rb 啟動專案。",
    overlayItem2: "確認網址是 http://localhost:8080。",
    overlayItem3: "重新整理本頁。",
    overlayTip: "如果仍未載入，請檢查 falstad/circuitjs.html 是否存在，並重新啟動本地 server。",
    healthMissingKey: "後端已啟動，但尚未設定 Poe API key。請在 server-config.local.json 填入金鑰後重新啟動。",
    healthUnreachable: "未能連上本地後端。請用 serve.command 或 ruby server.rb 啟動，再開 http://localhost:8080。",
    refreshSimulatorButton: "重新檢查模擬器",
    exportCodeButton: "從右側匯出目前電路",
    flowTitle: "模擬器簡易操作",
    flowItem1: "黃色小點代表電流方向；可在右側「電流速度」再調慢，方便看清楚。",
    flowItem2: "顏色深淺代表電壓高低。",
    flowItem3: "若線路歪了或接錯，用滑鼠拖曳元件或接線端點改正，不必改左側代碼。",
    flowItem4: "右鍵可刪除接錯的線；開關可以直接點擊開合。",
    flowItem5: "觀察串聯是否只有一條路徑，並聯是否在分岔後分開。",
    apiStatus: {
      idle: "尚未生成",
      loading: "生成中",
      success: "生成完成",
      error: "生成失敗",
    },
    simulatorStatus: {
      waiting: "等待載入",
      checking: "檢查中",
      connected: "已連線",
      notFound: "未找到",
      loaded: "已載入新電路",
    },
    feedback: {
      needInput: "請先輸入文字需求，或上載一張電路圖。",
      needCode: "請先生成電路，再進行這一步。",
      generatingCircuit: "正在生成電路...",
      generatingGuide: "正在生成觀察指引...",
      generatingTutor: "正在生成解題教學...",
      canceling: "正在停止目前生成...",
      canceled: "生成已停止。",
      generatedCircuit: "電路已出現在右側，可觀察電流與電壓。若佈局歪了，直接在模擬器裡拖曳修正。",
      generatedGuide: "教學指引已準備好，可配合右側模擬器觀察。",
      generatedTutor: "解題教學已準備好，可作為課堂提問流程。",
      generateFailed: "生成失敗：",
      invalidImageType: "只接受 PNG、JPEG 或 WebP 圖片。",
      imageTooLarge: "圖片太大，請改用 8MB 以下的檔案。",
      imageReadFailed: "無法讀取這張圖片，請改選另一個檔案。",
      emptyCircuit: "生成完成，但沒有可用的電路。請再試一次。",
      noCopy: "目前沒有可複製的內容。",
      copiedCode: "已複製電路代碼",
      copiedGuide: "已複製教學指引",
      copiedTutor: "已複製解題教學草稿",
      copiedRaw: "已複製除錯輸出",
      copyFailed: "複製失敗，請手動選取文字。",
      noFalstadCode: "目前還沒有電路可載入。",
      simulatorNotReady: "右側模擬器尚未準備好，請稍等一下再試。",
      simulatorLoaded: "電路已出現在右側模擬器。",
      simulatorLoadFailed: "載入失敗，請再生成一次，或在模擬器裡手動調整線路。",
      simulatorExportUnavailable: "目前未能從右側模擬器取得資料。",
      simulatorExported: "已把右側電路匯出到進階代碼框",
      simulatorExportFailed: "匯出失敗。",
    },
    examplePrompt:
      "請設計一個簡單電路：包含一個 9V 電池、一個開關，以及兩個串聯的電阻。佈局要清晰，方便學生觀察電流路徑與電壓變化。除非必要，請不要加入文字標籤。",
  },
  en: {
    heroEyebrow: "Series / Parallel Learning Studio",
    heroTitle: "Circuit Visualization Learning Assistant",
    heroCopy:
      "Generate a circuit from text or a photo, then watch current, voltage, and the difference between series and parallel.",
    step1Label: "Start",
    inputSectionTitle: "Input Request",
    promptLabel: "Text Request",
    promptPlaceholder:
      "Example: Design a circuit with two resistors in series, and include one short-circuit variation for comparison.",
    promptModePill: "Using text",
    clearPromptButton: "Clear text",
    imageLabel: "Circuit Image (Optional)",
    imageModePill: "Using image",
    removeImageButton: "Remove image",
    generateCircuitButton: "Generate Circuit",
    generateGuideButton: "Generate Guide",
    generateTutorButton: "Generate Tutor",
    stopGenerationButton: "Stop",
    exampleButton: "Load Example",
    helperText:
      "Enter a request or upload a question image, then click Generate Circuit. The circuit will appear on the right so you can watch current and voltage.",
    step2Label: "Advanced",
    codeSectionTitle: "Circuit Code",
    copyCodeButton: "Copy",
    loadToFalstadButton: "Load Into Simulator",
    falstadCodePlaceholder: "Generated circuit code appears here. You usually do not need to open this.",
    step3Label: "Observe",
    guideSectionTitle: "Teaching Guide",
    copyGuideButton: "Copy",
    teachingGuidePlaceholder: "Observation points and teaching suggestions will appear here.",
    step4Label: "Advanced",
    tutorSectionTitle: "Tutoring Draft",
    copyTutorButton: "Copy",
    tutorPlaceholder: "Guided questions and teaching flow will appear here.",
    stepRawLabel: "Advanced",
    rawSectionTitle: "Debug Output",
    copyRawButton: "Copy",
    rawOutputPlaceholder: "Open this only if generation fails.",
    step5Label: "Simulator",
    simulatorTitle: "Circuit Simulation",
    presentButton: "Present to Class",
    exitPresentButton: "Exit Presentation",
    simulatorToolsSummary: "Advanced: simulator tools",
    overlayTitle: "Local Falstad Is Not Ready Yet",
    overlayBody:
      "This project already includes a local CircuitJS1 runtime. If the simulator is still not visible on the right, you probably opened index.html directly or the local server is not running.",
    overlayItem1: "Start the project with serve.command or ruby server.rb first.",
    overlayItem2: "Make sure the URL is http://localhost:8080.",
    overlayItem3: "Refresh this page.",
    overlayTip: "If it still does not load, confirm falstad/circuitjs.html exists and restart the local server.",
    healthMissingKey: "The backend is running, but no Poe API key is configured. Add it in server-config.local.json and restart.",
    healthUnreachable: "The local backend is not reachable. Start it with serve.command or ruby server.rb, then open http://localhost:8080.",
    refreshSimulatorButton: "Recheck Simulator",
    exportCodeButton: "Export Current Circuit",
    flowTitle: "How to use the simulator",
    flowItem1: "Yellow dots show current direction. Use Current Speed on the right if the dots move too fast.",
    flowItem2: "Color shading shows voltage level.",
    flowItem3: "If the layout is crooked or a wire is wrong, drag the part or the wire end. You do not need to edit code.",
    flowItem4: "Right-click to delete a wrong wire. Click a switch to open or close it.",
    flowItem5: "In series, look for a single path. In parallel, look for the current splitting at a branch.",
    apiStatus: {
      idle: "Not generated",
      loading: "Generating",
      success: "Generated",
      error: "Failed",
    },
    simulatorStatus: {
      waiting: "Waiting",
      checking: "Checking",
      connected: "Connected",
      notFound: "Not Found",
      loaded: "Circuit Loaded",
    },
    feedback: {
      needInput: "Please enter a text request or upload a circuit image first.",
      needCode: "Please generate a circuit first before running this step.",
      generatingCircuit: "Generating the circuit...",
      generatingGuide: "Generating the observation guide...",
      generatingTutor: "Generating the tutoring draft...",
      canceling: "Stopping the current generation...",
      canceled: "Generation stopped.",
      generatedCircuit: "The circuit is on the right. Watch the current and voltage. If the layout looks off, drag the parts in the simulator.",
      generatedGuide: "The teaching guide is ready. Use it with the simulator on the right.",
      generatedTutor: "The tutoring draft is ready to use as a lesson flow.",
      generateFailed: "Generation failed: ",
      invalidImageType: "Only PNG, JPEG, or WebP images are accepted.",
      imageTooLarge: "The image is too large. Please use a file smaller than 8MB.",
      imageReadFailed: "This image could not be read. Please choose another file.",
      emptyCircuit: "Generation finished, but no usable circuit was returned. Please try again.",
      noCopy: "There is nothing to copy yet.",
      copiedCode: "Circuit code copied",
      copiedGuide: "Teaching guide copied",
      copiedTutor: "Tutoring draft copied",
      copiedRaw: "Debug output copied",
      copyFailed: "Copy failed. Please select the text manually.",
      noFalstadCode: "There is no circuit to load yet.",
      simulatorNotReady: "The simulator is not ready yet. Please wait a moment and try again.",
      simulatorLoaded: "The circuit is now in the simulator.",
      simulatorLoadFailed: "Import failed. Try generating again, or adjust the wires in the simulator.",
      simulatorExportUnavailable: "Unable to read data from the simulator right now.",
      simulatorExported: "The current circuit has been exported to the advanced code box.",
      simulatorExportFailed: "Export failed.",
    },
    examplePrompt:
      "Please design a simple circuit with one 9V battery, one switch, and two resistors in series. Keep the layout clear so students can observe current flow and voltage changes. Avoid text labels unless they are truly necessary.",
  },
};

const els = {
  heroEyebrow: document.getElementById("heroEyebrow"),
  heroTitle: document.getElementById("heroTitle"),
  heroCopy: document.getElementById("heroCopy"),
  langZhButton: document.getElementById("langZhButton"),
  langEnButton: document.getElementById("langEnButton"),
  step1Label: document.getElementById("step1Label"),
  inputSectionTitle: document.getElementById("inputSectionTitle"),
  promptLabel: document.getElementById("promptLabel"),
  promptField: document.getElementById("promptField"),
  promptModePill: document.getElementById("promptModePill"),
  clearPromptButton: document.getElementById("clearPromptButton"),
  userPrompt: document.getElementById("userPrompt"),
  imageLabel: document.getElementById("imageLabel"),
  imageField: document.getElementById("imageField"),
  imageModePill: document.getElementById("imageModePill"),
  imageInput: document.getElementById("imageInput"),
  imagePreviewWrap: document.getElementById("imagePreviewWrap"),
  imagePreview: document.getElementById("imagePreview"),
  removeImageButton: document.getElementById("removeImageButton"),
  generateCircuitButton: document.getElementById("generateCircuitButton"),
  generateGuideButton: document.getElementById("generateGuideButton"),
  generateTutorButton: document.getElementById("generateTutorButton"),
  stopGenerationButton: document.getElementById("stopGenerationButton"),
  exampleButton: document.getElementById("exampleButton"),
  feedbackText: document.getElementById("feedbackText"),
  apiStatus: document.getElementById("apiStatus"),
  step2Label: document.getElementById("step2Label"),
  codeSectionTitle: document.getElementById("codeSectionTitle"),
  codeDetails: document.getElementById("codeDetails"),
  falstadCode: document.getElementById("falstadCode"),
  copyCodeButton: document.getElementById("copyCodeButton"),
  loadToFalstadButton: document.getElementById("loadToFalstadButton"),
  step3Label: document.getElementById("step3Label"),
  guideSectionTitle: document.getElementById("guideSectionTitle"),
  guideDetails: document.getElementById("guideDetails"),
  teachingGuide: document.getElementById("teachingGuide"),
  copyGuideButton: document.getElementById("copyGuideButton"),
  step4Label: document.getElementById("step4Label"),
  tutorSectionTitle: document.getElementById("tutorSectionTitle"),
  tutorDetails: document.getElementById("tutorDetails"),
  tutorOutput: document.getElementById("tutorOutput"),
  copyTutorButton: document.getElementById("copyTutorButton"),
  stepRawLabel: document.getElementById("stepRawLabel"),
  rawSectionTitle: document.getElementById("rawSectionTitle"),
  rawDetails: document.getElementById("rawDetails"),
  rawAiOutput: document.getElementById("rawAiOutput"),
  copyRawButton: document.getElementById("copyRawButton"),
  step5Label: document.getElementById("step5Label"),
  simulatorTitle: document.getElementById("simulatorTitle"),
  presentButton: document.getElementById("presentButton"),
  exitPresentButton: document.getElementById("exitPresentButton"),
  simulatorToolsSummary: document.getElementById("simulatorToolsSummary"),
  falstadFrame: document.getElementById("falstadFrame"),
  simulatorStatus: document.getElementById("simulatorStatus"),
  simulatorOverlay: document.getElementById("simulatorOverlay"),
  overlayTitle: document.getElementById("overlayTitle"),
  overlayBody: document.getElementById("overlayBody"),
  overlayItem1: document.getElementById("overlayItem1"),
  overlayItem2: document.getElementById("overlayItem2"),
  overlayItem3: document.getElementById("overlayItem3"),
  overlayTip: document.getElementById("overlayTip"),
  refreshSimulatorButton: document.getElementById("refreshSimulatorButton"),
  exportCodeButton: document.getElementById("exportCodeButton"),
  flowTitle: document.getElementById("flowTitle"),
  flowItem1: document.getElementById("flowItem1"),
  flowItem2: document.getElementById("flowItem2"),
  flowItem3: document.getElementById("flowItem3"),
  flowItem4: document.getElementById("flowItem4"),
  flowItem5: document.getElementById("flowItem5"),
  healthBanner: document.getElementById("healthBanner"),
};

const APP_LANGUAGE_KEY = "cvla-language";

function normalizeAppLanguage(value) {
  return String(value || "").trim() === "en" ? "en" : "zh-Hant";
}

function readStoredLanguage() {
  return normalizeAppLanguage(localStorage.getItem(APP_LANGUAGE_KEY) || localStorage.getItem("language"));
}

let currentLanguage = readStoredLanguage();
let uploadedImageDataUrl = "";
let falstadSim = null;
let simulatorPollTimer = null;
let currentFeedbackKey = "helperText";
let currentLoadingTask = null;
let activeJobId = "";
let stopRequested = false;
let activeRequestController = null;
let generationSessionId = 0;
let healthBannerKey = "";
let isPresenting = false;
let pendingConnectDefaults = false;
const JOB_POLL_INTERVAL_MS = 2000;
const JOB_POLL_MAX_ATTEMPTS = 150;
const JOB_POLL_NETWORK_RETRIES = 3;

els.langZhButton.addEventListener("click", () => setLanguage("zh-Hant"));
els.langEnButton.addEventListener("click", () => setLanguage("en"));
els.imageInput.addEventListener("change", handleImageUpload);
els.removeImageButton.addEventListener("click", clearImage);
els.clearPromptButton.addEventListener("click", clearPrompt);
els.userPrompt.addEventListener("input", syncInputModes);
els.exampleButton.addEventListener("click", fillExample);
els.generateCircuitButton.addEventListener("click", () => runGenerationTask("circuit"));
els.generateGuideButton.addEventListener("click", (event) => {
  preventSummaryToggle(event);
  runGenerationTask("guide");
});
els.generateTutorButton.addEventListener("click", (event) => {
  preventSummaryToggle(event);
  runGenerationTask("tutor");
});
els.stopGenerationButton.addEventListener("click", stopGenerationTask);
els.copyCodeButton.addEventListener("click", (event) => {
  preventSummaryToggle(event);
  copyText(els.falstadCode.value, t("feedback.copiedCode"));
});
els.copyGuideButton.addEventListener("click", (event) => {
  preventSummaryToggle(event);
  copyText(els.teachingGuide.value, t("feedback.copiedGuide"));
});
els.copyTutorButton.addEventListener("click", (event) => {
  preventSummaryToggle(event);
  copyText(els.tutorOutput.value, t("feedback.copiedTutor"));
});
els.copyRawButton.addEventListener("click", (event) => {
  preventSummaryToggle(event);
  copyText(els.rawAiOutput.value, t("feedback.copiedRaw"));
});
els.loadToFalstadButton.addEventListener("click", () => importIntoFalstad());
els.refreshSimulatorButton.addEventListener("click", refreshSimulatorConnection);
els.exportCodeButton.addEventListener("click", exportFromFalstad);
els.presentButton.addEventListener("click", () => setPresenting(true));
els.exitPresentButton.addEventListener("click", () => setPresenting(false));
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && isPresenting) {
    setPresenting(false);
  }
});
els.falstadFrame.addEventListener("load", refreshSimulatorConnection);

function t(path) {
  return path.split(".").reduce((value, key) => value?.[key], translations[currentLanguage]) || path;
}

function preventSummaryToggle(event) {
  event.preventDefault();
  event.stopPropagation();
}

function setDetailsOpen(detailsEl, open) {
  if (detailsEl) {
    detailsEl.open = Boolean(open);
  }
}

function setPresenting(nextPresenting) {
  isPresenting = Boolean(nextPresenting);
  document.body.classList.toggle("is-presenting", isPresenting);
  els.presentButton.setAttribute("aria-pressed", String(isPresenting));
}

function setLanguage(language) {
  currentLanguage = normalizeAppLanguage(language);
  localStorage.setItem(APP_LANGUAGE_KEY, currentLanguage);
  renderLanguage();
  syncSimulatorLanguage();
}

function renderLanguage() {
  document.documentElement.lang = currentLanguage === "en" ? "en" : "zh-Hant";
  document.title = t("heroTitle");
  els.heroEyebrow.textContent = t("heroEyebrow");
  els.heroTitle.textContent = t("heroTitle");
  els.heroCopy.textContent = t("heroCopy");
  els.step1Label.textContent = t("step1Label");
  els.inputSectionTitle.textContent = t("inputSectionTitle");
  els.promptLabel.textContent = t("promptLabel");
  els.userPrompt.placeholder = t("promptPlaceholder");
  els.promptModePill.textContent = t("promptModePill");
  els.clearPromptButton.textContent = t("clearPromptButton");
  els.imageLabel.textContent = t("imageLabel");
  els.imageModePill.textContent = t("imageModePill");
  els.removeImageButton.textContent = t("removeImageButton");
  syncInputModes();
  refreshActionButtons();
  els.stopGenerationButton.textContent = t("stopGenerationButton");
  els.exampleButton.textContent = t("exampleButton");
  els.step2Label.textContent = t("step2Label");
  els.codeSectionTitle.textContent = t("codeSectionTitle");
  els.copyCodeButton.textContent = t("copyCodeButton");
  els.loadToFalstadButton.textContent = t("loadToFalstadButton");
  els.falstadCode.placeholder = t("falstadCodePlaceholder");
  els.step3Label.textContent = t("step3Label");
  els.guideSectionTitle.textContent = t("guideSectionTitle");
  els.copyGuideButton.textContent = t("copyGuideButton");
  els.teachingGuide.placeholder = t("teachingGuidePlaceholder");
  els.step4Label.textContent = t("step4Label");
  els.tutorSectionTitle.textContent = t("tutorSectionTitle");
  els.copyTutorButton.textContent = t("copyTutorButton");
  els.tutorOutput.placeholder = t("tutorPlaceholder");
  els.stepRawLabel.textContent = t("stepRawLabel");
  els.rawSectionTitle.textContent = t("rawSectionTitle");
  els.copyRawButton.textContent = t("copyRawButton");
  els.rawAiOutput.placeholder = t("rawOutputPlaceholder");
  els.step5Label.textContent = t("step5Label");
  els.simulatorTitle.textContent = t("simulatorTitle");
  els.presentButton.textContent = t("presentButton");
  els.exitPresentButton.textContent = t("exitPresentButton");
  els.simulatorToolsSummary.textContent = t("simulatorToolsSummary");
  els.overlayTitle.textContent = t("overlayTitle");
  els.overlayBody.textContent = t("overlayBody");
  els.overlayItem1.textContent = t("overlayItem1");
  els.overlayItem2.textContent = t("overlayItem2");
  els.overlayItem3.textContent = t("overlayItem3");
  els.overlayTip.textContent = t("overlayTip");
  els.refreshSimulatorButton.textContent = t("refreshSimulatorButton");
  els.exportCodeButton.textContent = t("exportCodeButton");
  els.flowTitle.textContent = t("flowTitle");
  els.flowItem1.textContent = t("flowItem1");
  els.flowItem2.textContent = t("flowItem2");
  els.flowItem3.textContent = t("flowItem3");
  els.flowItem4.textContent = t("flowItem4");
  els.flowItem5.textContent = t("flowItem5");
  els.langZhButton.classList.toggle("is-active", currentLanguage === "zh-Hant");
  els.langEnButton.classList.toggle("is-active", currentLanguage === "en");

  if (currentFeedbackKey === "helperText") {
    setFeedback(t("helperText"), false, "helperText");
  }

  if (healthBannerKey) {
    setHealthBanner(t(healthBannerKey), true);
  }
}

function fillExample() {
  els.userPrompt.value = t("examplePrompt");
  syncInputModes();
}

function clearPrompt() {
  els.userPrompt.value = "";
  els.userPrompt.focus();
  syncInputModes();
}

function syncInputModes() {
  const hasText = els.userPrompt.value.trim() !== "";
  const hasImage = Boolean(uploadedImageDataUrl);

  els.promptField.classList.toggle("is-active", hasText);
  els.promptField.classList.toggle("is-idle", hasImage && !hasText);
  els.imageField.classList.toggle("is-active", hasImage);
  els.imageField.classList.toggle("is-idle", hasText && !hasImage);

  els.promptModePill.classList.toggle("hidden", !hasText);
  els.imageModePill.classList.toggle("hidden", !hasImage);
  els.clearPromptButton.classList.toggle("hidden", !hasText);
}

function handleImageUpload(event) {
  const [file] = event.target.files || [];
  if (!file) {
    clearImage();
    return;
  }

  if (!APP_CONFIG.allowedImageTypes.includes(file.type)) {
    clearImage();
    setFeedback(t("feedback.invalidImageType"), true);
    setApiStatus("error");
    return;
  }

  if (file.size > APP_CONFIG.maxUploadBytes) {
    clearImage();
    setFeedback(t("feedback.imageTooLarge"), true);
    setApiStatus("error");
    return;
  }

  optimizeImageForUpload(file)
    .catch(async (error) => {
      console.warn("Image optimization failed, falling back to the original upload.", error);
      return readFileAsDataUrl(file);
    })
    .then((dataUrl) => {
      uploadedImageDataUrl = typeof dataUrl === "string" ? dataUrl : "";
      els.imagePreview.src = uploadedImageDataUrl;
      els.imagePreviewWrap.classList.remove("hidden");
      syncInputModes();
    })
    .catch((error) => {
      console.error(error);
      clearImage();
      setFeedback(t("feedback.imageReadFailed"), true);
      setApiStatus("error");
    });
}

function clearImage() {
  uploadedImageDataUrl = "";
  els.imageInput.value = "";
  els.imagePreview.src = "";
  els.imagePreviewWrap.classList.add("hidden");
  syncInputModes();
}

function normalizeGeneratedText(value, preserveNewlines = false) {
  if (typeof value !== "string") {
    return "";
  }

  const normalized = value
    .replace(/\\r\\n/g, "\n")
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\r\n/g, "\n")
    .trim();

  return preserveNewlines ? normalized : normalized.replace(/\n{3,}/g, "\n\n");
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(typeof reader.result === "string" ? reader.result : "");
    reader.onerror = () => reject(reader.error || new Error("Unable to read the selected image."));
    reader.readAsDataURL(file);
  });
}

function loadImageElement(dataUrl) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("Unable to decode the uploaded image."));
    image.src = dataUrl;
  });
}

function scaleImageSize(width, height, maxDimension) {
  if (!width || !height || Math.max(width, height) <= maxDimension) {
    return { width, height };
  }

  const scale = maxDimension / Math.max(width, height);
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

function supportedUploadType(fileType) {
  return ["image/png", "image/jpeg", "image/webp"].includes(fileType) ? fileType : "image/png";
}

async function optimizeImageForUpload(file) {
  const originalDataUrl = await readFileAsDataUrl(file);
  const image = await loadImageElement(originalDataUrl);
  const naturalWidth = image.naturalWidth || image.width;
  const naturalHeight = image.naturalHeight || image.height;
  const { width, height } = scaleImageSize(naturalWidth, naturalHeight, APP_CONFIG.uploadImageMaxDimension);

  if (width === naturalWidth && height === naturalHeight) {
    return originalDataUrl;
  }

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");

  if (!context) {
    return originalDataUrl;
  }

  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = "high";
  context.drawImage(image, 0, 0, width, height);

  return canvas.toDataURL(supportedUploadType(file.type), 0.92);
}

function clearTaskOutputs(task) {
  els.rawAiOutput.value = "";

  if (task === "circuit") {
    els.falstadCode.value = "";
    els.teachingGuide.value = "";
    els.tutorOutput.value = "";
  } else if (task === "guide") {
    els.teachingGuide.value = "";
  } else if (task === "tutor") {
    els.tutorOutput.value = "";
  }
}

async function runGenerationTask(task) {
  const promptText = els.userPrompt.value.trim();
  const falstadCode = normalizeGeneratedText(els.falstadCode.value, true);

  if (task === "circuit" && !promptText && !uploadedImageDataUrl) {
    setFeedback(t("feedback.needInput"), true);
    setApiStatus("error");
    return;
  }

  if ((task === "guide" || task === "tutor") && !falstadCode) {
    setFeedback(t("feedback.needCode"), true);
    setApiStatus("error");
    return;
  }

  const sessionId = generationSessionId + 1;
  generationSessionId = sessionId;
  setLoadingState(task, true);
  stopRequested = false;
  activeJobId = "";
  activeRequestController = new AbortController();
  setFeedback(t(`feedback.generating${capitalizeTask(task)}`), false);
  clearTaskOutputs(task);

  try {
    const startResponse = await fetch(APP_CONFIG.generateEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        task,
        promptText,
        imageDataUrl: uploadedImageDataUrl,
        outputLanguage: currentLanguage,
        falstadCode,
      }),
      signal: activeRequestController.signal,
    });

    const startPayload = await startResponse.json().catch(() => ({}));

    if (!startResponse.ok && startResponse.status !== 202) {
      const error = new Error(startPayload.error || `API request failed with status ${startResponse.status}`);
      error.rawOutput = startPayload.raw_output || "";
      throw error;
    }

    if (sessionId !== generationSessionId) {
      return;
    }

    activeJobId = startPayload.job_id || "";
    const payload = await pollGenerationJob(activeJobId, sessionId);

    if (sessionId !== generationSessionId) {
      return;
    }

    const rawOutput = payload.raw_output || "";
    els.rawAiOutput.value = rawOutput;

    if (payload.status === "canceled") {
      setFeedback(t("feedback.canceled"), false);
      setApiStatus("idle");
      return;
    }

    if (task === "circuit") {
      const generatedCode = normalizeGeneratedText(payload.falstad_code, true);
      if (!generatedCode) {
        throw new Error(t("feedback.emptyCircuit"));
      }

      els.falstadCode.value = generatedCode;
      els.teachingGuide.value = "";
      els.tutorOutput.value = "";
      setDetailsOpen(els.guideDetails, false);
      setDetailsOpen(els.tutorDetails, false);
      setDetailsOpen(els.rawDetails, false);
      importIntoFalstad({ silent: true });
    } else if (task === "guide") {
      els.teachingGuide.value = normalizeGeneratedText(payload.teaching_guide || payload.guide, true);
      setDetailsOpen(els.guideDetails, true);
    } else if (task === "tutor") {
      els.tutorOutput.value = normalizeGeneratedText(payload.tutor_response || payload.tutor_output, true);
      setDetailsOpen(els.tutorDetails, true);
    }

    setFeedback(t(`feedback.generated${capitalizeTask(task)}`), false);
    setApiStatus("success");
  } catch (error) {
    if (sessionId !== generationSessionId) {
      return;
    }

    if (stopRequested || error?.name === "AbortError") {
      setFeedback(t("feedback.canceled"), false);
      setApiStatus("idle");
      return;
    }

    console.error(error);
    if (!els.rawAiOutput.value && error.rawOutput) {
      els.rawAiOutput.value = error.rawOutput;
    }
    setDetailsOpen(els.rawDetails, true);
    setFeedback(`${t("feedback.generateFailed")}${translateBackendError(readableErrorMessage(error))}`, true);
    setApiStatus("error");
  } finally {
    if (sessionId !== generationSessionId) {
      return;
    }

    activeJobId = "";
    activeRequestController = null;
    stopRequested = false;
    setLoadingState(task, false);
  }
}

function wait(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

async function pollGenerationJob(jobId, sessionId) {
  if (!jobId) {
    throw new Error("生成工作沒有回傳 job id。");
  }

  for (let attempt = 0; attempt < JOB_POLL_MAX_ATTEMPTS; attempt += 1) {
    if (stopRequested || sessionId !== generationSessionId) {
      return { status: "canceled" };
    }

    await wait(attempt === 0 ? 0 : JOB_POLL_INTERVAL_MS);

    if (stopRequested || sessionId !== generationSessionId) {
      return { status: "canceled" };
    }

    let response;
    let networkFailures = 0;

    while (networkFailures <= JOB_POLL_NETWORK_RETRIES) {
      try {
        response = await fetch(APP_CONFIG.generateEndpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ jobId }),
          signal: activeRequestController?.signal,
        });
        break;
      } catch (error) {
        if (error?.name === "AbortError" || stopRequested || sessionId !== generationSessionId) {
          return { status: "canceled" };
        }

        networkFailures += 1;
        if (networkFailures > JOB_POLL_NETWORK_RETRIES) {
          throw error;
        }

        await wait(1000 * networkFailures);
      }
    }

    const payload = await response.json().catch(() => ({}));

    if (!response.ok) {
      const error = new Error(payload.error || `API request failed with status ${response.status}`);
      error.rawOutput = payload.raw_output || "";
      throw error;
    }

    if (sessionId !== generationSessionId) {
      return { status: "canceled" };
    }

    if (payload.raw_output) {
      els.rawAiOutput.value = payload.raw_output;
    }

    if (payload.status === "completed") {
      return payload;
    }

    if (payload.status === "canceled") {
      return payload;
    }

    if (payload.status === "failed") {
      const error = new Error(payload.error || "生成工作失敗。");
      error.rawOutput = payload.raw_output || "";
      throw error;
    }
  }

  throw new Error("生成工作等待逾時，請稍後再試。");
}

async function stopGenerationTask() {
  if (!currentLoadingTask) {
    return;
  }

  const sessionId = generationSessionId;
  const jobId = activeJobId;
  stopRequested = true;
  els.stopGenerationButton.disabled = true;
  setFeedback(t("feedback.canceling"), false);

  if (activeRequestController) {
    activeRequestController.abort();
  }

  if (jobId) {
    try {
      await fetch(APP_CONFIG.generateEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ cancelJobId: jobId }),
      });
    } catch (error) {
      console.warn("Unable to cancel the backend job.", error);
    }
  }

  if (sessionId !== generationSessionId) {
    return;
  }

  setFeedback(t("feedback.canceled"), false);
  setApiStatus("idle");
}

function translateBackendError(message) {
  if (currentLanguage === "zh-Hant") {
    if (message === "Failed to fetch") {
      return "網絡連線中斷，通常表示伺服器處理複雜請求時被平台中途切斷。現在系統已改用背景工作模式；請重新整理後再試一次。";
    }

    return message;
  }

  const knownTranslations = {
    "請提供文字需求或圖片。": "Please provide a text request or an image.",
    "請先生成或貼上 Falstad 代碼，再進行這一步。": "Please generate or paste Falstad code first before running this step.",
    "找不到這個生成工作，請重新開始。": "This generation job could not be found. Please start again.",
    "生成工作沒有回傳 job id。": "The generation job did not return a job id.",
    "生成工作等待逾時，請稍後再試。": "The generation job took too long to finish. Please try again shortly.",
    "Failed to fetch":
      "The network connection was interrupted, usually because the server connection was cut before a response completed. Refresh the page and try again.",
    "圖片格式無法解析，請重新上載。": "The image format could not be parsed. Please upload it again.",
    "只接受 PNG、JPEG 或 WebP 圖片。": "Only PNG, JPEG, or WebP images are accepted.",
    "圖片太大，請改用較小的檔案或先裁切後再上載。": "The image is too large. Please use a smaller file or crop it first.",
    "AI 沒有回傳文字內容，請再試一次。": "The AI returned no text. Please try again.",
    "AI 沒有回傳 Falstad 代碼，請再試一次。": "The AI returned no Falstad code. Please try again.",
    "AI 沒有回傳教學指引，請再試一次。": "The AI returned no teaching guide. Please try again.",
    "AI 沒有回傳解題教學內容，請再試一次。": "The AI returned no tutoring content. Please try again.",
    "AI 回應不是有效 JSON，請再按一次 Generate。": "The AI response was not valid JSON. Please click Generate again.",
    "AI 回應過長，系統已自動改用更精簡版本重試，但仍未完成。請把需求拆細一點，或先生成較簡單的單一電路。":
      "The AI response was too long. The system already retried with a more compact version, but it still did not complete. Please simplify the request or generate a single simple circuit first.",
  };

  return knownTranslations[message] || message;
}

function setFeedback(message, isError, feedbackKey = null) {
  currentFeedbackKey = feedbackKey || "runtime";
  els.feedbackText.textContent = message;
  els.feedbackText.style.color = isError ? "#a8451b" : "";
}

function setHealthBanner(message, visible) {
  if (!els.healthBanner) {
    return;
  }

  els.healthBanner.textContent = message;
  els.healthBanner.hidden = !visible;
  els.healthBanner.classList.toggle("hidden", !visible);
}

async function checkBackendHealth() {
  try {
    const response = await fetch(APP_CONFIG.healthEndpoint, { method: "GET" });
    const payload = await response.json().catch(() => ({}));

    if (!response.ok || !payload.ok) {
      healthBannerKey = "healthUnreachable";
      setHealthBanner(t(healthBannerKey), true);
      return;
    }

    if (!payload.has_api_key) {
      healthBannerKey = "healthMissingKey";
      setHealthBanner(t(healthBannerKey), true);
      return;
    }

    healthBannerKey = "";
    setHealthBanner("", false);
  } catch (error) {
    healthBannerKey = "healthUnreachable";
    setHealthBanner(t(healthBannerKey), true);
  }
}

function setApiStatus(state) {
  els.apiStatus.textContent = t(`apiStatus.${state}`);
}

function setSimulatorStatus(state) {
  els.simulatorStatus.textContent = t(`simulatorStatus.${state}`);
}

function capitalizeTask(task) {
  return task.charAt(0).toUpperCase() + task.slice(1);
}

function refreshActionButtons() {
  const buttonMap = {
    circuit: els.generateCircuitButton,
    guide: els.generateGuideButton,
    tutor: els.generateTutorButton,
  };

  Object.entries(buttonMap).forEach(([task, button]) => {
    if (!button) {
      return;
    }

    const label = t(`generate${capitalizeTask(task)}Button`);
    button.textContent = currentLoadingTask === task ? `${label}...` : label;
  });
}

function setLoadingState(task, isLoading) {
  currentLoadingTask = isLoading ? task : null;
  els.generateCircuitButton.disabled = isLoading;
  els.generateGuideButton.disabled = isLoading;
  els.generateTutorButton.disabled = isLoading;
  els.stopGenerationButton.classList.toggle("hidden", !isLoading);
  els.stopGenerationButton.disabled = !isLoading;
  refreshActionButtons();
  if (isLoading) {
    setApiStatus("loading");
  }
}

function readableErrorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

async function copyText(text, successMessage) {
  if (!text.trim()) {
    setFeedback(t("feedback.noCopy"), true);
    return;
  }

  try {
    await navigator.clipboard.writeText(text);
    setFeedback(successMessage, false);
  } catch (error) {
    console.error(error);
    setFeedback(t("feedback.copyFailed"), true);
  }
}

function readCurrentSpeed(dump) {
  const source = String(dump || "");
  const xmlMatch = source.match(/\bcb="(\d+)"/);
  if (xmlMatch) {
    return Number(xmlMatch[1]);
  }

  const headerMatch = source.match(/^\$\s+\S+\s+\S+\s+\S+\s+(\S+)/m);
  if (headerMatch) {
    return Number(headerMatch[1]);
  }

  return null;
}

function withTeachingCurrentSpeed(code) {
  const source = normalizeGeneratedText(code, true);
  if (!source) {
    return APP_CONFIG.teachingFalstadHeader;
  }

  if (/<cir[\s>]/.test(source)) {
    if (/\bcb="\d+"/.test(source)) {
      return source.replace(/\bcb="\d+"/, `cb="${APP_CONFIG.teachingCurrentSpeed}"`);
    }

    return source.replace(/<cir\b/, `<cir cb="${APP_CONFIG.teachingCurrentSpeed}"`);
  }

  const lines = source.split("\n");
  const headerIndex = lines.findIndex((line) => line.trim().startsWith("$"));

  if (headerIndex === -1) {
    return `${APP_CONFIG.teachingFalstadHeader}\n${source}`;
  }

  const tokens = lines[headerIndex].trim().split(/\s+/);
  if (tokens.length >= 5 && tokens[0] === "$") {
    tokens[4] = String(APP_CONFIG.teachingCurrentSpeed);
    lines[headerIndex] = tokens.join(" ");
    return lines.join("\n");
  }

  lines[headerIndex] = APP_CONFIG.teachingFalstadHeader;
  return lines.join("\n");
}

function applyTeachingDefaultsAfterConnect(attempt = 0) {
  if (!falstadSim || typeof falstadSim.importCircuit !== "function") {
    if (attempt < 16) {
      window.setTimeout(() => applyTeachingDefaultsAfterConnect(attempt + 1), 250);
    }
    return;
  }

  const existing = normalizeGeneratedText(els.falstadCode.value, true);
  if (existing) {
    importIntoFalstad({ silent: true });
    return;
  }

  try {
    const current = typeof falstadSim.exportCircuit === "function" ? falstadSim.exportCircuit() : "";
    const source = normalizeGeneratedText(current, true);
    if (!source && attempt < 16) {
      window.setTimeout(() => applyTeachingDefaultsAfterConnect(attempt + 1), 250);
      return;
    }

    falstadSim.importCircuit(source ? withTeachingCurrentSpeed(source) : APP_CONFIG.teachingFalstadHeader, false);

    window.setTimeout(() => {
      if (normalizeGeneratedText(els.falstadCode.value, true)) {
        return;
      }

      const applied = readCurrentSpeed(falstadSim.exportCircuit?.() || "");
      if (applied !== APP_CONFIG.teachingCurrentSpeed && attempt < 8) {
        applyTeachingDefaultsAfterConnect(attempt + 1);
      }
    }, 400);
  } catch (error) {
    if (attempt < 16) {
      window.setTimeout(() => applyTeachingDefaultsAfterConnect(attempt + 1), 250);
      return;
    }

    console.warn("Unable to apply teaching current speed.", error);
  }
}

function refreshSimulatorConnection() {
  falstadSim = null;
  pendingConnectDefaults = true;
  setSimulatorStatus("checking");
  setSimulatorOverlay(true);

  if (simulatorPollTimer) {
    window.clearInterval(simulatorPollTimer);
    simulatorPollTimer = null;
  }

  try {
    const frameWindow = els.falstadFrame.contentWindow;
    if (!frameWindow) {
      throw new Error("Unable to access iframe.");
    }

    const markConnected = (simulator) => {
      falstadSim = simulator || frameWindow.CircuitJS1 || null;
      if (!falstadSim) {
        return false;
      }

      setSimulatorOverlay(false);
      setSimulatorStatus("connected");

      if (simulatorPollTimer) {
        window.clearInterval(simulatorPollTimer);
        simulatorPollTimer = null;
      }

      if (pendingConnectDefaults) {
        pendingConnectDefaults = false;
        applyTeachingDefaultsAfterConnect();
      }

      return true;
    };

    frameWindow.oncircuitjsloaded = (simulator) => {
      markConnected(simulator);
    };

    if (markConnected(frameWindow.CircuitJS1)) {
      return;
    }

    let attempts = 0;
    simulatorPollTimer = window.setInterval(() => {
      attempts += 1;

      if (markConnected(frameWindow.CircuitJS1)) {
        return;
      }

      if (attempts >= 40) {
        window.clearInterval(simulatorPollTimer);
        simulatorPollTimer = null;
        setSimulatorOverlay(true);
        setSimulatorStatus("notFound");
      }
    }, 500);
  } catch (error) {
    setSimulatorOverlay(true);
    setSimulatorStatus("notFound");
  }
}

function syncSimulatorLanguage() {
  const targetSrc =
    APP_CONFIG.simulatorSources[currentLanguage] || APP_CONFIG.simulatorSources[APP_CONFIG.defaultLanguage];

  if (els.falstadFrame.getAttribute("src") !== targetSrc) {
    els.falstadFrame.setAttribute("src", targetSrc);
  } else {
    refreshSimulatorConnection();
  }
}

function setSimulatorOverlay(visible) {
  els.simulatorOverlay.hidden = !visible;
  els.simulatorOverlay.classList.toggle("hidden", !visible);
  els.simulatorOverlay.style.display = visible ? "flex" : "none";
}

function getFalstadSim() {
  try {
    return els.falstadFrame.contentWindow?.CircuitJS1 || falstadSim;
  } catch (error) {
    return falstadSim;
  }
}

function prepareCircuitText(rawCode) {
  const stripped = normalizeGeneratedText(rawCode, true)
    .replace(/^```(?:falstad|text|plaintext)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  if (!stripped) {
    return "";
  }

  const prepared = withTeachingCurrentSpeed(stripped);
  return prepared.endsWith("\n") ? prepared : `${prepared}\n`;
}

function importIntoFalstad({ silent = false } = {}) {
  const original = els.falstadCode.value;
  const code = prepareCircuitText(original);
  if (!code.trim()) {
    if (!silent) {
      setFeedback(t("feedback.noFalstadCode"), true);
    }
    return;
  }

  els.falstadCode.value = code.trim();

  const simulator = getFalstadSim();
  falstadSim = simulator;

  if (!simulator || typeof simulator.importCircuit !== "function") {
    if (!silent) {
      setFeedback(t("feedback.simulatorNotReady"), true);
    }
    return;
  }

  try {
    simulator.importCircuit(code, false);
    setSimulatorStatus("loaded");
    if (!silent) {
      setFeedback(t("feedback.simulatorLoaded"), false);
    }
  } catch (error) {
    console.error(error);
    try {
      const fallback = normalizeGeneratedText(original, true);
      simulator.importCircuit(`${fallback}\n`, false);
      els.falstadCode.value = fallback;
      setSimulatorStatus("loaded");
      if (!silent) {
        setFeedback(t("feedback.simulatorLoaded"), false);
      }
    } catch (retryError) {
      console.error(retryError);
      if (!silent) {
        setFeedback(t("feedback.simulatorLoadFailed"), true);
      }
    }
  }
}

async function exportFromFalstad() {
  if (!falstadSim || typeof falstadSim.exportCircuit !== "function") {
    setFeedback(t("feedback.simulatorExportUnavailable"), true);
    return;
  }

  try {
    const exported = falstadSim.exportCircuit();
    els.falstadCode.value = exported;
    await copyText(exported, t("feedback.simulatorExported"));
  } catch (error) {
    console.error(error);
    setFeedback(t("feedback.simulatorExportFailed"), true);
  }
}

renderLanguage();
setApiStatus("idle");
setSimulatorStatus("waiting");
setFeedback(t("helperText"), false, "helperText");
syncSimulatorLanguage();
checkBackendHealth();

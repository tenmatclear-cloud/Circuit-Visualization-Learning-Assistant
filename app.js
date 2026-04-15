const APP_CONFIG = {
  generateEndpoint: "/api/generate",
  defaultLanguage: "zh-Hant",
  simulatorSources: {
    "zh-Hant": "/circuit/circuitjs-zh-tw.html?whiteBackground=false",
    en: "/circuit/circuitjs.html?whiteBackground=false",
  },
};

const translations = {
  "zh-Hant": {
    heroEyebrow: "Series / Parallel Learning Studio",
    heroTitle: "電路視覺化教學助手",
    heroCopy: "讓學生用文字或電路圖片生成 Falstad 專用代碼，再配合動態模擬觀察串聯、並聯與短路特徵。",
    chipAi: "AI 生成",
    chipSim: "Falstad 模擬",
    chipGuide: "教學引導",
    step1Label: "Step 1",
    inputSectionTitle: "輸入需求",
    promptLabel: "文字需求",
    promptPlaceholder: "例如：請設計一個由兩個電阻組成的串聯電路，並加入一個短路變形圖供比較。",
    imageLabel: "電路圖圖片（可選）",
    removeImageButton: "移除圖片",
    generateButton: "Generate",
    exampleButton: "載入示例",
    helperText: "生成後，系統會把 Falstad 專用代碼、教學指引與 Raw AI Output 填到下方輸出框。",
    step2Label: "Step 2",
    codeSectionTitle: "Falstad 專用代碼",
    copyCodeButton: "複製",
    loadToFalstadButton: "載入右側模擬器",
    falstadCodePlaceholder: "AI 生成的 Falstad 匯入代碼會顯示在這裡。",
    step3Label: "Step 3",
    guideSectionTitle: "Falstad 視覺化教學指引",
    copyGuideButton: "複製",
    teachingGuidePlaceholder: "AI 生成的觀察重點與操作建議會顯示在這裡。",
    stepRawLabel: "Debug",
    rawSectionTitle: "Raw AI Output",
    copyRawButton: "複製",
    rawOutputPlaceholder: "無論 AI 回傳什麼，原始文字都會顯示在這裡，方便排錯。",
    step4Label: "Step 4",
    simulatorTitle: "Falstad Circuit Simulation",
    overlayTitle: "本地 Falstad 尚未成功載入",
    overlayBody:
      "此專案已內建本地 CircuitJS1 runtime。若右側仍未顯示模擬器，通常是因為你直接雙擊 index.html 開啟，或本地伺服器尚未啟動。",
    overlayItem1: "請先用 serve.command 或 ruby server.rb 啟動專案。",
    overlayItem2: "確認網址是 http://localhost:8080。",
    overlayItem3: "重新整理本頁。",
    overlayTip: "如果仍未載入，請檢查 falstad/circuitjs.html 是否存在，並重新啟動本地 server。",
    refreshSimulatorButton: "重新檢查模擬器",
    exportCodeButton: "從右側匯出目前電路",
    flowTitle: "學生建議流程",
    flowItem1: "在左側輸入電路需求或上載題目圖片。",
    flowItem2: "按下 Generate 取得 Falstad 代碼與教學指引。",
    flowItem3: "按 載入右側模擬器，或手動貼到 Falstad 匯入。",
    flowItem4: "觀察黃色小圓點、綠色電壓深淺與分岔位置，進行推理。",
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
      generating: "本地後端正在請求 AI，整理 Falstad 代碼與教學指引...",
      generated: "生成完成，可以直接複製或載入右側 Falstad 模擬器。",
      generateFailed: "生成失敗：",
      noCopy: "目前沒有可複製的內容。",
      copiedCode: "已複製 Falstad 代碼",
      copiedGuide: "已複製教學指引",
      copiedRaw: "已複製原始 AI 輸出",
      copyFailed: "複製失敗，請手動選取文字。",
      noFalstadCode: "目前沒有可匯入的 Falstad 代碼。",
      simulatorNotReady: "右側 Falstad 尚未完成連線，請先確認本地模擬器已載入。",
      simulatorLoaded: "Falstad 代碼已載入右側模擬器。",
      simulatorLoadFailed: "載入失敗，請檢查產生的 Falstad 代碼格式。",
      simulatorExportUnavailable: "目前未能從右側 Falstad 取得資料。",
      simulatorExported: "已把右側電路匯出到左側代碼框",
      simulatorExportFailed: "匯出失敗。",
    },
    guideHeaders: {
      analysis: "【電路設計與拓撲結構分析】",
      teachingGuide: "【Falstad 視覺化教學指引】",
    },
    examplePrompt:
      "請設計三個放在同一畫布上的電路：第一個是兩個電阻串聯，第二個是兩個電阻並聯，第三個是在第二個電路其中一個分支加入短路導線。請為每個圖加上文字標籤，方便學生比較。",
  },
  en: {
    heroEyebrow: "Series / Parallel Learning Studio",
    heroTitle: "Circuit Visualization Learning Assistant",
    heroCopy:
      "Generate Falstad-ready circuit code from text or circuit images, then learn series, parallel, and short-circuit behavior through dynamic simulation.",
    chipAi: "AI Generate",
    chipSim: "Falstad Sim",
    chipGuide: "Teaching Guide",
    step1Label: "Step 1",
    inputSectionTitle: "Input Request",
    promptLabel: "Text Request",
    promptPlaceholder:
      "Example: Design a circuit with two resistors in series, and include one short-circuit variation for comparison.",
    imageLabel: "Circuit Image (Optional)",
    removeImageButton: "Remove image",
    generateButton: "Generate",
    exampleButton: "Load Example",
    helperText:
      "After generation, the Falstad code, teaching guide, and raw AI output will appear in the output boxes below.",
    step2Label: "Step 2",
    codeSectionTitle: "Falstad Code",
    copyCodeButton: "Copy",
    loadToFalstadButton: "Load Into Simulator",
    falstadCodePlaceholder: "AI-generated Falstad import code will appear here.",
    step3Label: "Step 3",
    guideSectionTitle: "Falstad Teaching Guide",
    copyGuideButton: "Copy",
    teachingGuidePlaceholder: "AI-generated observation points and teaching suggestions will appear here.",
    stepRawLabel: "Debug",
    rawSectionTitle: "Raw AI Output",
    copyRawButton: "Copy",
    rawOutputPlaceholder: "Whatever the AI returns will appear here for debugging.",
    step4Label: "Step 4",
    simulatorTitle: "Falstad Circuit Simulation",
    overlayTitle: "Local Falstad Is Not Ready Yet",
    overlayBody:
      "This project already includes a local CircuitJS1 runtime. If the simulator is still not visible on the right, you probably opened index.html directly or the local server is not running.",
    overlayItem1: "Start the project with serve.command or ruby server.rb first.",
    overlayItem2: "Make sure the URL is http://localhost:8080.",
    overlayItem3: "Refresh this page.",
    overlayTip: "If it still does not load, confirm falstad/circuitjs.html exists and restart the local server.",
    refreshSimulatorButton: "Recheck Simulator",
    exportCodeButton: "Export Current Circuit",
    flowTitle: "Suggested Student Flow",
    flowItem1: "Enter a circuit request or upload a question image on the left.",
    flowItem2: "Click Generate to get Falstad code and the teaching guide.",
    flowItem3: "Click Load Into Simulator, or paste the code manually into Falstad.",
    flowItem4: "Observe the moving current dots, voltage colors, and branch points to reason it out.",
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
      generating: "The local backend is asking the AI to prepare Falstad code and a teaching guide...",
      generated: "Generation completed. You can now copy the result or load it into the simulator.",
      generateFailed: "Generation failed: ",
      noCopy: "There is nothing to copy yet.",
      copiedCode: "Falstad code copied",
      copiedGuide: "Teaching guide copied",
      copiedRaw: "Raw AI output copied",
      copyFailed: "Copy failed. Please select the text manually.",
      noFalstadCode: "There is no Falstad code to import yet.",
      simulatorNotReady: "The Falstad simulator is not connected yet. Please make sure the local simulator has loaded.",
      simulatorLoaded: "The Falstad code has been loaded into the simulator.",
      simulatorLoadFailed: "Import failed. Please check the generated Falstad code format.",
      simulatorExportUnavailable: "Unable to read data from the Falstad simulator right now.",
      simulatorExported: "The current circuit has been exported to the code box.",
      simulatorExportFailed: "Export failed.",
    },
    guideHeaders: {
      analysis: "[Circuit Topology Analysis]",
      teachingGuide: "[Falstad Teaching Guide]",
    },
    examplePrompt:
      "Please create three circuits on the same canvas: the first with two resistors in series, the second with two resistors in parallel, and the third with a short-circuit wire added across one branch of the second circuit. Add text labels for each diagram so students can compare them.",
  },
};

const els = {
  heroEyebrow: document.getElementById("heroEyebrow"),
  heroTitle: document.getElementById("heroTitle"),
  heroCopy: document.getElementById("heroCopy"),
  chipAi: document.getElementById("chipAi"),
  chipSim: document.getElementById("chipSim"),
  chipGuide: document.getElementById("chipGuide"),
  langZhButton: document.getElementById("langZhButton"),
  langEnButton: document.getElementById("langEnButton"),
  step1Label: document.getElementById("step1Label"),
  inputSectionTitle: document.getElementById("inputSectionTitle"),
  promptLabel: document.getElementById("promptLabel"),
  userPrompt: document.getElementById("userPrompt"),
  imageLabel: document.getElementById("imageLabel"),
  imageInput: document.getElementById("imageInput"),
  imagePreviewWrap: document.getElementById("imagePreviewWrap"),
  imagePreview: document.getElementById("imagePreview"),
  removeImageButton: document.getElementById("removeImageButton"),
  generateButton: document.getElementById("generateButton"),
  exampleButton: document.getElementById("exampleButton"),
  feedbackText: document.getElementById("feedbackText"),
  apiStatus: document.getElementById("apiStatus"),
  step2Label: document.getElementById("step2Label"),
  codeSectionTitle: document.getElementById("codeSectionTitle"),
  falstadCode: document.getElementById("falstadCode"),
  copyCodeButton: document.getElementById("copyCodeButton"),
  loadToFalstadButton: document.getElementById("loadToFalstadButton"),
  step3Label: document.getElementById("step3Label"),
  guideSectionTitle: document.getElementById("guideSectionTitle"),
  teachingGuide: document.getElementById("teachingGuide"),
  copyGuideButton: document.getElementById("copyGuideButton"),
  stepRawLabel: document.getElementById("stepRawLabel"),
  rawSectionTitle: document.getElementById("rawSectionTitle"),
  rawAiOutput: document.getElementById("rawAiOutput"),
  copyRawButton: document.getElementById("copyRawButton"),
  step4Label: document.getElementById("step4Label"),
  simulatorTitle: document.getElementById("simulatorTitle"),
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
};

let currentLanguage = localStorage.getItem("language") || APP_CONFIG.defaultLanguage;
let uploadedImageDataUrl = "";
let falstadSim = null;
let simulatorPollTimer = null;
let currentFeedbackKey = "helperText";

els.langZhButton.addEventListener("click", () => setLanguage("zh-Hant"));
els.langEnButton.addEventListener("click", () => setLanguage("en"));
els.imageInput.addEventListener("change", handleImageUpload);
els.removeImageButton.addEventListener("click", clearImage);
els.exampleButton.addEventListener("click", fillExample);
els.generateButton.addEventListener("click", generateCircuitMaterials);
els.copyCodeButton.addEventListener("click", () => copyText(els.falstadCode.value, t("feedback.copiedCode")));
els.copyGuideButton.addEventListener("click", () => copyText(els.teachingGuide.value, t("feedback.copiedGuide")));
els.copyRawButton.addEventListener("click", () => copyText(els.rawAiOutput.value, t("feedback.copiedRaw")));
els.loadToFalstadButton.addEventListener("click", importIntoFalstad);
els.refreshSimulatorButton.addEventListener("click", refreshSimulatorConnection);
els.exportCodeButton.addEventListener("click", exportFromFalstad);
els.falstadFrame.addEventListener("load", refreshSimulatorConnection);

function t(path) {
  return path.split(".").reduce((value, key) => value?.[key], translations[currentLanguage]) || path;
}

function setLanguage(language) {
  currentLanguage = language;
  localStorage.setItem("language", language);
  renderLanguage();
  syncSimulatorLanguage();
}

function renderLanguage() {
  els.heroEyebrow.textContent = t("heroEyebrow");
  els.heroTitle.textContent = t("heroTitle");
  els.heroCopy.textContent = t("heroCopy");
  els.chipAi.textContent = t("chipAi");
  els.chipSim.textContent = t("chipSim");
  els.chipGuide.textContent = t("chipGuide");
  els.step1Label.textContent = t("step1Label");
  els.inputSectionTitle.textContent = t("inputSectionTitle");
  els.promptLabel.textContent = t("promptLabel");
  els.userPrompt.placeholder = t("promptPlaceholder");
  els.imageLabel.textContent = t("imageLabel");
  els.removeImageButton.textContent = t("removeImageButton");
  els.generateButton.textContent = t("generateButton");
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
  els.stepRawLabel.textContent = t("stepRawLabel");
  els.rawSectionTitle.textContent = t("rawSectionTitle");
  els.copyRawButton.textContent = t("copyRawButton");
  els.rawAiOutput.placeholder = t("rawOutputPlaceholder");
  els.step4Label.textContent = t("step4Label");
  els.simulatorTitle.textContent = t("simulatorTitle");
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
  els.langZhButton.classList.toggle("is-active", currentLanguage === "zh-Hant");
  els.langEnButton.classList.toggle("is-active", currentLanguage === "en");

  if (currentFeedbackKey === "helperText") {
    setFeedback(t("helperText"), false, "helperText");
  }
}

function fillExample() {
  els.userPrompt.value = t("examplePrompt");
}

function handleImageUpload(event) {
  const [file] = event.target.files || [];
  if (!file) {
    clearImage();
    return;
  }

  const reader = new FileReader();
  reader.onload = () => {
    uploadedImageDataUrl = typeof reader.result === "string" ? reader.result : "";
    els.imagePreview.src = uploadedImageDataUrl;
    els.imagePreviewWrap.classList.remove("hidden");
  };
  reader.readAsDataURL(file);
}

function clearImage() {
  uploadedImageDataUrl = "";
  els.imageInput.value = "";
  els.imagePreview.src = "";
  els.imagePreviewWrap.classList.add("hidden");
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

async function generateCircuitMaterials() {
  const promptText = els.userPrompt.value.trim();

  if (!promptText && !uploadedImageDataUrl) {
    setFeedback(t("feedback.needInput"), true);
    setApiStatus("error");
    return;
  }

  setLoadingState(true);
  setFeedback(t("feedback.generating"), false);
  els.falstadCode.value = "";
  els.teachingGuide.value = "";
  els.rawAiOutput.value = "";

  try {
    const response = await fetch(APP_CONFIG.generateEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        promptText,
        imageDataUrl: uploadedImageDataUrl,
      }),
    });

    const payload = await response.json().catch(() => ({}));
    const rawOutput = payload.raw_output || "";
    els.rawAiOutput.value = rawOutput;

    if (!response.ok) {
      const error = new Error(payload.error || `API request failed with status ${response.status}`);
      error.rawOutput = rawOutput;
      throw error;
    }

    els.falstadCode.value = normalizeGeneratedText(payload.falstad_code, true);
    els.teachingGuide.value = joinGuide(
      normalizeGeneratedText(payload.analysis),
      normalizeGeneratedText(payload.teaching_guide)
    );
    setFeedback(t("feedback.generated"), false);
    setApiStatus("success");
  } catch (error) {
    console.error(error);
    if (!els.rawAiOutput.value && error.rawOutput) {
      els.rawAiOutput.value = error.rawOutput;
    }
    setFeedback(`${t("feedback.generateFailed")}${translateBackendError(readableErrorMessage(error))}`, true);
    setApiStatus("error");
  } finally {
    setLoadingState(false);
  }
}

function translateBackendError(message) {
  if (currentLanguage === "zh-Hant") {
    return message;
  }

  const knownTranslations = {
    "請提供文字需求或圖片。": "Please provide a text request or an image.",
    "圖片格式無法解析，請重新上載。": "The image format could not be parsed. Please upload it again.",
    "AI 沒有回傳文字內容，請再試一次。": "The AI returned no text. Please try again.",
    "AI 回應不是有效 JSON，請再按一次 Generate。": "The AI response was not valid JSON. Please click Generate again.",
    "Google API 連線中斷。": "The Google API connection was interrupted.",
    "Google API 連線失敗。": "The Google API connection failed.",
  };

  return knownTranslations[message] || message;
}

function joinGuide(analysis, teachingGuide) {
  const sections = [];

  if (analysis) {
    sections.push(`${t("guideHeaders.analysis")}\n${analysis.trim()}`);
  }

  if (teachingGuide) {
    sections.push(`${t("guideHeaders.teachingGuide")}\n${teachingGuide.trim()}`);
  }

  return sections.join("\n\n");
}

function setFeedback(message, isError, feedbackKey = null) {
  currentFeedbackKey = feedbackKey || "runtime";
  els.feedbackText.textContent = message;
  els.feedbackText.style.color = isError ? "#a8451b" : "";
}

function setApiStatus(state) {
  els.apiStatus.textContent = t(`apiStatus.${state}`);
}

function setSimulatorStatus(state) {
  els.simulatorStatus.textContent = t(`simulatorStatus.${state}`);
}

function setLoadingState(isLoading) {
  els.generateButton.disabled = isLoading;
  els.generateButton.textContent = isLoading ? `${t("generateButton")}...` : t("generateButton");
  setApiStatus(isLoading ? "loading" : "idle");
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

function refreshSimulatorConnection() {
  falstadSim = null;
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

function importIntoFalstad() {
  const code = normalizeGeneratedText(els.falstadCode.value, true);
  if (!code) {
    setFeedback(t("feedback.noFalstadCode"), true);
    return;
  }

  els.falstadCode.value = code;

  if (!falstadSim || typeof falstadSim.importCircuit !== "function") {
    setFeedback(t("feedback.simulatorNotReady"), true);
    return;
  }

  try {
    falstadSim.importCircuit(code, false);
    setSimulatorStatus("loaded");
    setFeedback(t("feedback.simulatorLoaded"), false);
  } catch (error) {
    console.error(error);
    setFeedback(t("feedback.simulatorLoadFailed"), true);
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

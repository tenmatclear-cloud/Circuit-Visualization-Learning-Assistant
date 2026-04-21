const APP_CONFIG = {
  generateEndpoint: "/api/generate",
  defaultLanguage: "zh-Hant",
  uploadImageMaxDimension: 1280,
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
    generateCircuitButton: "生成電路代碼",
    generateGuideButton: "生成教學指引",
    generateTutorButton: "生成解題教學",
    exampleButton: "載入示例",
    helperText: "先用 Step 2 生成與修改 Falstad 專用代碼；代碼成功後，再分開生成教學指引與解題教學。",
    step2Label: "Step 2",
    codeSectionTitle: "Falstad 專用代碼",
    copyCodeButton: "複製",
    loadToFalstadButton: "載入右側模擬器",
    falstadCodePlaceholder: "AI 生成的 Falstad 匯入代碼會顯示在這裡。",
    step3Label: "Step 3",
    guideSectionTitle: "Falstad 視覺化教學指引",
    copyGuideButton: "複製",
    teachingGuidePlaceholder: "AI 生成的觀察重點與操作建議會顯示在這裡。",
    step4Label: "Step 4",
    tutorSectionTitle: "引導式解題教學草稿",
    copyTutorButton: "複製",
    tutorPlaceholder: "AI 生成的引導式提問、教學步驟與常見迷思會顯示在這裡。",
    stepRawLabel: "Debug",
    rawSectionTitle: "Raw AI Output",
    copyRawButton: "複製",
    rawOutputPlaceholder: "無論 AI 回傳什麼，原始文字都會顯示在這裡，方便排錯。",
    step5Label: "Step 5",
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
    flowItem2: "先按「生成電路代碼」取得 Falstad 代碼，並視需要在 Step 2 直接修改。",
    flowItem3: "按「載入右側模擬器」，確認電路可以成功匯入與模擬。",
    flowItem4: "電路穩定後，再按「生成教學指引」或「生成解題教學」。",
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
      needCode: "請先成功生成或貼上 Falstad 代碼，再進行這一步。",
      generatingCircuit: "本地後端正在請求 AI 生成 Falstad 專用代碼...",
      generatingGuide: "本地後端正在根據 Falstad 代碼生成教學指引...",
      generatingTutor: "本地後端正在根據 Falstad 代碼生成引導式解題教學...",
      generatedCircuit: "Falstad 專用代碼已生成，可直接修改 Step 2，或載入右側模擬器。",
      generatedGuide: "教學指引已生成，可配合右側模擬器帶學生觀察。",
      generatedTutor: "引導式解題教學已生成，可作為課堂提問流程草稿。",
      generateFailed: "生成失敗：",
      noCopy: "目前沒有可複製的內容。",
      copiedCode: "已複製 Falstad 代碼",
      copiedGuide: "已複製教學指引",
      copiedTutor: "已複製解題教學草稿",
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
    examplePrompt:
      "請設計一個簡單電路：包含一個 9V 電池、一個開關，以及兩個串聯的電阻。佈局要清晰，方便學生觀察電流路徑與電壓變化。除非必要，請不要加入文字標籤。",
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
    generateCircuitButton: "Generate Circuit",
    generateGuideButton: "Generate Guide",
    generateTutorButton: "Generate Tutor",
    exampleButton: "Load Example",
    helperText:
      "Generate and refine the Falstad code first. After the circuit is ready, generate the teaching guide and tutoring script separately.",
    step2Label: "Step 2",
    codeSectionTitle: "Falstad Code",
    copyCodeButton: "Copy",
    loadToFalstadButton: "Load Into Simulator",
    falstadCodePlaceholder: "AI-generated Falstad import code will appear here.",
    step3Label: "Step 3",
    guideSectionTitle: "Falstad Teaching Guide",
    copyGuideButton: "Copy",
    teachingGuidePlaceholder: "AI-generated observation points and teaching suggestions will appear here.",
    step4Label: "Step 4",
    tutorSectionTitle: "Guided Tutoring Draft",
    copyTutorButton: "Copy",
    tutorPlaceholder: "AI-generated Socratic prompts, teaching moves, and common misconceptions will appear here.",
    stepRawLabel: "Debug",
    rawSectionTitle: "Raw AI Output",
    copyRawButton: "Copy",
    rawOutputPlaceholder: "Whatever the AI returns will appear here for debugging.",
    step5Label: "Step 5",
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
    flowItem2: "Click Generate Circuit first, then refine the Falstad code directly in Step 2 if needed.",
    flowItem3: "Load the circuit into the simulator and make sure it runs correctly.",
    flowItem4: "After the circuit is stable, generate the teaching guide or tutoring draft separately.",
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
      needCode: "Please generate or paste Falstad code first before running this step.",
      generatingCircuit: "The local backend is asking the AI to generate Falstad code...",
      generatingGuide: "The local backend is generating a teaching guide from the Falstad code...",
      generatingTutor: "The local backend is generating a guided tutoring draft from the Falstad code...",
      generatedCircuit: "Falstad code is ready. You can edit Step 2 directly or load it into the simulator.",
      generatedGuide: "The teaching guide is ready for classroom observation and discussion.",
      generatedTutor: "The guided tutoring draft is ready to use as a lesson flow.",
      generateFailed: "Generation failed: ",
      noCopy: "There is nothing to copy yet.",
      copiedCode: "Falstad code copied",
      copiedGuide: "Teaching guide copied",
      copiedTutor: "Tutoring draft copied",
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
    examplePrompt:
      "Please design a simple circuit with one 9V battery, one switch, and two resistors in series. Keep the layout clear so students can observe current flow and voltage changes. Avoid text labels unless they are truly necessary.",
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
  generateCircuitButton: document.getElementById("generateCircuitButton"),
  generateGuideButton: document.getElementById("generateGuideButton"),
  generateTutorButton: document.getElementById("generateTutorButton"),
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
  step4Label: document.getElementById("step4Label"),
  tutorSectionTitle: document.getElementById("tutorSectionTitle"),
  tutorOutput: document.getElementById("tutorOutput"),
  copyTutorButton: document.getElementById("copyTutorButton"),
  stepRawLabel: document.getElementById("stepRawLabel"),
  rawSectionTitle: document.getElementById("rawSectionTitle"),
  rawAiOutput: document.getElementById("rawAiOutput"),
  copyRawButton: document.getElementById("copyRawButton"),
  step5Label: document.getElementById("step5Label"),
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
let currentLoadingTask = null;

els.langZhButton.addEventListener("click", () => setLanguage("zh-Hant"));
els.langEnButton.addEventListener("click", () => setLanguage("en"));
els.imageInput.addEventListener("change", handleImageUpload);
els.removeImageButton.addEventListener("click", clearImage);
els.exampleButton.addEventListener("click", fillExample);
els.generateCircuitButton.addEventListener("click", () => runGenerationTask("circuit"));
els.generateGuideButton.addEventListener("click", () => runGenerationTask("guide"));
els.generateTutorButton.addEventListener("click", () => runGenerationTask("tutor"));
els.copyCodeButton.addEventListener("click", () => copyText(els.falstadCode.value, t("feedback.copiedCode")));
els.copyGuideButton.addEventListener("click", () => copyText(els.teachingGuide.value, t("feedback.copiedGuide")));
els.copyTutorButton.addEventListener("click", () => copyText(els.tutorOutput.value, t("feedback.copiedTutor")));
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
  refreshActionButtons();
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

  optimizeImageForUpload(file)
    .catch(async (error) => {
      console.warn("Image optimization failed, falling back to the original upload.", error);
      return readFileAsDataUrl(file);
    })
    .then((dataUrl) => {
      uploadedImageDataUrl = typeof dataUrl === "string" ? dataUrl : "";
      els.imagePreview.src = uploadedImageDataUrl;
      els.imagePreviewWrap.classList.remove("hidden");
    })
    .catch((error) => {
      console.error(error);
      clearImage();
      setFeedback(t("feedback.needInput"), true);
      setApiStatus("error");
    });
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

  setLoadingState(task, true);
  setFeedback(t(`feedback.generating${capitalizeTask(task)}`), false);
  clearTaskOutputs(task);

  try {
    const response = await fetch(APP_CONFIG.generateEndpoint, {
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
    });

    const payload = await response.json().catch(() => ({}));
    const rawOutput = payload.raw_output || "";
    els.rawAiOutput.value = rawOutput;

    if (!response.ok) {
      const error = new Error(payload.error || `API request failed with status ${response.status}`);
      error.rawOutput = rawOutput;
      throw error;
    }

    if (task === "circuit") {
      els.falstadCode.value = normalizeGeneratedText(payload.falstad_code, true);
      els.teachingGuide.value = "";
      els.tutorOutput.value = "";
    } else if (task === "guide") {
      els.teachingGuide.value = normalizeGeneratedText(payload.teaching_guide || payload.guide, true);
    } else if (task === "tutor") {
      els.tutorOutput.value = normalizeGeneratedText(payload.tutor_response || payload.tutor_output, true);
    }

    setFeedback(t(`feedback.generated${capitalizeTask(task)}`), false);
    setApiStatus("success");
  } catch (error) {
    console.error(error);
    if (!els.rawAiOutput.value && error.rawOutput) {
      els.rawAiOutput.value = error.rawOutput;
    }
    setFeedback(`${t("feedback.generateFailed")}${translateBackendError(readableErrorMessage(error))}`, true);
    setApiStatus("error");
  } finally {
    setLoadingState(task, false);
  }
}

function translateBackendError(message) {
  if (currentLanguage === "zh-Hant") {
    return message;
  }

  const knownTranslations = {
    "請提供文字需求或圖片。": "Please provide a text request or an image.",
    "請先生成或貼上 Falstad 代碼，再進行這一步。": "Please generate or paste Falstad code first before running this step.",
    "圖片格式無法解析，請重新上載。": "The image format could not be parsed. Please upload it again.",
    "AI 沒有回傳文字內容，請再試一次。": "The AI returned no text. Please try again.",
    "AI 沒有回傳 Falstad 代碼，請再試一次。": "The AI returned no Falstad code. Please try again.",
    "AI 沒有回傳教學指引，請再試一次。": "The AI returned no teaching guide. Please try again.",
    "AI 沒有回傳解題教學內容，請再試一次。": "The AI returned no tutoring content. Please try again.",
    "AI 規劃階段沒有回傳可用內容，請再試一次。": "The AI planning step returned no usable content. Please try again.",
    "AI 回應不是有效 JSON，請再按一次 Generate。": "The AI response was not valid JSON. Please click Generate again.",
    "AI 回應過長，系統已自動改用更精簡版本重試，但仍未完成。請把需求拆細一點，或先生成較簡單的單一電路。":
      "The AI response was too long. The system already retried with a more compact version, but it still did not complete. Please simplify the request or generate a single simple circuit first.",
    "Google API 連線中斷。": "The Google API connection was interrupted.",
    "Google API 連線失敗。": "The Google API connection failed.",
  };

  return knownTranslations[message] || message;
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
